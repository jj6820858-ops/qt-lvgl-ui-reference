#include <smarton/services/ActivityLog.h>

#include <QtCore/QJsonArray>
#include <QtCore/QJsonObject>
#include <QtTest/QSignalSpy>
#include <QtTest/QtTest>

using namespace smarton;

namespace {

class FakeStore final : public services::IActivityStore
{
public:
    QJsonArray entries;
    int saveCalls = 0;

    QJsonArray load() override { return entries; }
    bool save(const QJsonArray &next) override
    {
        ++saveCalls;
        entries = next;
        return true;
    }
};

} // namespace

class TestActivityLog : public QObject
{
    Q_OBJECT

private slots:
    void recordsNewestFirst();
    void boundsItself();
    void roundTripsThroughTheStore();
    void dropsEntriesWithNoReadableTime();
    void worksWithoutAStore();
    void clears();
};

void TestActivityLog::recordsNewestFirst()
{
    services::ActivityLog log;
    QSignalSpy spy(&log, &services::ActivityLog::recorded);

    log.record(QStringLiteral("device"), QStringLiteral("Smart Lamp"),
               QStringLiteral("switched on"), QStringLiteral("jack"));
    log.record(QStringLiteral("scene"), QStringLiteral("Movie Night"),
               QStringLiteral("ran"));

    QCOMPARE(spy.count(), 2);
    QCOMPARE(log.count(), 2);
    // Newest first, which is the order anybody reads a log in.
    QCOMPARE(log.entries().at(0).subject, QStringLiteral("Movie Night"));
    QCOMPARE(log.entries().at(1).subject, QStringLiteral("Smart Lamp"));
    // The house acting on its own has no actor. This is the field the whole
    // record exists for, so it is worth asserting rather than assuming.
    QVERIFY(log.entries().at(0).actor.isEmpty());
    QCOMPARE(log.entries().at(1).actor, QStringLiteral("jack"));
}

void TestActivityLog::boundsItself()
{
    services::ActivityLog log;
    for (int i = 0; i < services::ActivityLog::kMaxEntries + 25; ++i) {
        log.record(QStringLiteral("device"), QStringLiteral("Lamp %1").arg(i),
                   QStringLiteral("switched on"));
    }

    // A panel that is never switched off logs a line every time somebody
    // walks past a light switch. Unbounded, the question is not whether it
    // fills the disk but when.
    QCOMPARE(log.count(), services::ActivityLog::kMaxEntries);
    // And it is the OLD ones that went.
    QCOMPARE(log.entries().first().subject,
             QStringLiteral("Lamp %1").arg(services::ActivityLog::kMaxEntries + 24));
}

void TestActivityLog::roundTripsThroughTheStore()
{
    FakeStore store;

    services::ActivityLog first;
    first.setStore(&store);
    first.record(QStringLiteral("session"), QStringLiteral("jack"),
                 QStringLiteral("signed in"), QStringLiteral("jack"));
    first.record(QStringLiteral("device"), QStringLiteral("Speaker"),
                 QStringLiteral("switched off"), QStringLiteral("dina"));
    QCOMPARE(store.saveCalls, 2);

    services::ActivityLog second;
    second.setStore(&store);
    QSignalSpy resets(&second, &services::ActivityLog::reset);
    second.load();

    QCOMPARE(resets.count(), 1);
    QCOMPARE(second.count(), 2);
    QCOMPARE(second.entries().at(0).subject, QStringLiteral("Speaker"));
    QCOMPARE(second.entries().at(0).actor, QStringLiteral("dina"));
    QCOMPARE(second.entries().at(1).detail, QStringLiteral("signed in"));
}

void TestActivityLog::dropsEntriesWithNoReadableTime()
{
    FakeStore store;
    store.entries = QJsonArray {
        QJsonObject { { QStringLiteral("when"), QStringLiteral("not a time") },
                      { QStringLiteral("subject"), QStringLiteral("Broken") } },
        QJsonObject { { QStringLiteral("when"),
                        QDateTime::currentDateTime().toString(Qt::ISODate) },
                      { QStringLiteral("subject"), QStringLiteral("Fine") } },
    };

    services::ActivityLog log;
    log.setStore(&store);
    log.load();

    // A line nobody can place is worse than no line: shown at the epoch it
    // sorts to the bottom and reads as something that happened in 1970.
    QCOMPARE(log.count(), 1);
    QCOMPARE(log.entries().first().subject, QStringLiteral("Fine"));
}

void TestActivityLog::worksWithoutAStore()
{
    // The same "optional collaborator" rule the rest of the services follow:
    // without one it works and forgets.
    services::ActivityLog log;
    log.load();
    log.record(QStringLiteral("device"), QStringLiteral("Lamp"),
               QStringLiteral("switched on"));
    QCOMPARE(log.count(), 1);
}

void TestActivityLog::clears()
{
    FakeStore store;
    services::ActivityLog log;
    log.setStore(&store);
    log.record(QStringLiteral("device"), QStringLiteral("Lamp"),
               QStringLiteral("switched on"));

    QSignalSpy resets(&log, &services::ActivityLog::reset);
    log.clear();
    QCOMPARE(resets.count(), 1);
    QCOMPARE(log.count(), 0);
    // Cleared on disk too, not just in memory - the case this exists for is
    // handing the panel to somebody else.
    QVERIFY(store.entries.isEmpty());

    // And clearing an empty log is not an event.
    log.clear();
    QCOMPARE(resets.count(), 1);
}

QTEST_GUILESS_MAIN(TestActivityLog)
#include "tst_activitylog.moc"
