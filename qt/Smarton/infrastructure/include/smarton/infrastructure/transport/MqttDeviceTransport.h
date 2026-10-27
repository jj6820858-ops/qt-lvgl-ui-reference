#pragma once

#include <smarton/services/IDeviceTransport.h>

#include <QtCore/QHash>
#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtCore/QUrl>

QT_BEGIN_NAMESPACE
class QMqttClient;
class QMqttMessage;
QT_END_NAMESPACE

namespace smarton::infrastructure {

/**
 * @brief A real transport, over a real broker. See ADR-0019.
 *
 * MQTT rather than a radio: it reaches actual hardware today through
 * Zigbee2MQTT, Tasmota, ESPHome and the Matter bridges people already run,
 * it needs no 802.15.4 dongle, and standing up a broker costs nothing. What
 * it buys is not the protocol - it is that every layer above
 * `IDeviceTransport` stops being exercised only against a simulator.
 *
 * TOPICS ARE CONFIGURATION. Every ecosystem publishes a different shape:
 * Zigbee2MQTT uses `zigbee2mqtt/<name>` and `.../set`, Tasmota uses
 * `stat/<name>/POWER` and `cmnd/<name>/POWER`, a Matter bridge something else
 * again. Hard-coding one would make this "the Zigbee2MQTT transport" while
 * calling itself the MQTT one, so the two templates are settings with
 * `%1` standing in for the device id.
 *
 * WHAT IT DOES NOT DO, deliberately:
 *  - It does not confirm a command it published. Publishing succeeded means
 *    the broker took the bytes; whether a lamp moved is what the state topic
 *    says afterwards, and `IDeviceTransport` is shaped around exactly that
 *    distinction (ADR-0010).
 *  - It does not reconnect forever in silence. A broker that is down makes
 *    every device unreachable, which is a state the UI already renders, and
 *    a transport that hides an outage behind retries is a panel that lies.
 */
class MqttDeviceTransport final : public services::IDeviceTransport
{
    Q_OBJECT
public:
    explicit MqttDeviceTransport(QObject *parent = nullptr);
    ~MqttDeviceTransport() override;

    /*! Topic a device's reported state arrives on. \c %1 is the device id.
        Default matches Zigbee2MQTT, which is what most people already run. */
    void setStateTopic(const QString &tmpl);
    /*! Topic a command is published to. \c %1 is the device id. */
    void setCommandTopic(const QString &tmpl);
    /*! Payloads for on and off. Zigbee2MQTT and Tasmota both use ON/OFF. */
    void setPayloads(const QString &on, const QString &off);

    /*! Connect to @p url (mqtt://host[:port]). Returns false only when the
        URL is unusable - a broker that is merely down fails asynchronously,
        because that is how brokers actually fail. */
    bool connectToBroker(const QUrl &url);
    [[nodiscard]] bool isConnected() const;
    [[nodiscard]] QString lastError() const { return m_lastError; }

    /*! The devices to subscribe to. Called once with the model's ids: MQTT
        has no discovery of its own that is common across ecosystems, and a
        wildcard subscription would deliver every topic on the broker. */
    void setDeviceIds(const QStringList &deviceIds);

    bool requestPower(const QString &deviceId, bool on) override;
    void refresh() override;

private:
    void onConnected();
    void onDisconnected();
    void onMessage(const QMqttMessage &message);
    [[nodiscard]] QString topicFor(const QString &tmpl, const QString &deviceId) const;
    /*! Which device a state topic belongs to, or empty. Reverse of
        topicFor(): the broker hands back a topic, not an id. */
    [[nodiscard]] QString deviceForTopic(const QString &topic) const;

    QMqttClient *m_client = nullptr;
    QStringList  m_deviceIds;
    QString      m_stateTopic   = QStringLiteral("zigbee2mqtt/%1");
    QString      m_commandTopic = QStringLiteral("zigbee2mqtt/%1/set");
    QString      m_onPayload    = QStringLiteral("ON");
    QString      m_offPayload   = QStringLiteral("OFF");
    QString      m_lastError;
};

} // namespace smarton::infrastructure
