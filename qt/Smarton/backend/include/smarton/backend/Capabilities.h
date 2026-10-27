#pragma once

#include <QtCore/QObject>
#include <QtQml/qqml.h>
#include <QtQml/qqmlprivate.h>
#include <QtQml/qqmlregistration.h>

namespace smarton::backend {

/**
 * @brief What this BUILD can do, as opposed to what this product does.
 *
 * One property so far, and the pattern matters more than the count: a feature
 * with an optional dependency needs somewhere for QML to ask whether it is
 * there, and the alternative is a `try { import } catch` shape that QML does
 * not have. Guessing from a runtime probe would be worse - by the time the
 * import fails the component is already broken.
 *
 * Compile-time, deliberately. Whether Quick3D was linked cannot change while
 * the process runs, so a CONSTANT property is honest and lets the QML compiler
 * fold the branch away.
 */
class Capabilities : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    /*! True when Qt Quick 3D was found at configure time and the 3D map view
        is built. False means the Rooms screen shows the 2D plan and does not
        offer a toggle to something that is not there. */
    Q_PROPERTY(bool mapView3D READ mapView3D CONSTANT)
    /*! True when Qt Quick Particles was found and the backdrop's dust layer is
        built. False means the glass theme's backdrop runs without it - the
        aurora and the blur are unaffected. */
    Q_PROPERTY(bool particleLayer READ particleLayer CONSTANT)
    /*! True when Qt MQTT was found at configure time and the MQTT transport
        is built. False means the panel can only run against the loopback. */
    Q_PROPERTY(bool mqttTransport READ mqttTransport CONSTANT)

public:
    explicit Capabilities(QObject *parent = nullptr) : QObject(parent) {}

    [[nodiscard]] static bool mapView3D()
    {
#ifdef ST_HAS_QUICK3D
        return true;
#else
        return false;
#endif
    }

    /*! True when Qt MQTT was found and the MQTT transport is built. Reported
        in Preferences, because "can this panel even talk to a broker" is the
        first question anyone debugging a dead switch asks, and the answer is
        decided at configure time where nobody can see it. */
    [[nodiscard]] static bool mqttTransport()
    {
#ifdef ST_HAS_MQTT
        return true;
#else
        return false;
#endif
    }

    [[nodiscard]] static bool particleLayer()
    {
#ifdef ST_HAS_PARTICLES
        return true;
#else
        return false;
#endif
    }
};

} // namespace smarton::backend
