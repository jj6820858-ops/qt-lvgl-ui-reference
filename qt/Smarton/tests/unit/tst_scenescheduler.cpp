#include <smarton/services/HomeService.h>
#include <smarton/services/SceneScheduler.h>

#include <QtCore/QJsonObject>
#include <QtCore/QTemporaryFile>
#include <QtTest/QSignalSpy>
#include <QtTest/QtTest>

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
  "rooms":   [ { "id": "room-a", "name": "Living Room" },
               { "id": "room-b", "name": "Bedroom" } ],
  "devices": [ { "id": "dev-a", "roomId": "room-a", "name": "Lamp A", "on": false },
               { "id": "dev-b", "roomId": "room-a", "name": "Lamp B", "on": false },
               { "id": "dev-c", "roomId": "room-b", "name": "Lamp C", "on": false } ],
  "scenes":  [ { "id": "s-evening", "roomId": "room-a", "name": "Evening",
                 "days": "Everyday", "timeRange": "08:00 PM - 10:00 PM",
                 "enabled": true },
               { "id": "s-night", "roomId": "room-b", "name": "Sleeping",
                 "days": "Everyday", "timeRange": "10:00 PM - 06:00 AM",
                 "enabled": true },
               { "id": "s-weekday", "roomId": "room-a", "name": "Commute",
                 "days": "Mon, Fri", "timeRange": "07:00 AM - 08:00 AM",
                 "enabled": true },
               { "id": "s-off", "roomId": "room-a", "name": "Disabled",
                 "days": "Everyday", "timeRange": "01:00 AM - 02:00 AM",
                 "enabled": false } ],
  "members": []
})";

QDateTime at(int year, int month, int day, int hour, int minute)
{
    return QDateTime(QDate(year, month, day), QTime(hour, minute));
}

} // namespace

class TestSceneScheduler : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void init();

    void parsesTimeRanges_data();
    void parsesTimeRanges();
    void matchesDays_data();
    void matchesDays();

    void activatesOnEnteringTheWindow();
    void deactivatesOnLeavingTheWindow();
    void doesNotReassertWhileInsideTheWindow();
    void handlesWindowsThatWrapMidnight();
    void ignoresDisabledScenes();
    void respectsDayOfWeek();
    void appliesAnAlreadyOpenWindowOnStart();
    void onlyDrivesTheScenesOwnRoom();
    void drivesNamedDevicesWithTheirOwnSettings();
    void aSceneWithNoActionsStillTakesItsRoom();

private:
    QString m_seedPath;
    FakeStore m_store;
};

void TestSceneScheduler::initTestCase()
{
    auto *seed = new QTemporaryFile(this);
    QVERIFY(seed->open());
    seed->write(kSeed);
    seed->flush();
    m_seedPath = seed->fileName();
}

void TestSceneScheduler::init()
{
    m_store.model = QJsonObject {};
}

void TestSceneScheduler::parsesTimeRanges_data()
{
    QTest::addColumn<QString>("range");
    QTest::addColumn<bool>("valid");
    QTest::addColumn<QTime>("from");
    QTest::addColumn<QTime>("to");

    QTest::newRow("am/pm")   << "08:15 AM - 09:00 AM" << true  << QTime(8, 15)  << QTime(9, 0);
    QTest::newRow("pm")      << "08:00 PM - 10:00 PM" << true  << QTime(20, 0)  << QTime(22, 0);
    QTest::newRow("no pad")  << "8:05 AM - 9:05 AM"   << true  << QTime(8, 5)   << QTime(9, 5);
    QTest::newRow("24h")     << "18:30 - 20:45"       << true  << QTime(18, 30) << QTime(20, 45);
    QTest::newRow("garbage") << "whenever"            << false << QTime()       << QTime();
    QTest::newRow("one end") << "08:00 AM"            << false << QTime()       << QTime();
}

void TestSceneScheduler::parsesTimeRanges()
{
    QFETCH(QString, range);
    QFETCH(bool, valid);
    QFETCH(QTime, from);
    QFETCH(QTime, to);

    QTime parsedFrom;
    QTime parsedTo;
    QCOMPARE(services::SceneScheduler::parseRange(range, parsedFrom, parsedTo), valid);
    if (valid) {
        QCOMPARE(parsedFrom, from);
        QCOMPARE(parsedTo, to);
    }
}

