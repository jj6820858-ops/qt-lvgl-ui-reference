#include <smarton/services/HomeService.h>

#include <QtCore/QFile>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QTemporaryDir>
#include <QtCore/QTemporaryFile>
#include <QtTest/QSignalSpy>
#include <QtTest/QtTest>

using namespace smarton;

namespace {

/*! In-memory store, so these tests exercise the RULES with no database. */
class FakeStore final : public services::IHomeStore
{
public:
    QJsonObject model;
    int saveCalls = 0;
    bool saveSucceeds = true;

    QJsonObject load() override { return model; }

    bool save(const QJsonObject &next) override
    {
        ++saveCalls;
        if (!saveSucceeds)
            return false;
        model = next;
        return true;
    }
};

/*! A second seed, for the capability tests only.

    The shared kSeed is asserted on by count in half the tests in this file, so
    the device that has a volume and the device that has a level are added here
    rather than there: a fixture edited to suit one test is how the other
    fifteen start failing for reasons that have nothing to do with them. */
constexpr auto kCapabilitySeed = R"({
  "space":   { "id": "space-1", "name": "My Home", "address": "Somewhere" },
  "rooms":   [ { "id": "room-a", "name": "Living Room", "areaSqm": 20 } ],
  "devices": [ { "id": "dev-lamp", "roomId": "room-a", "name": "Smart Lamp",
                 "kind": "lamp", "on": true, "levelPercent": 80 },
               { "id": "dev-speaker", "roomId": "room-a", "name": "Speaker",
                 "kind": "speaker", "on": true, "volumePercent": 70 } ]
})";

constexpr auto kSeed = R"({
  "space":   { "id": "space-1", "name": "My Home", "address": "Somewhere",
               "image": "images/rooms/house-exterior.png" },
  "weather": { "description": "Partly Cloudy", "temperatureC": 23,
               "humidityPercent": 67 },
  "rooms":   [ { "id": "room-a", "name": "Living Room", "areaSqm": 20,
                 "image": "images/rooms/living-sofa.png" } ],
  "devices": [ { "id": "dev-a", "roomId": "room-a", "name": "Smart Lamp",
                 "kind": "lamp", "image": "x.png", "on": true } ],
  "availableDevices": [ { "id": "avail-a", "roomId": "", "name": "Speaker",
                          "kind": "speaker", "image": "y.png", "on": false } ],
  "scenes":  [ { "id": "scene-a", "roomId": "room-a", "name": "Movie Night",
                 "days": "Mon, Fri", "timeRange": "8-10", "enabled": false } ],
  "members": [ { "id": "mem-a", "name": "Dina", "email": "d@example.com" } ]
})";

} // namespace

class TestHomeService : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void init();

    void loadsTheSeedWhenTheStoreIsEmpty();
    void prefersTheStoredModelOverTheSeed();
    void survivesACorruptStoredModel();
    void persistsEveryMutation();
    void roundTripsThroughTheStore();

    void togglesDevicePower();
    void clampsPercentSettingsAndRefusesAbsentOnes();
    void enforcesRoles();
    void roundTripsABackup();
    void readsTheSingleSpaceShapeAsOneSpace();
    void addsSwitchesAndRemovesSpaces();
    void refusesABackupItCannotRead();
    void renameTrimsAndRejectsEmpty();
    void renameCapsTheLength();

    void addsAndRemovesRooms();
    void removingARoomReturnsItsDevicesToThePool();
    void removingARoomDropsItsScenes();
    void linksAndUnlinksDevices();
    void replacementPreservesHouseholdConfiguration();
    void clampsRoomArea();
    void addsScenesAndMembers();

private:
    QString m_seedPath;
    FakeStore m_store;
};

void TestHomeService::initTestCase()
{
    // A real file, because load() takes a path - the same path the app passes
    // a qrc URL. Writing it once keeps every test reading identical defaults.
    auto *seed = new QTemporaryFile(this);
    QVERIFY(seed->open());
    seed->write(kSeed);
    seed->flush();
    m_seedPath = seed->fileName();
}

