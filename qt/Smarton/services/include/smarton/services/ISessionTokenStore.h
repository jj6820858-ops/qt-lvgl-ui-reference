#pragma once

#include <QtCore/QString>

namespace smarton::services {

/**
 * @brief Where the PANEL keeps its half of a remembered sign-in.
 *
 * Deliberately not part of IPreferences. What is kept here is a bearer
 * credential, not an operator preference, and the distinction is the whole
 * point: preferences are a convenience that may be stored anywhere convenient,
 * whereas this is the thing an attacker with the filesystem wants. Keeping it
 * behind its own interface means moving it to a platform keychain later is one
 * new implementation and one line in main.cpp, rather than a hunt through a
 * settings class for which of its fields were secrets.
 *
 * HONEST LIMIT. The shipped implementation writes to QSettings, which on the
 * panel is a file with the same protection as the database beside it. Without
 * a secure element there is no way to do better locally, so the token is
 * defended by being short-lived, single-use and revocable instead: it expires,
 * it is rotated on every use, and signing out deletes it server-side so a copy
 * taken from the disk stops working. See ADR-0015.
 */
class ISessionTokenStore
{
public:
    virtual ~ISessionTokenStore() = default;

    /** "<selector>:<secret>", or empty when nothing is remembered. */
    [[nodiscard]] virtual QString token() const = 0;
    virtual void setToken(const QString &token) = 0;

    /**
     * The remembered username, kept separately from the token.
     *
     * Separate because the two die at different times: the token is cleared
     * the moment it is used or revoked, and the username is what lets the
     * login screen still arrive pre-filled afterwards. It is also the only
     * half that survives an idle lock.
     */
    [[nodiscard]] virtual QString rememberedUser() const = 0;
    virtual void setRememberedUser(const QString &username) = 0;

    /**
     * Set when the idle lock fires, cleared by a successful password entry.
     *
     * This is what stops a resume token defeating the idle lock. The lock
     * itself only protects a RUNNING panel; someone who can reach the screen
     * can also reach the power, so without this flag the bypass is to pull the
     * plug and let the remembered session sign itself back in. Persisting the
     * lock means a restart lands on the password prompt exactly as the lock
     * intended - while the user stays remembered for the next clean start.
     */
    [[nodiscard]] virtual bool lockedForInactivity() const = 0;
    virtual void setLockedForInactivity(bool locked) = 0;

    virtual void flush() = 0;
};

} // namespace smarton::services