void TestSceneScheduler::matchesDays_data()
{
    QTest::addColumn<QString>("days");
    QTest::addColumn<QDate>("date");
    QTest::addColumn<bool>("matches");

    const QDate monday(2026, 8, 31);
    const QDate saturday(2026, 9, 5);

    QTest::newRow("everyday/mon")  << "Everyday"  << monday   << true;
    QTest::newRow("everyday/sat")  << "Everyday"  << saturday << true;
    QTest::newRow("weekdays/mon")  << "Week days" << monday   << true;
    QTest::newRow("weekdays/sat")  << "Week days" << saturday << false;
    QTest::newRow("list hit")      << "Mon, Fri"  << monday   << true;
    QTest::newRow("list miss")     << "Mon, Fri"  << saturday << false;
    QTest::newRow("empty is all")  << ""          << saturday << true;
}

void TestSceneScheduler::matchesDays()
{
    QFETCH(QString, days);
    QFETCH(QDate, date);
    QFETCH(bool, matches);
    QCOMPARE(services::SceneScheduler::matchesDay(days, date), matches);
}

void TestSceneScheduler::activatesOnEnteringTheWindow()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    services::SceneScheduler scheduler(home);
    QDateTime now = at(2026, 8, 31, 19, 0);        // before the window
    scheduler.setClock([&now] { return now; });
    QSignalSpy spy(&scheduler, &services::SceneScheduler::sceneActivated);

    scheduler.evaluate();
    QCOMPARE(spy.count(), 0);
    QCOMPARE(home.devices().at(0).on, false);

    now = at(2026, 8, 31, 20, 30);                 // inside it
    scheduler.evaluate();

    QCOMPARE(spy.count(), 1);
    QCOMPARE(spy.first().first().toString(), QStringLiteral("s-evening"));
    QCOMPARE(home.devices().at(0).on, true);
    QCOMPARE(home.devices().at(1).on, true);
}

void TestSceneScheduler::deactivatesOnLeavingTheWindow()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    services::SceneScheduler scheduler(home);
    QDateTime now = at(2026, 8, 31, 20, 30);
    scheduler.setClock([&now] { return now; });
    scheduler.evaluate();
    QCOMPARE(home.devices().at(0).on, true);

    QSignalSpy spy(&scheduler, &services::SceneScheduler::sceneDeactivated);
    now = at(2026, 8, 31, 22, 30);
    scheduler.evaluate();

    QCOMPARE(spy.count(), 1);
    QCOMPARE(home.devices().at(0).on, false);
}

void TestSceneScheduler::doesNotReassertWhileInsideTheWindow()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    services::SceneScheduler scheduler(home);
    QDateTime now = at(2026, 8, 31, 20, 30);
    scheduler.setClock([&now] { return now; });
    scheduler.evaluate();
    QCOMPARE(home.devices().at(0).on, true);

    // The user turns a light off by hand, mid-scene.
    QVERIFY(home.setDevicePower(QStringLiteral("dev-a"), false));

    now = at(2026, 8, 31, 20, 45);
    scheduler.evaluate();

    // It must STAY off. Re-asserting every tick is what makes a house feel
    // like it is fighting the person in it.
    QCOMPARE(home.devices().at(0).on, false);
}

void TestSceneScheduler::handlesWindowsThatWrapMidnight()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    services::SceneScheduler scheduler(home);
    QDateTime now = at(2026, 8, 31, 23, 30);       // after 10 PM
    scheduler.setClock([&now] { return now; });
    scheduler.evaluate();
    QCOMPARE(home.devices().at(2).on, true);       // room-b's lamp

    now = at(2026, 9, 1, 3, 0);                    // still inside, next day
    scheduler.evaluate();
    QCOMPARE(home.devices().at(2).on, true);

    now = at(2026, 9, 1, 7, 0);                    // past 6 AM
    scheduler.evaluate();
    QCOMPARE(home.devices().at(2).on, false);
}

void TestSceneScheduler::ignoresDisabledScenes()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    services::SceneScheduler scheduler(home);
    QDateTime now = at(2026, 8, 31, 1, 30);        // inside s-off's window
    scheduler.setClock([&now] { return now; });
    QSignalSpy spy(&scheduler, &services::SceneScheduler::sceneActivated);

    scheduler.evaluate();
    QCOMPARE(spy.count(), 0);
    QCOMPARE(home.devices().at(0).on, false);
}

