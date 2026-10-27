#pragma once

#include <smarton/domain/entities/HomeEntities.h>
#include <smarton/domain/entities/User.h>

#include <QtCore/QJsonArray>
#include <QtCore/QJsonObject>
#include <QtCore/QHash>
#include <QtCore/QObject>

QT_BEGIN_NAMESPACE
class QTimer;
QT_END_NAMESPACE

namespace smarton::services {

/**
 * @brief Where the home model is kept between runs.
 *
 * A whole-model snapshot, not a table per entity.
 *
 * The first version of this stored only toggles and name overrides, keyed by
 * id, and let the seed supply the catalogue. That works exactly until the user
 * can ADD and REMOVE things - which the space wizard does - and then "the seed
 * says what exists, the store says what you changed" stops being expressible:
 * a room the user deleted has no row to represent its absence, and a room they
 * created has no seed entry to attach to.
 *
 * So the seed became what it always really was - factory defaults - and the
 * store holds the live model. One snapshot handles adds, removes, renames and
 * toggles with no per-field migration, and the format is the same JSON the
 * seed uses, so a snapshot can be diffed against defaults by eye.
 */
class IHomeStore
{
public:
    virtual ~IHomeStore() = default;

    /** The stored model, or an empty object when nothing is stored yet. */
    [[nodiscard]] virtual QJsonObject load() = 0;
    virtual bool save(const QJsonObject &model) = 0;
};

/**
 * @brief The home model: one space, its rooms, devices, scenes and members.
 *
 * Single source of truth for everything the signed-in app shows. Screens never
 * hold their own copy - they bind to list models that read from here, so a
 * device toggled on the dashboard is already on when you open its room.
 *
 * Every mutation persists immediately. There is no Save button in the design
 * and no session to lose work from, so deferring the write would only create a
 * window in which the panel losing power loses the user's rooms.
 */
class IDeviceTransport;

class HomeService : public QObject
{
    Q_OBJECT
public:
    explicit HomeService(QObject *parent = nullptr);

    /** Attach the store. Optional: without one the app works and forgets. */
    void setStore(IHomeStore *store);

    /**
     * Attach the hardware boundary. Optional, and its absence is the
     * difference between a demo and a product:
     *
     *  - WITHOUT a transport, setDevicePower() applies immediately. Nothing
     *    is being controlled, so there is nothing to wait for, and pretending
     *    otherwise would only add latency to a simulation.
     *  - WITH one, setDevicePower() RECORDS INTENT and asks the transport.
     *    `on` changes only when the device reports back. A command that is
     *    never answered leaves the device visibly pending and then offline -
     *    it does not silently become "on".
     */
    void setTransport(IDeviceTransport *transport);

    /**
     * Load the stored model, falling back to @p seedResourcePath the first
     * time. Returns false and sets lastError() when neither can be read.
     */
    bool load(const QString &seedResourcePath);

    /** Discard the stored model and re-read the factory defaults. */
    bool resetToDefaults(const QString &seedResourcePath);

    [[nodiscard]] QString lastError() const { return m_lastError; }
    [[nodiscard]] bool isEmpty() const { return m_space.id.isEmpty(); }

    // ---- spaces -------------------------------------------------------------
    /*!
        @brief The space this panel is currently showing.
        @note Everything below - rooms, devices, scenes - belongs to it.
     */
    [[nodiscard]] const domain::Space   &space()   const { return m_space; }

    /*!
        Every space the household has, in the order they were created.

        ONE SPACE IS LIVE AT A TIME, and that is a product position rather
        than a limitation worked around. A panel screwed to a wall controls
        the building it is screwed to; the second space is somewhere else,
        over a network its Zigbee mesh does not reach. Switching to it is
        looking at another house, not extending this one - so the fields
        below hold the active space's model and the others wait as stored
        snapshots. The single-space code IS the multi-space code, restricted
        to one at a time, which is why nothing that reads rooms() or
        devices() had to change.
     */
    [[nodiscard]] QList<domain::Space> spaces() const;
    [[nodiscard]] QString activeSpaceId() const { return m_activeSpaceId; }
    [[nodiscard]] int spaceCount() const { return int(m_spaceModels.size()); }

    /*! Show a different space. Operating, not administering: a guest may look
        at the other house without being able to rearrange either. */
    bool setActiveSpace(const QString &spaceId);

    /*! Create an empty space and switch to it. Returns its id, or empty when
        refused. The picker has offered this since it was written; until now
        nothing could honour it. */
    QString addSpace(const QString &name, const QString &address,
                     const QString &imageSource = {});

