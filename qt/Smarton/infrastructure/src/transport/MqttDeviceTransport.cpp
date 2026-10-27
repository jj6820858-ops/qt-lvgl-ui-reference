#include <smarton/infrastructure/transport/MqttDeviceTransport.h>

#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QJsonParseError>
#include <QtCore/QLoggingCategory>
#include <QtCore/QDateTime>
#include <QtCore/QVariantMap>
#include <QtMqtt/QMqttClient>
#include <QtMqtt/QMqttMessage>
#include <QtMqtt/QMqttSubscription>
#include <QtMqtt/QMqttTopicFilter>
#include <QtMqtt/QMqttTopicName>

namespace smarton::infrastructure {

namespace {
Q_LOGGING_CATEGORY(lcMqtt, "smarton.transport.mqtt")
}

MqttDeviceTransport::MqttDeviceTransport(QObject *parent)
    : services::IDeviceTransport(parent)
    , m_client(new QMqttClient(this))
{
    connect(m_client, &QMqttClient::connected,
            this, &MqttDeviceTransport::onConnected);
    connect(m_client, &QMqttClient::disconnected,
            this, &MqttDeviceTransport::onDisconnected);
    // No client-wide messageReceived handler: messages arrive through the
    // per-device subscriptions made in refresh(), which is what keeps this
    // process from seeing every topic on a shared broker.
}

MqttDeviceTransport::~MqttDeviceTransport() = default;

void MqttDeviceTransport::setStateTopic(const QString &tmpl)   { m_stateTopic = tmpl; }
void MqttDeviceTransport::setCommandTopic(const QString &tmpl) { m_commandTopic = tmpl; }

void MqttDeviceTransport::setPayloads(const QString &on, const QString &off)
{
    m_onPayload = on;
    m_offPayload = off;
}

void MqttDeviceTransport::setDeviceIds(const QStringList &deviceIds)
{
    m_deviceIds = deviceIds;
    if (isConnected())
        refresh();
}

bool MqttDeviceTransport::connectToBroker(const QUrl &url)
{
    if (!url.isValid() || url.host().isEmpty()) {
        m_lastError = QStringLiteral("not a usable broker URL: %1").arg(url.toString());
        return false;
    }

    m_client->setHostname(url.host());
    m_client->setPort(static_cast<quint16>(url.port(1883)));
    if (!url.userName().isEmpty()) {
        m_client->setUsername(url.userName());
        m_client->setPassword(url.password());
    }

    // Asynchronous on purpose. A broker that is down is not a configuration
    // error to report at startup - it is a runtime condition the panel has to
    // keep working through, showing every device unreachable until it comes
    // back. Returning false here for an unreachable host would turn a
    // recoverable outage into a failed boot.
    m_client->connectToHost();
    return true;
}

bool MqttDeviceTransport::isConnected() const
{
    return m_client->state() == QMqttClient::Connected;
}

QString MqttDeviceTransport::topicFor(const QString &tmpl, const QString &deviceId) const
{
    return QString(tmpl).replace(QLatin1String("%1"), deviceId);
}

QString MqttDeviceTransport::deviceForTopic(const QString &topic) const
{
    // Matched against the ids we subscribed for rather than parsed out of the
    // template. A template is a user-supplied string that may put the id
    // anywhere, including in the middle of a segment, and a parser for the
    // general case would be a small grammar for no benefit: the set of ids is
    // known and short.
    for (const QString &id : m_deviceIds) {
        if (topicFor(m_stateTopic, id) == topic)
            return id;
    }
    return {};
}

void MqttDeviceTransport::onConnected()
{
    qCInfo(lcMqtt) << "connected to" << m_client->hostname();
    m_lastError.clear();
    refresh();
}

void MqttDeviceTransport::onDisconnected()
{
    // Everything is unreachable, and the UI is told so device by device
    // rather than through a banner: reachability is already a per-device
    // concept the cards and switches render, and a second, broker-shaped way
    // of saying the same thing would be a second thing to keep in step.
    m_lastError = QStringLiteral("disconnected from the broker");
    qCWarning(lcMqtt) << m_lastError;
    for (const QString &id : m_deviceIds)
        emit reachabilityChanged(id, domain::Reachability::Offline);
}

void MqttDeviceTransport::onMessage(const QMqttMessage &message)
{
    const QString deviceId = deviceForTopic(message.topic().name());
    if (deviceId.isEmpty())
        return;

    // Two payload shapes, because both are common and neither is the
    // standard: Zigbee2MQTT publishes {"state":"ON"} and Tasmota publishes a
    // bare ON. Guessing wrong means a panel that shows every light off.
    const QByteArray raw = message.payload().trimmed();
    QString state = QString::fromUtf8(raw);

    QJsonParseError parse {};
    const QJsonDocument doc = QJsonDocument::fromJson(raw, &parse);
    QVariantMap metadata;
    if (parse.error == QJsonParseError::NoError && doc.isObject()) {
        const QJsonObject object = doc.object();
        if (object.contains(QLatin1String("state")))
            state = object.value(QLatin1String("state")).toString();
        if (object.contains(QLatin1String("battery")))
            metadata.insert(QStringLiteral("batteryPercent"), object.value(QLatin1String("battery")).toInt());
        if (object.contains(QLatin1String("linkquality")))
            metadata.insert(QStringLiteral("signalStrength"), object.value(QLatin1String("linkquality")).toInt());
        if (object.contains(QLatin1String("manufacturer")))
            metadata.insert(QStringLiteral("manufacturer"), object.value(QLatin1String("manufacturer")).toString());
        if (object.contains(QLatin1String("model_id")))
            metadata.insert(QStringLiteral("model"), object.value(QLatin1String("model_id")).toString());
        if (object.contains(QLatin1String("software_build_id")))
            metadata.insert(QStringLiteral("firmware"), object.value(QLatin1String("software_build_id")).toString());
        if (object.contains(QLatin1String("power")))
            metadata.insert(QStringLiteral("powerWatts"), object.value(QLatin1String("power")).toDouble());
        if (object.contains(QLatin1String("energy")))
            metadata.insert(QStringLiteral("energyKwh"), object.value(QLatin1String("energy")).toDouble());
        if (object.contains(QLatin1String("voltage")))
            metadata.insert(QStringLiteral("voltage"), object.value(QLatin1String("voltage")).toDouble());
        if (object.contains(QLatin1String("current")))
            metadata.insert(QStringLiteral("currentAmps"), object.value(QLatin1String("current")).toDouble());
    }

    metadata.insert(QStringLiteral("lastSeen"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    emit metadataReported(deviceId, metadata);

    if (state.compare(m_onPayload, Qt::CaseInsensitive) != 0
        && state.compare(m_offPayload, Qt::CaseInsensitive) != 0) {
        return;
    }

    emit reachabilityChanged(deviceId, domain::Reachability::Online);
    emit powerReported(deviceId, state.compare(m_onPayload, Qt::CaseInsensitive) == 0);
}

bool MqttDeviceTransport::requestPower(const QString &deviceId, bool on)
{
    if (!isConnected()) {
        emit commandFailed(deviceId, QStringLiteral("broker not connected"));
        emit reachabilityChanged(deviceId, domain::Reachability::Offline);
        return false;
    }

    const QString payload = on ? m_onPayload : m_offPayload;
    const qint32 id = m_client->publish(QMqttTopicName(topicFor(m_commandTopic, deviceId)),
                                        payload.toUtf8());
    if (id < 0) {
        emit commandFailed(deviceId, QStringLiteral("publish refused"));
        return false;
    }

    // Sent, NOT confirmed - which is the whole contract of this interface.
    // The device's own state topic is what says whether anything moved, and
    // if it never arrives the command stays pending, which is exactly what
    // the UI is built to show.
    return true;
}

void MqttDeviceTransport::refresh()
{
    if (!isConnected())
        return;

    // One subscription per device rather than a wildcard: a wildcard on a
    // shared broker delivers every topic in the house - other people's
    // integrations, sensor spam, another hub's traffic - and then filters it
    // in this process, on a panel with 1 GB of RAM.
    for (const QString &id : m_deviceIds) {
        auto *subscription = m_client->subscribe(QMqttTopicFilter(topicFor(m_stateTopic, id)));
        if (!subscription) {
            qCWarning(lcMqtt) << "could not subscribe for" << id;
            continue;
        }
        connect(subscription, &QMqttSubscription::messageReceived,
                this, &MqttDeviceTransport::onMessage, Qt::UniqueConnection);
    }
}

} // namespace smarton::infrastructure
