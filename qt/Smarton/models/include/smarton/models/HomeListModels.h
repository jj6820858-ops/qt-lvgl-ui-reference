#pragma once

#include <smarton/domain/entities/HomeEntities.h>

#include <QtCore/QAbstractListModel>
#include <QtQml/qqmlregistration.h>

namespace smarton::services { class HomeService; }

namespace smarton::models {

/**
 * @brief Rooms, as a list model. Frames 13, 18, 26.
 *
 * Filtering is by assignment of a fresh list rather than a QSortFilterProxy:
 * the collections here are a handful of items, and a proxy would add a layer
 * of indirection that has to be understood before anything can be debugged.
 * Revisit if a space ever holds hundreds of rooms.
 */
class RoomListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Role {
        IdRole = Qt::UserRole + 1,
        NameRole,
        AreaRole,
        ImageRole,
        TemperatureRole,
        HumidityRole,
        EnergyRole,
        DeviceCountRole,
    };
    Q_ENUM(Role)

    explicit RoomListModel(QObject *parent = nullptr);

    void setService(services::HomeService *service);
    void refresh();

    /** Rename from a delegate. No-op on an empty or unchanged name. */
    Q_INVOKABLE void rename(int row, const QString &name);
    /** The row holding @p roomId, or -1. Lets a screen open a room by id. */
    Q_INVOKABLE int rowForId(const QString &roomId) const;

    [[nodiscard]] int rowCount(const QModelIndex &parent = {}) const override;
    [[nodiscard]] QVariant data(const QModelIndex &index, int role) const override;
    [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

signals:
    void countChanged();

private:
    services::HomeService *m_service = nullptr;
    QList<domain::Room>    m_rooms;
};

/**
 * @brief Devices, optionally narrowed to one room. Frames 07, 15, 19.
 *
 * Power changes arrive as dataChanged on a single row, never a model reset:
 * a reset destroys and rebuilds every delegate, which on this panel is a
 * visible stutter for a change that affects one switch.
 */
class DeviceListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QString roomId READ roomId WRITE setRoomId NOTIFY roomIdChanged)

public:
    enum Role {
        IdRole = Qt::UserRole + 1,
        NameRole,
        RoomNameRole,
        KindRole,
        ImageRole,
        OnRole,
        PendingRole,
        ReachableRole,
        BatteryRole,
        VolumeRole,
        ProtocolRole,
        ManufacturerRole,
        ModelRole,
        SignalRole,
        LastSeenRole,
        StaleRole,
        CommandStateRole,
    };
    Q_ENUM(Role)

    explicit DeviceListModel(QObject *parent = nullptr);

    void setService(services::HomeService *service);
    void refresh();

    [[nodiscard]] QString roomId() const { return m_roomId; }
    /** Empty shows every device in the space. */
    void setRoomId(const QString &roomId);

    /** Toggle from a delegate. Routes through the service, so every view of
        the same device updates and the change is persisted. */
    Q_INVOKABLE void setPower(int row, bool on);
    Q_INVOKABLE void rename(int row, const QString &name);
    Q_INVOKABLE int rowForId(const QString &deviceId) const;

    [[nodiscard]] int rowCount(const QModelIndex &parent = {}) const override;
    [[nodiscard]] QVariant data(const QModelIndex &index, int role) const override;
    [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

signals:
    void countChanged();
    void roomIdChanged();

private:
    services::HomeService  *m_service = nullptr;
    QString                 m_roomId;
    QList<domain::Device>   m_devices;
};

/** Scenes, optionally narrowed to one room. Frames 21, 23. */
class SceneListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QString roomId READ roomId WRITE setRoomId NOTIFY roomIdChanged)

public:
    enum Role {
        IdRole = Qt::UserRole + 1,
        NameRole,
        DaysRole,
        TimeRangeRole,
        EnabledRole,
        /*! How many devices the scene names, or 0 when it takes its room.
            Two different facts sharing one number would be a bug; here 0
            genuinely means "not a per-device scene", which is what the card
            renders as "the whole room". */
        DeviceCountRole,
    };
    Q_ENUM(Role)

    explicit SceneListModel(QObject *parent = nullptr);

    void setService(services::HomeService *service);
    void refresh();

    [[nodiscard]] QString roomId() const { return m_roomId; }
    void setRoomId(const QString &roomId);

    Q_INVOKABLE void setEnabled(int row, bool enabled);
    Q_INVOKABLE void rename(int row, const QString &name);

    [[nodiscard]] int rowCount(const QModelIndex &parent = {}) const override;
    [[nodiscard]] QVariant data(const QModelIndex &index, int role) const override;
    [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

signals:
    void countChanged();
    void roomIdChanged();

private:
    services::HomeService *m_service = nullptr;
    QString                m_roomId;
    QList<domain::Scene>   m_scenes;
};

/** Household members. Frames 07 and 17. */
class MemberListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Role {
        IdRole = Qt::UserRole + 1,
        NameRole,
        EmailRole,
        PhoneRole,
        AvatarRole,
        OnlineRole,
        /*! Whether this member has a sign-in account. The card says so,
            because "member" now covers two genuinely different things and a
            list that does not distinguish them is a list nobody can audit. */
        CanSignInRole,
    };
    Q_ENUM(Role)

    explicit MemberListModel(QObject *parent = nullptr);

    void setService(services::HomeService *service);
    void refresh();

    [[nodiscard]] int rowCount(const QModelIndex &parent = {}) const override;
    [[nodiscard]] QVariant data(const QModelIndex &index, int role) const override;
    [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

signals:
    void countChanged();

private:
    services::HomeService *m_service = nullptr;
    QList<domain::Member>  m_members;
};

} // namespace smarton::models