    /*! Delete a space and everything in it. Refuses the last one - a panel
        with no space is a panel showing the empty state with no way out of
        it, which the setup wizard is for and this is not. */
    bool removeSpace(const QString &spaceId);
    [[nodiscard]] const domain::Weather &weather() const { return m_weather; }
    [[nodiscard]] const QList<domain::Room>   &rooms()   const { return m_rooms; }
    [[nodiscard]] const QList<domain::Device> &devices() const { return m_devices; }
    [[nodiscard]] const QList<domain::Scene>  &scenes()  const { return m_scenes; }
    [[nodiscard]] const QList<domain::Member> &members() const { return m_members; }
    /** Devices detected nearby but not yet linked. Frames 16 and 17. */
    [[nodiscard]] const QList<domain::Device> &availableDevices() const
    { return m_available; }

    [[nodiscard]] QList<domain::Device> devicesInRoom(const QString &roomId) const;
    [[nodiscard]] QList<domain::Scene>  scenesInRoom(const QString &roomId) const;
    [[nodiscard]] int deviceCountInRoom(const QString &roomId) const;
    [[nodiscard]] QString roomName(const QString &roomId) const;

    // ---- who is asking ------------------------------------------------------
    /**
     * @brief Who a mutation is on behalf of.
     *
     * @c User is a person at the panel and is gated by \l actor(). @c System
     * is the house acting on its own - the scene scheduler at six in the
     * morning - and is not. A schedule that only fires while an administrator
     * happens to be looking at the panel is not a schedule.
     */
    enum class Actor { User, System };

    /**
     * @brief The signed-in user's role. Gates every mutation below.
     *
     * STARTS AT VIEWER, the least-privileged value. An authorisation default
     * that is convenient is an authorisation default that ships: if the
     * composition root forgets to call this, the panel refuses to change
     * anything, and that is a bug somebody reports within a minute. The other
     * way round is a bug nobody reports at all.
     *
     * A plain value, not a pointer to AuthService. HomeService is that
     * service's sibling, not its dependent, and the composition root already
     * owns the wiring between the two.
     */
    void setActor(domain::Role role);
    [[nodiscard]] domain::Role actor() const { return m_actor; }

    /*! Operate the house: power, targets, modes, levels, scene enablement. */
    [[nodiscard]] bool mayOperate() const;
    /*! Commission, replace and unpair devices without granting account or
        household administration. This is the installer boundary. */
    [[nodiscard]] bool mayInstall() const;
    /*! Change household policy: rooms, members, names and schedules. */
    [[nodiscard]] bool mayAdminister() const;

    // ---- toggles ----------------------------------------------------------
    /**
     * Ask for a device to change. Returns false for an unknown id, or when
     * the actor's role does not permit it.
     *
     * With a transport attached this sets `desiredOn` and sends; the reported
     * state follows later, or does not. Read Device::pending() to render the
     * gap.
     */
    bool setDevicePower(const QString &deviceId, bool on, Actor by = Actor::User);
    bool setSceneEnabled(const QString &sceneId, bool enabled,
                         Actor by = Actor::User);

    /*!
        Flip a device, without the caller having to know which way.

        Flips \c desiredOn, not \c on. Asked twice in a row while a command
        is still in flight, a toggle that read the REPORTED state would send
        the same command again - the device has not answered yet, so it still
        reports what it did before - and the second press would appear to do
        nothing. Intent is what a toggle inverts.
    */
    bool toggleDevicePower(const QString &deviceId, Actor by = Actor::User);

    // ---- renames ----------------------------------------------------------
    bool renameSpace(const QString &name);
    bool renameRoom(const QString &roomId, const QString &name);
    bool renameDevice(const QString &deviceId, const QString &name);
    bool renameScene(const QString &sceneId, const QString &name);

    // ---- structure --------------------------------------------------------
    /** Create the space itself. Only meaningful when isEmpty(). */
    bool createSpace(const QString &name, const QString &address);
    bool setSpaceAddress(const QString &address);

    /** Returns the new room's id, or an empty string when refused. */
    QString addRoom(const QString &name, qreal areaSqm, const QString &imageSource);
    /*! With a storey. 0 is the ground floor; negatives are basements. */
    QString addRoom(const QString &name, qreal areaSqm, const QString &imageSource,
                    int floor);
    /*! Move a room to another storey. */
    bool setRoomFloor(const QString &roomId, int floor);
    bool removeRoom(const QString &roomId);

