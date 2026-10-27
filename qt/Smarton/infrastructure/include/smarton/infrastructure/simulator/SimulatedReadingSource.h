#pragma once

#include <smarton/services/IReadingSource.h>

#include <QtCore/QTimer>

namespace smarton::infrastructure {

/**
 * @brief Deterministic fake source, driven by a timer or stepped by hand.
 *
 * Replace with a real transport (CAN, MQTT, serial) in a real project — the
 * service layer will not notice, because it only knows IReadingSource.
 *
 * @note tick() is public so tests can advance the simulation without waiting
 *       on a timer. A test that sleeps is a test that flakes.
 */
class SimulatedReadingSource final : public services::IReadingSource
{
    Q_OBJECT
public:
    explicit SimulatedReadingSource(QObject *parent = nullptr);

    [[nodiscard]] QVector<domain::Reading> snapshot() const override { return m_readings; }
    [[nodiscard]] int intervalMs() const;

    void setIntervalMs(int ms);

    void start() override;
    void stop() override;

public slots:
    /** Advances the simulation one step and emits readingsChanged(). */
    void tick();

private:
    QVector<domain::Reading> m_readings;
    QTimer m_timer;
    int m_step = 0;
};

} // namespace smarton::infrastructure
