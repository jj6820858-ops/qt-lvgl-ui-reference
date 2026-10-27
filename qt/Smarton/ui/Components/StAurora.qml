import QtQuick
import QtQuick.Effects
import SmarTon.Backend
import SmarTon.Ui.Helpers
import SmarTon.Ui.Theme

/*!
    \qmltype StAurora
    \inqmlmodule SmarTon.Ui.Components
    \brief The page backdrop the glass surfaces refract.

    Glass needs something behind it. A frosted panel over a flat #202326 is a
    slightly lighter flat #202326 - the blur has nothing to blur, and all the
    expensive work produces an effect nobody can see. So the vibrance lives
    HERE, in the backdrop, and the surfaces above stay neutral.

    That order matters for legibility as much as for looks. The usual way a
    glass UI becomes unreadable is by putting the colour in the panels, which
    then have to carry text; putting it in the page instead means every
    surface keeps a consistent contrast against its own content no matter how
    saturated the wallpaper gets.

    THREE SLOW-MOVING BLOBS, not a static image. A gradient that never changes
    is indistinguishable from a wallpaper, and the blur behind a card is only
    convincing when the thing being blurred is doing something. Each blob is
    one small radial texture tinted at runtime and scaled up - see StBlob for
    why a texture rather than a gradient primitive - so the cost is fill rate
    on three quads rather than a per-pixel program.

    EVERYTHING HERE IS TIERED. At tier 0 the page is the flat theme colour, at
    tier 1 the blobs are static, at tier 2 they drift and the dust layer runs.
    A backdrop is decoration; it is the first thing that should go when there
    are no frames to spare.
*/
Item {
    id: root

    /*! The blobs move faster while something is loading, which is the one
        moment a backdrop earns attention. Off by default. */
    property bool busy: false

    // Publish, so glass surfaces can find this without twenty screens passing
    // a reference down. Cleared on destruction: a singleton holding a pointer
    // to a deleted Item is the one way this pattern goes wrong, and it goes
    // wrong at the exact moment a screen is being torn down.
    Component.onCompleted: Backdrop.source = root
    Component.onDestruction: {
        if (Backdrop.source === root)
            Backdrop.source = null;
    }

    // The base. Always painted, so the page has a colour even at tier 0 and
    // even before the blobs have laid out.
    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    // ---- aurora ------------------------------------------------------------
    Item {
        id: blobs

        anchors.fill: parent
        visible: Theme.glass && Theme.renderTier >= 1
        // Rendered to a texture once and blurred as a whole, rather than each
        // blob being blurred separately: three soft-edged quads composited and
        // then blurred is one pass, and blurring them individually is three.
        layer.enabled: Theme.renderTier >= 2
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            saturation: 0.15
        }

        StBlob {
            id: blobOne
            tone: Theme.auroraOne
            size: Math.max(root.width, root.height) * 0.85
            // Anchored to fractions of the page, so the composition holds at
            // 1024x600 and at 1600x980 instead of the blobs bunching in a
            // corner on the larger one.
            x: root.width * 0.08 - width / 2
            y: root.height * 0.10 - height / 2
            period: root.busy ? 4200 : 14000
            drift: root.width * 0.10
        }

        StBlob {
            id: blobTwo
            tone: Theme.auroraTwo
            size: Math.max(root.width, root.height) * 0.72
            x: root.width * 0.92 - width / 2
            y: root.height * 0.28 - height / 2
            period: root.busy ? 5200 : 17000
            drift: root.width * 0.08
        }

        StBlob {
            id: blobThree
            tone: Theme.auroraThree
            size: Math.max(root.width, root.height) * 0.66
            x: root.width * 0.55 - width / 2
            y: root.height * 1.02 - height / 2
            period: root.busy ? 6000 : 20000
            drift: root.height * 0.07
        }
    }

    // ---- dust ----------------------------------------------------------------
    // Loaded by URL from an optional module, the same way the 3D map is.
    // QtQuick.Particles ships with qtdeclarative, but its CMake component is
    // not guaranteed present in every packaging of Qt, and an `import` of a
    // missing module fails the WHOLE component rather than the one layer that
    // needs it. A backdrop flourish must never be able to take a screen down.
    Loader {
        anchors.fill: parent
        asynchronous: true
        active: Theme.glass && Theme.particlesEnabled
                && Capabilities.particleLayer && root.visible
        source: active ? "qrc:/qt/qml/SmarTon/Ui/Effects/StDustLayer.qml" : ""
    }

    /*!
        One aurora blob: a soft radial wash that drifts.

        A TINTED TEXTURE, not a RadialGradient.

        Rectangle's `gradient` property takes a LINEAR Gradient only. Qt 5 had
        a RadialGradient in QtGraphicalEffects and Qt 6 removed that module;
        what remains is QtQuick.Shapes' RadialGradient, which fills a ShapePath
        rather than a Rectangle and would pull in another module for one shape.

        So the falloff is a 256px greyscale texture, tinted at runtime with
        MultiEffect colorization - the same technique StIcon already uses for
        the whole icon set, which means it is a pattern proven in this codebase
        rather than an API taken on trust. It is also cheaper: one small texture
        scaled up, versus a per-pixel gradient program over a very large quad.
    */
    component StBlob: Item {
        id: blob

        property color tone: "transparent"
        property real size: 400
        /*! How far it wanders from where it was placed. */
        property real drift: 60
        /*! One full round trip, in ms. Long: see the class note. */
        property int period: 14000

        width: blob.size
        height: blob.size
        // The tint's alpha is applied to the ITEM, not to the colorization
        // colour: MultiEffect replaces the source's RGB and keeps its alpha,
        // so an alpha in the colour would be discarded.
        opacity: blob.tone.a

        Image {
            id: falloff

            anchors.fill: parent
            source: "qrc:/qt/qml/SmarTon/Resources/images/brand/radial-falloff.png"
            // Decoded at texture size and scaled up on the GPU. Decoding at
            // display size would be a 900px texture for a shape whose whole
            // point is that it has no detail.
            sourceSize.width: 256
            sourceSize.height: 256
            smooth: true
            mipmap: true
            asynchronous: true
            // Hidden: the effect below is what paints it.
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: falloff
            colorization: 1.0
            colorizationColor: Qt.rgba(blob.tone.r, blob.tone.g, blob.tone.b, 1.0)
        }

        // Two axes at different periods, so the path is a slow Lissajous
        // rather than a loop the eye can learn and start predicting.
        SequentialAnimation on x {
            running: Theme.renderTier >= 2 && root.visible
            loops: Animation.Infinite
            NumberAnimation {
                to: blob.x + blob.drift
                duration: blob.period
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: blob.x - blob.drift
                duration: blob.period
                easing.type: Easing.InOutSine
            }
        }

        SequentialAnimation on y {
            running: Theme.renderTier >= 2 && root.visible
            loops: Animation.Infinite
            NumberAnimation {
                to: blob.y - blob.drift * 0.7
                duration: Math.round(blob.period * 1.37)
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: blob.y + blob.drift * 0.7
                duration: Math.round(blob.period * 1.37)
                easing.type: Easing.InOutSine
            }
        }
    }
}