    /** Move an entry from availableDevices() into the space. */
    bool linkDevice(const QString &availableId, const QString &roomId);
    /*! Provision a protocol-ready device before a physical gateway is wired.
        The adapter later binds the stable id/protocol rather than replacing
        the room, name, scenes, or safety policy the household configured. */
    QString addManualDevice(const QString &name, const QString &kind,
                            const QString &roomId, const QString &protocol);
    /*! Replace a failed linked device with an available one while preserving
        its room, user-facing name, and every per-device scene reference. */
    bool replaceDevice(const QString &deviceId, const QString &availableId);
    bool unlinkDevice(const QString &deviceId);
    bool setDeviceRoom(const QString &deviceId, const QString &roomId);
    /*! Safety configuration for hazardous loads. Zero disables the panel-side
        timer; it does not replace an independent physical failsafe. */
    bool setDeviceMaxRunSeconds(const QString &deviceId, int seconds);

    QString addScene(const QString &name, const QString &roomId,
                     const QString &days, const QString &timeRange);
    bool removeScene(const QString &sceneId);
    bool setSceneSchedule(const QString &sceneId, const QString &days,
                          const QString &timeRange);

    /*!
        Replace what a scene drives.

        An empty list is not a refusal - it is the scene going back to taking
        its whole room, which is a state people move between and not an error.
        Actions naming a device that no longer exists are dropped here rather
        than at fire time: a scene that silently does nothing at 6 am is far
        harder to explain than one that shows four devices instead of five.
    */
    bool setSceneActions(const QString &sceneId,
                         const QList<domain::SceneAction> &actions);

    /*!
        Below this, a battery is worth telling somebody about.

        20 rather than 10. A wall panel is not a phone in a pocket: nobody is
        watching it, and the useful moment to mention a battery is while there
        is still time to do something about it on a weekend rather than the
        evening it stops responding.
    */
    static constexpr int kLowBatteryPercent = 20;

    /*! Devices that have a battery and are running low. Mains-powered devices
        report -1 and are not "at zero" - which is the bug you get from
        testing the number instead of the capability. */
    [[nodiscard]] QList<domain::Device> lowBatteryDevices() const;

    /*! Bounds for a thermostat target. Narrow on purpose: this is a home, and
        a range wide enough for an industrial chiller is a range wide enough to
        set by accident. */
    static constexpr int kMinTargetC = 16;
    static constexpr int kMaxTargetC = 30;

    /*! Target temperature, in °C. False when the device has no thermostat or
        the value is out of range. */
    bool setDeviceTarget(const QString &deviceId, int targetC,
                                   Actor by = Actor::User);
    /*! cold | wind | sleep | swing. False when unknown, or the device has no
        modes. */
    bool setDeviceMode(const QString &deviceId, const QString &mode,
                                 Actor by = Actor::User);

    /*! Speaker loudness, 0-100. False when the device has no volume. */
    bool setDeviceVolume(const QString &deviceId, int percent,
                                   Actor by = Actor::User);
    /*! Output level, 0-100 - brightness, mist, diffusion. False when the
        device has no continuous setting. */
    bool setDeviceLevel(const QString &deviceId, int percent,
                                  Actor by = Actor::User);

    // ---- backup and restore -------------------------------------------------
    /*!
        Version stamped into every export.

        A backup outlives the build that wrote it - that is the entire point
        of one - so it says what shape it is in. An import that finds a format
        it does not know refuses rather than guessing, because a half-understood
        restore is worse than no restore: it replaces a working house with a
        partial one and there is nothing left to compare against.
    */
    static constexpr int kBackupFormat = 1;

    /*!
        Write the whole home model to @p filePath.

        THE HOME MODEL, NOT THE ACCOUNTS. Spaces, rooms, devices, scenes and
        the member list go in; password verifiers, session tokens and the
        accounts table do not. A backup is a file people put on a USB stick
        and email to themselves, and a file full of PBKDF2 verifiers is not a
        file to treat that way. Members keep their account LINK, so restoring
        onto the same panel finds the same accounts and restoring onto a fresh
        one produces members who cannot sign in until they are given an
        account - which is the honest outcome, not a silent one.
    */
    bool exportModel(const QString &filePath);

    /*!
        Replace the home model with the one in @p filePath.

        Validated before anything is touched: the file is parsed, its format
        checked and the model read into a scratch service-shaped structure
        first, so a corrupt backup leaves the running model exactly as it was.
        A restore that fails halfway is the one failure mode this must not
        have.
    */
    bool importModel(const QString &filePath);

    QString addMember(const QString &name, const QString &email);
    /**
     * @brief Full form: the fields the Members screen collects.
     * @param accountId row in the accounts table, or 0 for a member who
     *        cannot sign in. The account itself is created by AuthService -
     *        this layer stores the link and never touches a credential.
     */
    QString addMember(const QString &name, const QString &email,
                      const QString &phone, const QString &avatarSource,
                      qint64 accountId);

