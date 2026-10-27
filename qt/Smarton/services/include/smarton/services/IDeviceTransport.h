#pragma once

#include <smarton/domain/entities/HomeEntities.h>

#include <QtCore/QObject>
#include <QtCore/QVariantMap>

namespace smarton::services {

/**
 * @brief The boundary between SmarTon and real hardware.
 *
 * Everything above this interface is written as though devices are remote,
 * slow and unreliable, because they are. A transport is asked to change a
 * device and answers later - or never.
 *
 * Deliberately NOT a synchronous `bool setPower(id, on)`. That signature
 * forces every caller to either block on a network round trip or lie about
 * the result, and both mistakes are unfixable once the API has shipped: the
 * blocking version freezes the UI on a slow Zigbee mesh, and the lying
 * version is how a panel ends up claiming a light is on that is off.
 *
 * Implementations that exist or are planned:
 *  - LoopbackDeviceTransport - in-process, models latency and failure. Ships.
 *  - An MQTT transport (Zigbee2MQTT / Matter bridge). Not written; this
 *    interface is the whole of what it has to satisfy.
 */
class IDeviceTransport : public QObject
{
    Q_OBJECT
public:
    explicit IDeviceTransport(QObject *parent = nullptr) : QObject(parent) {}

    /**
     * Ask @p deviceId to change power state. Returns false only when the
     * request could not be SENT; success means sent, never confirmed.
     * Confirmation arrives as powerReported().
     */
    virtual bool requestPower(const QString &deviceId, bool on) = 0;

    /** Ask every known device to report itself. Called on start and on resume. */
    virtual void refresh() = 0;

signals:
    /** The device reported its actual state. This is the only source of truth. */
    void powerReported(const QString &deviceId, bool on);
    /** Reachability changed - a command timed out, or the device came back. */
    void reachabilityChanged(const QString &deviceId, domain::Reachability state);
    /** A command could not be delivered. @p reason is for logs, not for users. */
    void commandFailed(const QString &deviceId, const QString &reason);
    /*! Adapter-normalised quality and identity data from a device report.
        Supported keys are intentionally simple: batteryPercent,
        signalStrength, lastSeen (ISO UTC), manufacturer, model, firmware,
        serialNumber and capabilities (a QStringList). */
    void metadataReported(const QString &deviceId, const QVariantMap &metadata);
};

} // namespace smarton::services
