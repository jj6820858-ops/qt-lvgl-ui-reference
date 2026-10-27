#pragma once

#include <smarton/services/ISessionTokenStore.h>

#include <QtCore/QSettings>

namespace smarton::infrastructure {

/**
 * @brief ISessionTokenStore on QSettings.
 *
 * Same backing store as the preferences beside it, and a separate class
 * because it holds something different in kind. See ISessionTokenStore for why
 * this is a bearer credential in a file and what compensates for that.
 */
class QSettingsSessionTokenStore final : public services::ISessionTokenStore
{
public:
    QSettingsSessionTokenStore();
    /** Explicit file, for tests. */
    explicit QSettingsSessionTokenStore(const QString &filePath);

    [[nodiscard]] QString token() const override;
    void setToken(const QString &token) override;

    [[nodiscard]] QString rememberedUser() const override;
    void setRememberedUser(const QString &username) override;

    [[nodiscard]] bool lockedForInactivity() const override;
    void setLockedForInactivity(bool locked) override;

    void flush() override;

    [[nodiscard]] QString fileName() const { return m_settings.fileName(); }

private:
    mutable QSettings m_settings;
};

} // namespace smarton::infrastructure
