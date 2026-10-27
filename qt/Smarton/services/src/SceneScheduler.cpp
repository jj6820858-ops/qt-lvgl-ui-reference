#include <smarton/services/SceneScheduler.h>

#include <smarton/services/HomeService.h>

#include <QtCore/QLocale>
#include <QtCore/QtGlobal>
#include <QtCore/QStringList>

#include <utility>

namespace smarton::services {

using namespace smarton::domain;

namespace {
constexpr int kDefaultTickMs = 60 * 1000;   // a minute; scenes resolve to minutes
}

SceneScheduler::SceneScheduler(HomeService &home, QObject *parent)
    : QObject(parent)
    , m_home(home)
{
    m_timer.setInterval(kDefaultTickMs);
    connect(&m_timer, &QTimer::timeout, this, &SceneScheduler::evaluate);
}

void SceneScheduler::setClock(std::function<QDateTime()> clock)
{
    m_now = std::move(clock);
}

void SceneScheduler::setTickInterval(int milliseconds)
{
    m_timer.setInterval(qMax(1, milliseconds));
}

void SceneScheduler::start()
{
    // Evaluate before the first tick, so a window that is already open is
    // applied on start rather than up to a minute later.
    evaluate();
    m_timer.start();
}

void SceneScheduler::stop()
{
    m_timer.stop();
}

bool SceneScheduler::parseRange(const QString &range, QTime &from, QTime &to)
{
    const QStringList parts = range.split(QLatin1Char('-'), Qt::SkipEmptyParts);
    if (parts.size() != 2)
        return false;

    // The C locale, not the user's: these strings are STORED, so they must
    // parse the same on a panel set to any language. A user-facing time is
    // formatted separately, at the point it is shown.
    const QLocale c(QLocale::C);
    const auto parse = [&c](const QString &text) {
        const QString trimmed = text.trimmed();
        QTime value = c.toTime(trimmed, QStringLiteral("hh:mm AP"));
        if (!value.isValid())
            value = c.toTime(trimmed, QStringLiteral("h:mm AP"));
        if (!value.isValid())
            value = QTime::fromString(trimmed, QStringLiteral("HH:mm"));
        return value;
    };

    from = parse(parts.at(0));
    to = parse(parts.at(1));
    return from.isValid() && to.isValid();
}

bool SceneScheduler::matchesDay(const QString &days, const QDate &date)
{
    const QString normalised = days.trimmed().toLower();
    if (normalised.isEmpty() || normalised == QLatin1String("everyday")
        || normalised == QLatin1String("every day"))
        return true;

    if (normalised == QLatin1String("week days") || normalised == QLatin1String("weekdays"))
        return date.dayOfWeek() >= 1 && date.dayOfWeek() <= 5;

    // A comma-separated list of English three-letter abbreviations. English
    // because it is the STORED form, for the same reason as the time above.
    static const QStringList abbreviations {
        QStringLiteral("mon"), QStringLiteral("tue"), QStringLiteral("wed"),
        QStringLiteral("thu"), QStringLiteral("fri"), QStringLiteral("sat"),
        QStringLiteral("sun")
    };
    const QString today = abbreviations.at(date.dayOfWeek() - 1);

    const QStringList listed = normalised.split(QLatin1Char(','), Qt::SkipEmptyParts);
    for (const QString &entry : listed) {
        if (entry.trimmed().startsWith(today))
            return true;
    }
    return false;
}

bool SceneScheduler::isWithinWindow(const Scene &scene, const QDateTime &now) const
{
    QTime from;
    QTime to;
    if (!parseRange(scene.timeRange, from, to))
        return false;
    if (!matchesDay(scene.days, now.date()))
        return false;

    const QTime current = now.time();
    if (from <= to)
        return current >= from && current < to;

    // Wraps midnight - "12:00 PM - 08:00 AM" is the seeded Sleeping scene.
    // Without this branch every overnight scene silently never runs.
    return current >= from || current < to;
}

void SceneScheduler::applyScene(const Scene &scene, bool on)
{
    // Everything below acts as the SYSTEM, not as whoever is signed in. A
    // schedule that only fires while an administrator happens to be looking
    // at the panel is not a schedule, and at 6 am nobody is signed in at all.
    constexpr auto system = HomeService::Actor::System;

    if (scene.isPerDevice()) {
        // A COPY, because applying an action emits, and a listener that edits
        // the scene while this loop walks the service's own list is how an
        // iterator bug gets in later.
        const QList<SceneAction> actions = scene.actions;
        for (const SceneAction &action : actions) {
            // Closing the window turns things OFF; it does not undo a level.
            // A scene that set the lamp to 20% has no earlier value to
            // restore - nothing recorded one - so pretending to restore it
            // would mean inventing a number and calling it the user's.
            m_home.setDevicePower(action.deviceId, on && action.on, system);
            if (!on)
                continue;
            if (action.levelPercent >= 0)
                m_home.setDeviceLevel(action.deviceId, action.levelPercent, system);
            if (action.targetC >= 0)
                m_home.setDeviceTarget(action.deviceId, action.targetC, system);
        }
        return;
    }

    // No named devices: the scene takes its room, or the whole space.
    const QList<Device> devices = scene.roomId.isEmpty()
                                      ? m_home.devices()
                                      : m_home.devicesInRoom(scene.roomId);

    // Ids first, then act, for the same reason as above.
    QStringList ids;
    ids.reserve(devices.size());
    for (const Device &device : devices)
        ids.append(device.id);

    for (const QString &id : std::as_const(ids))
        m_home.setDevicePower(id, on, system);
}

void SceneScheduler::evaluate()
{
    const QDateTime now = m_now();

    for (const Scene &scene : m_home.scenes()) {
        const bool wasActive = m_active.contains(scene.id);
        const bool shouldBeActive = scene.enabled && isWithinWindow(scene, now);

        if (shouldBeActive == wasActive)
            continue;                     // no edge, nothing to do

        if (shouldBeActive) {
            m_active.insert(scene.id);
            applyScene(scene, true);
            emit sceneActivated(scene.id, scene.name);
        } else {
            m_active.remove(scene.id);
            // Only drive devices off if the window CLOSED. A scene the user
            // just disabled should stop managing its devices, not switch them
            // off underneath whatever they are doing.
            if (scene.enabled)
                applyScene(scene, false);
            emit sceneDeactivated(scene.id, scene.name);
        }
    }

    // A scene deleted while active leaves a stale id behind, and a later scene
    // reusing that id would look already-active and never fire.
    QSet<QString> known;
    for (const Scene &scene : m_home.scenes())
        known.insert(scene.id);
    m_active.intersect(known);
}

} // namespace smarton::services
