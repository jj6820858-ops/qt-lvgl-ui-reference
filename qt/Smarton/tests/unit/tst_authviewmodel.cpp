#include <smarton/models/AuthViewModel.h>

#include <QtTest/QtTest>

using namespace smarton;

/*!
    The password policy has two implementations - this one and the predicates
    in StPasswordRules.qml - because one of them has to run without a QML
    engine and the other has to run without C++. The cases here are the same
    cases as tst_passwordrules.qml, on purpose: if the two ever drift, one of
    these two files fails.
*/
class TestAuthViewModel : public QObject
{
    Q_OBJECT

private slots:
    void passwordPolicy_data();
    void passwordPolicy();

    void rejectsEmptyCredentialsWithoutAService();
    void clearErrorEmptiesTheMessage();
    void startsSignedOut();
};

void TestAuthViewModel::passwordPolicy_data()
{
    QTest::addColumn<QString>("password");
    QTest::addColumn<bool>("acceptable");

    QTest::newRow("empty")            << QString()                       << false;
    QTest::newRow("too short")        << QStringLiteral("Aa1!")          << false;
    QTest::newRow("no uppercase")     << QStringLiteral("abcdefg1")      << false;
    QTest::newRow("no lowercase")     << QStringLiteral("ABCDEFG1")      << false;
    QTest::newRow("no number/symbol") << QStringLiteral("abcdefgH")      << false;
    QTest::newRow("digit")            << QStringLiteral("abcdefgH1")     << true;
    QTest::newRow("symbol")           << QStringLiteral("abcdefgH!")     << true;
    QTest::newRow("long")             << QStringLiteral("Correct-Horse1") << true;
}

void TestAuthViewModel::passwordPolicy()
{
    QFETCH(QString, password);
    QFETCH(bool, acceptable);
    QCOMPARE(models::AuthViewModel::isAcceptablePassword(password), acceptable);
}

void TestAuthViewModel::rejectsEmptyCredentialsWithoutAService()
{
    models::AuthViewModel viewModel;

    viewModel.signIn(QString(), QString());

    // Fails locally, without touching the service, and without leaving the
    // form stuck in a busy state.
    QVERIFY(!viewModel.errorText().isEmpty());
    QVERIFY(!viewModel.isBusy());
}

void TestAuthViewModel::clearErrorEmptiesTheMessage()
{
    models::AuthViewModel viewModel;
    viewModel.signIn(QString(), QString());
    QVERIFY(!viewModel.errorText().isEmpty());

    QSignalSpy spy(&viewModel, &models::AuthViewModel::errorTextChanged);
    viewModel.clearError();

    QVERIFY(viewModel.errorText().isEmpty());
    QCOMPARE(spy.count(), 1);
}

void TestAuthViewModel::startsSignedOut()
{
    const models::AuthViewModel viewModel;
    QVERIFY(!viewModel.isSignedIn());
    QVERIFY(viewModel.currentUserName().isEmpty());
    QVERIFY(viewModel.errorText().isEmpty());
}

QTEST_GUILESS_MAIN(TestAuthViewModel)
#include "tst_authviewmodel.moc"