void TestHomeService::init()
{
    m_store.model = QJsonObject {};
    m_store.saveCalls = 0;
    m_store.saveSucceeds = true;
}

void TestHomeService::loadsTheSeedWhenTheStoreIsEmpty()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QSignalSpy spy(&home, &services::HomeService::reloaded);

    QVERIFY(home.load(m_seedPath));

    QCOMPARE(home.space().name, QStringLiteral("My Home"));
    QCOMPARE(home.rooms().size(), 1);
    QCOMPARE(home.devices().size(), 1);
    QCOMPARE(home.availableDevices().size(), 1);
    QCOMPARE(spy.count(), 1);
    // The defaults are written back, so the next run reads the store.
    QVERIFY(m_store.saveCalls > 0);
}

void TestHomeService::prefersTheStoredModelOverTheSeed()
{
    services::HomeService first;
    first.setActor(domain::Role::Administrator);
    first.setStore(&m_store);
    QVERIFY(first.load(m_seedPath));
    QVERIFY(first.renameSpace(QStringLiteral("Beach House")));

    services::HomeService second;
    second.setActor(domain::Role::Administrator);
    second.setStore(&m_store);
    QVERIFY(second.load(m_seedPath));

    // The seed must not overwrite what the user did.
    QCOMPARE(second.space().name, QStringLiteral("Beach House"));
}

void TestHomeService::survivesACorruptStoredModel()
{
    // An empty object is what SqliteHomeStore returns for unparseable JSON.
    m_store.model = QJsonObject {};

    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);

    // Falls back to defaults rather than starting up with no model at all.
    QVERIFY(home.load(m_seedPath));
    QCOMPARE(home.rooms().size(), 1);
}

void TestHomeService::persistsEveryMutation()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    const int afterLoad = m_store.saveCalls;
    QVERIFY(home.setDevicePower(QStringLiteral("dev-a"), false));

    // There is no Save button in the design and no session to lose work from,
    // so a mutation that did not reach the store would just be a window in
    // which pulling the plug loses the user's change.
    QCOMPARE(m_store.saveCalls, afterLoad + 1);
}

void TestHomeService::roundTripsThroughTheStore()
{
    services::HomeService first;
    first.setActor(domain::Role::Administrator);
    first.setStore(&m_store);
    QVERIFY(first.load(m_seedPath));
    const QString roomId = first.addRoom(QStringLiteral("Study"), 14,
                                         QStringLiteral("images/rooms/lounge-framed.png"));
    QVERIFY(!roomId.isEmpty());
    QVERIFY(first.linkDevice(QStringLiteral("avail-a"), roomId));

    services::HomeService second;
    second.setActor(domain::Role::Administrator);
    second.setStore(&m_store);
    QVERIFY(second.load(m_seedPath));

    QCOMPARE(second.rooms().size(), 2);
    QCOMPARE(second.devices().size(), 2);
    QCOMPARE(second.availableDevices().size(), 0);
    QCOMPARE(second.roomName(roomId), QStringLiteral("Study"));
}

void TestHomeService::togglesDevicePower()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));
    QSignalSpy spy(&home, &services::HomeService::devicePowerChanged);

    QVERIFY(home.setDevicePower(QStringLiteral("dev-a"), false));
    QCOMPARE(spy.count(), 1);
    QCOMPARE(home.devices().first().on, false);

    // Setting the same value must not emit: a no-op change that still
    // notifies makes every listener rebuild for nothing.
    QVERIFY(home.setDevicePower(QStringLiteral("dev-a"), false));
    QCOMPARE(spy.count(), 1);

    QVERIFY(!home.setDevicePower(QStringLiteral("no-such-device"), true));
}

