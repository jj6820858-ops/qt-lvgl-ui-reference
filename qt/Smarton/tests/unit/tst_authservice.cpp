#include <smarton/services/AuthService.h>
#include <smarton/services/IPasswordHasher.h>
#include <smarton/services/IUserRepository.h>

#include <QtCore/QHash>
#include <QtCore/QTimeZone>

#include <memory>
#include <QtTest/QSignalSpy>
#include <QtTest/QtTest>

using namespace smarton;

namespace {

/*!
    In-memory accounts. Exists so these tests exercise the sign-in RULES with
    no database and no 210,000-iteration KDF - the two things that would make
    them slow and flaky without testing anything AuthService is responsible for.
*/
class FakeUserRepository final : public services::IUserRepository
{
public:
    QHash<QString, domain::User> users;
    int  findCalls = 0;
    int  saveCalls = 0;
    bool saveSucceeds = true;

    std::optional<domain::User> findByUsername(const QString &username) override
    {
        ++findCalls;
        const auto it = users.constFind(username);
        if (it == users.constEnd())
            return std::nullopt;
        return *it;
    }

    bool save(const domain::User &user) override
    {
        ++saveCalls;
        if (!saveSucceeds)
            return false;
        users.insert(user.username(), user);
        return true;
    }

    std::optional<domain::User> findById(qint64 id) override
    {
        ++findCalls;
        for (const domain::User &user : std::as_const(users)) {
            if (user.id() == id)
                return user;
        }
        return std::nullopt;
    }

    qint64 createUser(const QString &username, const domain::PasswordHash &hash,
                      domain::Role role) override
    {
        if (users.contains(username))
            return 0;
        const qint64 id = ++lastId;
        users.insert(username, domain::User(id, username, role, hash));
        return id;
    }

    bool isEmpty() override { return users.isEmpty(); }

    qint64 lastId = 100;
};

/*! Reversible "hash" - fine for a fake, criminal in production. */
class FakeHasher final : public services::IPasswordHasher
{
public:
    mutable int hashCalls = 0;
    mutable int verifyCalls = 0;
    bool rehashWanted = false;

    domain::PasswordHash hash(const QString &password) const override
    {
        ++hashCalls;
        return { QStringLiteral("fake"), 1, QByteArrayLiteral("salt"), password.toUtf8() };
    }

    bool verify(const QString &password, const domain::PasswordHash &stored) const override
    {
        ++verifyCalls;
        return stored.derivedKey() == password.toUtf8();
    }

    bool needsRehash(const domain::PasswordHash &) const override { return rehashWanted; }
};

} // namespace

class TestAuthService : public QObject
{
    Q_OBJECT

private slots:
    void init();

    void reportsNotProvisionedWhenTheStoreIsEmpty();
    void succeedsWithTheCorrectPassword();
    void rejectsTheWrongPassword();
    void reportsTheSameErrorForAnUnknownUser();
    void burnsHashingCostForAnUnknownUser();
    void countsDownRemainingAttempts();
    void locksAfterTooManyFailures();
    void staysLockedUntilTheLockoutExpires();
    void unlocksAfterTheLockoutExpires();
    void clearsCountersOnSuccess();
    void rehashesWhenParametersAreOutdated();
    void reportsStorageFailure();
    void signOutClearsTheSession();

    void changePasswordRequiresTheCurrentOne();
    void changePasswordEnforcesPolicy();
    void changePasswordRehashesAndClearsCounters();
    void changePasswordRefusesWhenSignedOut();
    void idleTimeoutSignsOut();
    void activityPostponesTheIdleTimeout();
    void idleTimeoutOfZeroNeverFires();

private:
    void addUser(const QString &name, const QString &password);
    std::unique_ptr<services::AuthService> makeService();

    FakeUserRepository m_users;
    FakeHasher         m_hasher;
    QDateTime          m_now;
};

