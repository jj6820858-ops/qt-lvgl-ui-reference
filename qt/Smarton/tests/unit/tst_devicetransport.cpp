#include <smarton/infrastructure/transport/LoopbackDeviceTransport.h>
#include <smarton/services/HomeService.h>

#include <QtCore/QJsonObject>
#include <QtCore/QTemporaryFile>
#include <QtTest/QSignalSpy>
#include <QtTest/QtTest>

#include <memory>

using namespace smarton;

namespace {

class FakeStore final : public services::IHomeStore
{
public:
    QJsonObject model;
    QJsonObject load() override { return model; }
    bool save(const QJsonObject &next) override { model = next; return true; }
};

constexpr auto kSeed = R"({
  "space":   { "id": "space-1", "name": "Home" },
  "weather": { "description": "Clear", "temperatureC": 20, "humidityPercent": 50 },
  "rooms":   [ { "id": "room-a", "name": "Living Room" } ],
  "devices": [ { "id": "dev-a", "roomId": "room-a", "name": "Lamp", "on": false } ],
  "scenes":  [],
  "members": []
})";

} // namespace

class TestDeviceTransport : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void init();

    void withoutATransportIntentIsStateImmediately();
    void withATransportTheDeviceStaysPendingUntilItReports();
    void aReportClearsPending();
    void aFailedCommandRollsBackIntent();
    void aFailedCommandMarksTheDeviceOffline();
    void anExternalReportOverridesIntent();
    void failureIsDeterministicForAGivenSeed();

private:
    [[nodiscard]] std::unique_ptr<services::HomeService> loadedHome();

    QString m_seedPath;
    FakeStore m_store;
};

void TestDeviceTransport::initTestCase()
{
    auto *seed = new QTemporaryFile(this);
    QVERIFY(seed->open());
    seed->write(kSeed);
    seed->flush();
    m_seedPath = seed->fileName();
}

void TestDeviceTransport::init()
{
    m_store.model = QJsonObject {};
}

std::unique_ptr<services::HomeService> TestDeviceTransport::loadedHome()
{
    auto home = std::make_unique<services::HomeService>();
    home->setStore(&m_store);
    home->load(m_seedPath);
    return home;
}

void TestDeviceTransport::withoutATransportIntentIsStateImmediately()
{
    auto home = loadedHome();

    QVERIFY(home->setDevicePower(QStringLiteral("dev-a"), true));

    // Nothing is being controlled, so there is nothing to wait for. Adding an
    // artificial delay to a simulation would only make it feel broken.
    QCOMPARE(home->devices().first().on, true);
    QVERIFY(!home->devices().first().pending());
}

void TestDeviceTransport::withATransportTheDeviceStaysPendingUntilItReports()
{
    auto home = loadedHome();
    infrastructure::LoopbackDeviceTransport transport;
    transport.setLatencyMs(80);
    transport.primeState(QStringLiteral("dev-a"), false);
    home->setTransport(&transport);

    QVERIFY(home->setDevicePower(QStringLiteral("dev-a"), true));

    // THE POINT OF THE WHOLE DESIGN: the reported state has not moved, so the
    // switch has not moved. A UI that flipped here would be claiming a lamp is
    // on before anything asked it to be.
    QCOMPARE(home->devices().first().on, false);
    QCOMPARE(home->devices().first().desiredOn, true);
    QVERIFY(home->devices().first().pending());
}

void TestDeviceTransport::aReportClearsPending()
{
    auto home = loadedHome();
    infrastructure::LoopbackDeviceTransport transport;
    transport.setLatencyMs(40);
    transport.primeState(QStringLiteral("dev-a"), false);
    home->setTransport(&transport);

    QSignalSpy spy(home.get(), &services::HomeService::devicePowerChanged);
    QVERIFY(home->setDevicePower(QStringLiteral("dev-a"), true));
    QVERIFY(spy.wait(2000));

    QCOMPARE(home->devices().first().on, true);
    QVERIFY(!home->devices().first().pending());
}

void TestDeviceTransport::aFailedCommandRollsBackIntent()
{
    auto home = loadedHome();
    infrastructure::LoopbackDeviceTransport transport;
    transport.setLatencyMs(40);
    transport.setFailureRate(1.0);            // drop everything
    home->setTransport(&transport);

    QSignalSpy spy(home.get(), &services::HomeService::deviceCommandFailed);
    QVERIFY(home->setDevicePower(QStringLiteral("dev-a"), true));
    QVERIFY(home->devices().first().pending());

    QVERIFY(spy.wait(2000));

    // Intent returns to reality. Left pending forever the switch would sit
    // half-way with no way for the user to retry.
    QCOMPARE(home->devices().first().on, false);
    QCOMPARE(home->devices().first().desiredOn, false);
    QVERIFY(!home->devices().first().pending());
}

void TestDeviceTransport::aFailedCommandMarksTheDeviceOffline()
{
    auto home = loadedHome();
    infrastructure::LoopbackDeviceTransport transport;
    transport.setLatencyMs(40);
    transport.setFailureRate(1.0);
    home->setTransport(&transport);

    QSignalSpy spy(home.get(), &services::HomeService::deviceCommandFailed);
    QVERIFY(home->setDevicePower(QStringLiteral("dev-a"), true));
    QVERIFY(spy.wait(2000));

    QCOMPARE(home->devices().first().reachability, domain::Reachability::Offline);
}

void TestDeviceTransport::anExternalReportOverridesIntent()
{
    auto home = loadedHome();
    infrastructure::LoopbackDeviceTransport transport;
    transport.setLatencyMs(30);
    transport.primeState(QStringLiteral("dev-a"), true);   // switched at the wall
    home->setTransport(&transport);

    QSignalSpy spy(home.get(), &services::HomeService::devicePowerChanged);
    transport.refresh();
    QVERIFY(spy.wait(2000));

    // The device is the authority. The panel's idea of what was last asked for
    // is stale, not authoritative.
    QCOMPARE(home->devices().first().on, true);
    QCOMPARE(home->devices().first().desiredOn, true);
    QVERIFY(!home->devices().first().pending());
}

void TestDeviceTransport::failureIsDeterministicForAGivenSeed()
{
    const auto sequence = [](quint32 seed) {
        infrastructure::LoopbackDeviceTransport transport;
        transport.setLatencyMs(0);
        transport.setFailureRate(0.5);
        transport.setSeed(seed);

        QSignalSpy failures(&transport, &services::IDeviceTransport::commandFailed);
        for (int i = 0; i < 20; ++i)
            transport.requestPower(QStringLiteral("dev-a"), i % 2 == 0);
        QTest::qWait(50);
        return failures.count();
    };

    // A transport that is flaky differently on every run turns any failing
    // test that uses it into a coin toss.
    QCOMPARE(sequence(42), sequence(42));
}

QTEST_GUILESS_MAIN(TestDeviceTransport)
#include "tst_devicetransport.moc"
