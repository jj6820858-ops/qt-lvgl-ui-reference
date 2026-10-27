#include <smarton/domain/entities/User.h>
#include <smarton/services/AuthService.h>
#include <smarton/services/IPasswordHasher.h>
#include <smarton/services/ISessionRepository.h>
#include <smarton/services/IUserRepository.h>

#include <QtCore/QHash>
#include <QtTest/QSignalSpy>
#include <QtTest/QtTest>

#include <memory>

using namespace smarton;

namespace {

class FakeUsers final : public services::IUserRepository
{
public:
    QHash<QString, domain::User> users;

    std::optional<domain::User> findByUsername(const QString &username) override
    {
        const auto it = users.constFind(username);
        return it == users.constEnd() ? std::nullopt : std::optional(*it);
    }

    std::optional<domain::User> findById(qint64 id) override
    {
        for (const domain::User &user : std::as_const(users)) {
            if (user.id() == id)
                return user;
        }
        return std::nullopt;
    }

    bool save(const domain::User &user) override
    {
        users.insert(user.username(), user);
        return true;
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
    domain::PasswordHash hash(const QString &password) const override
    {
        return { QStringLiteral("fake"), 1, QByteArrayLiteral("salt"), password.toUtf8() };
    }
    bool verify(const QString &password, const domain::PasswordHash &stored) const override
    {
        return stored.derivedKey() == password.toUtf8();
    }
    bool needsRehash(const domain::PasswordHash &) const override { return false; }
};

class FakeSessions final : public services::ISessionRepository
{
public:
    QList<services::StoredSession> rows;
    qint64 nextId = 1;
    int purgeCalls = 0;

    std::optional<services::StoredSession> findBySelector(const QString &selector) override
    {
        for (const auto &row : std::as_const(rows)) {
            if (row.selector == selector)
                return row;
        }
        return std::nullopt;
    }

    qint64 insert(const services::StoredSession &session) override
    {
        services::StoredSession stored = session;
        stored.id = nextId++;
        rows.append(stored);
        return stored.id;
    }

    bool rotate(qint64 id, const QString &secretHash,
                const QDateTime &expiresAt, const QDateTime &lastUsedAt) override
    {
        for (auto &row : rows) {
            if (row.id != id)
                continue;
            row.secretHash = secretHash;
            row.expiresAt  = expiresAt;
            row.lastUsedAt = lastUsedAt;
            return true;
        }
        return false;
    }

    bool remove(qint64 id) override
    {
        return rows.removeIf([id](const auto &row) { return row.id == id; }) > 0;
    }

    bool removeAllForUser(qint64 userId) override
    {
        rows.removeIf([userId](const auto &row) { return row.userId == userId; });
        return true;
    }

    int purgeExpired(const QDateTime &now) override
    {
        ++purgeCalls;
        return int(rows.removeIf([&now](const auto &row) { return row.expiresAt <= now; }));
    }
};

} // namespace

class TestSessionTokens : public QObject
{
    Q_OBJECT

private slots:
    void init();
    void cleanup();

    void noTokenUnlessAsked();
    void tokenIsIssuedAndResumes();
    void tokenIsSingleUse();
    void resumeRotatesTheSecret();
    void expiredTokenIsRefusedAndDeleted();
    void tamperedSecretBurnsTheRow();
    void malformedTokenIsRefused_data();
    void malformedTokenIsRefused();
    void resumeNeverLocksTheAccount();
    void lockedAccountCannotBeResumed();
    void explicitSignOutRevokesEveryDevice();
    void idleLockKeepsTheToken();
    void deletedAccountInvalidatesTheToken();
    void withoutARepositoryNothingIsIssued();

private:
    std::unique_ptr<FakeUsers>   m_users;
    std::unique_ptr<FakeHasher>  m_hasher;
    std::unique_ptr<FakeSessions> m_sessions;
    std::unique_ptr<services::AuthService> m_service;

    static constexpr auto kUser = "jack";
    static constexpr auto kPassword = "correct horse";

