#include <smarton/models/HomeListModels.h>

#include <smarton/services/HomeService.h>

namespace smarton::models {

using namespace smarton::domain;

// ---------------------------------------------------------------- rooms ----

RoomListModel::RoomListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

void RoomListModel::setService(services::HomeService *service)
{
    if (m_service == service)
        return;
    if (m_service)
        m_service->disconnect(this);

    m_service = service;
    if (m_service) {
        connect(m_service, &services::HomeService::reloaded,
                this, &RoomListModel::refresh);
        connect(m_service, &services::HomeService::roomChanged, this,
                [this](int serviceIndex) {
                    if (serviceIndex < 0 || serviceIndex >= m_rooms.size())
                        return;
                    m_rooms[serviceIndex] = m_service->rooms().at(serviceIndex);
                    const QModelIndex changed = index(serviceIndex);
                    emit dataChanged(changed, changed, { NameRole });
                });
        // Deliberately NOT connected to devicePowerChanged. The room badge
        // counts devices, not devices that are on, so power changes cannot
        // affect it - and resetting this model on every switch would rebuild
        // every room card for nothing.
    }
    refresh();
}

void RoomListModel::refresh()
{
    beginResetModel();
    m_rooms = m_service ? m_service->rooms() : QList<Room>{};
    endResetModel();
    emit countChanged();
}

void RoomListModel::rename(int row, const QString &name)
{
    if (!m_service || row < 0 || row >= m_rooms.size())
        return;
    m_service->renameRoom(m_rooms.at(row).id, name);
}

int RoomListModel::rowForId(const QString &roomId) const
{
    for (int row = 0; row < m_rooms.size(); ++row) {
        if (m_rooms.at(row).id == roomId)
            return row;
    }
    return -1;
}

int RoomListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : static_cast<int>(m_rooms.size());
}

QVariant RoomListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rooms.size())
        return {};

    const Room &room = m_rooms.at(index.row());
    switch (role) {
    case IdRole:          return room.id;
    case NameRole:        return room.name;
    case AreaRole:        return room.areaSqm;
    case ImageRole:       return room.imageSource;
    case TemperatureRole: return room.temperatureC;
    case HumidityRole:    return room.humidityPercent;
    case EnergyRole:      return room.energyKw;
    case DeviceCountRole: return m_service ? m_service->deviceCountInRoom(room.id) : 0;
    default:              return {};
    }
}

QHash<int, QByteArray> RoomListModel::roleNames() const
{
    return {
        { IdRole,          "roomId"      },
        { NameRole,        "name"        },
        { AreaRole,        "areaSqm"     },
        { ImageRole,       "image"       },
        { TemperatureRole, "temperature" },
        { HumidityRole,    "humidity"    },
        { EnergyRole,      "energyKw"    },
        { DeviceCountRole, "deviceCount" },
    };
}

// -------------------------------------------------------------- devices ----

DeviceListModel::DeviceListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

void DeviceListModel::setService(services::HomeService *service)
{
    if (m_service == service)
        return;
    if (m_service)
        m_service->disconnect(this);

    m_service = service;
    if (m_service) {
        connect(m_service, &services::HomeService::reloaded,
                this, &DeviceListModel::refresh);
        // One row, one role. Not a reset: rebuilding every delegate to move
        // one switch is a visible stutter on the panel.
        connect(m_service, &services::HomeService::devicePowerChanged, this,
                [this](int serviceIndex, bool on) {
                    for (int row = 0; row < m_devices.size(); ++row) {
                        if (m_devices.at(row).id
                            != m_service->devices().at(serviceIndex).id)
                            continue;
                        m_devices[row].on = on;
                        const QModelIndex changed = index(row);
                        emit dataChanged(changed, changed, { OnRole });
                        return;
                    }
                });
        connect(m_service, &services::HomeService::deviceChanged, this,
                [this](int serviceIndex) {
                    const QString id = m_service->devices().at(serviceIndex).id;
                    for (int row = 0; row < m_devices.size(); ++row) {
                        if (m_devices.at(row).id != id)
                            continue;
                        m_devices[row] = m_service->devices().at(serviceIndex);
                        const QModelIndex changed = index(row);
                        emit dataChanged(changed, changed, { NameRole });
                        return;
                    }
                });
        // Intent or reachability moved without the reported state changing -
        // a command in flight, or a device that stopped answering.
        connect(m_service, &services::HomeService::deviceStatusChanged, this,
                [this](int serviceIndex) {
                    const QString id = m_service->devices().at(serviceIndex).id;
                    for (int row = 0; row < m_devices.size(); ++row) {
                        if (m_devices.at(row).id != id)
                            continue;
                        m_devices[row] = m_service->devices().at(serviceIndex);
                        const QModelIndex changed = index(row);
                        emit dataChanged(changed, changed,
                                         { PendingRole, ReachableRole });
                        return;
                    }
                });
    }
    refresh();
}

