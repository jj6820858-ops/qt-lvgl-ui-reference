#include <smarton/infrastructure/transport/LoopbackDeviceTransport.h>

#include <QtCore/QtGlobal>

namespace smarton::infrastructure {

LoopbackDeviceTransport::LoopbackDeviceTransport(QObject *parent)
    : services::IDeviceTransport(parent)
{
}

void LoopbackDeviceTransport::setLatencyMs(int milliseconds)
{
    m_latencyMs = qMax(0, milliseconds);
}

void LoopbackDeviceTransport::setFailureRate(qreal rate)
{
    m_failureRate = qBound(0.0, rate, 1.0);
}

void LoopbackDeviceTransport::setSeed(quint32 seed)
{
    m_seed = seed;
    m_counter = 0;
}

void LoopbackDeviceTransport::primeState(const QString &deviceId, bool on)
{
    m_state.insert(deviceId, on);
}

bool LoopbackDeviceTransport::shouldDrop()
{
    if (m_failureRate <= 0.0)
        return false;

    // A deterministic hash sequence, not QRandomGenerator: a transport that
    // fails differently on every run turns a failing test into a coin toss.
    ++m_counter;
    const auto mixed = static_cast<quint32>(
        qHash(QStringLiteral("%1:%2").arg(m_seed).arg(m_counter)));
    return (mixed % 1000u) < static_cast<quint32>(m_failureRate * 1000.0);
}

bool LoopbackDeviceTransport::requestPower(const QString &deviceId, bool on)
{
    if (deviceId.isEmpty())
        return false;

    if (shouldDrop()) {
        // Queued, not immediate: a failure delivered on the caller's own stack
        // is indistinguishable from a synchronous return, and would let
        // callers get away with assuming one.
        QTimer::singleShot(m_latencyMs, this, [this, deviceId] {
            emit reachabilityChanged(deviceId, domain::Reachability::Offline);
            emit commandFailed(deviceId, QStringLiteral("no response from device"));
        });
        return true;      // SENT. Delivery is a separate question.
    }

    QTimer::singleShot(m_latencyMs, this, [this, deviceId, on] {
        m_state.insert(deviceId, on);
        emit reachabilityChanged(deviceId, domain::Reachability::Online);
        emit powerReported(deviceId, on);
    });
    return true;
}

void LoopbackDeviceTransport::refresh()
{
    const QList<QString> ids = m_state.keys();
    for (const QString &id : ids) {
        const bool on = m_state.value(id);
        QTimer::singleShot(m_latencyMs, this, [this, id, on] {
            emit reachabilityChanged(id, domain::Reachability::Online);
            emit powerReported(id, on);
        });
    }
}

} // namespace smarton::infrastructure
