#pragma once

#include <smarton/services/IPreferences.h>

#include <QtCore/QSettings>

namespace smarton::infrastructure {

/**
 * @brief IPreferences on QSettings.
 *
 * QSettings puts these where each platform expects: the registry on Windows,
 * a plist on macOS, an INI under XDG_CONFIG_HOME on Linux - including the
 * panel. That is the whole reason to use it rather than adding a table: an
 * operator preference should survive a factory reset of the home model, and
 * on the panel it should be inspectable without a SQL client.
 *
 * Every getter clamps. A settings file is a text file a person can edit, and
 * a window size of 0 or an idle lock of -4 must not reach the rest of the app.
 */
class QSettingsPreferences final : public services::IPreferences
{
public:
    /** Uses the organisation and application names set on QCoreApplication. */
    QSettingsPreferences();
    /** Explicit file, for tests - never touches a developer's real settings. */
    explicit QSettingsPreferences(const QString &filePath);

    [[nodiscard]] QSize windowSize() const override;
    void setWindowSize(const QSize &size) override;

    [[nodiscard]] QString locale() const override;
    void setLocale(const QString &locale) override;

    [[nodiscard]] int idleLockSeconds() const override;
    void setIdleLockSeconds(int seconds) override;

    [[nodiscard]] QString themeName() const override;
    void setThemeName(const QString &name) override;

    [[nodiscard]] int renderTier() const override;
    void setRenderTier(int tier) override;

    [[nodiscard]] bool shadowsEnabled() const override;
    void setShadowsEnabled(bool enabled) override;

    [[nodiscard]] int sidebarWidth() const override;
    void setSidebarWidth(int width) override;

    [[nodiscard]] QString accentColor() const override;
    void setAccentColor(const QString &color) override;

    void flush() override;

    /** Where the settings actually live. Logged at startup. */
    [[nodiscard]] QString fileName() const { return m_settings.fileName(); }

private:
    mutable QSettings m_settings;
};

} // namespace smarton::infrastructure