void TestAuthService::init()
{
    // Reset field by field rather than by assigning a fresh object: these
    // fakes derive from an interface with a user-declared destructor, so
    // copy-assignment is deprecated and -Werror would reject it.
    m_users.users.clear();
    m_users.findCalls = 0;
    m_users.saveCalls = 0;
    m_users.saveSucceeds = true;

    m_hasher.hashCalls = 0;
    m_hasher.verifyCalls = 0;
    m_hasher.rehashWanted = false;

    m_now = QDateTime(QDate(2026, 1, 1), QTime(12, 0), QTimeZone::UTC);
}

void TestAuthService::addUser(const QString &name, const QString &password)
{
    m_users.users.insert(name, domain::User(1, name, domain::Role::Operator,
                                            m_hasher.hash(password)));
    m_hasher.hashCalls = 0;
}

std::unique_ptr<services::AuthService> TestAuthService::makeService()
{
    auto service = std::make_unique<services::AuthService>(m_users, m_hasher);
    service->setClock([this] { return m_now; });
    return service;
}

void TestAuthService::succeedsWithTheCorrectPassword()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();
    QSignalSpy spy(service.get(), &services::AuthService::signedIn);

    const auto result = service->signIn(QStringLiteral("jack"), QStringLiteral("correct horse"));

    QVERIFY(result.success);
    QCOMPARE(result.error, services::AuthError::None);
    QVERIFY(service->isSignedIn());
    QCOMPARE(spy.count(), 1);
    QCOMPARE(spy.first().first().toString(), QStringLiteral("jack"));
}

void TestAuthService::rejectsTheWrongPassword()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();

    const auto result = service->signIn(QStringLiteral("jack"), QStringLiteral("wrong"));

    QVERIFY(!result.success);
    QCOMPARE(result.error, services::AuthError::InvalidCredentials);
    QVERIFY(!service->isSignedIn());
}

void TestAuthService::reportsTheSameErrorForAnUnknownUser()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();

    const auto wrongPassword = service->signIn(QStringLiteral("jack"), QStringLiteral("wrong"));
    const auto noSuchUser = service->signIn(QStringLiteral("nobody"), QStringLiteral("wrong"));

    // Identical error. Anything else turns the login form into an
    // account-enumeration oracle.
    QCOMPARE(noSuchUser.error, wrongPassword.error);
    QCOMPARE(noSuchUser.error, services::AuthError::InvalidCredentials);
}

void TestAuthService::reportsNotProvisionedWhenTheStoreIsEmpty()
{
    auto service = makeService();

    const auto result = service->signIn(QStringLiteral("anyone"), QStringLiteral("anything"));

    // An unprovisioned device must say so. Reporting InvalidCredentials here
    // means the owner is told "incorrect password" for a password that was
    // never set - and it leaks nothing, because there is no account to leak.
    QVERIFY(!result.success);
    QCOMPARE(result.error, services::AuthError::NotProvisioned);
}

void TestAuthService::burnsHashingCostForAnUnknownUser()
{
    // A decoy account, so the store is not empty: the enumeration defence only
    // has to hold once there is something to enumerate.
    addUser(QStringLiteral("someone-else"), QStringLiteral("irrelevant"));
    auto service = makeService();
    m_hasher.hashCalls = 0;

    (void)service->signIn(QStringLiteral("nobody"), QStringLiteral("whatever"));

    // Without this the "no such user" path returns in microseconds and the
    // difference is measurable over the network.
    QCOMPARE(m_hasher.hashCalls, 1);
}

void TestAuthService::countsDownRemainingAttempts()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();

    for (int attempt = 1; attempt < services::AuthService::kMaxFailedAttempts; ++attempt) {
        const auto result = service->signIn(QStringLiteral("jack"), QStringLiteral("wrong"));
        QCOMPARE(result.error, services::AuthError::InvalidCredentials);
        QCOMPARE(result.attemptsRemaining,
                 services::AuthService::kMaxFailedAttempts - attempt);
    }
}

