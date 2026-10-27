#pragma once

#include <QtCore/QDateTime>
#include <QtCore/QList>
#include <QtCore/QString>
#include <QtCore/QStringList>

namespace smarton::domain {

/**
 * @file
 * @brief The smart-home vocabulary: Space, Room, Device, Scene.
 *
 * These are deliberately plain value types in one header, with no .cpp.
 * Unlike User and PasswordHash they protect no invariant - a room with a
 * negative area is a data-entry bug, not a security hole - so wrapping them in
 * classes with getters would add ceremony and no safety. They gain behaviour
 * (and their own files) the moment they gain a rule worth enforcing.
 */

/** A house or apartment. The top of the containment hierarchy. */
struct Space
{
    QString id;
    QString name;
    QString address;
    QString imageSource;
};

/** A room inside a Space. */
struct Room
{
    QString id;
    QString spaceId;
    QString name;
    qreal   areaSqm = 0.0;
    QString imageSource;
    /**
     * Storey. 0 is the ground floor; negatives are basements.
     *
     * An INT, not a name. "Ground / First / Second" differ by country - a US
     * first floor is a UK ground floor - and a translated label is not
     * something to sort or stack by. The number is the fact; the wording is a
     * presentation choice the UI makes from it.
     */
    int     floor = 0;
    /** Ambient readings shown on the room header (frame 19). */
    qreal   temperatureC = 0.0;
    qreal   humidityPercent = 0.0;
    /** Consumption for the statistics screen (frame 26). */
    qreal   energyKw = 0.0;
};

/**
 * A controllable device.
 *
 * @c kind drives the icon and which detail controls appear; it is a string
 * rather than an enum because the set grows with every integration and an enum
 * would make adding one a recompile of every layer.
 */
/** How a device is currently reachable. */
enum class Reachability {
    Unknown,     ///< Never heard from - the state before the first report.
    Online,
    Offline,     ///< Last command timed out, or the transport said so.
};

/**
 * A controllable device.
 *
 * @c kind drives the icon and which detail controls appear; it is a string
 * rather than an enum because the set grows with every integration and an
 * enum would make adding one a recompile of every layer.
 *
 * TWO POWER FIELDS, DELIBERATELY. @c on is what the device last REPORTED.
 * @c desiredOn is what the user last ASKED for. They differ for as long as a
 * command is in flight, and they differ permanently if the device never
 * answers - which is the normal case for a lamp someone unplugged.
 *
 * Collapsing them into one field is the single most common bug in home
 * automation UIs: the switch moves the instant it is tapped, the command
 * fails silently, and the panel now says a light is on that is off. Anything
 * that shows state must read @c on; anything that shows intent reads
 * @c desiredOn; the gap between them is what @c pending renders.
 */
struct Device
{
    QString id;
    QString roomId;
    QString name;
    QString kind;              ///< lamp | speaker | diffuser | conditioner | humidifier | hub
    QString imageSource;
    // Stable integration identity. Display names are user-editable, so no
    // protocol adapter is ever allowed to use `name` as its device address.
    QString protocol;          ///< mqtt | zigbee2mqtt | modbus | ir | matter
    QString gatewayId;
    QString manufacturer;
    QString model;
    QString firmwareVersion;
    QString serialNumber;
    QStringList capabilities;  ///< onOff | level | thermostat | leak | lock...
    bool    on = false;        ///< last REPORTED state
    bool    desiredOn = false; ///< last REQUESTED state
    Reachability reachability = Reachability::Unknown;
    QDateTime lastSeen;
    int     signalStrength = -1;   ///< RSSI/LQI normalised by adapter, -1 unknown
    bool    stateStale = true;     ///< no current report from this integration
    QString commandState = QStringLiteral("idle");
    /*! 0 disables this guard. Non-zero is a physical-operation limit for
        pumps, valves, heaters and other loads that must not be left on. */
    int     maxRunSeconds = 0;
    /*! A report must arrive within this period after a command is sent.
        Kept per device because sleepy battery devices are not mains relays. */
    int     commandTimeoutSeconds = 20;
    /*! Require a deliberate second tap before energising/unlocking this device. */
    bool    requiresConfirmation = false;
    qreal   powerWatts = -1.0;      ///< instantaneous draw, -1 when unmetered
    qreal   energyKwh = -1.0;       ///< accumulated meter total, -1 when unmetered
    qreal   voltage = -1.0;
    qreal   currentAmps = -1.0;
    int     batteryPercent = -1;   ///< -1 when the device is mains powered
    int     volumePercent = -1;    ///< -1 when the device has no volume
    /*!
     * How hard the device is running, 0-100, or -1 when it has no continuous
     * setting. Brightness on a lamp, mist output on a humidifier, diffusion
     * rate on a diffuser.
     *
     * SEPARATE FROM @c volumePercent, and not a tidier name for it. They
     * answer different questions and a device can have both: a speaker's
     * loudness is not how hard it is working, and folding the two together
     * would mean the first device that has a volume AND an output level
     * cannot be described at all. The per-kind WORD - "Brightness", "Output"
     * - is the UI's business; the number is the device's.
     */
    int     levelPercent = -1;
    /*! Target temperature in °C, or -1 when the device has no thermostat.
        The TARGET, not the reading - a room's measured temperature lives on
        Room, and conflating the two is how a thermostat ends up displaying
        the number it is trying to reach as though it had reached it. */
    int     targetC = -1;
    /*! cold | wind | sleep | swing. Empty when the device has no modes.
        A string for the same reason \c kind is one: the set is defined by
        what devices exist, and an enum would need a migration every time a
        new appliance class turns up. */
    QString mode;

