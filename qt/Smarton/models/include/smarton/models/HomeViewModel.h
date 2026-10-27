#pragma once

#include <smarton/models/HomeListModels.h>

#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QUrl>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>
#include <QtQml/qqmlregistration.h>

namespace smarton::services {
class HomeService;
class AuthService;
class IAvatarStore;
}

namespace smarton::models {

/**
 * @brief Everything the signed-in shell binds to.
 *
 * One view model for the shell rather than one per screen, because every
 * screen here is a view of the SAME space: the rooms on the Rooms screen and
 * the rooms behind the device counts on the dashboard are one collection. Two
 * view models would mean two copies and a synchronisation bug waiting to
 * happen. Screens that need a narrowed list get their own DeviceListModel
 * pointed at a room; the catalogue underneath is still shared.
 */
class HomeViewModel : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString spaceName READ spaceName NOTIFY spaceChanged)
    Q_PROPERTY(QString spaceAddress READ spaceAddress NOTIFY spaceChanged)
    Q_PROPERTY(QString spaceImage READ spaceImage NOTIFY spaceChanged)
    Q_PROPERTY(bool hasSpace READ hasSpace NOTIFY spaceChanged)

    /*! Every space the household has: { spaceId, name, address, image,
        active }. The picker has had a `spaces` property since it was written
        and every screen passed it nothing. */
    Q_PROPERTY(QVariantList spaces READ spaces NOTIFY spacesChanged)
    Q_PROPERTY(QString activeSpaceId READ activeSpaceId NOTIFY spacesChanged)
    Q_PROPERTY(int spaceCount READ spaceCount NOTIFY spacesChanged)

    Q_PROPERTY(QString weatherDescription READ weatherDescription NOTIFY spaceChanged)
    Q_PROPERTY(int weatherTemperature READ weatherTemperature NOTIFY spaceChanged)
    Q_PROPERTY(int weatherHumidity READ weatherHumidity NOTIFY spaceChanged)

    Q_PROPERTY(QAbstractListModel *rooms READ rooms CONSTANT)
    Q_PROPERTY(QAbstractListModel *devices READ devices CONSTANT)
    /*! A SECOND device model, narrowed to one room. Two models rather than
        one shared model with a filter, because the dashboard and an open room
        screen are both live at the same time and would fight over the filter.
        Both read the same catalogue, so a toggle still updates both. */
    Q_PROPERTY(QAbstractListModel *roomDevices READ roomDevices CONSTANT)
    Q_PROPERTY(QAbstractListModel *scenes READ scenes CONSTANT)
    Q_PROPERTY(QAbstractListModel *members READ members CONSTANT)

    Q_PROPERTY(int roomCount READ roomCount NOTIFY countsChanged)
    Q_PROPERTY(int deviceCount READ deviceCount NOTIFY countsChanged)
    Q_PROPERTY(int memberCount READ memberCount NOTIFY countsChanged)
    Q_PROPERTY(int availableDeviceCount READ availableDeviceCount NOTIFY countsChanged)
    /*! Devices with a battery that is running low. Stored and shown as a
        number on one screen since the model was written; nothing ever said
        anything about it. */
    Q_PROPERTY(int lowBatteryCount READ lowBatteryCount NOTIFY countsChanged)
    Q_PROPERTY(int lowBatteryThreshold READ lowBatteryThreshold CONSTANT)
    Q_PROPERTY(int offlineDeviceCount READ offlineDeviceCount NOTIFY countsChanged)
    Q_PROPERTY(int staleDeviceCount READ staleDeviceCount NOTIFY countsChanged)
    /*! Active life-safety alarms. A sensor's reported ON state means alarm
        active for these kinds; it is never hidden behind a toast. */
    Q_PROPERTY(QVariantList criticalAlerts READ criticalAlerts NOTIFY countsChanged)