void TestHomeService::clampsPercentSettingsAndRefusesAbsentOnes()
{
    QTemporaryFile seed;
    QVERIFY(seed.open());
    seed.write(kCapabilitySeed);
    seed.flush();

    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(seed.fileName()));
    QCOMPARE(home.devices().size(), 2);

    // Clamped, not refused: a percentage out of range is a slider dragged past
    // its own end, and refusing that would make the last pixel of travel do
    // nothing. Contrast setDeviceTarget(), which refuses - out of range there
    // means a caller with a bug, not a finger at the end of a track.
    QVERIFY(home.setDeviceLevel(QStringLiteral("dev-lamp"), 140));
    QCOMPARE(home.devices().at(0).levelPercent, 100);
    QVERIFY(home.setDeviceLevel(QStringLiteral("dev-lamp"), -5));
    QCOMPARE(home.devices().at(0).levelPercent, 0);

    QVERIFY(home.setDeviceVolume(QStringLiteral("dev-speaker"), 35));
    QCOMPARE(home.devices().at(1).volumePercent, 35);

    // A device without the capability is refused rather than given one: -1
    // means "this hardware has no such control", and writing 40 into it would
    // invent a dimmer that the UI would then draw.
    QVERIFY(!home.setDeviceVolume(QStringLiteral("dev-lamp"), 40));
    QCOMPARE(home.devices().at(0).volumePercent, -1);
    QVERIFY(!home.setDeviceLevel(QStringLiteral("dev-speaker"), 40));
    QCOMPARE(home.devices().at(1).levelPercent, -1);

    QVERIFY(!home.setDeviceLevel(QStringLiteral("no-such-device"), 50));

    // Both survive the store, which is the point of putting them in the
    // snapshot rather than holding them in memory.
    services::HomeService reopened;
    reopened.setActor(domain::Role::Administrator);
    reopened.setStore(&m_store);
    QVERIFY(reopened.load(seed.fileName()));
    QCOMPARE(reopened.devices().at(0).levelPercent, 0);
    QCOMPARE(reopened.devices().at(1).volumePercent, 35);
}

void TestHomeService::enforcesRoles()
{
    services::HomeService home;
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));
    QSignalSpy refusals(&home, &services::HomeService::refusedByRole);

    // The default. A service nobody has told about a session refuses
    // everything, which is why the composition root has to say who is there.
    QCOMPARE(home.actor(), domain::Role::Viewer);
    QVERIFY(!home.mayOperate());
    QVERIFY(!home.mayInstall());
    QVERIFY(!home.mayAdminister());

    QVERIFY(!home.setDevicePower(QStringLiteral("dev-a"), false));
    QCOMPARE(home.devices().first().on, true);
    QVERIFY(!home.renameRoom(QStringLiteral("room-a"), QStringLiteral("Den")));
    QCOMPARE(refusals.count(), 2);

    // An Operator runs the house and cannot rearrange it. This is the whole
    // point of having three roles rather than two.
    home.setActor(domain::Role::Operator);
    QVERIFY(home.setDevicePower(QStringLiteral("dev-a"), false));
    QCOMPARE(home.devices().first().on, false);
    QVERIFY(!home.renameRoom(QStringLiteral("room-a"), QStringLiteral("Den")));
    QVERIFY(!home.removeRoom(QStringLiteral("room-a")));
    QCOMPARE(home.rooms().size(), 1);

    // Guests may use the panel but cannot alter the home. Installers can
    // commission hardware without being able to manage household policy.
    home.setActor(domain::Role::Guest);
    QVERIFY(home.mayOperate());
    QVERIFY(!home.mayInstall());
    QVERIFY(!home.mayAdminister());
    home.setActor(domain::Role::Installer);
    QVERIFY(home.mayOperate());
    QVERIFY(home.mayInstall());
    QVERIFY(!home.mayAdminister());

    home.setActor(domain::Role::Administrator);
    QVERIFY(home.renameRoom(QStringLiteral("room-a"), QStringLiteral("Den")));
    QCOMPARE(home.rooms().first().name, QStringLiteral("Den"));

    // The scheduler is not a person. Its scenes fire at six in the morning,
    // when the signed-in role is whatever the last person left behind - or
    // Viewer, because nobody is signed in at all.
    home.setActor(domain::Role::Viewer);
    QVERIFY(home.setDevicePower(QStringLiteral("dev-a"), true,
                                services::HomeService::Actor::System));
    QCOMPARE(home.devices().first().on, true);
}

