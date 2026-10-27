#include <smarton/models/AuthViewModel.h>

#include <smarton/services/AuthService.h>
#include <smarton/services/ISessionTokenStore.h>

#include <QtCore/QRegularExpression>
#include <QtCore/QFileInfo>
#include <QtCore/QLocale>
#include <QtCore/QUrl>
#include <QtCore/QTimer>

namespace smarton::models {

AuthViewModel::AuthViewModel(QObject *parent)
    : QObject(parent)
{
}

void AuthViewModel::setService(services::AuthService *service)
{
    m_service = service;
    if (!m_service)
        return;

    connect(m_service, &services::AuthService::avatarChanged, this,
            [this](const QString &path) {
                m_avatarPath = path;
                emit avatarChanged();
            });

    connect(m_service, &services::AuthService::lockedForInactivity, this, [this] {
        m_lockedForInactivity = true;
        emit lockedForInactivityChanged();

        // PERSIST the lock. The idle lock protects a running panel, but anyone
        // who can reach the screen can reach the power lead, so without this a
        // remembered session would sign itself straight back in after a power
        // cycle and the lock would be decorative. The token is deliberately
        // NOT revoked: the user still wants to be remembered, they just have
        // to get past the lock they asked for first.
        if (m_tokens) {
            m_tokens->setLockedForInactivity(true);
            m_tokens->flush();
        }
    });

    // Signalled whether the user pressed Log out or the panel timed out, so
    // the shell has exactly one thing to listen to.
    connect(m_service, &services::AuthService::signedOut, this, [this] {
        m_signedIn = false;
        m_currentUserName.clear();
        emit signedInChanged();
        emit sessionEnded();
    });
}

QString AuthViewModel::avatarSource() const
{
    // Checked, not trusted. The stored file can be deleted between runs, and
    // the fallback must happen here rather than as a broken Image in QML.
    if (!m_avatarPath.isEmpty() && QFileInfo::exists(m_avatarPath))
        return QUrl::fromLocalFile(m_avatarPath).toString();
    return QString::fromLatin1(kDefaultAvatar);
}

bool AuthViewModel::hasCustomAvatar() const
{
    return !m_avatarPath.isEmpty() && QFileInfo::exists(m_avatarPath);
}

void AuthViewModel::setAvatar(const QString &fileUrl)
{
    if (!m_service)
        return;
    if (!m_service->setAvatar(fileUrl))
        setErrorText(tr("That picture could not be used. Try a PNG or JPEG under 8 MB."));
    else
        setStatusText(tr("Picture updated."));
}

void AuthViewModel::clearAvatar()
{
    if (m_service)
        (void)m_service->setAvatar(QString());
}

void AuthViewModel::noteActivity()
{
    if (m_service)
        m_service->noteActivity();
}

int AuthViewModel::idleLockSeconds() const
{
    return m_service ? m_service->idleTimeoutSeconds() : 0;
}

void AuthViewModel::setIdleLockSeconds(int seconds)
{
    if (!m_service || seconds == m_service->idleTimeoutSeconds())
        return;

    m_service->setIdleTimeoutSeconds(seconds);
    // Persisting is the composition root's job, which is why this only
    // announces the change. This view model has no preferences pointer and
    // should not grow one to write a single integer: the root already owns
    // that file and already writes the window size to it on the way out.
    emit idleLockSecondsChanged();
}

void AuthViewModel::setStatusText(const QString &text)
{
    if (m_statusText == text)
        return;
    m_statusText = text;
    emit statusTextChanged();
}

void AuthViewModel::changePassword(const QString &currentPassword,
                                   const QString &newPassword,
                                   const QString &confirmPassword)
{
    clearError();
    setStatusText(QString());

    if (newPassword != confirmPassword) {
        setErrorText(tr("The new passwords do not match."));
        return;
    }
    if (!m_service) {
        setErrorText(tr("Sign-in is unavailable. Please restart the application."));
        return;
    }

    setBusy(true);
    // Same one-turn yield as signIn(): two PBKDF2 passes here, so the busy
    // state has to paint before the thread blocks. See signIn() for why this
    // is not a worker thread.
    QTimer::singleShot(0, this, [this, currentPassword, newPassword] {
        const services::AuthResult result =
            m_service->changePassword(currentPassword, newPassword);
        setBusy(false);

        if (result.success) {
            setStatusText(tr("Password updated."));
            return;
        }
        switch (result.error) {
        case services::AuthError::WeakPassword:
            setErrorText(tr("Choose at least 8 characters, with upper and lower "
                            "case and a number or symbol."));
            break;
        case services::AuthError::StorageFailure:
            setErrorText(tr("Could not reach the account store."));
            break;
        default:
            setErrorText(tr("Your current password is not correct."));
            break;
        }
    });
}

void AuthViewModel::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void AuthViewModel::setErrorText(const QString &text)
{
    if (m_errorText == text)
        return;
    m_errorText = text;
    emit errorTextChanged();
}

void AuthViewModel::clearError()
{
    setErrorText(QString());
}

bool AuthViewModel::isAcceptablePassword(const QString &password)
{
    if (password.size() < 8)
        return false;

    bool hasLower = false;
    bool hasUpper = false;
    bool hasNumberOrSymbol = false;
    for (const QChar c : password) {
        if (c.isLower())
            hasLower = true;
        else if (c.isUpper())
            hasUpper = true;
        if (c.isDigit() || c.isPunct() || c.isSymbol())
            hasNumberOrSymbol = true;
    }
    return hasLower && hasUpper && hasNumberOrSymbol;
}

void AuthViewModel::signIn(const QString &username, const QString &password)
{
    if (m_busy)
        return;
    if (username.isEmpty() || password.isEmpty()) {
        setErrorText(tr("Enter your email and password."));
        return;
    }

    clearError();
    setBusy(true);

    // Yield once to the event loop before hashing.
    //
    // Deriving the verifier costs ~200 ms by design - that cost is the whole
    // point of PBKDF2. Calling it inline would block the render thread before
    // the busy state was ever painted, so the button would appear to do
    // nothing and people would press it again.
    //
    // Why not a worker thread: the QSqlDatabase connection AuthService reads
    // through belongs to the thread that opened it, and QSqlDatabase is not
    // safe to use from another thread. Moving the hash off the GUI thread
    // means moving the repository with it (its own thread, queued calls) -
    // worth doing if a screen ever needs to stay animated during sign-in, and
    // not worth the machinery for a single 200 ms action that ends in a
    // screen change. A lambda capture by value keeps the plaintext alive for
    // exactly one event-loop turn.
    QTimer::singleShot(0, this, [this, username, password] {
        performSignIn(username, password);
    });
}

void AuthViewModel::performSignIn(const QString &username, const QString &password)
{
    if (!m_service) {
        setBusy(false);
        setErrorText(tr("Sign-in is unavailable. Please restart the application."));
        return;
    }

    const services::AuthResult result = m_service->signIn(username, password,
                                                         m_rememberMe);
    setBusy(false);

    if (result.success) {
        rememberSession(result.sessionToken, username);
        m_signedIn = true;
        m_currentUserName = username;
        refreshProfile();
        const auto signedInUser = m_service->currentUser();
        m_avatarPath = signedInUser.has_value() ? signedInUser->avatarSource() : QString();
        emit avatarChanged();
        m_lockedForInactivity = false;
        emit lockedForInactivityChanged();
        emit signedInChanged();
        emit authenticated();
        return;
    }

    switch (result.error) {
    case services::AuthError::AccountLocked: {
        // A locked account is safe to name: the caller already proved they can
        // trigger the lockout, so this leaks nothing an attacker cannot see.
        const QString until =
            QLocale().toString(result.lockedUntil.toLocalTime(), QLocale::ShortFormat);
        setErrorText(tr("Too many failed attempts. Try again after %1.").arg(until));
        break;
    }
    case services::AuthError::NotProvisioned:
        setErrorText(tr("No account has been set up on this device yet. "
                        "Run smarton --create-account <name> from a terminal."));
        break;
    case services::AuthError::StorageFailure:
        setErrorText(tr("Could not reach the account store."));
        break;
    case services::AuthError::InvalidCredentials:
    default:
        // ONE message for "no such account" and "wrong password". Splitting
        // them turns the login form into an account-enumeration oracle.
        setErrorText(tr("Incorrect email or password."));
        break;
    }
}

void AuthViewModel::refreshProfile()
{
    const auto user = m_service ? m_service->currentUser() : std::nullopt;
    m_fullName = user.has_value() ? user->fullName() : QString();
    m_email    = user.has_value() ? user->email()    : QString();
    m_phone    = user.has_value() ? user->phone()    : QString();
    emit profileChanged();
}

bool AuthViewModel::isPlausibleEmail(const QString &email)
{
    if (email.isEmpty())
        return true;      // optional field, not a login

    // Deliberately loose. The only way to know an address is real is to send
    // to it, and SmarTon has no mail transport; a strict pattern here would
    // reject valid addresses (plus-tags, new TLDs, unicode domains) while
    // still accepting ones that bounce. This catches the typo class - no @,
    // no dot, whitespace - and nothing else.
    static const QRegularExpression shape(
        QStringLiteral("^[^@\\s]+@[^@\\s]+\\.[^@\\s]{2,}$"));
    return shape.match(email.trimmed()).hasMatch();
}

bool AuthViewModel::saveProfile(const QString &fullName, const QString &email,
                                const QString &phone)
{
    if (!m_service || !m_signedIn) {
        setErrorText(tr("You are not signed in."));
        return false;
    }

    if (!isPlausibleEmail(email)) {
        setErrorText(tr("That does not look like an email address."));
        return false;
    }

    if (!m_service->updateProfile(fullName, email, phone)) {
        setErrorText(tr("Could not save your profile."));
        return false;
    }

    clearError();
    refreshProfile();
    return true;
}

void AuthViewModel::setSessionTokenStore(services::ISessionTokenStore *store)
{
    m_tokens = store;
    // The box comes up ticked for someone who ticked it last time. Anything
    // else makes "remember me" a thing you have to opt into on every machine
    // you already told to remember you.
    m_rememberMe = m_tokens && !m_tokens->rememberedUser().isEmpty();
    emit rememberMeChanged();
}

void AuthViewModel::setRememberMe(bool remember)
{
    if (m_rememberMe == remember)
        return;
    m_rememberMe = remember;

    // Unticking is an instruction, not just a preference for next time: it
    // means "forget what you have on me", so the stored token and username go
    // now rather than at the next sign-in that may never come.
    if (!m_rememberMe && m_tokens) {
        m_tokens->setToken(QString());
        m_tokens->setRememberedUser(QString());
        m_tokens->flush();
    }
    emit rememberMeChanged();
}

QString AuthViewModel::rememberedUser() const
{
    return m_tokens ? m_tokens->rememberedUser() : QString();
}

void AuthViewModel::rememberSession(const QString &token, const QString &username)
{
    if (!m_tokens)
        return;

    // A successful password entry clears the persisted idle lock. This is the
    // ONLY thing that clears it, which is what makes the lock survive a power
    // cycle: nothing else in the app can decide the user is back.
    m_tokens->setLockedForInactivity(false);

    if (m_rememberMe) {
        m_tokens->setToken(token);
        m_tokens->setRememberedUser(username);
    } else {
        m_tokens->setToken(QString());
        m_tokens->setRememberedUser(QString());
    }
    m_tokens->flush();
}

bool AuthViewModel::tryResumeSession()
{
    if (!m_service || !m_tokens)
        return false;

    // The persisted idle lock wins over the token. Checked BEFORE the token is
    // read so a locked panel cannot be resumed by any means short of the
    // password - see the comment on the lockedForInactivity connection.
    if (m_tokens->lockedForInactivity()) {
        m_lockedForInactivity = true;
        emit lockedForInactivityChanged();
        return false;
    }

    const QString token = m_tokens->token();
    if (token.isEmpty())
        return false;

    const services::AuthResult result = m_service->resumeSession(token);
    if (!result.success) {
        // Whatever the reason - expired, revoked, rotated past, tampered with -
        // the stored copy is now worthless, so it goes. The username stays, so
        // the login screen still arrives pre-filled.
        m_tokens->setToken(QString());
        m_tokens->flush();
        return false;
    }

    // Rotated: the token that just worked is already dead, and what comes back
    // is its replacement. Written before anything else, because a crash
    // between here and the next start would otherwise leave the panel holding
    // a token the database no longer accepts.
    m_tokens->setToken(result.sessionToken);
    m_tokens->flush();

    const auto resumedUser = m_service->currentUser();
    m_signedIn        = true;
    m_currentUserName = resumedUser.has_value() ? resumedUser->username()
                                                : m_tokens->rememberedUser();
    m_avatarPath      = resumedUser.has_value() ? resumedUser->avatarSource() : QString();
    m_rememberMe      = true;
    refreshProfile();

    emit avatarChanged();
    emit rememberMeChanged();
    emit signedInChanged();
    emit authenticated();
    return true;
}

void AuthViewModel::signOut()
{
    m_lockedForInactivity = false;
    emit lockedForInactivityChanged();
    clearError();
    setStatusText(QString());

    // An explicit sign-out is a decision to stop trusting this panel, so the
    // token goes - locally AND in the database, so a copy of the settings file
    // taken beforehand is dead too. The idle lock does not come through here.
    if (m_tokens) {
        m_tokens->setToken(QString());
        m_tokens->setLockedForInactivity(false);
        m_tokens->flush();
    }

    if (m_service) {
        // The service's signedOut signal does the rest, so a manual sign-out
        // and an idle lock take exactly the same path.
        m_service->signOut(/*forgetDevice=*/true);
        return;
    }

    m_signedIn = false;
    m_currentUserName.clear();
    emit signedInChanged();
    emit sessionEnded();
}

} // namespace smarton::models
