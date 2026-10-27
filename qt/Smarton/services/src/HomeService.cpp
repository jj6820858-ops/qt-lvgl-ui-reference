#include <smarton/services/HomeService.h>

#include <smarton/services/IDeviceTransport.h>

#include <QtCore/QDateTime>
#include <QtCore/QFile>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonParseError>
#include <QtCore/QTimer>

#include <algorithm>

namespace smarton::services {

using namespace smarton::domain;

namespace {

QString str(const QJsonObject &o, const char *key)
{
    return o.value(QLatin1String(key)).toString();
}

qreal num(const QJsonObject &o, const char *key)
{
    return o.value(QLatin1String(key)).toDouble();
}

int intOr(const QJsonObject &o, const char *key, int fallback)
{
    const QJsonValue v = o.value(QLatin1String(key));
    return v.isDouble() ? v.toInt() : fallback;
}

QList<Device> readDevices(const QJsonArray &array)
{
    QList<Device> devices;
    devices.reserve(array.size());
    for (const QJsonValue &value : array) {
        const QJsonObject o = value.toObject();

        // Field by field, not positional aggregate init. Device gained
        // desiredOn and reachability in the MIDDLE of the struct, and the
        // positional form silently slid batteryPercent into desiredOn - the
        // compiler only caught it because bool narrowing is an error. Naming
        // the fields makes the next insertion a non-event.
        Device device;
        device.id = str(o, "id");
        device.roomId = str(o, "roomId");
        device.name = str(o, "name");
        device.kind = str(o, "kind");
        device.imageSource = str(o, "image");
        device.protocol = str(o, "protocol");
        device.gatewayId = str(o, "gatewayId");
        device.manufacturer = str(o, "manufacturer");
        device.model = str(o, "model");
        device.firmwareVersion = str(o, "firmware");
        device.serialNumber = str(o, "serialNumber");
        for (const QJsonValue &capability : o.value(QLatin1String("capabilities")).toArray())
            device.capabilities.append(capability.toString());
        device.on = o.value(QLatin1String("on")).toBool();
        device.desiredOn = device.on;
        device.reachability = Reachability::Unknown;
        device.batteryPercent = intOr(o, "batteryPercent", -1);
        device.volumePercent = intOr(o, "volumePercent", -1);
        device.levelPercent = intOr(o, "levelPercent", -1);
        device.targetC = intOr(o, "targetC", -1);
        device.mode = str(o, "mode");
        device.signalStrength = intOr(o, "signalStrength", -1);
        device.lastSeen = QDateTime::fromString(str(o, "lastSeen"), Qt::ISODate);
        device.stateStale = o.value(QLatin1String("stateStale")).toBool(true);
        device.maxRunSeconds = intOr(o, "maxRunSeconds", 0);
        device.commandTimeoutSeconds = qBound(2, intOr(o, "commandTimeoutSeconds", 20), 3600);
        // Safe-by-default kinds, while retaining an explicit per-device
        // override for a harmless relay that happens to share a generic kind.
        const QStringList dangerousKinds {
            QStringLiteral("lock"), QStringLiteral("gate"),
            QStringLiteral("garage"), QStringLiteral("valve"),
            QStringLiteral("pump"), QStringLiteral("heater")
        };
        device.requiresConfirmation = o.contains(QLatin1String("requiresConfirmation"))
            ? o.value(QLatin1String("requiresConfirmation")).toBool()
            : dangerousKinds.contains(device.kind.toLower());
        device.powerWatts = o.value(QLatin1String("powerWatts")).toDouble(-1.0);
        device.energyKwh = o.value(QLatin1String("energyKwh")).toDouble(-1.0);
        device.voltage = o.value(QLatin1String("voltage")).toDouble(-1.0);
        device.currentAmps = o.value(QLatin1String("currentAmps")).toDouble(-1.0);
        devices.append(device);
    }
    return devices;
}

QJsonArray writeDevices(const QList<Device> &devices)
{
    QJsonArray array;
    for (const Device &d : devices) {
        QJsonArray capabilities;
        for (const QString &capability : d.capabilities)
            capabilities.append(capability);
        array.append(QJsonObject {
            { QStringLiteral("id"),     d.id },
            { QStringLiteral("roomId"), d.roomId },
            { QStringLiteral("name"),   d.name },
            { QStringLiteral("kind"),   d.kind },
            { QStringLiteral("image"),  d.imageSource },
            { QStringLiteral("protocol"), d.protocol },
            { QStringLiteral("gatewayId"), d.gatewayId },
            { QStringLiteral("manufacturer"), d.manufacturer },
            { QStringLiteral("model"), d.model },
            { QStringLiteral("firmware"), d.firmwareVersion },
            { QStringLiteral("serialNumber"), d.serialNumber },
            { QStringLiteral("capabilities"), capabilities },
            { QStringLiteral("on"),     d.on },
            // desiredOn is deliberately NOT stored: nothing is in flight
            // across a restart, so it is always reconstructed as equal to
            // `on`. Persisting it would let a crash mid-command resurrect a
            // pending state with no command behind it.
            { QStringLiteral("batteryPercent"), d.batteryPercent },
            { QStringLiteral("volumePercent"),  d.volumePercent },
            { QStringLiteral("levelPercent"),   d.levelPercent },
            { QStringLiteral("targetC"),        d.targetC },
            { QStringLiteral("mode"),           d.mode },
            { QStringLiteral("signalStrength"), d.signalStrength },
            { QStringLiteral("lastSeen"), d.lastSeen.toUTC().toString(Qt::ISODate) },
            { QStringLiteral("stateStale"), d.stateStale },
            { QStringLiteral("maxRunSeconds"), d.maxRunSeconds },
            { QStringLiteral("commandTimeoutSeconds"), d.commandTimeoutSeconds },
            { QStringLiteral("requiresConfirmation"), d.requiresConfirmation },
            { QStringLiteral("powerWatts"), d.powerWatts },
            { QStringLiteral("energyKwh"), d.energyKwh },
            { QStringLiteral("voltage"), d.voltage },
            { QStringLiteral("currentAmps"), d.currentAmps },
        });
    }
    return array;
}

} // namespace

HomeService::HomeService(QObject *parent)
    : QObject(parent)
{
}

void HomeService::setStore(IHomeStore *store)
{
    m_store = store;
}

void HomeService::setTransport(IDeviceTransport *transport)
{
    if (m_transport == transport)
        return;
    if (m_transport)
        m_transport->disconnect(this);

    m_transport = transport;
    if (!m_transport)
        return;

    connect(m_transport, &IDeviceTransport::powerReported,
            this, &HomeService::onPowerReported);
    connect(m_transport, &IDeviceTransport::reachabilityChanged,
            this, &HomeService::onReachabilityChanged);
    connect(m_transport, &IDeviceTransport::metadataReported,
            this, &HomeService::onMetadataReported);
    connect(m_transport, &IDeviceTransport::commandFailed, this,
            [this](const QString &deviceId, const QString &) {
                const int index = indexOfDevice(deviceId);
                if (index < 0)
                    return;
                // Intent is rolled back to the reported state. Leaving it
                // pending forever would show a switch stuck half-way with no
                // way for the user to retry.
                m_devices[index].desiredOn = m_devices.at(index).on;
                m_devices[index].commandState = QStringLiteral("failed");
                clearCommandTimeout(deviceId);
                persist();
                emit deviceStatusChanged(index);
                emit deviceCommandFailed(deviceId, m_devices.at(index).name);
            });
}

void HomeService::setActor(Role role)
{
    if (m_actor == role)
        return;
    m_actor = role;
    emit actorChanged();
}

bool HomeService::mayOperate() const
{
    return m_actor != Role::Viewer;
}

bool HomeService::mayInstall() const
{
    return m_actor == Role::Installer || m_actor == Role::Administrator
        || m_actor == Role::Owner;
}

bool HomeService::mayAdminister() const
{
    return m_actor == Role::Administrator || m_actor == Role::Owner;
}

bool HomeService::permitted(bool allowed, const char *action)
{
    if (allowed)
        return true;
    // Said once, here, rather than at each of the thirty call sites. A refusal
    // the UI never hears about is indistinguishable from a control that is
    // broken, and "the switch does nothing" is the bug report you get.
    emit refusedByRole(QString::fromLatin1(action));
    return false;
}

void HomeService::onPowerReported(const QString &deviceId, bool on)
{
    const int index = indexOfDevice(deviceId);
    if (index < 0)
        return;

    const bool changed = m_devices.at(index).on != on;
    m_devices[index].on = on;
    // A report is also the truth about intent: if a device was switched at the
    // wall, the panel's idea of what was asked for is stale, not authoritative.
    m_devices[index].desiredOn = on;
    m_devices[index].commandState = QStringLiteral("reported");
    clearCommandTimeout(deviceId);
    m_devices[index].lastSeen = QDateTime::currentDateTimeUtc();
    m_devices[index].stateStale = false;
    updateSafetyTimer(m_devices.at(index));
    persist();

    if (changed)
        emit devicePowerChanged(index, on);
    else
        emit deviceStatusChanged(index);
}

void HomeService::onReachabilityChanged(const QString &deviceId,
                                        domain::Reachability state)
{
    const int index = indexOfDevice(deviceId);
    if (index < 0 || m_devices.at(index).reachability == state)
        return;

    m_devices[index].reachability = state;
    if (state == Reachability::Online) {
        m_devices[index].lastSeen = QDateTime::currentDateTimeUtc();
        m_devices[index].stateStale = false;
    }
    if (state == Reachability::Offline)
        m_devices[index].stateStale = true;
    persist();
    emit deviceStatusChanged(index);
    if (state == Reachability::Online || state == Reachability::Offline)
        emit deviceReachabilityChanged(deviceId, m_devices.at(index).name,
                                       state == Reachability::Online);
}

void HomeService::updateSafetyTimer(const Device &device)
{
    QTimer *&timer = m_safetyTimers[device.id];
    if (!timer) {
        timer = new QTimer(this);
        timer->setSingleShot(true);
        connect(timer, &QTimer::timeout, this, [this, id = device.id] {
            const int index = indexOfDevice(id);
            if (index < 0 || !m_devices.at(index).on)
                return;
            // System actions bypass a panel user's role, but still travel
            // through the normal transport/reporting path and are auditable.
            setDevicePower(id, false, Actor::System);
            emit deviceSafetyTimeout(id, m_devices.at(index).name);
        });
    }
    if (!device.on || device.maxRunSeconds <= 0) {
        timer->stop();
        return;
    }
    timer->start(device.maxRunSeconds * 1000);
}

void HomeService::startCommandTimeout(const QString &deviceId)
{
    const int index = indexOfDevice(deviceId);
    if (index < 0)
        return;

    QTimer *&timer = m_commandTimers[deviceId];
    if (!timer) {
        timer = new QTimer(this);
        timer->setSingleShot(true);
        connect(timer, &QTimer::timeout, this, [this, deviceId] {
            const int current = indexOfDevice(deviceId);
            if (current < 0 || !m_devices.at(current).pending())
                return;
            // A command that never receives a device report is a failure, not
            // an optimistic state. Revert intent and make retry possible.
            m_devices[current].desiredOn = m_devices.at(current).on;
            m_devices[current].commandState = QStringLiteral("timed-out");
            m_devices[current].reachability = Reachability::Offline;
            m_devices[current].stateStale = true;
            persist();
            emit deviceStatusChanged(current);
            emit deviceReachabilityChanged(deviceId, m_devices.at(current).name, false);
            emit deviceCommandFailed(deviceId, m_devices.at(current).name);
        });
    }
    timer->start(m_devices.at(index).commandTimeoutSeconds * 1000);
}

void HomeService::clearCommandTimeout(const QString &deviceId)
{
    if (QTimer *timer = m_commandTimers.value(deviceId, nullptr))
        timer->stop();
}

void HomeService::onMetadataReported(const QString &deviceId, const QVariantMap &metadata)
{
    const int index = indexOfDevice(deviceId);
    if (index < 0)
        return;

    Device &device = m_devices[index];
    if (metadata.contains(QStringLiteral("batteryPercent")))
        device.batteryPercent = metadata.value(QStringLiteral("batteryPercent")).toInt();
    if (metadata.contains(QStringLiteral("signalStrength")))
        device.signalStrength = metadata.value(QStringLiteral("signalStrength")).toInt();
    if (metadata.contains(QStringLiteral("manufacturer")))
        device.manufacturer = metadata.value(QStringLiteral("manufacturer")).toString();
    if (metadata.contains(QStringLiteral("model")))
        device.model = metadata.value(QStringLiteral("model")).toString();
    if (metadata.contains(QStringLiteral("firmware")))
        device.firmwareVersion = metadata.value(QStringLiteral("firmware")).toString();
    if (metadata.contains(QStringLiteral("serialNumber")))
        device.serialNumber = metadata.value(QStringLiteral("serialNumber")).toString();
    if (metadata.contains(QStringLiteral("capabilities")))
        device.capabilities = metadata.value(QStringLiteral("capabilities")).toStringList();
    if (metadata.contains(QStringLiteral("powerWatts")))
        device.powerWatts = metadata.value(QStringLiteral("powerWatts")).toDouble();
    if (metadata.contains(QStringLiteral("energyKwh")))
        device.energyKwh = metadata.value(QStringLiteral("energyKwh")).toDouble();
    if (metadata.contains(QStringLiteral("voltage")))
        device.voltage = metadata.value(QStringLiteral("voltage")).toDouble();
    if (metadata.contains(QStringLiteral("currentAmps")))
        device.currentAmps = metadata.value(QStringLiteral("currentAmps")).toDouble();
    const QDateTime reported = QDateTime::fromString(
        metadata.value(QStringLiteral("lastSeen")).toString(), Qt::ISODate);
    device.lastSeen = reported.isValid() ? reported.toUTC() : QDateTime::currentDateTimeUtc();
    device.stateStale = false;
    const int roomIndex = indexOfRoom(device.roomId);
    if (roomIndex >= 0) {
        qreal watts = 0.0;
        for (const Device &candidate : m_devices) {
            if (candidate.roomId == device.roomId && candidate.powerWatts >= 0.0)
                watts += candidate.powerWatts;
        }
        m_rooms[roomIndex].energyKw = watts / 1000.0;
        emit roomChanged(roomIndex);
    }
    persist();
    emit deviceStatusChanged(index);
}

QString HomeService::makeId(const QString &prefix)
{
    // Monotonic and readable. Not a UUID: these ids are local to one panel's
    // database and end up in log lines, where "room-1788100031472" is far
    // easier to follow than a 36-character hex string.
    return QStringLiteral("%1-%2").arg(prefix)
            .arg(QDateTime::currentMSecsSinceEpoch());
}

bool HomeService::load(const QString &seedResourcePath)
{
    if (m_store) {
        const QJsonObject stored = m_store->load();
        if (!stored.isEmpty() && readModel(stored)) {
            emit reloaded();
            return true;
        }
    }

    QFile file(seedResourcePath);
    if (!file.open(QIODevice::ReadOnly)) {
        m_lastError = QStringLiteral("cannot open %1").arg(seedResourcePath);
        return false;
    }

    QJsonParseError parseError {};
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        m_lastError = QStringLiteral("%1: %2").arg(seedResourcePath,
                                                   parseError.errorString());
        return false;
    }