void TestAuthService::locksAfterTooManyFailures()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();

    services::AuthResult result;
    for (int i = 0; i < services::AuthService::kMaxFailedAttempts; ++i)
        result = service->signIn(QStringLiteral("jack"), QStringLiteral("wrong"));

    QCOMPARE(result.error, services::AuthError::AccountLocked);
    QCOMPARE(result.lockedUntil,
             m_now.addSecs(services::AuthService::kLockoutSeconds));
}

void TestAuthService::staysLockedUntilTheLockoutExpires()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();
    for (int i = 0; i < services::AuthService::kMaxFailedAttempts; ++i)
        (void)service->signIn(QStringLiteral("jack"), QStringLiteral("wrong"));

    m_now = m_now.addSecs(services::AuthService::kLockoutSeconds - 1);

    // The CORRECT password must still be refused while the lockout stands,
    // otherwise the lockout only slows down attackers who guess wrong.
    const auto result = service->signIn(QStringLiteral("jack"), QStringLiteral("correct horse"));
    QVERIFY(!result.success);
    QCOMPARE(result.error, services::AuthError::AccountLocked);
}

void TestAuthService::unlocksAfterTheLockoutExpires()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();
    for (int i = 0; i < services::AuthService::kMaxFailedAttempts; ++i)
        (void)service->signIn(QStringLiteral("jack"), QStringLiteral("wrong"));

    m_now = m_now.addSecs(services::AuthService::kLockoutSeconds + 1);

    const auto result = service->signIn(QStringLiteral("jack"), QStringLiteral("correct horse"));
    QVERIFY(result.success);
}

void TestAuthService::clearsCountersOnSuccess()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();

    (void)service->signIn(QStringLiteral("jack"), QStringLiteral("wrong"));
    (void)service->signIn(QStringLiteral("jack"), QStringLiteral("correct horse"));

    QCOMPARE(m_users.users.value(QStringLiteral("jack")).failedAttempts(), 0);
    QVERIFY(!m_users.users.value(QStringLiteral("jack")).lockedUntil().isValid());
}

void TestAuthService::rehashesWhenParametersAreOutdated()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();
    m_hasher.rehashWanted = true;
    m_hasher.hashCalls = 0;

    QVERIFY(service->signIn(QStringLiteral("jack"), QStringLiteral("correct horse")).success);

    // Cost can be raised over time with no migration and no password reset.
    QCOMPARE(m_hasher.hashCalls, 1);
}

void TestAuthService::reportsStorageFailure()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();
    m_users.saveSucceeds = false;

    const auto result = service->signIn(QStringLiteral("jack"), QStringLiteral("correct horse"));

    // A sign-in whose counters could not be persisted is NOT a sign-in: the
    // lockout would be unenforceable.
    QVERIFY(!result.success);
    QCOMPARE(result.error, services::AuthError::StorageFailure);
    QVERIFY(!service->isSignedIn());
}

void TestAuthService::signOutClearsTheSession()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();
    QVERIFY(service->signIn(QStringLiteral("jack"), QStringLiteral("correct horse")).success);

    QSignalSpy spy(service.get(), &services::AuthService::signedOut);
    service->signOut();

    QVERIFY(!service->isSignedIn());
    QVERIFY(!service->currentUser().has_value());
    QCOMPARE(spy.count(), 1);

    // Idempotent: signing out twice must not emit twice.
    service->signOut();
    QCOMPARE(spy.count(), 1);
}

// ---- password change -------------------------------------------------------

void TestAuthService::changePasswordRequiresTheCurrentOne()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();
    QVERIFY(service->signIn(QStringLiteral("jack"), QStringLiteral("correct horse")).success);

    const auto result = service->changePassword(QStringLiteral("wrong"),
                                                QStringLiteral("NewPassw0rd"));

    // An authenticated session is not proof of presence: the panel may have
    // been signed in minutes ago and left unattended.
    QVERIFY(!result.success);
    QCOMPARE(result.error, services::AuthError::InvalidCredentials);
    QCOMPARE(m_users.users.value(QStringLiteral("jack")).passwordHash().derivedKey(),
             QByteArrayLiteral("correct horse"));
}

