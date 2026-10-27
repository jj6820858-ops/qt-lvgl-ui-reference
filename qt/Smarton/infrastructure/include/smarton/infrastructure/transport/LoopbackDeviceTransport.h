#pragma once

#include <smarton/services/IDeviceTransport.h>

#include <QtCore/QHash>
#include <QtCore/QTimer>

namespace smarton::infrastructure {

/**
 * @brief An in-process transport that behaves like real hardware.
 *
 * SmarTon has no radio. This stands in for one, and it is deliberately NOT a
 * pass-through that echoes commands instantly: an instant, always-successful
 * transport lets every latency and failure bug in the layers above hide until
 * the day a real device is attached.
 *
 * So it models the two things that actually happen:
 *  - **Latency.** A confirmation arrives after \l setLatencyMs, not on the
 *    same call stack. Anything that assumed synchronous confirmation breaks
 *    here, on a developer's desk, instead of in a hallway.
 *  - **Failure.** \l setFailureRate of commands are dropped and reported as
 *    unreachable. Default 0 so demos are clean; turn it up to exercise the
 *    recovery paths.
 *
 * @note Deterministic, not random: a transport that is flaky differently on
 *       every run makes a failing test useless.
 */
class LoopbackDeviceTransport final : public services::IDeviceTransport
{
    Q_OBJECT
public:
    explicit LoopbackDeviceTransport(QObject *parent = nullptr);

    /** Round-trip delay applied to every confirmation. */
    void setLatencyMs(int milliseconds);
    /** 0.0 delivers everything; 1.0 drops everything. */
    void setFailureRate(qreal rate);
    /** Seed the failure sequence so a run is reproducible. */
    void setSeed(quint32 seed);

    /** Seed the simulated hardware's starting state. */
    void primeState(const QString &deviceId, bool on);

    bool requestPower(const QString &deviceId, bool on) override;
    void refresh() override;

private:
    [[nodiscard]] bool shouldDrop();

    QHash<QString, bool> m_state;
    int     m_latencyMs = 220;
    qreal   m_failureRate = 0.0;
    quint32 m_seed = 1;
    quint32 m_counter = 0;
};

} // namespace smarton::infrastructure