    /** A command is in flight: the device has not yet confirmed the request. */
    [[nodiscard]] bool pending() const { return on != desiredOn; }
    /*! The only state safe to present as the appliance's current state. */
    [[nodiscard]] bool effectiveOn() const
    { return on && reachability != Reachability::Offline && !stateStale; }
};

/**
 * @brief One device a scene drives, and what it drives it to.
 *
 * -1 MEANS "LEAVE IT ALONE", the same convention the Device fields use. A
 * scene that dims the lamp says nothing about the thermostat, and a scene
 * that sets a temperature is not also asserting that every lamp should be at
 * whatever 0 would mean.
 */
struct SceneAction
{
    QString deviceId;
    bool    on = true;             ///< what the device becomes when the window opens
    int     levelPercent = -1;     ///< brightness, mist, fan - or -1 to leave it
    int     targetC = -1;          ///< thermostat target, or -1 to leave it
};

/**
 * @brief A schedule that drives devices. Frames 21, 23 and 24.
 *
 * TWO SCOPES, AND THE NARROWER ONE WINS. @c actions names devices explicitly.
 * When it is empty the scene falls back to @c roomId - every device in that
 * room, or in the whole space when the room is empty too.
 *
 * That fallback is not a compatibility shim bolted on afterwards, though it
 * is also exactly that: a snapshot written before actions existed has no
 * `actions` key, reads as an empty list, and keeps behaving the way it did.
 * It earns its place independently, because "the living room, at eight" is a
 * scene people actually want and forcing them to enumerate five devices to
 * express it would be worse.
 */
struct Scene
{
    QString id;
    QString roomId;            ///< empty means it spans the whole space
    QString name;
    QString days;              ///< "Everyday", "Mon, Fri", "July 30th"
    QString timeRange;         ///< "08:15 AM - 09:00 AM"
    bool    enabled = false;
    QList<SceneAction> actions;

    /** True when this scene names its devices rather than taking a room. */
    [[nodiscard]] bool isPerDevice() const { return !actions.isEmpty(); }
};

/** A person with access to the space. Frames 07 and 17. */
struct Member
{
    QString id;
    QString name;
    QString email;
    QString phone;
    QString avatarSource;
    bool    online = false;

    /**
     * Row id in the accounts table, or 0 for a member who cannot sign in.
     *
     * A LINK, not a copy. The credential lives in `users` with everything the
     * password path already guarantees - PBKDF2 verifier, lockout counters,
     * rehash-on-cost-change - and duplicating any of it into the home model
     * would mean a second copy to keep in step and a second place a verifier
     * could leak from. The home model is also what a factory reset wipes; an
     * account outliving that is the correct behaviour, and only possible if
     * the two are separate records.
     */
    qint64  accountId = 0;

    [[nodiscard]] bool canSignIn() const { return accountId > 0; }
};

/**
 * @brief Something that happened in the house, worth telling a person later.
 *
 * A RECORD, not a reference. @c subject is the device's name AS IT WAS, not
 * its id: a log line that says "Smart Lamp switched on" has to keep saying
 * that after the lamp is renamed or removed, and an id resolved at read time
 * says "(deleted) switched on" or nothing at all. That is the difference
 * between a log and a join.
 */
struct ActivityEntry
{
    QDateTime when;
    QString   kind;      ///< device | scene | space | session
    QString   subject;   ///< what it happened to, named at the time
    QString   detail;    ///< what happened: "switched on", "ran", "removed"
    /*! Who did it - a username, or empty when the house did it to itself.
        The schedule firing at 6 am has no actor, and saying it was whoever
        happened to be signed in last would be a lie in a record people will
        read to work out what happened. */
    QString   actor;
};

/** Current conditions for the dashboard strip. Frame 07. */
struct Weather
{
    QString description;
    qreal   temperatureC = 0.0;
    qreal   humidityPercent = 0.0;
};

} // namespace smarton::domain