void TestSceneScheduler::respectsDayOfWeek()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    services::SceneScheduler scheduler(home);
    QDateTime now = at(2026, 9, 5, 7, 30);         // Saturday, inside 7-8 AM
    scheduler.setClock([&now] { return now; });
    scheduler.evaluate();
    QCOMPARE(home.devices().at(0).on, false);

    now = at(2026, 8, 31, 7, 30);                  // Monday, same time
    scheduler.evaluate();
    QCOMPARE(home.devices().at(0).on, true);
}

void TestSceneScheduler::appliesAnAlreadyOpenWindowOnStart()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    services::SceneScheduler scheduler(home);
    QDateTime now = at(2026, 8, 31, 20, 30);
    scheduler.setClock([&now] { return now; });

    // The panel booted mid-scene. The house should already look the way the
    // scene says, not wait until tomorrow.
    scheduler.start();
    QVERIFY(scheduler.isRunning());
    QCOMPARE(home.devices().at(0).on, true);
    scheduler.stop();
}

void TestSceneScheduler::onlyDrivesTheScenesOwnRoom()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    services::SceneScheduler scheduler(home);
    QDateTime now = at(2026, 8, 31, 20, 30);       // s-evening, room-a only
    scheduler.setClock([&now] { return now; });
    scheduler.evaluate();

    QCOMPARE(home.devices().at(0).on, true);       // room-a
    QCOMPARE(home.devices().at(1).on, true);       // room-a
    QCOMPARE(home.devices().at(2).on, false);      // room-b, untouched
}

void TestSceneScheduler::drivesNamedDevicesWithTheirOwnSettings()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    // dev-b gains a dimmer and dev-c a thermostat, so the scene has something
    // to set beyond power. Done through the service rather than the seed
    // because the seed is shared with eight other tests that count on it.
    QVERIFY(home.setDeviceLevel(QStringLiteral("dev-b"), 90));
    QCOMPARE(home.devices().at(1).levelPercent, -1);   // no dimmer: refused

    // A scene that names ONE device in a room of two, and dims it.
    QList<domain::SceneAction> actions;
    domain::SceneAction dim;
    dim.deviceId = QStringLiteral("dev-a");
    dim.on = true;
    dim.levelPercent = 25;
    actions.append(dim);
    QVERIFY(home.setSceneActions(QStringLiteral("s-evening"), actions));

    services::SceneScheduler scheduler(home);
    QDateTime now = at(2026, 8, 31, 20, 30);           // inside s-evening
    scheduler.setClock([&now] { return now; });
    scheduler.evaluate();

    QCOMPARE(home.devices().at(0).on, true);           // named
    QCOMPARE(home.devices().at(1).on, false);          // same room, NOT named
    QCOMPARE(home.devices().at(2).on, false);          // other room

    // Leaving the window switches the named device off and leaves the level
    // where the scene put it: nothing recorded what it was before, so there
    // is nothing honest to restore.
    now = at(2026, 8, 31, 22, 30);
    scheduler.evaluate();
    QCOMPARE(home.devices().at(0).on, false);
}

void TestSceneScheduler::aSceneWithNoActionsStillTakesItsRoom()
{
    // The migration, as a test. A snapshot written before scenes could name
    // devices has no `actions` key; it must keep doing exactly what it did.
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));
    QVERIFY(home.scenes().first().actions.isEmpty());
    QVERIFY(!home.scenes().first().isPerDevice());

    services::SceneScheduler scheduler(home);
    QDateTime now = at(2026, 8, 31, 20, 30);
    scheduler.setClock([&now] { return now; });
    scheduler.evaluate();

    QCOMPARE(home.devices().at(0).on, true);
    QCOMPARE(home.devices().at(1).on, true);
    QCOMPARE(home.devices().at(2).on, false);

    // And an emptied action list puts it back to the room, rather than
    // leaving a scene that names nothing and therefore does nothing.
    QVERIFY(home.setSceneActions(QStringLiteral("s-evening"),
                                 QList<domain::SceneAction>()));
    QVERIFY(!home.scenes().first().isPerDevice());
}

QTEST_GUILESS_MAIN(TestSceneScheduler)
#include "tst_scenescheduler.moc"