    /*! Attach an account to an existing member, or 0 to detach. */
    bool linkMemberAccount(const QString &memberId, qint64 accountId);
    bool removeMember(const QString &memberId);

signals:
    /** The catalogue changed shape - models must reset. */
    void reloaded();
    void devicePowerChanged(int index, bool on);
    /*! An accepted intent, before a physical device has necessarily reported
        it. Kept distinct from devicePowerChanged so the audit trail cannot
        claim a requested relay change was already confirmed. */
    void deviceCommandRequested(const QString &deviceId, const QString &deviceName,
                                bool on, Actor actor);
    /** Intent or reachability moved without the reported state changing. */
    void deviceStatusChanged(int index);
    /** A command could not be delivered. The UI should say so, once. */
    void deviceCommandFailed(const QString &deviceId, const QString &deviceName);
    /*! A configured maximum run time elapsed and an OFF command was issued. */
    void deviceSafetyTimeout(const QString &deviceId, const QString &deviceName);
    /*! Reported when an adapter establishes or loses device reachability. */
    void deviceReachabilityChanged(const QString &deviceId, const QString &deviceName,
                                   bool online);
    void sceneEnabledChanged(int index, bool enabled);
    void spaceChanged();
    void roomChanged(int index);
    void deviceChanged(int index);
    void sceneChanged(int index);
    /*! A space was added, removed, or became the active one. The whole model
        underneath has changed with it, so \l reloaded() fires too. */
    void spacesChanged();
    /*! A mutation was refused because of the actor's role. @p action is a KEY
        - "operate", "administer" - not a sentence: the wording belongs to the
        UI, which is the layer that knows the user's language. */
    void refusedByRole(const QString &action);
    /*! Somebody else is at the panel. Everything bound to what the actor may
        do has to re-evaluate. */
    void actorChanged();

private:
    /*! Guard for every mutation. Returns @p permitted, and says so once when
        it is false - a refusal the UI never hears about is indistinguishable
        from a control that is broken. */
    bool permitted(bool allowed, const char *action);

    domain::Role m_actor = domain::Role::Viewer;

    /*! Shared body of the two percentage setters. A pointer-to-member rather
        than two near-identical functions, because the only thing that differed
        between them was which field to clamp into. */
    bool setPercentField(const QString &deviceId, int percent,
                         int domain::Device::*field, Actor by);

    [[nodiscard]] int indexOfDevice(const QString &deviceId) const;
    [[nodiscard]] int indexOfScene(const QString &sceneId) const;
    [[nodiscard]] int indexOfRoom(const QString &roomId) const;
    [[nodiscard]] static QString sanitiseName(const QString &name);
    /** Time-ordered, collision-free within a run. */
    [[nodiscard]] static QString makeId(const QString &prefix);

    bool readModel(const QJsonObject &root);
    [[nodiscard]] QJsonObject writeModel() const;
    /*! One space's model: its details, weather, rooms, devices and scenes -
        everything except the members, who belong to the household rather
        than to a building. */
    void readSpace(const QJsonObject &object);
    void readMembers(const QJsonArray &memberArray);
    [[nodiscard]] QJsonObject writeSpace() const;
    /*! Index into \l m_spaceModels, or -1. */
    [[nodiscard]] int indexOfSpaceModel(const QString &spaceId) const;
    /*! Park the live space back into the array and load another. No
        permission check: the two callers do their own, and doing it twice
        would emit the refusal twice for one action. */
    void switchTo(const QString &spaceId);
    void persist();

    void onPowerReported(const QString &deviceId, bool on);
    void onReachabilityChanged(const QString &deviceId, domain::Reachability state);
    void onMetadataReported(const QString &deviceId, const QVariantMap &metadata);
    void updateSafetyTimer(const domain::Device &device);
    void startCommandTimeout(const QString &deviceId);
    void clearCommandTimeout(const QString &deviceId);

    IHomeStore           *m_store = nullptr;
    IDeviceTransport     *m_transport = nullptr;
    QHash<QString, QTimer *> m_safetyTimers;
    QHash<QString, QTimer *> m_commandTimers;
    /*! Every space as stored, INCLUDING the active one - which is refreshed
        from the live fields on the way out rather than kept in step on every
        edit. Two copies that must agree at all times is the bug; one copy
        that is authoritative at a known moment is not. */
    QJsonArray            m_spaceModels;
    QString               m_activeSpaceId;
    domain::Space         m_space;
    domain::Weather       m_weather;
    QList<domain::Room>   m_rooms;
    QList<domain::Device> m_devices;
    QList<domain::Device> m_available;
    QList<domain::Scene>  m_scenes;
    QList<domain::Member> m_members;
    QString               m_lastError;
    /** Suppresses writes while load() is populating. */
    bool                  m_loading = false;
};

} // namespace smarton::services