    if (!readModel(doc.object()))
        return false;

    // First run: the factory defaults become the live model.
    persist();
    emit reloaded();
    return true;
}

bool HomeService::resetToDefaults(const QString &seedResourcePath)
{
    // A factory reset is the most administrative thing in the file.
    if (!permitted(mayAdminister(), "administer"))
        return false;

    if (m_store)
        m_store->save(QJsonObject {});
    return load(seedResourcePath);
}

bool HomeService::readModel(const QJsonObject &root)
{
    // The one check worth making before touching anything: does this object
    // look like a home model at all? Not "is every field valid" - a model
    // with a nonsense room area is still a model, and clamping beats
    // rejecting (ADR-0002). But an object with none of these keys is a
    // different kind of file entirely, and reading it would empty the house.
    static const QStringList expected {
        // "spaces" is the shape this class writes; the other three are the
        // single-space shape it still reads. Leaving "spaces" out of this
        // list would mean the first model this class SAVED was a model it
        // then refused to load - which is the kind of bug that only appears
        // on the second run.
        QStringLiteral("spaces"),
        QStringLiteral("space"), QStringLiteral("rooms"), QStringLiteral("devices"),
    };
    bool recognised = false;
    for (const QString &key : expected)
        recognised = recognised || root.contains(key);
    if (!recognised) {
        m_lastError = QStringLiteral("that is not a home model");
        return false;
    }

    m_loading = true;

    // MEMBERS ARE THE HOUSEHOLD'S, not a building's. A person with an account
    // does not stop being one when the panel is showing the cabin, and
    // copying them into every space would mean a rename that takes in one
    // place and not the others.
    readMembers(root.value(QLatin1String("members")).toArray());

    if (root.contains(QLatin1String("spaces"))) {
        m_spaceModels = root.value(QLatin1String("spaces")).toArray();
        m_activeSpaceId = str(root, "activeSpaceId");
    } else {
        // THE OLD SHAPE, and the migration is that it is still a legal one:
        // a snapshot written before there could be two spaces IS a single
        // space's model, so it becomes the only entry in the array. No
        // conversion pass, no version number, nothing to get wrong on the
        // one run that does it.
        m_spaceModels = QJsonArray { root };
        m_activeSpaceId = root.value(QLatin1String("space"))
                              .toObject().value(QLatin1String("id")).toString();
    }

    if (indexOfSpaceModel(m_activeSpaceId) < 0) {
        // A stored active id naming a space that is gone - hand-edited file,
        // or a delete that did not finish. The first space is a better answer
        // than none, and none means a panel that shows nothing and says
        // nothing about why.
        m_activeSpaceId = m_spaceModels.isEmpty()
            ? QString()
            : m_spaceModels.first().toObject().value(QLatin1String("space"))
                  .toObject().value(QLatin1String("id")).toString();
    }

    const int active = indexOfSpaceModel(m_activeSpaceId);
    readSpace(active >= 0 ? m_spaceModels.at(active).toObject() : root);

    m_loading = false;
    m_lastError.clear();
    return true;
}

