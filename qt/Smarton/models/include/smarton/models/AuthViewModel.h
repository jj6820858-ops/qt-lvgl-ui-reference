#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtQml/qqmlregistration.h>

namespace smarton::services {
class AuthService;
class ISessionTokenStore;
}

namespace smarton::models {

/**
 * @brief Everything the pre-login flow binds to, and nothing else.
 *
 * Deliberate properties:
 *  - There is no `password` property. The plaintext is passed as an argument
 *    to signIn() and is never stored on a QObject, never exposed to the QML
 *    engine as readable state, and never lands in a debugger dump of the view
 *    model or in a QML property-change trace.
 *  - errorText carries the SAME message for an unknown account and a wrong
 *    password, because AuthService returns the same error for both. Rewording
 *    one of them here would undo the account-enumeration defence in the layer
 *    below.
 *  - signIn() is asynchronous only in the sense that it yields once to the
 *    event loop before hashing. That is enough for the busy state to paint,
 *    and it keeps the SQLite connection on the thread that owns it. See the
 *    note in the .cpp before changing it to a real worker thread.
 */
class AuthViewModel : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool busy READ isBusy NOTIFY busyChanged)
    Q_PROPERTY(bool signedIn READ isSignedIn NOTIFY signedInChanged)
    Q_PROPERTY(QString currentUserName READ currentUserName NOTIFY signedInChanged)
    /*! Profile fields. Separate from currentUserName, which is the credential
        half of the account - the profile screen was showing the username in
        both the name and the email boxes because there was nothing else to
        read, which made two editable fields that could not be edited. */
    Q_PROPERTY(QString fullName READ fullName NOTIFY profileChanged)
    Q_PROPERTY(QString email    READ email    NOTIFY profileChanged)
    Q_PROPERTY(QString phone    READ phone    NOTIFY profileChanged)
    Q_PROPERTY(QString errorText READ errorText NOTIFY errorTextChanged)
    /*! True when the last sign-out was the idle timer, not the user. Lets the
        login screen say why it is showing rather than looking like a crash. */
    Q_PROPERTY(bool lockedForInactivity READ wasLockedForInactivity
               NOTIFY lockedForInactivityChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)
    /*! Bound to the "Remember information" checkbox. Read at sign-in. */
    /*!
        Seconds of inactivity before the panel locks; 0 disables it.

        Exposed so the Preferences tab can set it. It was a command-line
        option only, which is a setting that exists for whoever starts the
        process and not for whoever lives with the panel - and on a device
        with no shell prompt, that is nobody.
    */
    Q_PROPERTY(int idleLockSeconds READ idleLockSeconds WRITE setIdleLockSeconds
               NOTIFY idleLockSecondsChanged)

    Q_PROPERTY(bool rememberMe READ rememberMe WRITE setRememberMe NOTIFY rememberMeChanged)
    /*! The username to pre-fill, from the last remembered sign-in. Empty when
        nothing is remembered. */
    Q_PROPERTY(QString rememberedUser READ rememberedUser NOTIFY rememberMeChanged)
    /*! Always a usable URL. Falls back to the bundled picture when the account
        has none, or when the stored file has since been deleted - a broken
        image with no explanation is worse than a generic face. */
    Q_PROPERTY(QString avatarSource READ avatarSource NOTIFY avatarChanged)
    Q_PROPERTY(bool hasCustomAvatar READ hasCustomAvatar NOTIFY avatarChanged)

