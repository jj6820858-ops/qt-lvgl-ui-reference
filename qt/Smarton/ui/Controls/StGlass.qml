import QtQuick
import QtQuick.Effects
import SmarTon.Ui.Helpers
import SmarTon.Ui.Theme

/*!
    \qmltype StGlass
    \inqmlmodule SmarTon.Ui.Controls
    \brief A frosted panel: backdrop blur, translucent film, rim light.

    The one place the glass material is defined, so every card, bar and sheet
    in the app is the same material rather than twenty near-misses.

    WHAT MAKES IT READ AS GLASS. Three things, and the blur is the least
    important of them:

    \list
    \li A RIM. A bright hairline along the top and left edges, dimmer along the
        bottom and right - a lit edge is what the eye uses to decide something
        has a surface. A translucent rectangle without one reads as a smudge on
        the background, blurred or not.
    \li A GRADIENT across the film, not a flat alpha. Real glass is not evenly
        lit; a constant fill is the single biggest tell that a "glass" panel is
        a rectangle with opacity set on it.
    \li A BACKDROP BLUR, when the machine can afford one.
    \endlist

    Because the first two carry most of the effect and cost nothing, the
    fallback on a slow machine is not a different-looking component - it is the
    same component with its most expensive layer switched off. That same
    reasoning is why \l frosted defaults to FALSE even on a fast machine: see
    its documentation for the arithmetic.

    THE BLUR IS OF A SOURCE, NOT OF "BEHIND". Qt has no backdrop filter: an
    item cannot blur what is painted under it, because by the time it draws,
    what is under it is already in the framebuffer and unreadable. So the
    caller nominates a \l backdrop item - the page's background layer - and
    this blurs a live copy of it. That is why the wallpaper behind a card
    blurs and the sibling card next to it does not.
*/
Item {
    id: root

    /*!
        The item to blur. Defaults to the page backdrop - see the Backdrop
        singleton for why that is a window fact rather than a card parameter.

        Null is a supported state, not a broken one: during startup, in the
        gallery and in tests there is no backdrop, and the surface still
        renders as film plus rim, which is most of the material.
    */
    property Item backdrop: Backdrop.source

    /*!
        Actually frost the backdrop. OFF by default, and that default is the
        important part.

        Every frosted surface costs a live texture copy of the backdrop plus a
        multi-pass blur - two render targets, per surface, per frame. Nine
        device cards on the dashboard would be eighteen. That does not scale on
        any GPU, and on the panel it is not close.

        It also is not needed. As the class note says, the rim and the gradient
        carry most of what makes this read as glass; the blur is the layer with
        the worst cost-to-effect ratio of the three. So it is spent
        deliberately, on the few large surfaces where a moving backdrop is
        actually visible through them - the header band, a hero panel - and
        ordinary cards get the free two-thirds.
    */
    property bool frosted: false

    property real radius: Theme.radiusLg
    /*! Raised surfaces sit a step brighter, the same way surfaceRaised does in
        the Figma theme - the hierarchy has to survive the reskin. */
    property bool raised: false
    /*! Tint the film toward a colour - a scene card in the accent, a warning
        in amber. Transparent leaves it neutral. */
    property color tint: "transparent"
    /*! Border emphasis, for selection. */
    property bool highlighted: false

    readonly property bool blurring: root.frosted && Theme.blurEnabled
                                     && root.backdrop !== null

    // ---- blurred backdrop ---------------------------------------------------
    // Clipped to this item's rounded rectangle by the same mask trick
    // StRoundedImage uses: `clip` clips to the BOUNDING BOX, so a blurred
    // rectangle behind a rounded card would show square corners through it.
    Item {
        id: blurLayer

        anchors.fill: parent
        visible: root.blurring
        layer.enabled: root.blurring
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: cornerMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.35
        }

        // A live copy of the backdrop, aligned so the blurred pixels line up
        // with what is actually behind this item rather than with the
        // backdrop's own origin.
        ShaderEffectSource {
            id: backdropCopy

            anchors.fill: parent
            sourceItem: root.backdrop
            visible: false
            live: true
            recursive: false
            hideSource: false
            sourceRect: root.backdrop
                        ? Qt.rect(root.mapToItem(root.backdrop, 0, 0).x,
                                  root.mapToItem(root.backdrop, 0, 0).y,
                                  root.width, root.height)
                        : Qt.rect(0, 0, 1, 1)
        }

        MultiEffect {
            anchors.fill: parent
            source: backdropCopy
            blurEnabled: true
            blur: Theme.glassBlur
            // 3 passes at this radius. Fewer bands visibly; more costs frames
            // for a difference nobody can see at this blur strength.
            blurMax: 48
            blurMultiplier: 1.0
            // Pulled down slightly: a blurred bright wallpaper behind white
            // text is the classic unreadable-glass failure.
            brightness: -0.06
            saturation: 0.25
        }
    }

    Item {
        id: cornerMask

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "black"
            antialiasing: true
        }
    }

    // ---- the film ------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        antialiasing: true

        // A gradient, not a flat alpha. See the class note.
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.lighter(root.raised ? Theme.glassFillRaised
                                              : Theme.glassFill, 1.35)
            }
            GradientStop {
                position: 1.0
                color: root.raised ? Theme.glassFillRaised : Theme.glassFill
            }
        }

        // Optional colour wash, over the film rather than replacing it, so a
        // tinted panel is still the same material.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: root.tint.a > 0
            antialiasing: true
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.30)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.06)
                }
            }
        }
    }

    // ---- rim ------------------------------------------------------------------
    // Two borders, not one. A single uniform stroke reads as an outline; the
    // eye reads a SURFACE when the lit edge and the shadowed edge differ, which
    // is what these two overlapping rectangles fake cheaply.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        antialiasing: true
        border.width: root.highlighted ? Theme.borderWidthFocus : Theme.borderWidth
        border.color: root.highlighted ? Theme.primary : Theme.glassRim
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.borderWidth
        radius: Math.max(0, root.radius - Theme.borderWidth)
        color: "transparent"
        antialiasing: true
        visible: !root.highlighted
        border.width: Theme.borderWidth
        // Top-left highlight. Faked with an inner stroke at low alpha rather
        // than a real directional gradient border, which QML has no primitive
        // for and which would cost a shader per card.
        border.color: Qt.rgba(1, 1, 1, 0.06)
    }
}
