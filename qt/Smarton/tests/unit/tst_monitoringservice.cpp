#include <QSignalSpy>
#include <QtTest>

#include <smarton/infrastructure/simulator/SimulatedReadingSource.h>
#include <smarton/services/MonitoringService.h>

using namespace smarton;

namespace {

/// Minimal stub source: lets a test set exactly the readings it needs.
class StubSource final : public services::IReadingSource
{
public:
    using IReadingSource::IReadingSource;

    QVector<domain::Reading> snapshot() const override { return m_readings; }
    void start() override { m_started = true; }
    void stop() override { m_started = false; }

    void push(QVector<domain::Reading> readings)
    {
        m_readings = std::move(readings);
        emit readingsChanged(m_readings);
    }

    bool started() const { return m_started; }

private:
    QVector<domain::Reading> m_readings;
    bool m_started = false;
};

domain::Reading make(double value, double max)
{
    return domain::Reading(QStringLiteral("R"), QStringLiteral("u"), value,
                           domain::Range { 0.0, max });
}

} // namespace

class TestMonitoringService : public QObject
{
    Q_OBJECT
private slots:
    void adoptsSnapshotOnAttach();
    void severityEmitsOnlyOnChange();
    void severityTakesTheWorstReading();
    void detachingStopsUpdates();
    void worksWithTheRealSimulator();
};

void TestMonitoringService::adoptsSnapshotOnAttach()
{
    StubSource source;
    source.push({ make(10.0, 100.0), make(20.0, 100.0) });

    services::MonitoringService service;
    service.setSource(&source); // must pull the existing snapshot

    QCOMPARE(service.readings().size(), 2);
}

void TestMonitoringService::severityEmitsOnlyOnChange()
{
    StubSource source;
    services::MonitoringService service;
    service.setSource(&source);

    QSignalSpy spy(&service, &services::MonitoringService::overallSeverityChanged);

    source.push({ make(10.0, 100.0) }); // normal -> no change
    QCOMPARE(spy.count(), 0);

    source.push({ make(95.0, 100.0) }); // -> critical
    QCOMPARE(int(service.overallSeverity()), int(common::Severity::Critical));
    QCOMPARE(spy.count(), 1);

    source.push({ make(97.0, 100.0) }); // moved, still critical
    QCOMPARE(spy.count(), 1); // must NOT re-emit
}

void TestMonitoringService::severityTakesTheWorstReading()
{
    StubSource source;
    services::MonitoringService service;
    service.setSource(&source);

    source.push({ make(10.0, 100.0), make(80.0, 100.0), make(5.0, 100.0) });
    QCOMPARE(int(service.overallSeverity()), int(common::Severity::Warning));

    source.push({ make(10.0, 100.0), make(80.0, 100.0), make(99.0, 100.0) });
    QCOMPARE(int(service.overallSeverity()), int(common::Severity::Critical));
}

void TestMonitoringService::detachingStopsUpdates()
{
    StubSource source;
    services::MonitoringService service;
    service.setSource(&source);
    service.setSource(nullptr);

    QSignalSpy spy(&service, &services::MonitoringService::readingsUpdated);
    source.push({ make(99.0, 100.0) });
    QCOMPARE(spy.count(), 0);
}

void TestMonitoringService::worksWithTheRealSimulator()
{
    infrastructure::SimulatedReadingSource source;
    services::MonitoringService service;
    service.setSource(&source);

    QCOMPARE(service.readings().size(), source.snapshot().size());

    QSignalSpy spy(&service, &services::MonitoringService::readingsUpdated);
    source.tick(); // stepped by hand, no timer
    QCOMPARE(spy.count(), 1);
}

QTEST_GUILESS_MAIN(TestMonitoringService)
#include "tst_monitoringservice.moc"