void TestHomeService::readsTheSingleSpaceShapeAsOneSpace()
{
    // THE MIGRATION, as a test. Every snapshot in the field is the old shape,
    // and the claim is that no conversion pass is needed because that shape
    // IS a single space's model.
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    QCOMPARE(home.spaceCount(), 1);
    QCOMPARE(home.spaces().size(), 1);
    QCOMPARE(home.activeSpaceId(), QStringLiteral("space-1"));
    QCOMPARE(home.space().name, QStringLiteral("My Home"));
    QCOMPARE(home.rooms().size(), 1);

    // And what it writes back has to be something it can read again. Getting
    // this wrong is a bug that only appears on the SECOND run.
    QVERIFY(home.renameSpace(QStringLiteral("Beach House")));
    services::HomeService reopened;
    reopened.setActor(domain::Role::Administrator);
    reopened.setStore(&m_store);
    QVERIFY(reopened.load(m_seedPath));
    QCOMPARE(reopened.spaceCount(), 1);
    QCOMPARE(reopened.space().name, QStringLiteral("Beach House"));
}

void TestHomeService::addsSwitchesAndRemovesSpaces()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    const QString first = home.activeSpaceId();
    QSignalSpy spaces(&home, &services::HomeService::spacesChanged);

    const QString cabin = home.addSpace(QStringLiteral("Cabin"),
                                        QStringLiteral("Somewhere else"));
    QVERIFY(!cabin.isEmpty());
    QCOMPARE(home.spaceCount(), 2);
    QCOMPARE(spaces.count(), 1);

    // A new space is EMPTY, and switching to it took us there.
    QCOMPARE(home.activeSpaceId(), cabin);
    QCOMPARE(home.space().name, QStringLiteral("Cabin"));
    QCOMPARE(home.rooms().size(), 0);
    QCOMPARE(home.devices().size(), 0);

    // Members are the household's, not a building's: they survive the move.
    QCOMPARE(home.members().size(), 1);

    // Back, and the first space still has everything in it. This is the one
    // that breaks if switching forgets to park the live space first.
    QVERIFY(home.addRoom(QStringLiteral("Study"), 12, QString()).isEmpty() == false);
    QVERIFY(home.setActiveSpace(first));
    QCOMPARE(home.rooms().size(), 1);
    QCOMPARE(home.space().name, QStringLiteral("My Home"));

    QVERIFY(home.setActiveSpace(cabin));
    QCOMPARE(home.rooms().size(), 1);
    QCOMPARE(home.rooms().first().name, QStringLiteral("Study"));

    // Switching to where we already are, or to nowhere, is not an event.
    const int before = spaces.count();
    QVERIFY(!home.setActiveSpace(cabin));
    QVERIFY(!home.setActiveSpace(QStringLiteral("no-such-space")));
    QCOMPARE(spaces.count(), before);

    // Removing the active one lands somewhere real rather than nowhere.
    QVERIFY(home.removeSpace(cabin));
    QCOMPARE(home.spaceCount(), 1);
    QCOMPARE(home.activeSpaceId(), first);
    QCOMPARE(home.rooms().size(), 1);
    QCOMPARE(home.rooms().first().name, QStringLiteral("Living Room"));

    // And the last one cannot go: a panel with no space shows the empty
    // state with no way out of it.
    QVERIFY(!home.removeSpace(first));
    QCOMPARE(home.spaceCount(), 1);
}

