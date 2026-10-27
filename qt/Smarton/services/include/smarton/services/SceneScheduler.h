#pragma once

#include <smarton/domain/entities/HomeEntities.h>

#include <QtCore/QDateTime>
#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QTimer>

#include <functional>

namespace smarton::services {

class HomeService;

/**
 * @brief Runs enabled scenes against the clock.
 *
 * Until now a scene was a stored intention: it recorded days and a time range
 * and nothing ever evaluated them. This is what evaluates them.
 *
 * WHAT A SCENE APPLIES TO. A scene names a room, not a device list, so it
 * applies to every device in that room. That is a real limitation and a
 * deliberate one: a scene-to-device table is the right model, and inventing
 * one before the editor (frames 24-25) can populate it would mean shipping a
 * schema nothing writes to. A scene with no room applies to the whole space.
 *
 * EDGES, NOT LEVELS. The scheduler acts when a scene ENTERS or LEAVES its
 * window, not continuously while inside it. Re-asserting every tick would
 * make a light impossible to turn off by hand for the duration of a scene,
 * which is infuriating and is what "the house fights me" complaints are.
 *
 * MISSED WINDOWS. The panel is not always on. On start, a scene whose window
 * is already open is treated as an entry - the house should look the way the
 * scene says when you walk in, not wait for tomorrow. A window that opened
 * AND closed while the panel was off is not replayed.
 *
 * The clock is injectable, so every rule above is testable without waiting.
 */
class SceneScheduler : public QObject
{
    Q_OBJECT
public:
    explicit SceneScheduler(HomeService &home, QObject *parent = nullptr);

    /** Begin evaluating. Applies any window that is already open. */
    void start();
    void stop();
    [[nodiscard]] bool isRunning() const { return m_timer.isActive(); }

    /** Injectable clock, so window edges are testable without sleeping. */
    void setClock(std::function<QDateTime()> clock);
    /** How often to re-evaluate. One minute in production. */
    void setTickInterval(int milliseconds);

    /** Evaluate now. Called by the timer; public so tests can step it. */
    void evaluate();

    /**
     * Parse "08:15 AM - 09:00 AM" into two times.
     * Returns false when @p range is malformed, which is not an error the
     * user can see - it means a stored scene predates the current format.
     */
    static bool parseRange(const QString &range, QTime &from, QTime &to);

    /** Does @p days ("Everyday", "Week days", "Mon, Fri") include @p date? */
    static bool matchesDay(const QString &days, const QDate &date);

signals:
    /** A scene's window opened and its devices were driven on. */
    void sceneActivated(const QString &sceneId, const QString &sceneName);
    void sceneDeactivated(const QString &sceneId, const QString &sceneName);

private:
    void applyScene(const domain::Scene &scene, bool on);
    [[nodiscard]] bool isWithinWindow(const domain::Scene &scene,
                                      const QDateTime &now) const;

    HomeService &m_home;
    QTimer       m_timer;
    /** Scene ids currently inside their window. The edge detector's memory. */
    QSet<QString> m_active;
    std::function<QDateTime()> m_now = [] { return QDateTime::currentDateTime(); };
};

} // namespace smarton::services