public:
    explicit AuthViewModel(QObject *parent = nullptr);

    void setService(services::AuthService *service);
    /** Where this panel's resume token lives. Optional; without it the
        "Remember information" box still ticks and simply does not persist. */
    void setSessionTokenStore(services::ISessionTokenStore *store);

    /**
     * @brief Try to sign in from a stored token. Called once at startup.
     *
     * Returns false without touching anything when there is no token, when it
     * has expired or been revoked, or when the idle lock is still standing
     * from the last run - see ISessionTokenStore::lockedForInactivity().
     */
    Q_INVOKABLE bool tryResumeSession();

    [[nodiscard]] bool isBusy() const { return m_busy; }
    [[nodiscard]] bool isSignedIn() const { return m_signedIn; }
    [[nodiscard]] QString currentUserName() const { return m_currentUserName; }
    [[nodiscard]] QString fullName() const { return m_fullName; }
    [[nodiscard]] QString email()    const { return m_email; }
    [[nodiscard]] QString phone()    const { return m_phone; }
    [[nodiscard]] QString errorText() const { return m_errorText; }
    [[nodiscard]] bool wasLockedForInactivity() const { return m_lockedForInactivity; }
    [[nodiscard]] QString statusText() const { return m_statusText; }
    [[nodiscard]] bool rememberMe() const { return m_rememberMe; }
    void setRememberMe(bool remember);
    [[nodiscard]] QString rememberedUser() const;
    [[nodiscard]] QString avatarSource() const;
    [[nodiscard]] bool hasCustomAvatar() const;

    /*! The picture used when an account has none. */
    static constexpr auto kDefaultAvatar =
        "qrc:/qt/qml/SmarTon/Resources/images/avatars/default-profile.jpeg";

    /** Verify @p password for @p username. Result arrives via property change. */
    Q_INVOKABLE void signIn(const QString &username, const QString &password);
    Q_INVOKABLE void signOut();
    /*! Any user input. Cheap by design - it is called from a global handler. */
    Q_INVOKABLE void noteActivity();

    [[nodiscard]] int idleLockSeconds() const;
    void setIdleLockSeconds(int seconds);
    /*! @p fileUrl comes straight from a FileDialog. */
    Q_INVOKABLE void setAvatar(const QString &fileUrl);
    Q_INVOKABLE void clearAvatar();

    /**
     * @brief Save the profile fields.
     *
     * Returns true on success so the CALLER can decide what to say about it.
     * A view model that raised its own toast would be deciding presentation,
     * and the same call is going to be made from a settings screen and a
     * first-run wizard that want to say different things.
     */
    Q_INVOKABLE bool saveProfile(const QString &fullName,
                                 const QString &email,
                                 const QString &phone);

    /*! Empty is allowed - this is an optional field, not a login. */
    Q_INVOKABLE static bool isPlausibleEmail(const QString &email);
    /*! Change the signed-in user's password. Result via statusText/errorText. */
    Q_INVOKABLE void changePassword(const QString &currentPassword,
                                    const QString &newPassword,
                                    const QString &confirmPassword);
    /** Clear the error line - called as soon as the user edits a field. */
    Q_INVOKABLE void clearError();

    /**
     * The password policy, in the one place both the composition root and any
     * future password-change path can call. StPasswordRules mirrors these
     * three predicates for live UI feedback; if they ever disagree, this one
     * wins, and tst_passwordrules.qml / tst_authviewmodel.cpp run the same
     * cases so the disagreement shows up as a failing test.
     *
     * Deliberately NOT Q_INVOKABLE: QML has no reason to call it (the rules
     * control renders its own feedback), and static invokables are a corner
     * of moc worth not depending on.
     */
    [[nodiscard]] static bool isAcceptablePassword(const QString &password);

signals:
    void busyChanged();
    void signedInChanged();
    void errorTextChanged();
    void statusTextChanged();
    void avatarChanged();
    void profileChanged();
    void lockedForInactivityChanged();
    void rememberMeChanged();
    void idleLockSecondsChanged();
    /*! The session ended by itself; the shell should return to the login flow. */
    void sessionEnded();
    /** Emitted once a sign-in succeeds, for the shell to swap itself in. */
    void authenticated();

private:
    void setBusy(bool busy);
    void setErrorText(const QString &text);
    void setStatusText(const QString &text);
    void performSignIn(const QString &username, const QString &password);
    /** Copy the signed-in user's profile fields onto this object. */
    void refreshProfile();
    /** Persist or clear the resume token after a successful password entry. */
    void rememberSession(const QString &token, const QString &username);

    services::AuthService        *m_service = nullptr;
    services::ISessionTokenStore *m_tokens  = nullptr;
    bool    m_rememberMe = false;
    bool    m_busy = false;
    bool    m_signedIn = false;
    QString m_currentUserName;
    QString m_fullName;
    QString m_email;
    QString m_phone;
    QString m_errorText;
    QString m_statusText;
    QString m_avatarPath;
    bool    m_lockedForInactivity = false;
};

} // namespace smarton::models