void HomeService::readMembers(const QJsonArray &memberArray)
{
    m_members.clear();
    m_members.reserve(memberArray.size());
    for (const QJsonValue &value : memberArray) {
        const QJsonObject o = value.toObject();
        Member member;
        member.id = str(o, "id");
        member.name = str(o, "name");
        member.email = str(o, "email");
        member.phone = str(o, "phone");
        member.avatarSource = str(o, "avatar");
        member.online = o.value(QLatin1String("online")).toBool();
        // toDouble, not toInt: QJsonValue stores every number as a double and
        // toInt() silently returns 0 for anything that does not fit, which
        // would quietly unlink an account rather than fail loudly.
        member.accountId = qint64(o.value(QLatin1String("accountId")).toDouble());
        m_members.append(member);
    }
}

void HomeService::readSpace(const QJsonObject &root)
{
    const QJsonObject spaceObject = root.value(QLatin1String("space")).toObject();
    m_space.id = str(spaceObject, "id");
    m_space.name = str(spaceObject, "name");
    m_space.address = str(spaceObject, "address");
    m_space.imageSource = str(spaceObject, "image");

    const QJsonObject weatherObject = root.value(QLatin1String("weather")).toObject();
    m_weather.description = str(weatherObject, "description");
    m_weather.temperatureC = num(weatherObject, "temperatureC");
    m_weather.humidityPercent = num(weatherObject, "humidityPercent");

    m_rooms.clear();
    const QJsonArray roomArray = root.value(QLatin1String("rooms")).toArray();
    m_rooms.reserve(roomArray.size());
    for (const QJsonValue &value : roomArray) {
        const QJsonObject o = value.toObject();
        Room room;
        room.id = str(o, "id");
        room.spaceId = m_space.id;
        room.name = str(o, "name");
        room.areaSqm = num(o, "areaSqm");
        room.floor = o.value(QLatin1String("floor")).toInt();
        room.imageSource = str(o, "image");
        room.temperatureC = num(o, "temperatureC");
        room.humidityPercent = num(o, "humidityPercent");
        room.energyKw = num(o, "energyKw");
        m_rooms.append(room);
    }

    // readDevices() sets desiredOn == on: a stored snapshot records reported
    // state, and nothing is in flight across a restart, so nothing comes back
    // from a reboot looking pending.
    m_devices   = readDevices(root.value(QLatin1String("devices")).toArray());
    m_available = readDevices(root.value(QLatin1String("availableDevices")).toArray());

    m_scenes.clear();
    const QJsonArray sceneArray = root.value(QLatin1String("scenes")).toArray();
    m_scenes.reserve(sceneArray.size());
    for (const QJsonValue &value : sceneArray) {
        const QJsonObject o = value.toObject();
        Scene scene;
        scene.id = str(o, "id");
        scene.roomId = str(o, "roomId");
        scene.name = str(o, "name");
        scene.days = str(o, "days");
        scene.timeRange = str(o, "timeRange");
        scene.enabled = o.value(QLatin1String("enabled")).toBool();
        // Absent in every snapshot written before scenes could name devices,
        // which reads as empty and means "the room" - the behaviour those
        // snapshots were written under. The migration is that the old shape
        // is still a legal value with the same meaning.
        const QJsonArray actionArray = o.value(QLatin1String("actions")).toArray();
        for (const QJsonValue &entry : actionArray) {
            const QJsonObject a = entry.toObject();
            SceneAction action;
            action.deviceId = str(a, "deviceId");
            if (action.deviceId.isEmpty())
                continue;
            action.on = a.value(QLatin1String("on")).toBool(true);
            action.levelPercent = intOr(a, "levelPercent", -1);
            action.targetC = intOr(a, "targetC", -1);
            scene.actions.append(action);
        }
        m_scenes.append(scene);
    }

}

