#pragma once

#include <smarton/domain/entities/User.h>

#include <QtCore/QDateTime>
#include <QtCore/QObject>
#include <QtCore/QTimer>

#include <functional>
#include <optional>
#include <utility>

namespace smarton::services {

class IUserRepository;
class IPasswordHasher;
class IAvatarStore;
class ISessionRepository;

/** Why a sign-in attempt did not succeed. */
enum class AuthError {
    None,
    InvalidCredentials,   ///< Wrong username OR wrong password - never say which.
    AccountLocked,
    WeakPassword,         ///< Only ever returned by changePassword().
    NotProvisioned,       ///< No accounts exist at all. See the note in signIn().
    StorageFailure,
};

struct AuthResult
{
    bool        success = false;
    AuthError   error   = AuthError::None;
    QDateTime   lockedUntil;      ///< Set when error == AccountLocked.
    int         attemptsRemaining = 0;
    /**
     * A freshly minted "<selector>:<secret>" for the caller to persist, when
     * the sign-in asked to be remembered. Empty otherwise.
     *
     * RETURNED, not written. AuthService has no opinion about where a panel
     * keeps its token - that is a platform question, and on a different
     * platform the answer is a keychain rather than a file. Handing it back
     * also means the ONE object that touches the token store is the caller,
     * so "who can persist a credential" is answerable by reading main.cpp.
     */
    QString     sessionToken;
};

/**
 * @brief The only place that decides whether a sign-in succeeds.
 *
 * Deliberate properties:
 *  - A missing user and a wrong password return the SAME error. Distinguishing
 *    them tells an attacker which usernames exist.
 *  - An EMPTY store is the one exception, and reports NotProvisioned. That
 *    leaks nothing about any account, because there are none; it is a fact
 *    about the device, discoverable by anyone who tries once. Folding it into
 *    InvalidCredentials instead means an unprovisioned unit tells its owner
 *    "incorrect password" forever, which is the single most confusing thing a
 *    login screen can say.
 *  - A missing user still runs a dummy hash so the response time does not
 *    reveal whether the account exists (timing-attack mitigation).
 *  - Failed attempts are counted and the account locks for a cooling-off
 *    period, defeating online brute force.
 *  - On success with outdated KDF parameters the verifier is transparently
 *    re-hashed, so cost can be raised over time without a migration.
 */
class AuthService : public QObject
{
    Q_OBJECT
public:
    static constexpr int kMaxFailedAttempts = 5;
    static constexpr int kLockoutSeconds    = 300;
    /*! Five minutes. A hallway panel inherits its session to whoever walks
        past; the only question is how long that window is. */
    static constexpr int kDefaultIdleLockSeconds = 300;

    AuthService(IUserRepository &users, const IPasswordHasher &hasher,
                QObject *parent = nullptr);

    /**
     * @param rememberMe issue a resume token in AuthResult::sessionToken.
     *        Ignored when no session repository is set.
     */
    [[nodiscard]] AuthResult signIn(const QString &username, const QString &password,
                                    bool rememberMe = false);

    /**
     * @brief Sign in using a token from a previous "remember me", if it is
     *        still good.
     *
     * Never returns AccountLocked or a failed-attempt count: a token is not a
     * password guess, so presenting a bad one must not consume an attempt or
     * lock the account. That is the difference between an attacker burning
     * someone's login and an attacker being ignored.
     *
     * SINGLE USE. A token that validates is rotated: the row keeps its
     * selector and gets a new secret, and the old string stops working. So a
     * copy taken from the panel's disk is good until the panel next starts,
     * and after that its use is detectable rather than silent.
     */
    [[nodiscard]] AuthResult resumeSession(const QString &token);

    /**
     * @brief End the session.
     * @param forgetDevice also revoke every remembered sign-in for this
     *        account. True for an explicit sign-out, false for the idle lock -
     *        the idle lock is a screen lock, not a decision to stop trusting
     *        this panel.
     */
    void signOut(bool forgetDevice = false);

    /** Optional. Without one, rememberMe is ignored and resumeSession() always
        fails - which is the correct behaviour for a build with no store. */
    void setSessionRepository(ISessionRepository *sessions);