void TestAuthService::changePasswordEnforcesPolicy()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();
    QVERIFY(service->signIn(QStringLiteral("jack"), QStringLiteral("correct horse")).success);

    // Checked in the service, not only in the form: the UI is not the only
    // possible caller, and a policy that lives in one screen is not a policy.
    const auto result = service->changePassword(QStringLiteral("correct horse"),
                                                QStringLiteral("short"));

    QVERIFY(!result.success);
    QCOMPARE(result.error, services::AuthError::WeakPassword);
}

void TestAuthService::changePasswordRehashesAndClearsCounters()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();
    QVERIFY(service->signIn(QStringLiteral("jack"), QStringLiteral("correct horse")).success);
    (void)service->signIn(QStringLiteral("jack"), QStringLiteral("wrong"));

    QSignalSpy spy(service.get(), &services::AuthService::passwordChanged);
    const auto result = service->changePassword(QStringLiteral("correct horse"),
                                                QStringLiteral("NewPassw0rd"));

    QVERIFY(result.success);
    QCOMPARE(spy.count(), 1);
    const domain::User stored = m_users.users.value(QStringLiteral("jack"));
    QCOMPARE(stored.passwordHash().derivedKey(), QByteArrayLiteral("NewPassw0rd"));
    QCOMPARE(stored.failedAttempts(), 0);
    QVERIFY(!stored.lockedUntil().isValid());
}

void TestAuthService::changePasswordRefusesWhenSignedOut()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();

    const auto result = service->changePassword(QStringLiteral("correct horse"),
                                                QStringLiteral("NewPassw0rd"));
    QVERIFY(!result.success);
}

// ---- idle lock -------------------------------------------------------------

void TestAuthService::idleTimeoutSignsOut()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();
    // Milliseconds, not minutes: the timer is real, so the test waits on it.
    service->setIdleTimeoutSeconds(1);
    QVERIFY(service->signIn(QStringLiteral("jack"), QStringLiteral("correct horse")).success);

    QSignalSpy lockSpy(service.get(), &services::AuthService::lockedForInactivity);
    QSignalSpy outSpy(service.get(), &services::AuthService::signedOut);

    QVERIFY(lockSpy.wait(3000));
    QCOMPARE(outSpy.count(), 1);
    QVERIFY(!service->isSignedIn());
}

void TestAuthService::activityPostponesTheIdleTimeout()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();
    service->setIdleTimeoutSeconds(1);
    QVERIFY(service->signIn(QStringLiteral("jack"), QStringLiteral("correct horse")).success);

    QSignalSpy lockSpy(service.get(), &services::AuthService::lockedForInactivity);

    // Poke it repeatedly across more than one timeout's worth of wall clock.
    // A lock that fires anyway is a lock that fires while someone is using it.
    for (int i = 0; i < 6; ++i) {
        QTest::qWait(250);
        service->noteActivity();
    }
    QCOMPARE(lockSpy.count(), 0);
    QVERIFY(service->isSignedIn());
}

void TestAuthService::idleTimeoutOfZeroNeverFires()
{
    addUser(QStringLiteral("jack"), QStringLiteral("correct horse"));
    auto service = makeService();
    service->setIdleTimeoutSeconds(0);
    QVERIFY(service->signIn(QStringLiteral("jack"), QStringLiteral("correct horse")).success);

    QSignalSpy lockSpy(service.get(), &services::AuthService::lockedForInactivity);
    QTest::qWait(1200);

    QCOMPARE(lockSpy.count(), 0);
    QVERIFY(service->isSignedIn());
}

QTEST_GUILESS_MAIN(TestAuthService)
#include "tst_authservice.moc"
