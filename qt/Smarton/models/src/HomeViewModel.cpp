#include <smarton/models/HomeViewModel.h>

#include <smarton/domain/entities/User.h>
#include <smarton/services/AuthService.h>
#include <smarton/services/HomeService.h>
#include <smarton/services/IAvatarStore.h>

#include <QtCore/QDate>
#include <QtCore/QPair>
#include <QtCore/QRegularExpression>
#include <QtCore/QUrl>
#include <QtCore/QStringList>
#include <QtCore/QtMath>

#include <algorithm>

#include <utility>

namespace smarton::models {

namespace {

/*! One row for the scene editor: who the device is and what it can be told. */
QVariantMap describeDevice(const domain::Device &device, const QString &imageUrl,
                           const domain::SceneAction &action)
{
    return QVariantMap {
        { QStringLiteral("deviceId"),  device.id },
        { QStringLiteral("name"),      device.name },
        { QStringLiteral("kind"),      device.kind },
        { QStringLiteral("image"),     imageUrl },
        { QStringLiteral("on"),        action.on },
        { QStringLiteral("level"),     action.levelPercent },
        { QStringLiteral("targetC"),   action.targetC },
        // The CAPABILITIES, not just the values. The editor has to know
        // whether to draw a brightness slider before it knows what the scene
        // sets it to, and -1 on the action is "leave it alone" rather than
        // "this device has no such control" - two different facts that would
        // otherwise share one number.
        { QStringLiteral("hasLevel"),  device.levelPercent >= 0 },
        { QStringLiteral("hasTarget"), device.targetC >= 0 },
    };
}

constexpr auto kResourcePrefix = "qrc:/qt/qml/SmarTon/Resources/";
}

HomeViewModel::HomeViewModel(QObject *parent)
    : QObject(parent)
{
}

void HomeViewModel::setService(services::HomeService *service)
{
    m_service = service;

    m_rooms.setService(service);
    m_devices.setService(service);
    m_roomDevices.setService(service);
    m_scenes.setService(service);
    m_members.setService(service);

    if (m_service) {
        connect(m_service, &services::HomeService::reloaded, this, [this] {
            emit spaceChanged();
            emit countsChanged();
        });
        connect(m_service, &services::HomeService::devicePowerChanged, this,
                [this](int index, bool) {
                    emit countsChanged();
                    emit deviceChanged(m_service->devices().at(index).id);
                });
        connect(m_service, &services::HomeService::deviceChanged, this,
                [this](int index) {
                    emit deviceChanged(m_service->devices().at(index).id);
                });
        connect(m_service, &services::HomeService::deviceStatusChanged, this,
                [this](int index) {
                    emit deviceChanged(m_service->devices().at(index).id);
                });
        connect(m_service, &services::HomeService::deviceCommandFailed, this,
                &HomeViewModel::commandFailed);
        connect(m_service, &services::HomeService::deviceReachabilityChanged, this,
                &HomeViewModel::deviceReachabilityChanged);
        connect(m_service, &services::HomeService::refusedByRole, this,
                &HomeViewModel::permissionDenied);
        connect(m_service, &services::HomeService::actorChanged, this,
                &HomeViewModel::permissionsChanged);
        connect(m_service, &services::HomeService::spacesChanged, this, [this] {
            // Everything, not just the picker: switching space replaces the
            // rooms, the devices and the scenes underneath every screen.
            emit spacesChanged();
            emit spaceChanged();
            emit countsChanged();
        });
        connect(m_service, &services::HomeService::roomChanged, this,
                [this](int index) {
                    emit roomChanged(m_service->rooms().at(index).id);
                });
        connect(m_service, &services::HomeService::spaceChanged,
                this, &HomeViewModel::spaceChanged);
    }

    emit spaceChanged();
    emit countsChanged();
}

QString HomeViewModel::spaceName() const
{
    return m_service ? m_service->space().name : QString();
}

QString HomeViewModel::spaceAddress() const
{
    return m_service ? m_service->space().address : QString();
}

QString HomeViewModel::spaceImage() const
{
    return m_service ? imageUrl(m_service->space().imageSource) : QString();
}

bool HomeViewModel::hasSpace() const
{
    return m_service && !m_service->isEmpty();
}

QString HomeViewModel::weatherDescription() const
{
    return m_service ? m_service->weather().description : QString();
}

int HomeViewModel::weatherTemperature() const
{
    return m_service ? qRound(m_service->weather().temperatureC) : 0;
}

int HomeViewModel::weatherHumidity() const
{
    return m_service ? qRound(m_service->weather().humidityPercent) : 0;
}

int HomeViewModel::roomCount() const
{
    return m_service ? static_cast<int>(m_service->rooms().size()) : 0;
}

int HomeViewModel::deviceCount() const
{
    return m_service ? static_cast<int>(m_service->devices().size()) : 0;
}

int HomeViewModel::memberCount() const
{
    return m_service ? static_cast<int>(m_service->members().size()) : 0;
}

void HomeViewModel::setAllLights(bool on)
{
    if (!m_service)
        return;
    // Snapshot the ids first: setDevicePower emits, and emitting while walking
    // the service's own list is how a subtle iterator bug gets in later.
    QStringList lampIds;
    for (const domain::Device &device : m_service->devices()) {
        if (device.kind == QLatin1String("lamp"))
            lampIds.append(device.id);
    }
    for (const QString &id : std::as_const(lampIds))
        m_service->setDevicePower(id, on);
}

bool HomeViewModel::anyLightOn() const
{
    if (!m_service)
        return false;
    for (const domain::Device &device : m_service->devices()) {
        if (device.kind == QLatin1String("lamp") && device.on)
            return true;
    }
    return false;
}

void HomeViewModel::renameSpace(const QString &name)
{
    if (m_service)
        m_service->renameSpace(name);
}

int HomeViewModel::lowBatteryCount() const
{
    return m_service ? int(m_service->lowBatteryDevices().size()) : 0;
}

int HomeViewModel::lowBatteryThreshold() const
{
    return services::HomeService::kLowBatteryPercent;
}

QStringList HomeViewModel::lowBatteryNames() const
{
    QStringList names;
    if (!m_service)
        return names;
    for (const domain::Device &device : m_service->lowBatteryDevices())
        names.append(device.name);
    return names;
}

int HomeViewModel::offlineDeviceCount() const
{
    return offlineDeviceNames().size();
}

int HomeViewModel::staleDeviceCount() const
{
    return staleDeviceNames().size();
}

QStringList HomeViewModel::offlineDeviceNames() const
{
    QStringList names;
    if (!m_service)
        return names;
    for (const domain::Device &device : m_service->devices()) {
        if (device.reachability == domain::Reachability::Offline)
            names.append(device.name);
    }
    return names;
}

QStringList HomeViewModel::staleDeviceNames() const
{
    QStringList names;
    if (!m_service)
        return names;
    for (const domain::Device &device : m_service->devices()) {
        if (device.stateStale && device.reachability != domain::Reachability::Offline)
            names.append(device.name);
    }
    return names;
}

QVariantList HomeViewModel::criticalAlerts() const
{
    QVariantList alerts;
    if (!m_service)
        return alerts;

    static const QStringList safetyKinds {
        QStringLiteral("leak"), QStringLiteral("smoke"), QStringLiteral("gas"),
        QStringLiteral("carbon-monoxide"), QStringLiteral("intrusion"),
        QStringLiteral("panic")
    };
    for (const domain::Device &device : m_service->devices()) {
        if (device.on && safetyKinds.contains(device.kind.toLower())) {
            alerts.append(QVariantMap {
                { QStringLiteral("deviceId"), device.id },
                { QStringLiteral("name"), device.name },
                { QStringLiteral("kind"), device.kind },
            });
        }
    }
    return alerts;
}

bool HomeViewModel::canOperate() const
{
    return m_service && m_service->mayOperate();
}

bool HomeViewModel::canInstall() const
{
    return m_service && m_service->mayInstall();
}

bool HomeViewModel::canAdminister() const
{
    return m_service && m_service->mayAdminister();
}

QString HomeViewModel::currentRole() const
{
    return m_service ? domain::roleToString(m_service->actor()) : QString();
}

QVariantMap HomeViewModel::device(const QString &deviceId) const
{
    if (!m_service)
        return {};
    for (const domain::Device &d : m_service->devices()) {
        if (d.id != deviceId)
            continue;
        return QVariantMap {
            { QStringLiteral("deviceId"), d.id },
            { QStringLiteral("name"),     d.name },
            { QStringLiteral("kind"),     d.kind },
            { QStringLiteral("image"),    imageUrl(d.imageSource) },
            { QStringLiteral("isOn"),        d.on },
            { QStringLiteral("isPending"),   d.pending() },
            { QStringLiteral("isReachable"),
              d.reachability != domain::Reachability::Offline },
            { QStringLiteral("isStale"), d.stateStale },
            { QStringLiteral("commandState"), d.commandState },
            { QStringLiteral("protocol"), d.protocol },
            { QStringLiteral("manufacturer"), d.manufacturer },
            { QStringLiteral("model"), d.model },
            { QStringLiteral("firmware"), d.firmwareVersion },
            { QStringLiteral("signalStrength"), d.signalStrength },
            { QStringLiteral("lastSeen"), d.lastSeen },
            { QStringLiteral("maxRunSeconds"), d.maxRunSeconds },
            { QStringLiteral("requiresConfirmation"), d.requiresConfirmation },
            { QStringLiteral("powerWatts"), d.powerWatts },
            { QStringLiteral("energyKwh"), d.energyKwh },
            { QStringLiteral("voltage"), d.voltage },
            { QStringLiteral("currentAmps"), d.currentAmps },
            { QStringLiteral("battery"),  d.batteryPercent },
            { QStringLiteral("batteryLow"),
              d.batteryPercent >= 0
                  && d.batteryPercent <= services::HomeService::kLowBatteryPercent },
            { QStringLiteral("volume"),   d.volumePercent },
            { QStringLiteral("level"),    d.levelPercent },
            { QStringLiteral("targetC"),  d.targetC },
            { QStringLiteral("mode"),     d.mode },
            { QStringLiteral("roomId"),   d.roomId },
            { QStringLiteral("roomName"), m_service->roomName(d.roomId) },
        };
    }
    return {};
}

QVariantMap HomeViewModel::room(const QString &roomId) const
{
    if (!m_service)
        return {};
    for (const domain::Room &r : m_service->rooms()) {
        if (r.id != roomId)
            continue;
        return QVariantMap {
            { QStringLiteral("roomId"),      r.id },
            { QStringLiteral("name"),        r.name },
            { QStringLiteral("areaSqm"),     r.areaSqm },
            { QStringLiteral("image"),       imageUrl(r.imageSource) },
            { QStringLiteral("temperature"), qRound(r.temperatureC) },
            { QStringLiteral("humidity"),    qRound(r.humidityPercent) },
            { QStringLiteral("energyKw"),    r.energyKw },
        };
    }
    return {};
}

int HomeViewModel::roomDeviceCount(const QString &roomId) const
{
    return m_service ? m_service->deviceCountInRoom(roomId) : 0;
}

void HomeViewModel::setDevicePower(const QString &deviceId, bool on)
{
    if (m_service)
        m_service->setDevicePower(deviceId, on);
}

void HomeViewModel::renameDevice(const QString &deviceId, const QString &name)
{
    if (m_service)
        m_service->renameDevice(deviceId, name);
}

void HomeViewModel::renameRoom(const QString &roomId, const QString &name)
{
    if (m_service)
        m_service->renameRoom(roomId, name);
}

QVariantList HomeViewModel::spaces() const
{
    QVariantList list;
    if (!m_service)
        return list;

    const QString active = m_service->activeSpaceId();
    for (const domain::Space &space : m_service->spaces()) {
        list.append(QVariantMap {
            { QStringLiteral("spaceId"), space.id },
            { QStringLiteral("name"),    space.name },
            { QStringLiteral("address"), space.address },
            { QStringLiteral("image"),   imageUrl(space.imageSource) },
            { QStringLiteral("active"),  space.id == active },
        });
    }
    return list;
}

QString HomeViewModel::activeSpaceId() const
{
    return m_service ? m_service->activeSpaceId() : QString();
}

int HomeViewModel::spaceCount() const
{
    return m_service ? m_service->spaceCount() : 0;
}

bool HomeViewModel::switchSpace(const QString &spaceId)
{
    return m_service ? m_service->setActiveSpace(spaceId) : false;
}

QString HomeViewModel::addSpace(const QString &name, const QString &address)
{
    return m_service ? m_service->addSpace(name, address) : QString();
}

bool HomeViewModel::removeSpace(const QString &spaceId)
{
    return m_service ? m_service->removeSpace(spaceId) : false;
}

bool HomeViewModel::createSpace(const QString &name, const QString &address)
{
    if (!m_service)
        return false;

    // The wizard is the way into BOTH cases: the first space on a fresh panel,
    // and a second one from the picker. Branching HERE rather than in the
    // wizard, because "is this the first space" is a fact about the model and
    // a screen should not have to ask before it knows which function to call.
    //
    // Getting this wrong is not a cosmetic bug: HomeService::createSpace fills
    // the ACTIVE space, so running it with a space already there renames the
    // house you are standing in instead of adding another one.
    if (!m_service->isEmpty())
        return !m_service->addSpace(name, address).isEmpty();

    return m_service->createSpace(name, address);
}

void HomeViewModel::setSpaceAddress(const QString &address)
{
    if (m_service)
        m_service->setSpaceAddress(address);
}

QString HomeViewModel::addRoom(const QString &name, qreal areaSqm,
                               const QString &imageSource)
{
    return m_service ? m_service->addRoom(name, areaSqm, imageSource) : QString();
}

QString HomeViewModel::addRoomOnFloor(const QString &name, qreal areaSqm,
                                      const QString &imageSource, int floor)
{
    return m_service ? m_service->addRoom(name, areaSqm, imageSource, floor)
                     : QString();
}

bool HomeViewModel::removeRoom(const QString &roomId)
{
    return m_service && m_service->removeRoom(roomId);
}

bool HomeViewModel::linkDevice(const QString &availableId, const QString &roomId)
{
    return m_service && m_service->linkDevice(availableId, roomId);
}

QString HomeViewModel::addManualDevice(const QString &name, const QString &kind,
                                       const QString &roomId, const QString &protocol)
{
    return m_service ? m_service->addManualDevice(name, kind, roomId, protocol) : QString();
}

bool HomeViewModel::replaceDevice(const QString &deviceId, const QString &availableId)
{
    return m_service && m_service->replaceDevice(deviceId, availableId);
}

bool HomeViewModel::unlinkDevice(const QString &deviceId)
{
    return m_service && m_service->unlinkDevice(deviceId);
}

QString HomeViewModel::addScene(const QString &name, const QString &roomId,
                                const QString &days, const QString &timeRange)
{
    return m_service ? m_service->addScene(name, roomId, days, timeRange) : QString();
}

bool HomeViewModel::removeScene(const QString &sceneId)
{
    return m_service && m_service->removeScene(sceneId);
}

bool HomeViewModel::setSceneSchedule(const QString &sceneId, const QString &days,
                                     const QString &timeRange)
{
    return m_service && m_service->setSceneSchedule(sceneId, days, timeRange);
}

void HomeViewModel::setDeviceTarget(const QString &deviceId, int targetC)
{
    if (m_service)
        (void)m_service->setDeviceTarget(deviceId, targetC);
}

void HomeViewModel::setDeviceMode(const QString &deviceId, const QString &mode)
{
    if (m_service)
        (void)m_service->setDeviceMode(deviceId, mode);
}

void HomeViewModel::toggleDevicePower(const QString &deviceId)
{
    if (m_service)
        (void)m_service->toggleDevicePower(deviceId);
}

void HomeViewModel::setDeviceVolume(const QString &deviceId, int percent)
{
    if (m_service)
        (void)m_service->setDeviceVolume(deviceId, percent);
}

void HomeViewModel::setDeviceLevel(const QString &deviceId, int percent)
{
    if (m_service)
        (void)m_service->setDeviceLevel(deviceId, percent);
}

bool HomeViewModel::setDeviceRoom(const QString &deviceId, const QString &roomId)
{
    return m_service ? m_service->setDeviceRoom(deviceId, roomId) : false;
}

bool HomeViewModel::setDeviceMaxRunSeconds(const QString &deviceId, int seconds)
{
    return m_service ? m_service->setDeviceMaxRunSeconds(deviceId, seconds) : false;
}

QString HomeViewModel::levelLabel(const QString &deviceId) const
{
    // The WORD, decided here rather than in QML, so the four screens that can
    // show this control cannot disagree about what a humidifier's slider is
    // called. It is a presentation string, which is why it lives in the view
    // model and not on the device: the domain knows there is a level, not
    // what a person calls it.
    if (!m_service)
        return {};
    for (const domain::Device &d : m_service->devices()) {
        if (d.id != deviceId)
            continue;
        if (d.kind == QLatin1String("lamp"))
            return tr("Brightness");
        if (d.kind == QLatin1String("humidifier"))
            return tr("Mist output");
        if (d.kind == QLatin1String("diffuser"))
            return tr("Diffusion");
        if (d.kind == QLatin1String("conditioner"))
            return tr("Fan speed");
        return tr("Level");
    }
    return {};
}

int HomeViewModel::minTargetC() const { return services::HomeService::kMinTargetC; }
int HomeViewModel::maxTargetC() const { return services::HomeService::kMaxTargetC; }

QString HomeViewModel::addMember(const QString &name, const QString &email)
{
    return m_service ? m_service->addMember(name, email) : QString();
}

void HomeViewModel::setAuthService(services::AuthService *auth)
{
    m_auth = auth;
}

void HomeViewModel::setAvatarStore(services::IAvatarStore *avatars)
{
    m_avatars = avatars;
}

QString HomeViewModel::addMemberDetailed(const QString &name, const QString &email,
                                         const QString &phone,
                                         const QString &avatarFileUrl,
                                         const QString &password,
                                         const QString &role)
{
    const auto fail = [this](const QString &why) -> QString {
        m_lastMemberError = why;
        emit lastMemberErrorChanged();
        return {};
    };

    if (!m_service)
        return fail(tr("The home model is unavailable."));

    if (name.trimmed().isEmpty())
        return fail(tr("A member needs a name."));

    // ORDER MATTERS, and this is the order that cannot strand anything.
    //
    // The account is created first because it is the only step that can fail
    // for a reason the user must fix - a taken name, a weak password - and
    // creating the member first would mean showing them a member row that
    // then could not be given the credential they asked for. Adding the member
    // afterwards fails only on an empty name, which is already rejected above.
    qint64 accountId = 0;
    if (!password.isEmpty()) {
        if (!m_auth)
            return fail(tr("Sign-in accounts are unavailable on this build."));

        // The account's USERNAME is the email when there is one, and the name
        // otherwise. Stated rather than derived silently, because it is what
        // the person will type to sign in and the form says so.
        const QString username = email.trimmed().isEmpty() ? name.trimmed()
                                                           : email.trimmed();

        services::AuthError error = services::AuthError::None;
        // roleFromString returns Viewer for anything it does not recognise,
        // which is the right way for this to fail: an unknown role string
        // grants the LEAST access, never the most.
        accountId = m_auth->createAccount(username, password,
                                          domain::roleFromString(role), &error);
        if (accountId <= 0) {
            switch (error) {
            case services::AuthError::WeakPassword:
                return fail(tr("That password is too weak. Use at least 8 "
                               "characters with upper and lower case and a "
                               "number or symbol."));
            case services::AuthError::InvalidCredentials:
                return fail(tr("\"%1\" is already taken. Sign-in names must be "
                               "unique on this panel.").arg(username));
            default:
                return fail(tr("Could not create the sign-in account."));
            }
        }
    }

    // Custody of the picture, keyed by a value that is stable for this member.
    // Taken AFTER the account so a rejected password does not leave a stray
    // file behind, and tolerated if it fails: a member without a photo is a
    // member, and losing the whole action over an unreadable image would be a
    // poor trade.
    QString avatarPath;
    if (!avatarFileUrl.isEmpty() && m_avatars) {
        const QUrl url(avatarFileUrl);
        const QString localFile = url.isLocalFile() ? url.toLocalFile() : avatarFileUrl;
        avatarPath = m_avatars->store(localFile,
                                      QStringLiteral("member-%1").arg(
                                          accountId > 0 ? QString::number(accountId)
                                                        : name.trimmed()));
    }

    const QString memberId = m_service->addMember(name, email, phone,
                                                  avatarPath, accountId);
    if (memberId.isEmpty())
        return fail(tr("Could not add the member."));

    m_lastMemberError.clear();
    emit lastMemberErrorChanged();
    return memberId;
}

bool HomeViewModel::removeMember(const QString &memberId)
{
    return m_service && m_service->removeMember(memberId);
}

int HomeViewModel::availableDeviceCount() const
{
    return m_service ? static_cast<int>(m_service->availableDevices().size()) : 0;
}

bool HomeViewModel::exportBackup(const QUrl &fileUrl)
{
    const QString path = fileUrl.isLocalFile() ? fileUrl.toLocalFile()
                                               : fileUrl.toString();
    if (!m_service) {
        m_lastBackupError = tr("There is nothing to back up.");
        emit lastBackupErrorChanged();
        return false;
    }
    if (!m_service->exportModel(path)) {
        m_lastBackupError = m_service->lastError();
        emit lastBackupErrorChanged();
        return false;
    }
    m_lastBackupError.clear();
    emit lastBackupErrorChanged();
    return true;
}

bool HomeViewModel::importBackup(const QUrl &fileUrl)
{
    const QString path = fileUrl.isLocalFile() ? fileUrl.toLocalFile()
                                               : fileUrl.toString();
    if (!m_service) {
        m_lastBackupError = tr("There is nothing to restore into.");
        emit lastBackupErrorChanged();
        return false;
    }
    if (!m_service->importModel(path)) {
        m_lastBackupError = m_service->lastError();
        emit lastBackupErrorChanged();
        return false;
    }
    m_lastBackupError.clear();
    emit lastBackupErrorChanged();
    // Everything on screen is now about a different house.
    emit spaceChanged();
    emit countsChanged();
    return true;
}

QString HomeViewModel::suggestedBackupName() const
{
    // Dated, and the space's name only when it is safe as a file name. A
    // house called "Mum & Dad's / Summer" is a perfectly good house name and
    // a terrible path component.
    QString name = m_service ? m_service->space().name : QString();
    name.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9 _-]")), QString());
    name = name.simplified().replace(QLatin1Char(' '), QLatin1Char('-'));
    if (name.isEmpty())
        name = QStringLiteral("smarton");
    return QStringLiteral("%1-%2.smarton.json")
        .arg(name.toLower(),
             QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd")));
}

QVariantList HomeViewModel::availableDevices() const
{
    QVariantList list;
    if (!m_service)
        return list;

    for (const domain::Device &d : m_service->availableDevices()) {
        list.append(QVariantMap {
            { QStringLiteral("deviceId"), d.id },
            { QStringLiteral("name"),     d.name },
            { QStringLiteral("kind"),     d.kind },
            { QStringLiteral("image"),    imageUrl(d.imageSource) },
        });
    }
    return list;
}

QVariantList HomeViewModel::linkedDevices() const
{
    QVariantList list;
    if (!m_service)
        return list;

    for (const domain::Device &d : m_service->devices()) {
        list.append(QVariantMap {
            { QStringLiteral("deviceId"), d.id },
            { QStringLiteral("name"),     d.name },
            { QStringLiteral("kind"),     d.kind },
            { QStringLiteral("image"),    imageUrl(d.imageSource) },
            { QStringLiteral("roomName"), m_service->roomName(d.roomId) },
        });
    }
    return list;
}

QVariantList HomeViewModel::sceneActions(const QString &sceneId) const
{
    QVariantList list;
    if (!m_service)
        return list;

    for (const domain::Scene &scene : m_service->scenes()) {
        if (scene.id != sceneId)
            continue;
        for (const domain::SceneAction &action : scene.actions) {
            for (const domain::Device &device : m_service->devices()) {
                if (device.id != action.deviceId)
                    continue;
                list.append(describeDevice(device, imageUrl(device.imageSource), action));
                break;
            }
        }
        break;
    }
    return list;
}

QVariantList HomeViewModel::scenePreview(const QString &sceneId) const
{
    QVariantList list;
    if (!m_service)
        return list;

    for (const domain::Scene &scene : m_service->scenes()) {
        if (scene.id != sceneId)
            continue;

        if (scene.isPerDevice()) {
            for (const domain::SceneAction &action : scene.actions) {
                for (const domain::Device &device : m_service->devices()) {
                    if (device.id != action.deviceId)
                        continue;
                    QVariantMap row = describeDevice(device, imageUrl(device.imageSource), action);
                    row.insert(QStringLiteral("effectiveOn"), action.on);
                    list.append(row);
                    break;
                }
            }
        } else {
            const QList<domain::Device> devices = scene.roomId.isEmpty()
                ? m_service->devices() : m_service->devicesInRoom(scene.roomId);
            for (const domain::Device &device : devices) {
                QVariantMap row = describeDevice(device, imageUrl(device.imageSource), {});
                row.insert(QStringLiteral("effectiveOn"), true);
                list.append(row);
            }
        }
        break;
    }
    return list;
}

QVariantList HomeViewModel::sceneCandidates(const QString &roomId) const
{
    QVariantList list;
    if (!m_service)
        return list;

    for (const domain::Device &device : m_service->devices()) {
        if (!roomId.isEmpty() && device.roomId != roomId)
            continue;
        domain::SceneAction blank;
        blank.deviceId = device.id;
        // Seeded from what the device is doing NOW, not from zero. Building a
        // scene is "make it like this, later", and starting every slider at
        // the bottom means the first thing anyone does is drag them all back.
        blank.on = device.on;
        blank.levelPercent = device.levelPercent;
        blank.targetC = device.targetC;
        list.append(describeDevice(device, imageUrl(device.imageSource), blank));
    }
    return list;
}

bool HomeViewModel::setSceneActions(const QString &sceneId,
                                    const QVariantList &actions)
{
    if (!m_service)
        return false;

    QList<domain::SceneAction> parsed;
    parsed.reserve(actions.size());
    for (const QVariant &entry : actions) {
        const QVariantMap row = entry.toMap();
        domain::SceneAction action;
        action.deviceId = row.value(QStringLiteral("deviceId")).toString();
        if (action.deviceId.isEmpty())
            continue;
        action.on = row.value(QStringLiteral("on"), true).toBool();
        action.levelPercent = row.value(QStringLiteral("level"), -1).toInt();
        action.targetC = row.value(QStringLiteral("targetC"), -1).toInt();
        parsed.append(action);
    }
    return m_service->setSceneActions(sceneId, parsed);
}

QVariantList HomeViewModel::roomChoices() const
{
    QVariantList list;
    if (!m_service)
        return list;

    for (const domain::Room &r : m_service->rooms()) {
        list.append(QVariantMap {
            { QStringLiteral("id"),   r.id },
            { QStringLiteral("name"), r.name },
        });
    }
    return list;
}

QVariantList HomeViewModel::floors() const
{
    QVariantList list;
    if (!m_service)
        return list;

    QList<int> seen;
    for (const domain::Room &room : m_service->rooms()) {
        if (!seen.contains(room.floor))
            seen.append(room.floor);
    }
    std::sort(seen.begin(), seen.end());

    for (int floor : std::as_const(seen))
        list.append(floor);
    return list;
}

bool HomeViewModel::setRoomFloor(const QString &roomId, int floor)
{
    return m_service && m_service->setRoomFloor(roomId, floor);
}

QVariantList HomeViewModel::floorPlan() const
{
    QVariantList list;
    if (!m_service)
        return list;

    for (const domain::Room &room : m_service->rooms()) {
        QVariantList devices;
        for (const domain::Device &device : m_service->devices()) {
            if (device.roomId != room.id)
                continue;
            devices.append(QVariantMap {
                { QStringLiteral("deviceId"), device.id },
                { QStringLiteral("name"),     device.name },
                { QStringLiteral("kind"),     device.kind },
                // The REPORTED state, like everywhere else - a pin that lights
                // up because someone asked rather than because the device
                // answered is the lie ADR-0010 exists to prevent.
                { QStringLiteral("on"),       device.on },
                { QStringLiteral("pending"),  device.pending() },
                { QStringLiteral("offline"),
                  device.reachability == domain::Reachability::Offline },
            });
        }

        list.append(QVariantMap {
            { QStringLiteral("roomId"),      room.id },
            { QStringLiteral("name"),        room.name },
            { QStringLiteral("areaSqm"),     room.areaSqm },
            { QStringLiteral("floor"),       room.floor },
            { QStringLiteral("deviceCount"), devices.size() },
            { QStringLiteral("devices"),     devices },
        });
    }
    return list;
}

QVariantList HomeViewModel::roomArtwork() const
{
    // The artwork a new room can be given. Hardcoded because it IS the shipped
    // asset set - there is no upload path on the panel, so offering a file
    // picker would be offering something that cannot work.
    static const QList<QPair<QString, QString>> kArtwork {
        { tr("Living room"), QStringLiteral("images/rooms/living-sofa.png") },
        { tr("Kitchen"),     QStringLiteral("images/rooms/kitchen-hob.png") },
        { tr("Bedroom"),     QStringLiteral("images/rooms/bedroom-bed.png") },
        { tr("Bathroom"),    QStringLiteral("images/rooms/bathroom-tub.png") },
        { tr("Lounge"),      QStringLiteral("images/rooms/lounge-framed.png") },
        { tr("Interior"),    QStringLiteral("images/rooms/living-interior.png") },
    };

    QVariantList list;
    for (const auto &[label, path] : kArtwork) {
        list.append(QVariantMap {
            { QStringLiteral("label"), label },
            { QStringLiteral("image"), path },
            { QStringLiteral("url"),   imageUrl(path) },
        });
    }
    return list;
}

void HomeViewModel::setRoomFilter(const QString &roomId)
{
    m_roomDevices.setRoomId(roomId);
    m_scenes.setRoomId(roomId);
}

void HomeViewModel::setSceneFilter(const QString &roomId)
{
    m_scenes.setRoomId(roomId);
}

QVariantList HomeViewModel::roomFilters() const
{
    QVariantList filters;
    filters.append(QVariantMap {
        { QStringLiteral("id"), QString() },
        { QStringLiteral("name"), tr("All scenes") },
    });
    if (!m_service)
        return filters;

    for (const domain::Room &room : m_service->rooms()) {
        filters.append(QVariantMap {
            { QStringLiteral("id"), room.id },
            { QStringLiteral("name"), room.name },
        });
    }
    return filters;
}

QVariantList HomeViewModel::energySeries(const QString &period) const
{
    // SmarTon has no metering hardware and no history table. Rather than
    // return numbers that look measured, this derives a deterministic shape
    // from the rooms' seeded energyKw so the chart is honest about being a
    // preview: same input, same curve, every run. Frame 26's series is the
    // "week" case, matching the design's peak on Thursday.
    static const QList<qreal> kWeekShape   { 0.30, 0.55, 0.30, 1.00, 0.52, 0.60, 0.22 };
    static const QList<qreal> kDayShape    { 0.15, 0.10, 0.35, 0.70, 1.00, 0.80, 0.45, 0.25 };
    static const QList<qreal> kMonthShape  { 0.55, 0.72, 0.48, 1.00 };
    static const QList<qreal> kYearShape   { 0.42, 0.58, 0.70, 0.51, 0.86, 1.00,
                                             0.92, 0.74, 0.60, 0.55, 0.68, 0.80 };

    const QList<qreal> *shape = &kWeekShape;
    if (period == QLatin1String("Today"))        shape = &kDayShape;
    else if (period == QLatin1String("Month"))   shape = &kMonthShape;
    else if (period == QLatin1String("Year"))    shape = &kYearShape;
    else if (period == QLatin1String("Quarter")) shape = &kMonthShape;

    qreal peak = 0;
    if (m_service) {
        for (const domain::Room &r : m_service->rooms())
            peak += r.energyKw;
    }
    if (peak <= 0)
        peak = 20;
    // Frame 26 peaks at 17 kW against a 20 kW axis.
    peak = peak * 0.2125;

    QVariantList series;
    series.reserve(shape->size());
    for (const qreal factor : *shape)
        series.append(QVariant(factor * peak));
    return series;
}

qreal HomeViewModel::energyTotal(const QString &period) const
{
    qreal total = 0;
    const QVariantList series = energySeries(period);
    for (const QVariant &value : series)
        total += value.toReal();
    return total;
}

QString HomeViewModel::imageUrl(const QString &relativePath) const
{
    if (relativePath.isEmpty())
        return {};
    if (relativePath.startsWith(QLatin1String("qrc:"))
        || relativePath.startsWith(QLatin1String("file:")))
        return relativePath;
    return QLatin1String(kResourcePrefix) + relativePath;
}

} // namespace smarton::models