QJsonObject HomeService::writeSpace() const
{
    QJsonArray roomArray;
    for (const Room &r : m_rooms) {
        roomArray.append(QJsonObject {
            { QStringLiteral("id"),      r.id },
            { QStringLiteral("name"),    r.name },
            { QStringLiteral("areaSqm"), r.areaSqm },
            { QStringLiteral("floor"),   r.floor },
            { QStringLiteral("image"),   r.imageSource },
            { QStringLiteral("temperatureC"),    r.temperatureC },
            { QStringLiteral("humidityPercent"), r.humidityPercent },
            { QStringLiteral("energyKw"),        r.energyKw },
        });
    }

    QJsonArray sceneArray;
    for (const Scene &s : m_scenes) {
        QJsonArray actionArray;
        for (const SceneAction &a : s.actions) {
            actionArray.append(QJsonObject {
                { QStringLiteral("deviceId"),     a.deviceId },
                { QStringLiteral("on"),           a.on },
                { QStringLiteral("levelPercent"), a.levelPercent },
                { QStringLiteral("targetC"),      a.targetC },
            });
        }

        sceneArray.append(QJsonObject {
            { QStringLiteral("id"),        s.id },
            { QStringLiteral("roomId"),    s.roomId },
            { QStringLiteral("name"),      s.name },
            { QStringLiteral("days"),      s.days },
            { QStringLiteral("timeRange"), s.timeRange },
            { QStringLiteral("enabled"),   s.enabled },
            // Always written, even when empty. A key that appears only
            // sometimes is a key a reader has to guess about, and an empty
            // array says "this scene takes a room" out loud.
            { QStringLiteral("actions"),   actionArray },
        });
    }

    return QJsonObject {
        { QStringLiteral("space"), QJsonObject {
            { QStringLiteral("id"),      m_space.id },
            { QStringLiteral("name"),    m_space.name },
            { QStringLiteral("address"), m_space.address },
            { QStringLiteral("image"),   m_space.imageSource },
        } },
        { QStringLiteral("weather"), QJsonObject {
            { QStringLiteral("description"),     m_weather.description },
            { QStringLiteral("temperatureC"),    m_weather.temperatureC },
            { QStringLiteral("humidityPercent"), m_weather.humidityPercent },
        } },
        { QStringLiteral("rooms"),   roomArray },
        { QStringLiteral("devices"), writeDevices(m_devices) },
        { QStringLiteral("availableDevices"), writeDevices(m_available) },
        { QStringLiteral("scenes"),  sceneArray },
    };
}

QJsonObject HomeService::writeModel() const
{
    QJsonArray memberArray;
    for (const Member &m : m_members) {
        memberArray.append(QJsonObject {
            { QStringLiteral("id"),     m.id },
            { QStringLiteral("name"),   m.name },
            { QStringLiteral("email"),  m.email },
            { QStringLiteral("phone"),  m.phone },
            { QStringLiteral("avatar"), m.avatarSource },
            { QStringLiteral("online"), m.online },
            { QStringLiteral("accountId"), double(m.accountId) },
        });
    }

    // The live space is written back over its stored copy HERE, on the way
    // out, rather than being kept in step on every edit. Two copies that must
    // agree at all times is the bug; one copy that becomes authoritative at a
    // known moment is not - and persist() is that moment for everything else
    // in this class already.
    QJsonArray spaces = m_spaceModels;
    const int active = indexOfSpaceModel(m_activeSpaceId);
    if (active >= 0)
        spaces[active] = writeSpace();
    else if (!m_space.id.isEmpty())
        spaces.append(writeSpace());

    return QJsonObject {
        { QStringLiteral("activeSpaceId"), m_activeSpaceId },
        { QStringLiteral("spaces"),        spaces },
        { QStringLiteral("members"),       memberArray },
    };
}

int HomeService::indexOfSpaceModel(const QString &spaceId) const
{
    if (spaceId.isEmpty())
        return -1;
    for (int i = 0; i < m_spaceModels.size(); ++i) {
        const QJsonObject entry = m_spaceModels.at(i).toObject();
        if (entry.value(QLatin1String("space")).toObject()
                 .value(QLatin1String("id")).toString() == spaceId) {
            return i;
        }
    }
    return -1;
}

QList<Space> HomeService::spaces() const
{
    QList<Space> out;
    out.reserve(m_spaceModels.size());
    for (const QJsonValue &value : m_spaceModels) {
        const QJsonObject object = value.toObject()
                                       .value(QLatin1String("space")).toObject();
        Space space;
        space.id = str(object, "id");
        // The ACTIVE space comes from the live fields, not from its stored
        // copy: renaming it has to show in the picker before the rename is
        // written back, which is on the next persist().
        if (space.id == m_activeSpaceId) {
            out.append(m_space);
            continue;
        }
        space.name = str(object, "name");
        space.address = str(object, "address");
        space.imageSource = str(object, "image");
        out.append(space);
    }
    return out;
}

void HomeService::switchTo(const QString &spaceId)
{
    const int target = indexOfSpaceModel(spaceId);
    if (target < 0)
        return;

    // Park the live one first. Without this, everything done since the last
    // persist() to the space being left is lost - which is every edit, because
    // persist() writes the stored copy from these same fields.
    const int current = indexOfSpaceModel(m_activeSpaceId);
    if (current >= 0)
        m_spaceModels[current] = writeSpace();

    m_activeSpaceId = spaceId;
    m_loading = true;
    readSpace(m_spaceModels.at(target).toObject());
    m_loading = false;

    persist();
    emit reloaded();
    emit spacesChanged();
}

bool HomeService::setActiveSpace(const QString &spaceId)
{
    if (!permitted(mayOperate(), "operate"))
        return false;
    if (spaceId == m_activeSpaceId || indexOfSpaceModel(spaceId) < 0)
        return false;

    switchTo(spaceId);
    return true;
}