    /*! How long a remembered sign-in lasts. 30 days: long enough that a panel
        in daily use never re-prompts, short enough that one taken out of
        service stops being a key within a month. */
    static constexpr int kSessionDays = 30;

    /**
     * @brief Replace the signed-in user's password.
     *
     * Requires @p currentPassword even though the session is already
     * authenticated: the session may be minutes old and unattended, and
     * re-proving knowledge is what stops a passer-by locking the owner out of
     * their own panel.
     *
     * The new verifier is derived with the CURRENT cost parameters, so a
     * change is also an upgrade. Fails with WeakPassword if @p newPassword
     * does not meet policy - checked here, not only in the UI.
     */
    [[nodiscard]] AuthResult changePassword(const QString &currentPassword,
                                            const QString &newPassword);

    /**
     * @brief Sign out automatically after this much inactivity. 0 disables.
     *
     * The service owns the timer rather than the UI because the UI is the
     * thing that might be busy or wedged, and a lock that depends on the view
     * layer being responsive is not a lock.
     */
    void setIdleTimeoutSeconds(int seconds);
    [[nodiscard]] int idleTimeoutSeconds() const { return m_idleSeconds; }

    /** Called on any user input. Restarts the idle countdown. */
    void noteActivity();

    [[nodiscard]] bool isSignedIn() const { return m_current.has_value(); }
    [[nodiscard]] std::optional<domain::User> currentUser() const { return m_current; }

    /**
     * @brief Update the signed-in user's profile fields.
     *
     * NOT changePassword: these are labels, not credentials, so they need no
     * re-authentication and none of them can lock anyone out. They are still
     * written here rather than from the view model, because the view model
     * does not own the record and re-reading it before writing is what stops
     * a stale copy overwriting an avatar someone changed on another screen.
     *
     * @return false when nobody is signed in, or the store refused.
     */
    /**
     * @brief Create a sign-in account for a household member.
     *
     * DOES NOT sign anybody in and does not touch the current session: adding
     * a member is an administrative act performed BY the signed-in operator,
     * not a sign-in by the person being added.
     *
     * The password goes through the same policy and the same hasher as the
     * operator's own - there is no second, weaker path for "just a member".
     * The verifier lands in the accounts table; the home model stores only the
     * returned id.
     *
     * @return the new account id, or 0. \a error is set to something a person
     *         can act on: taken, too weak, or a storage failure.
     */
    qint64 createAccount(const QString &username, const QString &password,
                         domain::Role role, AuthError *error = nullptr);

    [[nodiscard]] bool updateProfile(const QString &fullName,
                                     const QString &email,
                                     const QString &phone);

    /** Optional. Without one, setAvatar() refuses rather than storing a path
        that points at wherever the user happened to browse. */
    void setAvatarStore(IAvatarStore *store) { m_avatars = store; }

    /**
     * Take custody of @p sourceFile and use it as the signed-in user's
     * picture. Passing an empty string clears it back to the default.
     * @return false when nobody is signed in, or the file is unusable.
     */
    [[nodiscard]] bool setAvatar(const QString &sourceFile);

    /** Injectable clock, so lockout expiry is testable without sleeping. */
    void setClock(std::function<QDateTime()> clock) { m_now = std::move(clock); }

signals:
    void signedIn(const QString &username);
    void signedOut();
    /** Emitted just before an idle sign-out, so the UI can say why. */
    void lockedForInactivity();
    void passwordChanged();
    void profileChanged();
    void avatarChanged(const QString &path);

private:
    /** Length, mixed case, and a digit or symbol. */
    [[nodiscard]] static bool meetsPolicy(const QString &password);

    /** Mint a token for @p user and store its hash. Empty on failure. */
    [[nodiscard]] QString issueSessionToken(const domain::User &user);

    IUserRepository        &m_users;
    ISessionRepository     *m_sessions = nullptr;
    const IPasswordHasher  &m_hasher;
    IAvatarStore           *m_avatars = nullptr;
    QTimer                  m_idleTimer;
    int                     m_idleSeconds = 0;
    std::optional<domain::User> m_current;
    std::function<QDateTime()>  m_now = [] { return QDateTime::currentDateTimeUtc(); };
};

} // namespace smarton::services
