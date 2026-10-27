#pragma once

#include <QtCore/QSize>
#include <QtCore/QString>

namespace smarton::services {

/**
 * @brief Small, user-scoped settings that are not part of the home model.
 *
 * The split matters. The home model is the PRODUCT's state - rooms, devices,
 * what is on - and lives in the database, because it is what the panel exists
 * to manage and what a factory reset should be able to wipe independently.
 * These are the OPERATOR's preferences: window geometry, locale, how long
 * before the panel locks. They belong wherever the platform keeps such things,
 * which on every platform Qt supports is what QSettings writes to.
 *
 * An interface, so nothing above it has to know that, and so tests do not
 * write to a developer's real registry or plist.
 */
class IPreferences
{
public:
    virtual ~IPreferences() = default;

    [[nodiscard]] virtual QSize windowSize() const = 0;
    virtual void setWindowSize(const QSize &size) = 0;

    /** Empty means follow the system locale. */
    [[nodiscard]] virtual QString locale() const = 0;
    virtual void setLocale(const QString &locale) = 0;

    /** Seconds; 0 disables the idle lock. */
    [[nodiscard]] virtual int idleLockSeconds() const = 0;
    virtual void setIdleLockSeconds(int seconds) = 0;

    /**
     * "figma" or "glass". Both are dark; they differ in surface treatment.
     *
     * This used to have one legal value and existed so the preference was read
     * from one place if a second theme was ever added. A second theme was
     * added, which is the only reason the setting was already in the right
     * shape to take it.
     */
    [[nodiscard]] virtual QString themeName() const = 0;
    virtual void setThemeName(const QString &name) = 0;

    /**
     * How much per-frame GPU work to spend: 0 plain, 1 gradients and glow,
     * 2 full glass. -1 means "never chosen" - let the app detect.
     *
     * Stored rather than detected every run because the detection is a coarse
     * guess (see Appearance::detectRenderTier) and someone who has overridden
     * it has more information than the guess does.
     */
    [[nodiscard]] virtual int renderTier() const = 0;
    virtual void setRenderTier(int tier) = 0;

    [[nodiscard]] virtual bool shadowsEnabled() const = 0;
    virtual void setShadowsEnabled(bool enabled) = 0;

    /**
     * The user's accent colour as "#RRGGBB", or empty for the brand default.
     *
     * A STRING, not a QColor, deliberately. This interface sits in services,
     * which links Qt Core only - a headless test of the preference layer, and
     * anything that ever reads these settings without a GUI, should not have
     * to drag QtGui in for one field. The colour type belongs at the edge that
     * cares about colour, and \c backend::Appearance is that edge.
     */
    /**
     * Width of the navigation rail, in pixels. 0 means "never dragged" - use
     * the design default.
     *
     * A stored LAYOUT, like the window size beside it: it is a decision the
     * operator made with a mouse, and losing it on every restart is the same
     * annoyance as a window that forgets where it was.
     */
    [[nodiscard]] virtual int sidebarWidth() const = 0;
    virtual void setSidebarWidth(int width) = 0;

    [[nodiscard]] virtual QString accentColor() const = 0;
    /** Empty, or anything QColor cannot parse, restores the default. */
    virtual void setAccentColor(const QString &color) = 0;

    /** Write through to the backing store now. */
    virtual void flush() = 0;
};

} // namespace smarton::services