QString HomeService::addSpace(const QString &name, const QString &address,
                              const QString &imageSource)
{
    if (!permitted(mayAdminister(), "administer"))
        return {};

    const QString cleaned = sanitiseName(name);
    if (cleaned.isEmpty())
        return {};

    // Park the live one before the array grows, so writeSpace() below is
    // describing the NEW space rather than half of the old one.
    const int current = indexOfSpaceModel(m_activeSpaceId);
    if (current >= 0)
        m_spaceModels[current] = writeSpace();

    Space space;
    space.id = makeId(QStringLiteral("space"));
    space.name = cleaned;
    space.address = address.simplified();
    space.imageSource = imageSource.isEmpty()
        ? QStringLiteral("images/rooms/house-exterior.png") : imageSource;

    m_spaceModels.append(QJsonObject {
        { QStringLiteral("space"), QJsonObject {
            { QStringLiteral("id"),      space.id },
            { QStringLiteral("name"),    space.name },
            { QStringLiteral("address"), space.address },
            { QStringLiteral("image"),   space.imageSource },
        } },
        // No weather, no rooms, no devices. A new space is empty and the
        // screens already know what to draw for that - it is the state the
        // whole setup wizard exists to get you out of.
        { QStringLiteral("rooms"),   QJsonArray {} },
        { QStringLiteral("devices"), QJsonArray {} },
        { QStringLiteral("availableDevices"), QJsonArray {} },
        { QStringLiteral("scenes"),  QJsonArray {} },
    });

    switchTo(space.id);
    return space.id;
}

bool HomeService::removeSpace(const QString &spaceId)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const int target = indexOfSpaceModel(spaceId);
    if (target < 0)
        return false;
    // A panel with no space shows the empty state with no way out of it. The
    // setup wizard is how you get a first space; this is not how you get rid
    // of the last one.
    if (m_spaceModels.size() <= 1)
        return false;

    const bool removingActive = spaceId == m_activeSpaceId;
    m_spaceModels.removeAt(target);

    if (removingActive) {
        // Straight to the first survivor, WITHOUT parking the space that no
        // longer exists - switchTo() would write it back into the array it
        // was just removed from.
        m_activeSpaceId = m_spaceModels.first().toObject()
                              .value(QLatin1String("space")).toObject()
                              .value(QLatin1String("id")).toString();
        m_loading = true;
        readSpace(m_spaceModels.first().toObject());
        m_loading = false;
    }

    persist();
    emit reloaded();
    emit spacesChanged();
    return true;
}

void HomeService::persist()
{
    if (!m_store || m_loading)
        return;
    if (!m_store->save(writeModel()))
        m_lastError = QStringLiteral("could not save the home model");
}

// ---- queries ---------------------------------------------------------------

QList<Device> HomeService::devicesInRoom(const QString &roomId) const
{
    QList<Device> out;
    for (const Device &device : m_devices) {
        if (device.roomId == roomId)
            out.append(device);
    }
    return out;
}

QList<Device> HomeService::lowBatteryDevices() const
{
    QList<Device> out;
    for (const Device &device : m_devices) {
        if (device.batteryPercent < 0)
            continue;                 // mains powered: no battery, not a flat one
        if (device.batteryPercent <= kLowBatteryPercent)
            out.append(device);
    }
    return out;
}

QList<Scene> HomeService::scenesInRoom(const QString &roomId) const
{
    QList<Scene> out;
    for (const Scene &scene : m_scenes) {
        if (roomId.isEmpty() || scene.roomId == roomId || scene.roomId.isEmpty())
            out.append(scene);
    }
    return out;
}

int HomeService::deviceCountInRoom(const QString &roomId) const
{
    int count = 0;
    for (const Device &device : m_devices) {
        if (device.roomId == roomId)
            ++count;
    }
    return count;
}

QString HomeService::roomName(const QString &roomId) const
{
    for (const Room &room : m_rooms) {
        if (room.id == roomId)
            return room.name;
    }
    return {};
}

int HomeService::indexOfDevice(const QString &deviceId) const
{
    for (int i = 0; i < m_devices.size(); ++i) {
        if (m_devices.at(i).id == deviceId)
            return i;
    }
    return -1;
}

int HomeService::indexOfRoom(const QString &roomId) const
{
    for (int i = 0; i < m_rooms.size(); ++i) {
        if (m_rooms.at(i).id == roomId)
            return i;
    }
    return -1;
}

int HomeService::indexOfScene(const QString &sceneId) const
{
    for (int i = 0; i < m_scenes.size(); ++i) {
        if (m_scenes.at(i).id == sceneId)
            return i;
    }
    return -1;
}

// ---- toggles ---------------------------------------------------------------

bool HomeService::setDevicePower(const QString &deviceId, bool on, Actor by)
{
    if (by == Actor::User && !permitted(mayOperate(), "operate"))
        return false;

    const int index = indexOfDevice(deviceId);
    if (index < 0)
        return false;

    if (!m_transport) {
        // No hardware behind this build: intent IS state, and adding an
        // artificial delay to a simulation would only make it feel broken.
        if (m_devices.at(index).on == on && m_devices.at(index).desiredOn == on)
            return true;
        m_devices[index].on = on;
        m_devices[index].desiredOn = on;
        m_devices[index].commandState = QStringLiteral("reported");
        m_devices[index].lastSeen = QDateTime::currentDateTimeUtc();
        m_devices[index].stateStale = false;
        updateSafetyTimer(m_devices.at(index));
        persist();
        emit deviceCommandRequested(deviceId, m_devices.at(index).name, on, by);
        emit devicePowerChanged(index, on);
        return true;
    }

    // Idempotency at the panel boundary: repeating a tap/retry while the
    // identical command is in flight must never publish a second relay toggle.
    if (m_devices.at(index).desiredOn == on)
        return true;

    // Record the intent and ask. `on` does NOT move here - that is the whole
    // point of the split, and the reason the switch reports rather than
    // toggling itself.
    m_devices[index].desiredOn = on;
    m_devices[index].commandState = QStringLiteral("queued");
    persist();
    emit deviceStatusChanged(index);

    if (!m_transport->requestPower(deviceId, on)) {
        m_devices[index].desiredOn = m_devices.at(index).on;
        m_devices[index].commandState = QStringLiteral("failed");
        persist();
        emit deviceStatusChanged(index);
        emit deviceCommandFailed(deviceId, m_devices.at(index).name);
        return false;
    }
    m_devices[index].commandState = QStringLiteral("sent");
    persist();
    emit deviceStatusChanged(index);
    emit deviceCommandRequested(deviceId, m_devices.at(index).name, on, by);
    startCommandTimeout(deviceId);
    return true;
}

bool HomeService::toggleDevicePower(const QString &deviceId, Actor by)
{
    const int index = indexOfDevice(deviceId);
    if (index < 0)
        return false;
    // No permission check here: setDevicePower does it, and doing it twice
    // would emit the refusal twice for one press.
    return setDevicePower(deviceId, !m_devices.at(index).desiredOn, by);
}