void TestHomeService::roundTripsABackup()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    const QString backup = dir.filePath(QStringLiteral("house.json"));

    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));
    QVERIFY(home.renameSpace(QStringLiteral("Beach House")));
    QVERIFY(home.exportModel(backup));

    // Somebody else's panel: a different store, the same seed, and then the
    // backup on top of it.
    FakeStore other;
    services::HomeService restored;
    restored.setActor(domain::Role::Administrator);
    restored.setStore(&other);
    QVERIFY(restored.load(m_seedPath));
    QCOMPARE(restored.space().name, QStringLiteral("My Home"));

    QSignalSpy reloads(&restored, &services::HomeService::reloaded);
    QVERIFY(restored.importModel(backup));
    QCOMPARE(restored.space().name, QStringLiteral("Beach House"));
    QCOMPARE(restored.rooms().size(), home.rooms().size());
    QCOMPARE(restored.devices().size(), home.devices().size());
    // The models have to reset: every list on screen is now about a
    // different house, and an incremental update cannot express that.
    QCOMPARE(reloads.count(), 1);
    // And it persisted, rather than living until the next restart.
    QVERIFY(!other.model.isEmpty());
}

void TestHomeService::refusesABackupItCannotRead()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());

    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    const auto write = [&dir](const QString &name, const QByteArray &bytes) {
        const QString path = dir.filePath(name);
        QFile file(path);
        file.open(QIODevice::WriteOnly);
        file.write(bytes);
        file.close();
        return path;
    };

    // Not JSON, JSON that is not a backup, a future format, and a backup
    // whose model is not a model. All four must leave the house alone - a
    // restore that half-succeeds is the failure mode this cannot have.
    const QStringList bad {
        write(QStringLiteral("a.json"), "not json at all"),
        write(QStringLiteral("b.json"), R"({"hello":"world"})"),
        write(QStringLiteral("c.json"), R"({"format":99,"model":{"space":{}}})"),
        write(QStringLiteral("d.json"), R"({"format":1,"model":{"unrelated":1}})"),
        dir.filePath(QStringLiteral("missing.json")),
    };

    for (const QString &path : bad) {
        QVERIFY2(!home.importModel(path), qPrintable(path));
        QCOMPARE(home.space().name, QStringLiteral("My Home"));
        QCOMPARE(home.rooms().size(), 1);
        QVERIFY(!home.lastError().isEmpty());
    }
}

void TestHomeService::renameTrimsAndRejectsEmpty()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    QVERIFY(home.renameRoom(QStringLiteral("room-a"), QStringLiteral("  Den   Room  ")));
    QCOMPARE(home.rooms().first().name, QStringLiteral("Den Room"));

    // Whitespace is not a name, and the UI must not appear to accept one.
    QVERIFY(!home.renameRoom(QStringLiteral("room-a"), QStringLiteral("   ")));
    QCOMPARE(home.rooms().first().name, QStringLiteral("Den Room"));
}

void TestHomeService::renameCapsTheLength()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    QVERIFY(home.renameSpace(QString(200, QLatin1Char('x'))));
    // A name is drawn in a fixed-width tile; unbounded is a layout bug.
    QCOMPARE(home.space().name.size(), 48);
}

void TestHomeService::addsAndRemovesRooms()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    const QString id = home.addRoom(QStringLiteral("Study"), 14, QString());
    QVERIFY(!id.isEmpty());
    QCOMPARE(home.rooms().size(), 2);

    QVERIFY(home.addRoom(QStringLiteral("   "), 10, QString()).isEmpty());
    QCOMPARE(home.rooms().size(), 2);

    QVERIFY(home.removeRoom(id));
    QCOMPARE(home.rooms().size(), 1);
    QVERIFY(!home.removeRoom(QStringLiteral("no-such-room")));
}

void TestHomeService::removingARoomReturnsItsDevicesToThePool()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    QVERIFY(home.removeRoom(QStringLiteral("room-a")));

    // The hardware still exists; only the grouping went away. Deleting the
    // device with the room would leave a real lamp unreachable from the UI.
    QCOMPARE(home.devices().size(), 0);
    QCOMPARE(home.availableDevices().size(), 2);
    QVERIFY(home.availableDevices().last().roomId.isEmpty());
    QCOMPARE(home.availableDevices().last().on, false);
}

