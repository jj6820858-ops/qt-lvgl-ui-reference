#include <smarton/infrastructure/settings/QSettingsPreferences.h>

#include <QtCore/QtGlobal>
#include <QtGui/QColor>

namespace smarton::infrastructure {

namespace {
// Grouped so the file is readable by a person, which is half the point of
// using QSettings rather than a table.
constexpr auto kWindowSize    = "window/size";
constexpr auto kLocale        = "ui/locale";
constexpr auto kTheme         = "ui/theme";
constexpr auto kRenderTier    = "ui/renderTier";
constexpr auto kShadows       = "ui/shadows";
constexpr auto kSidebar       = "window/sidebarWidth";
constexpr auto kAccent        = "ui/accent";
constexpr auto kIdleLock      = "security/idleLockSeconds";

constexpr int kMinWidth  = 1024;
constexpr int kMinHeight = 600;
constexpr int kMaxWidth  = 1600;
constexpr int kMaxHeight = 980;
constexpr int kMaxIdleSeconds = 60 * 60;   // an hour is already generous
// Must match Theme.sidebarMinWidth / sidebarMaxWidth. Clamped here too,
// because a hand-edited 4000 would produce a rail with no content beside it
// and no way to drag it back.
constexpr int kMinSidebar = 168;
constexpr int kMaxSidebar = 320;
}

QSettingsPreferences::QSettingsPreferences() = default;

QSettingsPreferences::QSettingsPreferences(const QString &filePath)
    : m_settings(filePath, QSettings::IniFormat)
{
}

QSize QSettingsPreferences::windowSize() const
{
    const QSize stored = m_settings.value(QLatin1String(kWindowSize),
                                          QSize(kMinWidth, kMinHeight)).toSize();
    // Clamped, not trusted. This is a text file someone can edit, and a stored
    // 0x0 would produce a window with no way to resize it back.
    return QSize(qBound(kMinWidth, stored.width(), kMaxWidth),
                 qBound(kMinHeight, stored.height(), kMaxHeight));
}

void QSettingsPreferences::setWindowSize(const QSize &size)
{
    if (!size.isValid() || size.isEmpty())
        return;
    m_settings.setValue(QLatin1String(kWindowSize), size);
}

QString QSettingsPreferences::locale() const
{
    return m_settings.value(QLatin1String(kLocale)).toString();
}

void QSettingsPreferences::setLocale(const QString &locale)
{
    m_settings.setValue(QLatin1String(kLocale), locale);
}

int QSettingsPreferences::idleLockSeconds() const
{
    const int stored = m_settings.value(QLatin1String(kIdleLock), 300).toInt();
    // A negative value would disable the lock silently, which is the one
    // outcome a security setting must never reach by accident.
    return qBound(0, stored, kMaxIdleSeconds);
}

void QSettingsPreferences::setIdleLockSeconds(int seconds)
{
    m_settings.setValue(QLatin1String(kIdleLock), qBound(0, seconds, kMaxIdleSeconds));
}

QString QSettingsPreferences::themeName() const
{
    // Two legal values, and anything else falls back to the measured Figma
    // treatment - the one the rest of the project is checked against. A
    // hand-edited `ui/theme=neon` should not leave the app with no theme.
    const QString stored = m_settings.value(QLatin1String(kTheme),
                                            QStringLiteral("figma")).toString();
    return stored == QLatin1String("glass") ? stored : QStringLiteral("figma");
}

void QSettingsPreferences::setThemeName(const QString &name)
{
    if (name != QLatin1String("glass") && name != QLatin1String("figma"))
        return;
    m_settings.setValue(QLatin1String(kTheme), name);
}

int QSettingsPreferences::renderTier() const
{
    // -1 is meaningful - "never chosen, let the app detect" - so it survives
    // the clamp rather than being bounded up to 0.
    const int stored = m_settings.value(QLatin1String(kRenderTier), -1).toInt();
    return stored < 0 ? -1 : qBound(0, stored, 2);
}

void QSettingsPreferences::setRenderTier(int tier)
{
    if (tier < 0) {
        m_settings.remove(QLatin1String(kRenderTier));
        return;
    }
    m_settings.setValue(QLatin1String(kRenderTier), qBound(0, tier, 2));
}

bool QSettingsPreferences::shadowsEnabled() const
{
    return m_settings.value(QLatin1String(kShadows), true).toBool();
}

void QSettingsPreferences::setShadowsEnabled(bool enabled)
{
    m_settings.setValue(QLatin1String(kShadows), enabled);
}

int QSettingsPreferences::sidebarWidth() const
{
    const int stored = m_settings.value(QLatin1String(kSidebar), 0).toInt();
    // 0 is meaningful - "never dragged" - and must survive the clamp, so it is
    // checked before rather than being bounded up to the minimum.
    if (stored <= 0)
        return 0;
    return qBound(kMinSidebar, stored, kMaxSidebar);
}

void QSettingsPreferences::setSidebarWidth(int width)
{
    if (width <= 0) {
        m_settings.remove(QLatin1String(kSidebar));
        return;
    }
    m_settings.setValue(QLatin1String(kSidebar), qBound(kMinSidebar, width, kMaxSidebar));
}

QString QSettingsPreferences::accentColor() const
{
    const QString stored = m_settings.value(QLatin1String(kAccent)).toString();
    // Validated HERE rather than only at the reader, because "empty means the
    // brand default" and "garbage means the brand default" have to be the same
    // answer - otherwise hand-editing this file to `ui/accent=blueish` gives a
    // caller an invalid QColor and a black button.
    return QColor(stored).isValid() ? stored : QString();
}

void QSettingsPreferences::setAccentColor(const QString &color)
{
    if (color.isEmpty() || !QColor(color).isValid()) {
        // Clearing the key rather than writing the default hex keeps the two
        // states distinguishable in the file: absent is "never chose", present
        // is "chose this" - even when the choice happens to be the default.
        m_settings.remove(QLatin1String(kAccent));
        return;
    }
    m_settings.setValue(QLatin1String(kAccent), color);
}

void QSettingsPreferences::flush()
{
    m_settings.sync();
}

} // namespace smarton::infrastructure
