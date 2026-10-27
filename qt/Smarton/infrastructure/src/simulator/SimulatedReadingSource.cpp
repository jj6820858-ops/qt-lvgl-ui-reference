#include <smarton/infrastructure/simulator/SimulatedReadingSource.h>

#include <cmath>

namespace smarton::infrastructure {

using domain::Range;
using domain::Reading;

namespace {
constexpr int kDefaultIntervalMs = 250;
}

SimulatedReadingSource::SimulatedReadingSource(QObject *parent) : services::IReadingSource(parent)
{
    m_readings = {
        Reading(QStringLiteral("Airway pressure"), QStringLiteral("cmH2O"), 0.0,
                Range { 0.0, 60.0 }),
        Reading(QStringLiteral("Tidal volume"), QStringLiteral("mL"), 0.0, Range { 0.0, 800.0 }),
        Reading(QStringLiteral("Respiratory rate"), QStringLiteral("bpm"), 0.0,
                Range { 0.0, 40.0 }),
        Reading(QStringLiteral("FiO2"), QStringLiteral("%"), 0.0, Range { 21.0, 100.0 }),
    };

    m_timer.setInterval(kDefaultIntervalMs);
    connect(&m_timer, &QTimer::timeout, this, &SimulatedReadingSource::tick);
}

int SimulatedReadingSource::intervalMs() const
{
    return m_timer.interval();
}

void SimulatedReadingSource::setIntervalMs(int ms)
{
    m_timer.setInterval(qMax(1, ms));
}

void SimulatedReadingSource::start()
{
    m_timer.start();
}
void SimulatedReadingSource::stop()
{
    m_timer.stop();
}

void SimulatedReadingSource::tick()
{
    ++m_step;
    const double phase = m_step * 0.08;

    for (int i = 0; i < m_readings.size(); ++i) {
        const Range r = m_readings.at(i).range();
        const double swing = (std::sin(phase + i) + 1.0) / 2.0;
        m_readings[i].setValue(r.minimum + swing * (r.maximum - r.minimum));
    }

    emit readingsChanged(m_readings);
}

} // namespace smarton::infrastructure
