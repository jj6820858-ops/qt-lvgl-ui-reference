#include <smarton/services/MonitoringService.h>

#include <smarton/services/IReadingSource.h>

#include <utility>

namespace smarton::services {

MonitoringService::MonitoringService(QObject *parent) : QObject(parent) { }

void MonitoringService::setSource(IReadingSource *source)
{
    if (m_source == source)
        return;

    if (m_source)
        disconnect(m_source, nullptr, this, nullptr);

    m_source = source;

    if (m_source) {
        connect(m_source, &IReadingSource::readingsChanged, this, &MonitoringService::onReadings);
        onReadings(m_source->snapshot());
    }
}

void MonitoringService::onReadings(const QVector<domain::Reading> &readings)
{
    m_readings = readings;
    emit readingsUpdated(m_readings);

    common::Severity worst = common::Severity::Normal;
    for (const domain::Reading &r : std::as_const(m_readings))
        worst = common::worse(worst, r.severity());

    if (worst == m_overall)
        return; // guard: never re-emit an unchanged value

    m_overall = worst;
    emit overallSeverityChanged(m_overall);
}

} // namespace smarton::services
