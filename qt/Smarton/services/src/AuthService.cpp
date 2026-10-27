#include <smarton/services/AuthService.h>

#include <smarton/services/IPasswordHasher.h>
#include <smarton/services/IAvatarStore.h>
#include <smarton/services/ISessionRepository.h>
#include <smarton/services/IUserRepository.h>

#include <QtCore/QChar>
#include <QtCore/QCryptographicHash>
#include <QtCore/QRandomGenerator>
#include <QtCore/QtGlobal>

namespace smarton::services {

namespace {
// Verifying a password is deliberately expensive. If we skip that work when
// the username does not exist, the response is measurably faster and an
// attacker can enumerate valid accounts by timing alone. Burn the same cost.
constexpr auto kDummyPassword = "timing-equalisation";

/** Public half of a token: enough to be unique, it protects nothing. */
constexpr int kSelectorBytes = 16;
/** Secret half. 32 bytes of CSPRNG output - not guessable, so it does not
    need to be slow to verify. See ISessionRepository. */
constexpr int kSecretBytes = 32;

QString randomHex(int bytes)
{
    QByteArray raw(bytes, Qt::Uninitialized);
    // system(), not global(): the global generator is seeded once per process
    // from a source that is fine for shuffling a list and is not a CSPRNG.
    // A predictable session secret is the same bug as no session secret.
    QRandomGenerator::system()->generate(reinterpret_cast<quint32 *>(raw.data()),
                                         reinterpret_cast<quint32 *>(raw.data() + bytes));
    return QString::fromLatin1(raw.toHex());
}

QString digestOf(const QString &secret)
{
    return QString::fromLatin1(
        QCryptographicHash::hash(secret.toUtf8(), QCryptographicHash::Sha256).toHex());
}

/**
 * Constant-time comparison of two hex digests.
 *
 * qstrcmp and operator== both return as soon as they find a difference, which
 * leaks how many leading bytes were right. That is enough to reconstruct a
 * digest one byte at a time given enough attempts, and a resume endpoint is
 * exactly the sort of thing that can be retried without limit.
 */
bool constantTimeEquals(const QString &a, const QString &b)
{
    const QByteArray lhs = a.toLatin1();
    const QByteArray rhs = b.toLatin1();
    if (lhs.size() != rhs.size())
        return false;

    quint8 difference = 0;
    for (int i = 0; i < lhs.size(); ++i)
        difference |= static_cast<quint8>(lhs[i]) ^ static_cast<quint8>(rhs[i]);
    return difference == 0;
}
} // namespace

AuthService::AuthService(IUserRepository &users, const IPasswordHasher &hasher,
                         QObject *parent)
    : QObject(parent)
    , m_users(users)
    , m_hasher(hasher)
{
    m_idleTimer.setSingleShot(true);
    connect(&m_idleTimer, &QTimer::timeout, this, [this] {
        if (!m_current.has_value())
            return;
        emit lockedForInactivity();
        signOut();
    });
}

void AuthService::setIdleTimeoutSeconds(int seconds)
{
    m_idleSeconds = qMax(0, seconds);
    if (m_idleSeconds == 0) {
        m_idleTimer.stop();
        return;
    }
    m_idleTimer.setInterval(m_idleSeconds * 1000);
    if (m_current.has_value())
        m_idleTimer.start();
}

void AuthService::noteActivity()
{
    // Only while signed in: restarting a timer that is not running is
    // harmless, but starting one when nobody is signed in would lock an
    // already-locked panel and emit a confusing signal.
    if (m_idleSeconds > 0 && m_current.has_value())
        m_idleTimer.start();
}

bool AuthService::meetsPolicy(const QString &password)
{
    if (password.size() < 8)
        return false;

    bool lower = false;
    bool upper = false;
    bool other = false;
    for (const QChar c : password) {
        if (c.isLower())
            lower = true;
        else if (c.isUpper())
            upper = true;
        if (c.isDigit() || c.isPunct() || c.isSymbol())
            other = true;
    }
    return lower && upper && other;
}

AuthResult AuthService::changePassword(const QString &currentPassword,
                                       const QString &newPassword)
{
    AuthResult result;

    if (!m_current.has_value()) {
        result.error = AuthError::InvalidCredentials;
        return result;
    }

    // Re-read rather than trusting the cached copy: the record may have been
    // re-hashed or locked since sign-in.
    auto maybeUser = m_users.findByUsername(m_current->username());
    if (!maybeUser.has_value()) {
        result.error = AuthError::StorageFailure;
        return result;
    }

    domain::User user = *maybeUser;

    if (!m_hasher.verify(currentPassword, user.passwordHash())) {
        result.error = AuthError::InvalidCredentials;
        return result;
    }

    if (!meetsPolicy(newPassword)) {
        result.error = AuthError::WeakPassword;
        return result;
    }

    // Derived with the CURRENT parameters, so every change is also an upgrade.
    user.setPasswordHash(m_hasher.hash(newPassword));
    user.setFailedAttempts(0);
    user.setLockedUntil({});

    if (!m_users.save(user)) {
        result.error = AuthError::StorageFailure;
        return result;
    }

    m_current = user;
    result.success = true;
    emit passwordChanged();
    return result;
}

AuthResult AuthService::signIn(const QString &username, const QString &password,
                               bool rememberMe)
{
    AuthResult result;
    const QDateTime now = m_now();

    // Distinguish "this device has no accounts" from "those credentials are
    // wrong". No enumeration risk: with an empty store there is no account to
    // enumerate. The alternative is a device that answers "incorrect password"
    // to a password that was never set.
    if (m_users.isEmpty()) {
        result.error = AuthError::NotProvisioned;
        return result;
    }

    auto maybeUser = m_users.findByUsername(username);

    if (!maybeUser.has_value()) {
        // Equalise timing, then report the SAME error as a wrong password.
        // Telling the caller "no such user" leaks which accounts exist.
        (void)m_hasher.hash(QString::fromLatin1(kDummyPassword));
        result.error = AuthError::InvalidCredentials;
        return result;
    }

    domain::User user = *maybeUser;

    if (user.isLocked(now)) {
        result.error       = AuthError::AccountLocked;
        result.lockedUntil = user.lockedUntil();
        return result;
    }

    if (!m_hasher.verify(password, user.passwordHash())) {
        const int attempts = user.failedAttempts() + 1;
        user.setFailedAttempts(attempts);

        if (attempts >= kMaxFailedAttempts) {
            user.setLockedUntil(now.addSecs(kLockoutSeconds));
            user.setFailedAttempts(0);
            result.error       = AuthError::AccountLocked;
            result.lockedUntil = user.lockedUntil();
        } else {
            result.error             = AuthError::InvalidCredentials;
            result.attemptsRemaining = kMaxFailedAttempts - attempts;
        }

        if (!m_users.save(user))
            result.error = AuthError::StorageFailure;
        return result;
    }

    // Correct password. Clear the counters, and raise the KDF cost silently if
    // this verifier predates the current policy.
    user.setFailedAttempts(0);
    user.setLockedUntil({});

    if (m_hasher.needsRehash(user.passwordHash()))
        user.setPasswordHash(m_hasher.hash(password));

    if (!m_users.save(user)) {
        result.error = AuthError::StorageFailure;
        return result;
    }

    m_current      = user;
    result.success = true;
    if (rememberMe)
        result.sessionToken = issueSessionToken(user);
    noteActivity();          // starts the idle countdown for this session
    emit signedIn(user.username());
    return result;
}

void AuthService::setSessionRepository(ISessionRepository *sessions)
{
    m_sessions = sessions;
}

QString AuthService::issueSessionToken(const domain::User &user)
{
    if (!m_sessions)
        return {};

    const QDateTime now = m_now();
    // Opportunistic housekeeping. A panel signs in rarely, so this costs
    // nothing here and means dead rows never need a separate sweeper.
    (void)m_sessions->purgeExpired(now);

    StoredSession session;
    session.userId     = user.id();
    session.selector   = randomHex(kSelectorBytes);
    const QString secret = randomHex(kSecretBytes);
    session.secretHash = digestOf(secret);
    session.issuedAt   = now;
    session.lastUsedAt = now;
    session.expiresAt  = now.addDays(kSessionDays);

    if (m_sessions->insert(session) <= 0)
        return {};

    // The only moment the secret exists in full. It is not kept on this
    // object: what is stored is the digest, so even a memory dump of the
    // service after this returns does not yield a usable token.
    return session.selector + QLatin1Char(':') + secret;
}

AuthResult AuthService::resumeSession(const QString &token)
{
    AuthResult result;
    if (!m_sessions || token.isEmpty()) {
        result.error = AuthError::InvalidCredentials;
        return result;
    }

    const qsizetype separator = token.indexOf(QLatin1Char(':'));
    if (separator <= 0 || separator == token.size() - 1) {
        result.error = AuthError::InvalidCredentials;
        return result;
    }

    const QString selector = token.left(separator);
    const QString secret   = token.mid(separator + 1);

    const auto stored = m_sessions->findBySelector(selector);
    if (!stored.has_value()) {
        result.error = AuthError::InvalidCredentials;
        return result;
    }

    const QDateTime now = m_now();
    if (!stored->expiresAt.isValid() || stored->expiresAt <= now) {
        (void)m_sessions->remove(stored->id);
        result.error = AuthError::InvalidCredentials;
        return result;
    }

    if (!constantTimeEquals(digestOf(secret), stored->secretHash)) {
        // A valid selector with the wrong secret is not a typo - nobody types
        // these. It means someone has a stale or forged copy, so the row goes:
        // better to make the real user sign in once than to leave a token
        // alive that somebody else is probing.
        (void)m_sessions->remove(stored->id);
        result.error = AuthError::InvalidCredentials;
        return result;
    }

    auto maybeUser = m_users.findById(stored->userId);
    if (!maybeUser.has_value()) {
        // The account went away underneath the token.
        (void)m_sessions->remove(stored->id);
        result.error = AuthError::InvalidCredentials;
        return result;
    }

    domain::User user = *maybeUser;

    // A locked account stays locked. The token proves the device was trusted
    // once; it does not override the lockout that a burst of wrong passwords
    // just earned.
    if (user.isLocked(now)) {
        result.error       = AuthError::AccountLocked;
        result.lockedUntil = user.lockedUntil();
        return result;
    }

    // ROTATE. Same row, same selector, new secret and a fresh 30 days. The
    // token just presented stops working from here, so a copy lifted off the
    // disk is good for exactly one restart rather than for a month.
    const QString nextSecret = randomHex(kSecretBytes);
    if (!m_sessions->rotate(stored->id, digestOf(nextSecret),
                            now.addDays(kSessionDays), now)) {
        result.error = AuthError::StorageFailure;
        return result;
    }

    m_current           = user;
    result.success      = true;
    result.sessionToken = selector + QLatin1Char(':') + nextSecret;
    noteActivity();
    emit signedIn(user.username());
    return result;
}

qint64 AuthService::createAccount(const QString &username, const QString &password,
                                  domain::Role role, AuthError *error)
{
    const auto fail = [error](AuthError what) -> qint64 {
        if (error)
            *error = what;
        return 0;
    };

    const QString cleaned = username.trimmed();
    if (cleaned.isEmpty())
        return fail(AuthError::InvalidCredentials);

    // Policy checked HERE, not only in the form. A UI is one caller; the rule
    // belongs where nothing can route around it.
    if (!meetsPolicy(password))
        return fail(AuthError::WeakPassword);

    // Checked before inserting so the caller gets "that name is taken" rather
    // than a driver's UNIQUE-constraint text. The insert is still the real
    // guard - this is a race, and losing it means createUser returns 0, which
    // is handled below.
    if (m_users.findByUsername(cleaned).has_value())
        return fail(AuthError::InvalidCredentials);

    const qint64 id = m_users.createUser(cleaned, m_hasher.hash(password), role);
    if (id <= 0)
        return fail(AuthError::StorageFailure);

    if (error)
        *error = AuthError::None;
    return id;
}

bool AuthService::updateProfile(const QString &fullName, const QString &email,
                                const QString &phone)
{
    if (!m_current.has_value())
        return false;

    // Re-read before writing. m_current is a snapshot taken at sign-in, and
    // saving it back wholesale would undo anything changed since - the avatar
    // above being the obvious one.
    auto maybeUser = m_users.findByUsername(m_current->username());
    if (!maybeUser.has_value())
        return false;

    domain::User user = *maybeUser;
    user.setFullName(fullName.trimmed());
    user.setEmail(email.trimmed());
    user.setPhone(phone.trimmed());

    if (!m_users.save(user))
        return false;

    m_current = user;
    emit profileChanged();
    return true;
}

bool AuthService::setAvatar(const QString &sourceFile)
{
    if (!m_current.has_value() || !m_avatars)
        return false;

    // Re-read: the row may have changed since sign-in.
    auto maybeUser = m_users.findByUsername(m_current->username());
    if (!maybeUser.has_value())
        return false;

    domain::User user = *maybeUser;
    const QString previous = user.avatarSource();

    if (sourceFile.isEmpty()) {
        m_avatars->clear(user.username());
        user.setAvatarSource(QString());
    } else {
        // Custody first, then the record. Writing the row before the copy
        // succeeds would leave the database pointing at a file that is not
        // there - which renders as a broken avatar with nothing to retry.
        const QString stored = m_avatars->store(sourceFile, user.username());
        if (stored.isEmpty())
            return false;
        user.setAvatarSource(stored);
    }

    if (!m_users.save(user)) {
        // Roll the file back so disk and database cannot disagree.
        if (previous.isEmpty())
            m_avatars->clear(user.username());
        return false;
    }

    m_current = user;
    emit avatarChanged(user.avatarSource());
    return true;
}

void AuthService::signOut(bool forgetDevice)
{
    if (!m_current.has_value())
        return;

    // Revoked BEFORE the session is dropped, because m_current is where the
    // user id comes from. Every remembered sign-in for the account goes, not
    // just this panel's: "sign me out" from a device you are holding is the
    // only revocation control the product has.
    if (forgetDevice && m_sessions)
        (void)m_sessions->removeAllForUser(m_current->id());

    m_idleTimer.stop();
    m_current.reset();
    emit signedOut();
}

} // namespace smarton::services