void DeviceListModel::rename(int row, const QString &name)
{
    if (!m_service || row < 0 || row >= m_devices.size())
        return;
    m_service->renameDevice(m_devices.at(row).id, name);
}

int DeviceListModel::rowForId(const QString &deviceId) const
{
    for (int row = 0; row < m_devices.size(); ++row) {
        if (m_devices.at(row).id == deviceId)
            return row;
    }
    return -1;
}

void DeviceListModel::setRoomId(const QString &roomId)
{
    if (m_roomId == roomId)
        return;
    m_roomId = roomId;
    emit roomIdChanged();
    refresh();
}

void DeviceListModel::refresh()
{
    beginResetModel();
    if (!m_service)
        m_devices.clear();
    else if (m_roomId.isEmpty())
        m_devices = m_service->devices();
    else
        m_devices = m_service->devicesInRoom(m_roomId);
    endResetModel();
    emit countChanged();
}

void DeviceListModel::setPower(int row, bool on)
{
    if (!m_service || row < 0 || row >= m_devices.size())
        return;
    // Through the service, never straight into m_devices: every other view of
    // the same device has to hear about it, and it has to be persisted.
    m_service->setDevicePower(m_devices.at(row).id, on);
}

int DeviceListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : static_cast<int>(m_devices.size());
}

QVariant DeviceListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_devices.size())
        return {};

    const Device &device = m_devices.at(index.row());
    switch (role) {
    case IdRole:       return device.id;
    case NameRole:     return device.name;
    case RoomNameRole: return m_service ? m_service->roomName(device.roomId) : QString();
    case KindRole:     return device.kind;
    case ImageRole:    return device.imageSource;
    case OnRole:       return device.on;
    case PendingRole:  return device.pending();
    case ReachableRole:
        return device.reachability != domain::Reachability::Offline;
    case BatteryRole:  return device.batteryPercent;
    case VolumeRole:   return device.volumePercent;
    case ProtocolRole: return device.protocol;
    case ManufacturerRole: return device.manufacturer;
    case ModelRole: return device.model;
    case SignalRole: return device.signalStrength;
    case LastSeenRole: return device.lastSeen;
    case StaleRole: return device.stateStale;
    case CommandStateRole: return device.commandState;
    default:           return {};
    }
}

QHash<int, QByteArray> DeviceListModel::roleNames() const
{
    return {
        { IdRole,       "deviceId" },
        { NameRole,     "name"     },
        { RoomNameRole, "roomName" },
        { KindRole,     "kind"     },
        { ImageRole,    "image"    },
        { OnRole,       "isOn"      },
        { PendingRole,  "isPending" },
        { ReachableRole,"isReachable" },
        { BatteryRole,  "battery"  },
        { VolumeRole,   "volume"   },
        { ProtocolRole, "protocol" },
        { ManufacturerRole, "manufacturer" },
        { ModelRole, "model" },
        { SignalRole, "signalStrength" },
        { LastSeenRole, "lastSeen" },
        { StaleRole, "isStale" },
        { CommandStateRole, "commandState" },
    };
}

// --------------------------------------------------------------- scenes ----

SceneListModel::SceneListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