    QString signInRemembering()
    {
        const auto result = m_service->signIn(QString::fromLatin1(kUser),
                                              QString::fromLatin1(kPassword), true);
        Q_ASSERT(result.success);
        return result.sessionToken;
    }
};

void TestSessionTokens::init()
{
    m_users   = std::make_unique<FakeUsers>();
    m_hasher  = std::make_unique<FakeHasher>();
    m_sessions = std::make_unique<FakeSessions>();

    domain::User jack(7, QString::fromLatin1(kUser), domain::Role::Administrator,
                      m_hasher->hash(QString::fromLatin1(kPassword)));
    m_users->users.insert(jack.username(), jack);

    m_service = std::make_unique<services::AuthService>(*m_users, *m_hasher);
    m_service->setSessionRepository(m_sessions.get());
}

void TestSessionTokens::cleanup()
{
    m_service.reset();
    m_sessions.reset();
    m_hasher.reset();
    m_users.reset();
}

void TestSessionTokens::noTokenUnlessAsked()
{
    const auto result = m_service->signIn(QString::fromLatin1(kUser),
                                          QString::fromLatin1(kPassword));
    QVERIFY(result.success);
    // Remembering is opt-in. A default that quietly issued a 30-day credential
    // to anyone who signed in would be the wrong way round.
    QVERIFY(result.sessionToken.isEmpty());
    QVERIFY(m_sessions->rows.isEmpty());
}

void TestSessionTokens::tokenIsIssuedAndResumes()
{
    const QString token = signInRemembering();
    QVERIFY(!token.isEmpty());
    QCOMPARE(m_sessions->rows.size(), 1);

    // The SECRET is never stored. What is on disk is a digest, so a dump of
    // the sessions table is not a pile of usable tokens.
    const QString secret = token.section(QLatin1Char(':'), 1);
    QVERIFY(!secret.isEmpty());
    QVERIFY(!m_sessions->rows.first().secretHash.contains(secret));
    QCOMPARE(m_sessions->rows.first().secretHash.size(), 64);   // SHA-256, hex

    m_service->signOut();
    QVERIFY(!m_service->isSignedIn());

    const auto resumed = m_service->resumeSession(token);
    QVERIFY(resumed.success);
    QVERIFY(m_service->isSignedIn());
    QCOMPARE(m_service->currentUser()->username(), QString::fromLatin1(kUser));
}

void TestSessionTokens::tokenIsSingleUse()
{
    const QString first = signInRemembering();
    m_service->signOut();

    const auto resumed = m_service->resumeSession(first);
    QVERIFY(resumed.success);
    QVERIFY(!resumed.sessionToken.isEmpty());
    QVERIFY(resumed.sessionToken != first);

    m_service->signOut();

    // The old string is dead. This is what bounds the damage from a settings
    // file copied off the panel: it is good until the panel next starts, not
    // for the thirty days on the row.
    QVERIFY(!m_service->resumeSession(first).success);
    // ...and the replacement still works, so a legitimate panel is unaffected.
    QVERIFY(m_service->resumeSession(resumed.sessionToken).success);
}

void TestSessionTokens::resumeRotatesTheSecret()
{
    const QString token = signInRemembering();
    const QString hashBefore = m_sessions->rows.first().secretHash;
    const QDateTime expiryBefore = m_sessions->rows.first().expiresAt;

    m_service->signOut();
    const auto resumed = m_service->resumeSession(token);
    QVERIFY(resumed.success);

    // Same ROW - the selector is stable, so this is a rotation and not a leak
    // of rows on every restart.
    QCOMPARE(m_sessions->rows.size(), 1);
    QCOMPARE(m_sessions->rows.first().selector, token.section(QLatin1Char(':'), 0, 0));
    QVERIFY(m_sessions->rows.first().secretHash != hashBefore);
    QVERIFY(m_sessions->rows.first().expiresAt >= expiryBefore);
}

void TestSessionTokens::expiredTokenIsRefusedAndDeleted()
{
    const QString token = signInRemembering();

    // Reach past the clock rather than sleeping for a month.
    m_sessions->rows.first().expiresAt = QDateTime::currentDateTimeUtc().addDays(-1);
    m_service->signOut();

    QVERIFY(!m_service->resumeSession(token).success);
    // Swept, not left to be retried forever.
    QVERIFY(m_sessions->rows.isEmpty());
}

void TestSessionTokens::tamperedSecretBurnsTheRow()
{
    const QString token = signInRemembering();
    m_service->signOut();

    const QString selector = token.section(QLatin1Char(':'), 0, 0);
    const QString forged = selector + QStringLiteral(":")
                         + QString(64, QLatin1Char('a'));

    QVERIFY(!m_service->resumeSession(forged).success);

    // A real selector with a wrong secret is not a typo - nobody types these.
    // It means someone is probing, so the row goes rather than being left
    // alive for the next attempt.
    QVERIFY(m_sessions->rows.isEmpty());
    QVERIFY(!m_service->resumeSession(token).success);
}

void TestSessionTokens::malformedTokenIsRefused_data()
{
    QTest::addColumn<QString>("token");

    QTest::newRow("empty")          << QString();
    QTest::newRow("no separator")   << QStringLiteral("abcdef0123456789");
    QTest::newRow("leading colon")  << QStringLiteral(":secret");
    QTest::newRow("trailing colon") << QStringLiteral("selector:");
    QTest::newRow("only a colon")   << QStringLiteral(":");
    QTest::newRow("unknown")        << QStringLiteral("deadbeef:cafebabe");
}

void TestSessionTokens::malformedTokenIsRefused()
{
    QFETCH(QString, token);
    m_service->signOut();

    const auto result = m_service->resumeSession(token);
    QVERIFY(!result.success);
    QVERIFY(!m_service->isSignedIn());
    // Must not crash, and must not touch anyone else's rows.
    QCOMPARE(result.error, services::AuthError::InvalidCredentials);
}

void TestSessionTokens::resumeNeverLocksTheAccount()
{
    (void)signInRemembering();
    m_service->signOut();

    // More bad tokens than kMaxFailedAttempts. A token is not a password
    // guess, so presenting bad ones must not consume attempts - otherwise
    // anyone who can reach the panel can lock its owner out without ever
    // knowing a username.
    for (int i = 0; i < services::AuthService::kMaxFailedAttempts + 3; ++i)
        (void)m_service->resumeSession(QStringLiteral("nope%1:bad").arg(i));

    const auto result = m_service->signIn(QString::fromLatin1(kUser),
                                          QString::fromLatin1(kPassword));
    QVERIFY2(result.success, "bad tokens must not count as failed passwords");
    QCOMPARE(m_users->users.value(QString::fromLatin1(kUser)).failedAttempts(), 0);
}

void TestSessionTokens::lockedAccountCannotBeResumed()
{
    const QString token = signInRemembering();
    m_service->signOut();

    domain::User jack = m_users->users.value(QString::fromLatin1(kUser));
    jack.setLockedUntil(QDateTime::currentDateTimeUtc().addSecs(300));
    m_users->users.insert(jack.username(), jack);

    const auto result = m_service->resumeSession(token);
    // The token proves the device was trusted once; it does not override a
    // lockout that a burst of wrong passwords just earned.
    QVERIFY(!result.success);
    QCOMPARE(result.error, services::AuthError::AccountLocked);
    QVERIFY(!m_service->isSignedIn());
}

void TestSessionTokens::explicitSignOutRevokesEveryDevice()
{
    const QString panelA = signInRemembering();
    m_service->signOut();
    const QString panelB = signInRemembering();
    QCOMPARE(m_sessions->rows.size(), 2);

    m_service->signOut(/*forgetDevice=*/true);

    QVERIFY(m_sessions->rows.isEmpty());
    QVERIFY(!m_service->resumeSession(panelA).success);
    QVERIFY(!m_service->resumeSession(panelB).success);
}

void TestSessionTokens::idleLockKeepsTheToken()
{
    const QString token = signInRemembering();

    // The idle lock is a screen lock, not a decision to stop trusting this
    // panel, so it takes the default forgetDevice=false path.
    m_service->signOut();

    QCOMPARE(m_sessions->rows.size(), 1);
    QVERIFY(m_service->resumeSession(token).success);
}

void TestSessionTokens::deletedAccountInvalidatesTheToken()
{
    const QString token = signInRemembering();
    m_service->signOut();
    m_users->users.clear();

    QVERIFY(!m_service->resumeSession(token).success);
    // The row goes too: a session pointing at nothing is not worth keeping,
    // and leaving it lets a recreated account inherit someone else's session
    // if ids are ever reused.
    QVERIFY(m_sessions->rows.isEmpty());
}

void TestSessionTokens::withoutARepositoryNothingIsIssued()
{
    services::AuthService bare(*m_users, *m_hasher);   // no session repository

    const auto result = bare.signIn(QString::fromLatin1(kUser),
                                    QString::fromLatin1(kPassword), true);
    QVERIFY(result.success);
    // Asked to remember, unable to - and it says nothing rather than handing
    // back a token that resolves to no row.
    QVERIFY(result.sessionToken.isEmpty());
    QVERIFY(!bare.resumeSession(QStringLiteral("a:b")).success);
}

QTEST_GUILESS_MAIN(TestSessionTokens)
#include "tst_sessiontokens.moc"