bool HomeService::setSceneEnabled(const QString &sceneId, bool enabled, Actor by)
{
    if (by == Actor::User && !permitted(mayOperate(), "operate"))
        return false;

    const int index = indexOfScene(sceneId);
    if (index < 0)
        return false;
    if (m_scenes.at(index).enabled == enabled)
        return true;

    m_scenes[index].enabled = enabled;
    persist();
    emit sceneEnabledChanged(index, enabled);
    return true;
}

// ---- renames ---------------------------------------------------------------

QString HomeService::sanitiseName(const QString &name)
{
    // Trim, collapse runs of whitespace, and cap the length. A name is shown
    // in a fixed-width tile, so an unbounded one is a layout bug waiting to
    // happen - and a name that is only spaces is not a name.
    QString cleaned = name.simplified();
    constexpr int kMaxNameLength = 48;
    if (cleaned.size() > kMaxNameLength)
        cleaned.truncate(kMaxNameLength);
    return cleaned;
}

bool HomeService::renameSpace(const QString &name)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const QString cleaned = sanitiseName(name);
    if (cleaned.isEmpty() || cleaned == m_space.name)
        return false;

    m_space.name = cleaned;
    persist();
    emit spaceChanged();
    return true;
}

bool HomeService::setSpaceAddress(const QString &address)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const QString cleaned = address.simplified();
    if (cleaned == m_space.address)
        return false;

    m_space.address = cleaned;
    persist();
    emit spaceChanged();
    return true;
}

bool HomeService::renameRoom(const QString &roomId, const QString &name)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const int index = indexOfRoom(roomId);
    const QString cleaned = sanitiseName(name);
    if (index < 0 || cleaned.isEmpty() || cleaned == m_rooms.at(index).name)
        return false;

    m_rooms[index].name = cleaned;
    persist();
    emit roomChanged(index);
    return true;
}

bool HomeService::renameDevice(const QString &deviceId, const QString &name)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const int index = indexOfDevice(deviceId);
    const QString cleaned = sanitiseName(name);
    if (index < 0 || cleaned.isEmpty() || cleaned == m_devices.at(index).name)
        return false;

    m_devices[index].name = cleaned;
    persist();
    emit deviceChanged(index);
    return true;
}

bool HomeService::renameScene(const QString &sceneId, const QString &name)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const int index = indexOfScene(sceneId);
    const QString cleaned = sanitiseName(name);
    if (index < 0 || cleaned.isEmpty() || cleaned == m_scenes.at(index).name)
        return false;

    m_scenes[index].name = cleaned;
    persist();
    emit sceneChanged(index);
    return true;
}

// ---- structure -------------------------------------------------------------

bool HomeService::createSpace(const QString &name, const QString &address)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const QString cleaned = sanitiseName(name);
    if (cleaned.isEmpty())
        return false;

    if (m_space.id.isEmpty())
        m_space.id = makeId(QStringLiteral("space"));
    // The first space is also the active one. Without this the stored
    // activeSpaceId is empty and the next load falls back to "the first
    // entry" - which is right, but by accident rather than by record.
    m_activeSpaceId = m_space.id;
    m_space.name = cleaned;
    m_space.address = address.simplified();
    if (m_space.imageSource.isEmpty())
        m_space.imageSource = QStringLiteral("images/rooms/house-exterior.png");

    persist();
    emit spaceChanged();
    emit reloaded();
    return true;
}

QString HomeService::addRoom(const QString &name, qreal areaSqm,
                             const QString &imageSource)
{
    return addRoom(name, areaSqm, imageSource, 0);
}

QString HomeService::addRoom(const QString &name, qreal areaSqm,
                             const QString &imageSource, int floor)
{
    if (!permitted(mayAdminister(), "administer"))
        return {};

    const QString cleaned = sanitiseName(name);
    if (cleaned.isEmpty())
        return {};

    Room room;
    room.id = makeId(QStringLiteral("room"));
    room.spaceId = m_space.id;
    room.name = cleaned;
    // Clamped like the area, and for the same reason. The bounds are a
    // basement and a tower block; anything outside them is a typo, and a plan
    // that stacks forty empty storeys to reach one room is not a plan.
    room.floor = qBound(-2, floor, 20);
    // Clamped rather than rejected: a slider that snaps back tells the user
    // nothing, and a room is not zero or a thousand square metres.
    room.areaSqm = qBound(1.0, areaSqm, 500.0);
    room.imageSource = imageSource.isEmpty()
                           ? QStringLiteral("images/rooms/living-sofa.png")
                           : imageSource;
    room.temperatureC = m_weather.temperatureC;
    room.humidityPercent = m_weather.humidityPercent;
    room.energyKw = 0;

    m_rooms.append(room);
    persist();
    emit reloaded();
    return room.id;
}

bool HomeService::setRoomFloor(const QString &roomId, int floor)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const int index = indexOfRoom(roomId);
    if (index < 0)
        return false;

    const int clamped = qBound(-2, floor, 20);
    if (m_rooms[index].floor == clamped)
        return true;

    m_rooms[index].floor = clamped;
    persist();
    emit roomChanged(index);
    return true;
}

bool HomeService::removeRoom(const QString &roomId)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const int index = indexOfRoom(roomId);
    if (index < 0)
        return false;

    // Devices in the room go back to the available pool rather than being
    // deleted with it. The hardware still exists; only the grouping went away.
    for (int i = m_devices.size() - 1; i >= 0; --i) {
        if (m_devices.at(i).roomId != roomId)
            continue;
        Device device = m_devices.takeAt(i);
        device.roomId.clear();
        device.on = false;
        device.desiredOn = false;
        device.reachability = Reachability::Unknown;
        m_available.append(device);
    }

    for (int i = m_scenes.size() - 1; i >= 0; --i) {
        if (m_scenes.at(i).roomId == roomId)
            m_scenes.removeAt(i);
    }

    m_rooms.removeAt(index);
    persist();
    emit reloaded();
    return true;
}

bool HomeService::linkDevice(const QString &availableId, const QString &roomId)
{
    if (!permitted(mayInstall(), "install"))
        return false;

    for (int i = 0; i < m_available.size(); ++i) {
        if (m_available.at(i).id != availableId)
            continue;

        Device device = m_available.takeAt(i);
        device.roomId = roomId;
        m_devices.append(device);
        persist();
        emit reloaded();
        return true;
    }
    return false;
}