public:
    explicit HomeViewModel(QObject *parent = nullptr);

    void setService(services::HomeService *service);
    /*! Optional. Without it, members can be added but never given a password -
        the form disables that half rather than pretending. */
    void setAuthService(services::AuthService *auth);
    /*! Optional. Without it, a chosen picture is refused rather than stored
        as a path into wherever the user was browsing. */
    void setAvatarStore(services::IAvatarStore *avatars);

    [[nodiscard]] QString spaceName() const;
    [[nodiscard]] QString spaceAddress() const;
    [[nodiscard]] QString spaceImage() const;
    [[nodiscard]] bool hasSpace() const;

    [[nodiscard]] QString weatherDescription() const;
    [[nodiscard]] int weatherTemperature() const;
    [[nodiscard]] int weatherHumidity() const;

    [[nodiscard]] QAbstractListModel *rooms()   { return &m_rooms; }
    [[nodiscard]] QAbstractListModel *devices() { return &m_devices; }
    [[nodiscard]] QAbstractListModel *roomDevices() { return &m_roomDevices; }
    [[nodiscard]] QAbstractListModel *scenes()  { return &m_scenes; }
    [[nodiscard]] QAbstractListModel *members() { return &m_members; }

    [[nodiscard]] int roomCount() const;
    [[nodiscard]] int deviceCount() const;
    [[nodiscard]] int memberCount() const;
    [[nodiscard]] int availableDeviceCount() const;

    /** Turn every light in the space on or off. The dashboard quick action. */
    Q_INVOKABLE void setAllLights(bool on);

    [[nodiscard]] int lowBatteryCount() const;
    [[nodiscard]] int lowBatteryThreshold() const;
    /*! Names of the devices running low, for the message that says which. */
    Q_INVOKABLE QStringList lowBatteryNames() const;
    [[nodiscard]] int offlineDeviceCount() const;
    [[nodiscard]] int staleDeviceCount() const;
    Q_INVOKABLE QStringList offlineDeviceNames() const;
    Q_INVOKABLE QStringList staleDeviceNames() const;
    [[nodiscard]] QVariantList criticalAlerts() const;

    [[nodiscard]] bool canOperate() const;
    [[nodiscard]] bool canInstall() const;
    [[nodiscard]] bool canAdminister() const;
    /*! Viewer | Guest | Operator | Installer | Administrator | Owner. */
    Q_INVOKABLE QString currentRole() const;
    /** True when at least one lamp is on - so the tile can say which it does. */
    Q_PROPERTY(bool anyLightOn READ anyLightOn NOTIFY countsChanged)

    /*! What the signed-in user is allowed to do. Screens bind controls to
        these rather than letting the service refuse afterwards: a switch that
        moves and does nothing is worse than one that is visibly disabled, and
        the same rule already applies to every other inert control in the app. */
    Q_PROPERTY(bool canOperate READ canOperate NOTIFY permissionsChanged)
    Q_PROPERTY(bool canInstall READ canInstall NOTIFY permissionsChanged)
    Q_PROPERTY(bool canAdminister READ canAdminister NOTIFY permissionsChanged)
    [[nodiscard]] bool anyLightOn() const;

    Q_INVOKABLE void renameSpace(const QString &name);

    // ---- single-entity lookups, for the detail screens -------------------
    // A detail screen is given an id and asks for what it needs. It does NOT
    // get handed a copy of the entity: a copy goes stale the moment anything
    // else changes it, and these screens are open while the dashboard is
    // still toggling the same device.
    Q_INVOKABLE QVariantMap device(const QString &deviceId) const;
    Q_INVOKABLE QVariantMap room(const QString &roomId) const;
    Q_INVOKABLE int roomDeviceCount(const QString &roomId) const;
    Q_INVOKABLE void setDevicePower(const QString &deviceId, bool on);
    /*! Flip a device by id. For surfaces that have a device but no switch -
        the 3D map, where holding a marker operates it. */
    Q_INVOKABLE void toggleDevicePower(const QString &deviceId);
    /*! Thermostat target in °C. Ignored when the device has none. */
    Q_INVOKABLE void setDeviceTarget(const QString &deviceId, int targetC);
    /*! cold | wind | sleep | swing. Ignored when the device has no modes. */
    Q_INVOKABLE void setDeviceMode(const QString &deviceId, const QString &mode);
    /*! Speaker loudness, 0-100. Ignored when the device has no volume. */
    Q_INVOKABLE void setDeviceVolume(const QString &deviceId, int percent);
    /*! Output level, 0-100 - brightness on a lamp, mist on a humidifier.
        Ignored when the device has no continuous setting. */
    Q_INVOKABLE void setDeviceLevel(const QString &deviceId, int percent);
    /*! Move a device to another room. False for an unknown id or no change. */
    Q_INVOKABLE bool setDeviceRoom(const QString &deviceId, const QString &roomId);
    Q_INVOKABLE bool setDeviceMaxRunSeconds(const QString &deviceId, int seconds);
    /*! The word this device's level is called, for the control's label. */
    Q_INVOKABLE QString levelLabel(const QString &deviceId) const;
    /*! The bounds the dial should span. Read from the service rather than
        repeated in QML, so the control cannot offer a value the service then
        refuses. */
    Q_INVOKABLE int minTargetC() const;
    Q_INVOKABLE int maxTargetC() const;
    Q_INVOKABLE void renameDevice(const QString &deviceId, const QString &name);
    Q_INVOKABLE void renameRoom(const QString &roomId, const QString &name);

    // ---- structure -------------------------------------------------------
    // Wizards call these. Each returns the new id (or "" on refusal) so the
    // caller can navigate straight to what it just made.

    Q_INVOKABLE bool createSpace(const QString &name, const QString &address);

    [[nodiscard]] QVariantList spaces() const;
    [[nodiscard]] QString activeSpaceId() const;
    [[nodiscard]] int spaceCount() const;
    /*! Show a different space. Everything on screen changes with it. */
    Q_INVOKABLE bool switchSpace(const QString &spaceId);
    /*! Create an empty space and switch to it. Returns its id, or empty. */
    Q_INVOKABLE QString addSpace(const QString &name, const QString &address);
    /*! Delete a space and everything in it. Refuses the last one. */
    Q_INVOKABLE bool removeSpace(const QString &spaceId);
    Q_INVOKABLE void setSpaceAddress(const QString &address);
    /*! Distinct storeys that have rooms, ascending. Empty when there are no
        rooms at all - the map shows its empty state rather than one blank
        floor. */
    Q_INVOKABLE QVariantList floors() const;
    /*! Move a room to another storey. */
    Q_INVOKABLE bool setRoomFloor(const QString &roomId, int floor);

    Q_INVOKABLE QString addRoom(const QString &name, qreal areaSqm,
                                const QString &imageSource);
    /*! With a storey. */
    Q_INVOKABLE QString addRoomOnFloor(const QString &name, qreal areaSqm,
                                       const QString &imageSource, int floor);
    Q_INVOKABLE bool removeRoom(const QString &roomId);
    Q_INVOKABLE bool linkDevice(const QString &availableId, const QString &roomId);
    Q_INVOKABLE QString addManualDevice(const QString &name, const QString &kind,
                                        const QString &roomId, const QString &protocol);
    Q_INVOKABLE bool replaceDevice(const QString &deviceId, const QString &availableId);
    Q_INVOKABLE bool unlinkDevice(const QString &deviceId);
    Q_INVOKABLE QString addScene(const QString &name, const QString &roomId,
                                 const QString &days, const QString &timeRange);
    Q_INVOKABLE bool removeScene(const QString &sceneId);
    /*!
        What a scene drives, one entry per device.

        Rows are { deviceId, name, image, on, level, targetC, hasLevel,
        hasTarget } - the device's identity AND its capabilities, because the
        editor has to know whether to draw a brightness slider before it knows
        what the scene sets it to. An empty list means the scene takes its
        room.
    */
    Q_INVOKABLE QVariantList sceneActions(const QString &sceneId) const;
    /*! A no-side-effect explanation of what a stored scene would do. It is
        deliberately separate from the scheduler so an installer can verify a
        scene without opening a relay, lock or valve. */
    Q_INVOKABLE QVariantList scenePreview(const QString &sceneId) const;
    /*! Replace them. Rows need only deviceId; on, level and targetC default
        to on, -1, -1 - "switch it on and leave everything else alone". */
    Q_INVOKABLE bool setSceneActions(const QString &sceneId,
                                     const QVariantList &actions);
    /*! Every device that could be added to a scene, with its capabilities.
        The scene editor's palette. */
    Q_INVOKABLE QVariantList sceneCandidates(const QString &roomId) const;

    Q_INVOKABLE bool setSceneSchedule(const QString &sceneId, const QString &days,
                                      const QString &timeRange);
    Q_INVOKABLE QString addMember(const QString &name, const QString &email);

    /**
     * @brief The full Add-member form.
     *
     * ONE call rather than the screen orchestrating three, because this is one
     * user action and the steps are not independent: an account created and
     * then a member record that fails leaves a credential nobody can reach,
     * and splitting it across two view models puts that failure window in the
     * UI where it cannot be tested.
     *
     * @param password empty for a member who cannot sign in - only the name is
     *        mandatory, everything else is optional by design.
     * @param avatarFileUrl straight from a FileDialog; copied into managed
     *        storage, never referenced where the user picked it.
     * @return the new member id, or empty. \l lastMemberError explains why.
     */
    Q_INVOKABLE QString addMemberDetailed(const QString &name,
                                          const QString &email,
                                          const QString &phone,
                                          const QString &avatarFileUrl,
                                          const QString &password,
                                          const QString &role);

    /*! Why the last addMemberDetailed() failed. Empty after a success. */
    Q_PROPERTY(QString lastMemberError READ lastMemberError NOTIFY lastMemberErrorChanged)
    [[nodiscard]] QString lastMemberError() const { return m_lastMemberError; }
    Q_INVOKABLE bool removeMember(const QString &memberId);

    /** Detected-but-unlinked devices, as [{ id, name, kind, image }, ...]. */
    // ---- backup and restore -------------------------------------------------
    /*! Write a backup to \a fileUrl - a file:// URL, because that is what
        FileDialog hands back. False sets \l lastBackupError. */
    Q_INVOKABLE bool exportBackup(const QUrl &fileUrl);
    /*! Replace the home model from \a fileUrl. False sets \l lastBackupError. */
    Q_INVOKABLE bool importBackup(const QUrl &fileUrl);
    /*! A dated default file name, so two backups in one week do not overwrite
        each other by default. */
    Q_INVOKABLE QString suggestedBackupName() const;
    Q_PROPERTY(QString lastBackupError READ lastBackupError NOTIFY lastBackupErrorChanged)
    [[nodiscard]] QString lastBackupError() const { return m_lastBackupError; }

    Q_INVOKABLE QVariantList availableDevices() const;
    /*! The devices already in the space, in the same shape availableDevices()
        returns. A plain list, not the list MODEL: the search on the link step
        has to fold both sets into one result list and filter them together,
        which is a JavaScript array operation. */
    Q_INVOKABLE QVariantList linkedDevices() const;
    /** Rooms as [{ id, name }, ...], for the wizard's room picker. */
    Q_INVOKABLE QVariantList roomChoices() const;
    /** Artwork a new room can be given, as [{ label, image }, ...]. */
    Q_INVOKABLE QVariantList roomArtwork() const;

    /**
     * @brief Everything the map view needs, in one call.
     *
     * A QVariantList rather than the existing rooms list model, because the
     * floor-plan layout is computed in JavaScript and a QAbstractListModel is
     * not iterable from there. One call rather than a room query plus a device
     * query per room: the map redraws on every resize, and N+1 invokables
     * across the QML/C++ boundary during a drag is exactly the kind of cost
     * that only shows up on the panel.
     *
     * Each entry: { roomId, name, areaSqm, deviceCount, devices: [...] }.
     */
    Q_INVOKABLE QVariantList floorPlan() const;

    /** Point the room-scoped device AND scene models at a room. Empty clears. */
    Q_INVOKABLE void setRoomFilter(const QString &roomId);
    /** Narrow only the scene model. Empty shows every scene in the space. */
    Q_INVOKABLE void setSceneFilter(const QString &roomId);

    /**
     * Room filter chips as [{ id, name }, ...], with an "All" entry first.
     *
     * Exists so QML never has to index a model by raw role NUMBER to build a
     * filter bar. Role numbers are an implementation detail of the model and
     * change the moment a role is inserted; a screen that hardcodes 257 breaks
     * silently and shows blank chips.
     */
    Q_INVOKABLE QVariantList roomFilters() const;

    /** Total consumption, and the per-day series the chart draws. */
    Q_INVOKABLE QVariantList energySeries(const QString &period) const;
    Q_INVOKABLE qreal energyTotal(const QString &period) const;

    /** Resolve a seed-relative image path to a resource URL. Kept here so the
        prefix appears once in the codebase instead of in every delegate.
        Deliberately not static: QML calls it, and a Q_INVOKABLE static member
        is a corner of moc this project does not need to rely on. */
    Q_INVOKABLE QString imageUrl(const QString &relativePath) const;

signals:
    void spaceChanged();
    void spacesChanged();
    void countsChanged();
    void lastMemberErrorChanged();
    void lastBackupErrorChanged();
    /** A device's fields changed; detail screens re-read what they need. */
    void deviceChanged(const QString &deviceId);
    void roomChanged(const QString &roomId);
    /** A device did not answer. The UI should say so, briefly and once. */
    void commandFailed(const QString &deviceId, const QString &deviceName);
    void deviceReachabilityChanged(const QString &deviceId, const QString &deviceName,
                                   bool online);
    void permissionsChanged();
    /*! The service refused a change because of the signed-in role. \a action
        is "operate" or "administer"; the sentence is the UI's to write. */
    void permissionDenied(const QString &action);

private:
    services::HomeService  *m_service = nullptr;
    services::AuthService  *m_auth    = nullptr;
    services::IAvatarStore *m_avatars = nullptr;
    QString                 m_lastMemberError;
    QString                 m_lastBackupError;
    RoomListModel   m_rooms;
    DeviceListModel m_devices;
    DeviceListModel m_roomDevices;
    SceneListModel  m_scenes;
    MemberListModel m_members;
};

} // namespace smarton::models