void TestHomeService::removingARoomDropsItsScenes()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));
    QCOMPARE(home.scenes().size(), 1);

    QVERIFY(home.removeRoom(QStringLiteral("room-a")));

    // A scene scoped to a room that no longer exists can never run.
    QCOMPARE(home.scenes().size(), 0);
}

void TestHomeService::linksAndUnlinksDevices()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    QVERIFY(home.linkDevice(QStringLiteral("avail-a"), QStringLiteral("room-a")));
    QCOMPARE(home.devices().size(), 2);
    QCOMPARE(home.availableDevices().size(), 0);
    QCOMPARE(home.deviceCountInRoom(QStringLiteral("room-a")), 2);

    QVERIFY(!home.linkDevice(QStringLiteral("avail-a"), QStringLiteral("room-a")));

    QVERIFY(home.unlinkDevice(QStringLiteral("avail-a")));
    QCOMPARE(home.devices().size(), 1);
    QCOMPARE(home.availableDevices().size(), 1);
}

void TestHomeService::replacementPreservesHouseholdConfiguration()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    QList<domain::SceneAction> actions;
    actions.append({ QStringLiteral("dev-a"), true, -1, -1 });
    QVERIFY(home.setSceneActions(QStringLiteral("scene-a"), actions));

    QVERIFY(home.replaceDevice(QStringLiteral("dev-a"), QStringLiteral("avail-a")));
    QCOMPARE(home.devices().size(), 1);
    QCOMPARE(home.availableDevices().size(), 0);
    const domain::Device replacement = home.devices().first();
    QCOMPARE(replacement.id, QStringLiteral("avail-a"));
    QCOMPARE(replacement.name, QStringLiteral("Smart Lamp"));
    QCOMPARE(replacement.roomId, QStringLiteral("room-a"));
    QCOMPARE(home.scenes().first().actions.first().deviceId, QStringLiteral("avail-a"));
}

void TestHomeService::clampsRoomArea()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    const QString tiny = home.addRoom(QStringLiteral("Cupboard"), -5, QString());
    const QString huge = home.addRoom(QStringLiteral("Hangar"), 9000, QString());

    // Clamped, not rejected: a control that snaps back without explanation
    // tells the user nothing.
    QCOMPARE(home.rooms().at(1).areaSqm, 1.0);
    QCOMPARE(home.rooms().at(2).areaSqm, 500.0);
    QVERIFY(!tiny.isEmpty());
    QVERIFY(!huge.isEmpty());
}

void TestHomeService::addsScenesAndMembers()
{
    services::HomeService home;
    home.setActor(domain::Role::Administrator);
    home.setStore(&m_store);
    QVERIFY(home.load(m_seedPath));

    const QString sceneId = home.addScene(QStringLiteral("Wake up"),
                                          QStringLiteral("room-a"),
                                          QStringLiteral("Everyday"),
                                          QStringLiteral("07:00 AM - 07:30 AM"));
    QVERIFY(!sceneId.isEmpty());
    QCOMPARE(home.scenes().size(), 2);
    QVERIFY(home.setSceneSchedule(sceneId, QStringLiteral("Mon"),
                                  QStringLiteral("06:00 AM - 06:30 AM")));
    QCOMPARE(home.scenes().last().days, QStringLiteral("Mon"));
    QVERIFY(home.removeScene(sceneId));
    QCOMPARE(home.scenes().size(), 1);

    const QString memberId = home.addMember(QStringLiteral("Vasilisa"),
                                            QStringLiteral("v@example.com"));
    QVERIFY(!memberId.isEmpty());
    QCOMPARE(home.members().size(), 2);
    QVERIFY(home.removeMember(memberId));
    QCOMPARE(home.members().size(), 1);
}

QTEST_GUILESS_MAIN(TestHomeService)
#include "tst_homeservice.moc"