void SceneListModel::setService(services::HomeService *service)
{
    if (m_service == service)
        return;
    if (m_service)
        m_service->disconnect(this);

    m_service = service;
    if (m_service) {
        connect(m_service, &services::HomeService::reloaded,
                this, &SceneListModel::refresh);
        connect(m_service, &services::HomeService::sceneEnabledChanged, this,
                [this](int serviceIndex, bool enabled) {
                    for (int row = 0; row < m_scenes.size(); ++row) {
                        if (m_scenes.at(row).id
                            != m_service->scenes().at(serviceIndex).id)
                            continue;
                        m_scenes[row].enabled = enabled;
                        const QModelIndex changed = index(row);
                        emit dataChanged(changed, changed, { EnabledRole });
                        return;
                    }
                });
        connect(m_service, &services::HomeService::sceneChanged, this,
                [this](int serviceIndex) {
                    const QString id = m_service->scenes().at(serviceIndex).id;
                    for (int row = 0; row < m_scenes.size(); ++row) {
                        if (m_scenes.at(row).id != id)
                            continue;
                        m_scenes[row] = m_service->scenes().at(serviceIndex);
                        const QModelIndex changed = index(row);
                        emit dataChanged(changed, changed, { NameRole });
                        return;
                    }
                });
    }
    refresh();
}

void SceneListModel::rename(int row, const QString &name)
{
    if (!m_service || row < 0 || row >= m_scenes.size())
        return;
    m_service->renameScene(m_scenes.at(row).id, name);
}

void SceneListModel::setRoomId(const QString &roomId)
{
    if (m_roomId == roomId)
        return;
    m_roomId = roomId;
    emit roomIdChanged();
    refresh();
}

void SceneListModel::refresh()
{
    beginResetModel();
    m_scenes = m_service ? m_service->scenesInRoom(m_roomId) : QList<Scene>{};
    endResetModel();
    emit countChanged();
}

void SceneListModel::setEnabled(int row, bool enabled)
{
    if (!m_service || row < 0 || row >= m_scenes.size())
        return;
    m_service->setSceneEnabled(m_scenes.at(row).id, enabled);
}

int SceneListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : static_cast<int>(m_scenes.size());
}

QVariant SceneListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_scenes.size())
        return {};

    const Scene &scene = m_scenes.at(index.row());
    switch (role) {
    case IdRole:        return scene.id;
    case NameRole:      return scene.name;
    case DaysRole:      return scene.days;
    case TimeRangeRole: return scene.timeRange;
    case EnabledRole:   return scene.enabled;
    case DeviceCountRole: return int(scene.actions.size());
    default:            return {};
    }
}

QHash<int, QByteArray> SceneListModel::roleNames() const
{
    return {
        { IdRole,        "sceneId"   },
        { NameRole,      "name"      },
        { DaysRole,      "days"      },
        { TimeRangeRole, "timeRange" },
        { DeviceCountRole, "deviceCount" },
        { EnabledRole,   "isEnabled" },
    };
}

// -------------------------------------------------------------- members ----

MemberListModel::MemberListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

void MemberListModel::setService(services::HomeService *service)
{
    if (m_service == service)
        return;
    if (m_service)
        m_service->disconnect(this);

    m_service = service;
    if (m_service) {
        connect(m_service, &services::HomeService::reloaded,
                this, &MemberListModel::refresh);
    }
    refresh();
}

void MemberListModel::refresh()
{
    beginResetModel();
    m_members = m_service ? m_service->members() : QList<Member>{};
    endResetModel();
    emit countChanged();
}

int MemberListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : static_cast<int>(m_members.size());
}

QVariant MemberListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_members.size())
        return {};

    const Member &member = m_members.at(index.row());
    switch (role) {
    case IdRole:     return member.id;
    case NameRole:   return member.name;
    case EmailRole:  return member.email;
    case PhoneRole:  return member.phone;
    case CanSignInRole: return member.canSignIn();
    case AvatarRole:
        // Empty is normal - the seed ships no member photographs - so the
        // bundled picture stands in rather than every row showing an initial.
        return member.avatarSource.isEmpty()
                   ? QStringLiteral("qrc:/qt/qml/SmarTon/Resources/images/"
                                    "avatars/default-profile.jpeg")
                   : member.avatarSource;
    case OnlineRole: return member.online;
    default:         return {};
    }
}

QHash<int, QByteArray> MemberListModel::roleNames() const
{
    return {
        { IdRole,        "memberId"   },
        { NameRole,      "name"       },
        { EmailRole,     "email"      },
        { PhoneRole,     "phone"      },
        { AvatarRole,    "avatar"     },
        { OnlineRole,    "online"     },
        { CanSignInRole, "canSignIn"  },
    };
}

} // namespace smarton::models