QString HomeService::addManualDevice(const QString &name, const QString &kind,
                                     const QString &roomId, const QString &protocol)
{
    if (!permitted(mayInstall(), "install"))
        return {};

    const QString cleanedName = sanitiseName(name);
    const QString cleanedKind = kind.trimmed().toLower();
    if (cleanedName.isEmpty() || cleanedKind.isEmpty())
        return {};
    if (!roomId.isEmpty() && indexOfRoom(roomId) < 0)
        return {};

    Device device;
    device.id = makeId(QStringLiteral("device"));
    device.name = cleanedName;
    device.kind = cleanedKind;
    device.roomId = roomId;
    device.protocol = protocol.trimmed().isEmpty() ? QStringLiteral("manual")
                                                    : protocol.trimmed().toLower();
    device.stateStale = true;
    // Use an existing bundled illustration immediately. A manually created
    // device is useful before its gateway exists, and it must not look like a
    // broken blank tile simply because no vendor image has been provisioned.
    if (cleanedKind == QLatin1String("lamp"))
        device.imageSource = QStringLiteral("images/devices/pendant-lamp.png");
    else if (cleanedKind == QLatin1String("conditioner")
             || cleanedKind == QLatin1String("thermostat")
             || cleanedKind == QLatin1String("heater"))
        device.imageSource = QStringLiteral("images/devices/air-purifier.png");
    else if (cleanedKind == QLatin1String("speaker"))
        device.imageSource = QStringLiteral("images/devices/speaker.png");
    else
        device.imageSource = QStringLiteral("images/devices/sensor-hub.png");

    // Small capability catalogue rather than vendor-specific screen branches.
    // A gateway may enrich it later through metadataReported().
    if (cleanedKind == QLatin1String("lamp"))
        device.capabilities = { QStringLiteral("onOff"), QStringLiteral("level") };
    else if (cleanedKind == QLatin1String("conditioner") || cleanedKind == QLatin1String("thermostat"))
        device.capabilities = { QStringLiteral("onOff"), QStringLiteral("thermostat"),
                                QStringLiteral("fan"), QStringLiteral("mode") };
    else if (cleanedKind == QLatin1String("sensor") || cleanedKind == QLatin1String("leak"))
        device.capabilities = { QStringLiteral("sensor") };
    else if (cleanedKind == QLatin1String("lock"))
        device.capabilities = { QStringLiteral("lock") };
    else if (cleanedKind == QLatin1String("cover"))
        device.capabilities = { QStringLiteral("cover") };
    else
        device.capabilities = { QStringLiteral("onOff") };

    device.requiresConfirmation = cleanedKind == QLatin1String("lock")
        || cleanedKind == QLatin1String("gate") || cleanedKind == QLatin1String("garage")
        || cleanedKind == QLatin1String("valve") || cleanedKind == QLatin1String("pump")
        || cleanedKind == QLatin1String("heater");
    m_devices.append(device);
    persist();
    emit reloaded();
    return device.id;
}

bool HomeService::replaceDevice(const QString &deviceId, const QString &availableId)
{
    if (!permitted(mayInstall(), "install"))
        return false;

    const int oldIndex = indexOfDevice(deviceId);
    if (oldIndex < 0)
        return false;
    int availableIndex = -1;
    for (int i = 0; i < m_available.size(); ++i) {
        if (m_available.at(i).id == availableId) {
            availableIndex = i;
            break;
        }
    }
    if (availableIndex < 0)
        return false;

    const Device old = m_devices.at(oldIndex);
    Device replacement = m_available.takeAt(availableIndex);
    // Preserve household intent, not transport identity. The replacement's
    // id/protocol/gateway data must remain its own so commands reach the new
    // hardware, while name/room are what a person expects not to re-enter.
    replacement.roomId = old.roomId;
    replacement.name = old.name;
    replacement.maxRunSeconds = old.maxRunSeconds;
    replacement.on = false;
    replacement.desiredOn = false;
    replacement.reachability = Reachability::Unknown;
    replacement.stateStale = true;
    replacement.commandState = QStringLiteral("idle");
    m_devices[oldIndex] = replacement;

    // Scene actions name integration ids. Replace every one atomically with
    // the device swap so a morning scene cannot turn into a no-op tomorrow.
    for (Scene &scene : m_scenes) {
        for (SceneAction &action : scene.actions) {
            if (action.deviceId == old.id)
                action.deviceId = replacement.id;
        }
    }
    persist();
    emit reloaded();
    return true;
}

bool HomeService::unlinkDevice(const QString &deviceId)
{
    if (!permitted(mayInstall(), "install"))
        return false;

    const int index = indexOfDevice(deviceId);
    if (index < 0)
        return false;

    Device device = m_devices.takeAt(index);
    device.roomId.clear();
    device.on = false;
    device.desiredOn = false;
    device.reachability = Reachability::Unknown;
    m_available.append(device);
    persist();
    emit reloaded();
    return true;
}

bool HomeService::setDeviceRoom(const QString &deviceId, const QString &roomId)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const int index = indexOfDevice(deviceId);
    if (index < 0 || m_devices.at(index).roomId == roomId)
        return false;

    m_devices[index].roomId = roomId;
    persist();
    emit deviceChanged(index);
    emit reloaded();
    return true;
}

bool HomeService::setDeviceMaxRunSeconds(const QString &deviceId, int seconds)
{
    if (!permitted(mayInstall(), "install"))
        return false;

    const int index = indexOfDevice(deviceId);
    if (index < 0)
        return false;
    const int safeSeconds = qBound(0, seconds, 8 * 60 * 60);
    if (m_devices.at(index).maxRunSeconds == safeSeconds)
        return true;

    m_devices[index].maxRunSeconds = safeSeconds;
    updateSafetyTimer(m_devices.at(index));
    persist();
    emit deviceChanged(index);
    return true;
}

QString HomeService::addScene(const QString &name, const QString &roomId,
                              const QString &days, const QString &timeRange)
{
    if (!permitted(mayAdminister(), "administer"))
        return {};

    const QString cleaned = sanitiseName(name);
    if (cleaned.isEmpty())
        return {};

    Scene scene;
    scene.id = makeId(QStringLiteral("scene"));
    scene.roomId = roomId;
    scene.name = cleaned;
    scene.days = days;
    scene.timeRange = timeRange;
    scene.enabled = false;

    m_scenes.append(scene);
    persist();
    emit reloaded();
    return scene.id;
}

bool HomeService::removeScene(const QString &sceneId)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const int index = indexOfScene(sceneId);
    if (index < 0)
        return false;

    m_scenes.removeAt(index);
    persist();
    emit reloaded();
    return true;
}

bool HomeService::setSceneSchedule(const QString &sceneId, const QString &days,
                                   const QString &timeRange)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const int index = indexOfScene(sceneId);
    if (index < 0)
        return false;

    m_scenes[index].days = days;
    m_scenes[index].timeRange = timeRange;
    persist();
    emit sceneChanged(index);
    return true;
}

bool HomeService::setSceneActions(const QString &sceneId,
                                  const QList<SceneAction> &actions)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const int index = indexOfScene(sceneId);
    if (index < 0)
        return false;

    QList<SceneAction> kept;
    kept.reserve(actions.size());
    for (const SceneAction &action : actions) {
        if (indexOfDevice(action.deviceId) < 0)
            continue;
        SceneAction clean = action;
        // Clamped here rather than at fire time. A scene is stored once and
        // fires every day; storing 140 and clamping it every morning means
        // the stored value and the applied value disagree forever, and the
        // editor shows the one that is wrong.
        if (clean.levelPercent >= 0)
            clean.levelPercent = std::clamp(clean.levelPercent, 0, 100);
        if (clean.targetC >= 0)
            clean.targetC = std::clamp(clean.targetC, kMinTargetC, kMaxTargetC);
        kept.append(clean);
    }

    m_scenes[index].actions = kept;
    persist();
    emit sceneChanged(index);
    return true;
}

