#include <QtTest>

#include <smarton/infrastructure/auth/Pbkdf2PasswordHasher.h>

using namespace smarton;
using domain::PasswordHash;
using infrastructure::Pbkdf2PasswordHasher;

class TestPasswordHashing : public QObject
{
    Q_OBJECT

    // A low iteration count keeps the suite fast. Production cost is asserted
    // separately in policyUsesOwaspIterationCount().
    Pbkdf2PasswordHasher m_fast{1000};

private slots:
    void roundTripsThroughStorageFormat();
    void rejectsMalformedStorage_data();
    void rejectsMalformedStorage();

    void acceptsCorrectPassword();
    void rejectsWrongPassword();
    void rejectsEmptyAndNearMissPasswords_data();
    void rejectsEmptyAndNearMissPasswords();

    void saltIsUniquePerHash();
    void neverStoresThePlaintext();

    void needsRehashWhenIterationsAreRaised();
    void verifiesWithTheStoredParametersNotCurrentPolicy();

    void policyUsesOwaspIterationCount();
};

void TestPasswordHashing::roundTripsThroughStorageFormat()
{
    const PasswordHash original = m_fast.hash(QStringLiteral("correct horse"));
    const PasswordHash parsed   = PasswordHash::fromStorage(original.toStorage());

    QVERIFY(parsed.isValid());
    QCOMPARE(parsed.algorithm(),  original.algorithm());
    QCOMPARE(parsed.iterations(), original.iterations());
    QCOMPARE(parsed.salt(),       original.salt());
    QCOMPARE(parsed.derivedKey(), original.derivedKey());
}

void TestPasswordHashing::rejectsMalformedStorage_data()
{
    QTest::addColumn<QString>("encoded");
    QTest::newRow("empty")          << QString();
    QTest::newRow("too few fields") << QStringLiteral("pbkdf2-sha512$1000$abc");
    QTest::newRow("zero iterations")<< QStringLiteral("pbkdf2-sha512$0$YWJj$ZGVm");
    QTest::newRow("bad iterations") << QStringLiteral("pbkdf2-sha512$xx$YWJj$ZGVm");
    QTest::newRow("empty salt")     << QStringLiteral("pbkdf2-sha512$1000$$ZGVm");
}

void TestPasswordHashing::rejectsMalformedStorage()
{
    QFETCH(QString, encoded);
    QVERIFY(!PasswordHash::fromStorage(encoded).isValid());
}

void TestPasswordHashing::acceptsCorrectPassword()
{
    const PasswordHash h = m_fast.hash(QStringLiteral("s3cret-pass"));
    QVERIFY(m_fast.verify(QStringLiteral("s3cret-pass"), h));
}

void TestPasswordHashing::rejectsWrongPassword()
{
    const PasswordHash h = m_fast.hash(QStringLiteral("s3cret-pass"));
    QVERIFY(!m_fast.verify(QStringLiteral("s3cret-pasS"), h));
}

void TestPasswordHashing::rejectsEmptyAndNearMissPasswords_data()
{
    QTest::addColumn<QString>("candidate");
    QTest::newRow("empty")           << QString();
    QTest::newRow("prefix")          << QStringLiteral("s3cret-pas");
    QTest::newRow("suffix added")    << QStringLiteral("s3cret-passX");
    QTest::newRow("case flipped")    << QStringLiteral("S3CRET-PASS");
    QTest::newRow("trailing space")  << QStringLiteral("s3cret-pass ");
}

void TestPasswordHashing::rejectsEmptyAndNearMissPasswords()
{
    QFETCH(QString, candidate);
    const PasswordHash h = m_fast.hash(QStringLiteral("s3cret-pass"));
    QVERIFY(!m_fast.verify(candidate, h));
}

void TestPasswordHashing::saltIsUniquePerHash()
{
    // Same password, two hashes: the salts and therefore the derived keys must
    // differ, or identical passwords would be visibly identical in the table.
    const PasswordHash a = m_fast.hash(QStringLiteral("same-password"));
    const PasswordHash b = m_fast.hash(QStringLiteral("same-password"));

    QVERIFY(a.salt() != b.salt());
    QVERIFY(a.derivedKey() != b.derivedKey());
    QVERIFY(m_fast.verify(QStringLiteral("same-password"), a));
    QVERIFY(m_fast.verify(QStringLiteral("same-password"), b));
}

void TestPasswordHashing::neverStoresThePlaintext()
{
    // The regression test for the whole point of this class.
    const QString password = QStringLiteral("unmistakable-plaintext-marker");
    const QString stored   = m_fast.hash(password).toStorage();

    QVERIFY2(!stored.contains(password),
             "the stored verifier must never contain the password");
    QVERIFY(!stored.toUtf8().toBase64().contains(password.toUtf8()));
}

void TestPasswordHashing::needsRehashWhenIterationsAreRaised()
{
    const Pbkdf2PasswordHasher weak{1000};
    const Pbkdf2PasswordHasher strong{5000};

    const PasswordHash old = weak.hash(QStringLiteral("pw"));
    QVERIFY(!weak.needsRehash(old));
    QVERIFY(strong.needsRehash(old));
}

void TestPasswordHashing::verifiesWithTheStoredParametersNotCurrentPolicy()
{
    // Raising the cost must not invalidate existing passwords.
    const Pbkdf2PasswordHasher weak{1000};
    const Pbkdf2PasswordHasher strong{5000};

    const PasswordHash old = weak.hash(QStringLiteral("pw"));
    QVERIFY(strong.verify(QStringLiteral("pw"), old));
}

void TestPasswordHashing::policyUsesOwaspIterationCount()
{
    QCOMPARE(Pbkdf2PasswordHasher::kIterations, 210000);
    QVERIFY(Pbkdf2PasswordHasher::kSaltBytes >= 16);
    QVERIFY(Pbkdf2PasswordHasher::kKeyBytes  >= 32);
}

QTEST_MAIN(TestPasswordHashing)
#include "tst_passwordhashing.moc"
