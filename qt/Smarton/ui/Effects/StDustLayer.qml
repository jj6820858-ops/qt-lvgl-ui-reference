import QtQuick
import QtQuick.Particles
import SmarTon.Ui.Theme

/*!
    \qmltype StDustLayer
    \inqmlmodule SmarTon.Ui.Effects
    \brief Slow motes drifting across the page backdrop.

    SPARSE AND SLOW, deliberately. Particles on a control panel are the easiest
    thing in this design to overdo: anything fast or dense stops being
    atmosphere and becomes something the eye tracks instead of reading the
    screen. Forty motes over a whole page, drifting upward at roughly walking
    pace and fading in and out, is the budget - enough that the backdrop is
    alive under a blurred card, little enough that nobody notices it directly.

    ITS OWN MODULE because QtQuick.Particles' CMake component is not present in
    every packaging of Qt, and an `import` of a missing module fails the whole
    component that imports it. Isolated here, its absence costs the dust and
    nothing else.
*/
ParticleSystem {
    id: root

    ImageParticle {
        // OUR asset, not the one bundled inside the particles module. Qt's
        // internal resource paths are not API and have moved between releases;
        // pointing at one is a runtime failure the compiler cannot catch. The
        // aurora already ships a soft radial texture, and a mote is exactly
        // that shape at 3px.
        source: "qrc:/qt/qml/SmarTon/Resources/images/brand/radial-falloff.png"
        color: Qt.rgba(1, 1, 1, 0.20)
        colorVariation: 0.15
        // Faded in and out rather than popping: at this size a mote appearing
        // instantly reads as a dead pixel.
        entryEffect: ImageParticle.Fade
    }

    Emitter {
        anchors.fill: parent
        emitRate: 6
        lifeSpan: 7000
        lifeSpanVariation: 2500
        size: 3
        sizeVariation: 2
        endSize: 1
        // Hard cap. emitRate x lifeSpan already bounds this, but a cap means a
        // stall in the animation driver cannot produce a burst on resume.
        maximumEmitted: 40

        velocity: AngleDirection {
            angle: 268              // up, near enough vertical to read as still
            angleVariation: 14
            magnitude: 9
            magnitudeVariation: 5
        }
    }
}
