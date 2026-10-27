#include <smarton/infrastructure/settings/QSettingsSessionTokenStore.h>

namespace smarton::infrastructure {

namespace {
constexpr auto kToken  = "session/token";
constexpr auto kUser   = "session/user";
constexpr auto kLocked = "session/lockedForInactivity";
} // namespace

QSettingsSessionTokenStore::QSettingsSessionTokenStore() = default;

QSettingsSessionTokenStore::QSettingsSessionTokenStore(const QString &filePath)
    : m_settings(filePath, QSettings::IniFormat)
{
}

QString QSettingsSessionTokenStore::token() const
{
    return m_settings.value(QLatin1String(kToken)).toString();
}

void QSettingsSessionTokenStore::setToken(const QString &token)
{
    if (token.isEmpty()) {
        // Removed, not overwritten with "". A key that is present and empty
        // and a key that is absent read the same through this class, and
        // leaving the key behind is one more place a stale value can appear
        // in a file someone is reading to work out what went wrong.
        m_settings.remove(QLatin1String(kToken));
        // Written through immediately: this path is a REVOCATION, and a
        // revocation that is still sitting in QSettings' cache when the power
        // goes out has not happened.
        m_settings.sync();
        return;
    }
    m_settings.setValue(QLatin1String(kToken), token);
    m_settings.sync();
}

QString QSettingsSessionTokenStore::rememberedUser() const
{
    return m_settings.value(QLatin1String(kUser)).toString();
}

void QSettingsSessionTokenStore::setRememberedUser(const QString &username)
{
    if (username.isEmpty()) {
        m_settings.remove(QLatin1String(kUser));
        return;
    }
    m_settings.setValue(QLatin1String(kUser), username);
}

bool QSettingsSessionTokenStore::lockedForInactivity() const
{
    return m_settings.value(QLatin1String(kLocked), false).toBool();
}

void QSettingsSessionTokenStore::setLockedForInactivity(bool locked)
{
    m_settings.setValue(QLatin1String(kLocked), locked);
    // Same reasoning as revocation: the whole point of persisting the lock is
    // that it survives the power being pulled, so it cannot wait for a clean
    // exit to be written.
    m_settings.sync();
}

void QSettingsSessionTokenStore::flush()
{
    m_settings.sync();
}

} // namespace smarton::infrastructure