bool HomeService::setDeviceTarget(const QString &deviceId, int targetC, Actor by)
{
    if (by == Actor::User && !permitted(mayOperate(), "operate"))
        return false;

    const int index = indexOfDevice(deviceId);
    if (index < 0)
        return false;
    // Refuse rather than clamp, unlike room area. A thermostat is not a
    // preference slider: -40 is not a user overshooting a bound, it is a
    // caller with a bug, and silently storing 5 would hide it.
    if (m_devices.at(index).targetC < 0)
        return false;
    if (targetC < kMinTargetC || targetC > kMaxTargetC)
        return false;

    m_devices[index].targetC = targetC;
    persist();
    emit deviceChanged(index);
    return true;
}

bool HomeService::setDeviceVolume(const QString &deviceId, int percent, Actor by)
{
    return setPercentField(deviceId, percent, &Device::volumePercent, by);
}

bool HomeService::setDeviceLevel(const QString &deviceId, int percent, Actor by)
{
    return setPercentField(deviceId, percent, &Device::levelPercent, by);
}

bool HomeService::setPercentField(const QString &deviceId, int percent,
                                  int Device::*field, Actor by)
{
    if (by == Actor::User && !permitted(mayOperate(), "operate"))
        return false;

    const int index = indexOfDevice(deviceId);
    if (index < 0)
        return false;
    // A device without the capability is refused rather than given one. -1 is
    // "this hardware has no such control", and writing 40 into it would invent
    // a dimmer on a device that has no dimmer - which the UI would then draw.
    if (m_devices.at(index).*field < 0)
        return false;
    // CLAMPED, unlike setDeviceTarget(), which refuses. The difference is what
    // is on the other end: a thermostat target out of range means a caller
    // with a bug, while a percentage out of range means a slider that was
    // dragged past its own end - rounding at the extremes of a drag is normal
    // and refusing it would make the last pixel of travel do nothing.
    const int clamped = std::clamp(percent, 0, 100);

    if (m_devices.at(index).*field == clamped)
        return true;

    m_devices[index].*field = clamped;
    persist();
    emit deviceChanged(index);
    return true;
}

bool HomeService::setDeviceMode(const QString &deviceId, const QString &mode, Actor by)
{
    if (by == Actor::User && !permitted(mayOperate(), "operate"))
        return false;

    static const QStringList known { QStringLiteral("cold"), QStringLiteral("wind"),
                                     QStringLiteral("sleep"), QStringLiteral("swing") };
    if (!known.contains(mode))
        return false;

    const int index = indexOfDevice(deviceId);
    if (index < 0 || m_devices.at(index).mode.isEmpty())
        return false;

    m_devices[index].mode = mode;
    persist();
    emit deviceChanged(index);
    return true;
}

bool HomeService::exportModel(const QString &filePath)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    const QJsonObject envelope {
        { QStringLiteral("format"),     kBackupFormat },
        { QStringLiteral("exportedAt"), QDateTime::currentDateTimeUtc()
                                            .toString(Qt::ISODate) },
        // The model, nested rather than merged into the envelope. Merged, the
        // first key a future format adds could collide with a key the model
        // already has, and the reader would have no way to tell whose it was.
        { QStringLiteral("model"),      writeModel() },
    };

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        m_lastError = QStringLiteral("cannot write %1").arg(filePath);
        return false;
    }
    // Indented. A backup is a file a person may well open in an editor to see
    // what it claims about their house, and a single 40 KB line is a file that
    // refuses to be read.
    const qint64 written =
        file.write(QJsonDocument(envelope).toJson(QJsonDocument::Indented));
    file.close();

    if (written <= 0) {
        m_lastError = QStringLiteral("nothing was written to %1").arg(filePath);
        return false;
    }
    return true;
}

bool HomeService::importModel(const QString &filePath)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        m_lastError = QStringLiteral("cannot open %1").arg(filePath);
        return false;
    }

    QJsonParseError parse {};
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parse);
    file.close();

    if (parse.error != QJsonParseError::NoError || !doc.isObject()) {
        m_lastError = QStringLiteral("%1 is not a SmarTon backup").arg(filePath);
        return false;
    }

    const QJsonObject envelope = doc.object();
    const int format = envelope.value(QLatin1String("format")).toInt(-1);
    if (format != kBackupFormat) {
        m_lastError = format < 0
            ? QStringLiteral("%1 is not a SmarTon backup").arg(filePath)
            : QStringLiteral("that backup is format %1 and this panel reads %2")
                  .arg(format).arg(kBackupFormat);
        return false;
    }

    const QJsonObject model = envelope.value(QLatin1String("model")).toObject();
    if (model.isEmpty()) {
        m_lastError = QStringLiteral("that backup contains no model");
        return false;
    }

    // KEPT UNTIL THE NEW ONE IS IN. readModel() replaces the lists as it goes,
    // so a backup that parses but does not read leaves a half-populated house
    // with nothing to compare against. The old model goes back if that
    // happens - a restore that fails halfway is the one failure mode this
    // must not have.
    const QJsonObject previous = writeModel();
    if (!readModel(model)) {
        (void)readModel(previous);
        m_lastError = QStringLiteral("that backup could not be read");
        return false;
    }

    persist();
    emit reloaded();
    return true;
}

QString HomeService::addMember(const QString &name, const QString &email)
{
    return addMember(name, email, QString(), QString(), 0);
}

QString HomeService::addMember(const QString &name, const QString &email,
                               const QString &phone, const QString &avatarSource,
                               qint64 accountId)
{
    if (!permitted(mayAdminister(), "administer"))
        return {};

    const QString cleaned = sanitiseName(name);
    if (cleaned.isEmpty())
        return {};

    Member member;
    member.id = makeId(QStringLiteral("member"));
    member.name = cleaned;
    member.email = email.simplified();
    member.phone = phone.simplified();
    member.avatarSource = avatarSource;
    member.accountId = accountId;
    member.online = false;

    m_members.append(member);
    persist();
    emit reloaded();
    return member.id;
}

bool HomeService::linkMemberAccount(const QString &memberId, qint64 accountId)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    for (Member &member : m_members) {
        if (member.id != memberId)
            continue;
        member.accountId = accountId;
        persist();
        emit reloaded();
        return true;
    }
    return false;
}

bool HomeService::removeMember(const QString &memberId)
{
    if (!permitted(mayAdminister(), "administer"))
        return false;

    for (int i = 0; i < m_members.size(); ++i) {
        if (m_members.at(i).id != memberId)
            continue;
        m_members.removeAt(i);
        persist();
        emit reloaded();
        return true;
    }
    return false;
}

} // namespace smarton::services
