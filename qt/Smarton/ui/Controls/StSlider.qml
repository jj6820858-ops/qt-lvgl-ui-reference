import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme

/*!
    \qmltype StSlider
    \inqmlmodule SmarTon.Ui.Controls
    \brief Ticked volume slider. Figma frame 21.

    The design fills the track with a left-to-right orange gradient and prints
    tick marks across it, with the percentage inside the track on the right.
    Derives from T.Slider so drag, keyboard steps and page steps come from Qt.
*/
T.Slider {
    id: root

    property int tickCount: 20
    property string suffix: "%"
    /*! Icon inside the track's left end. The control is frame 21's volume
        slider, and it is also every other 0-100 device setting - brightness,
        mist output - so the glyph is the caller's to name. */
    property string glyph: "volume"

    /*!
        What the MODEL says this is.

        Assign this, never \l value. A T.Slider writes to \c value itself
        while a finger is down, and an assignment destroys a binding: bound
        directly, the slider follows the model exactly once, and every later
        change made anywhere else in the app is silently ignored by a control
        that looks live. So the caller binds the model here, the drag owns
        \c value, and the model is re-asserted the moment the finger lifts.
    */
    property real modelValue: 0
    // The binding gives the initial position and tracks the model until the
    // first drag destroys it; the two handlers take over from there. Declared
    // as a default binding rather than assigned on completion, so a caller
    // that genuinely wants to own `value` can still just set it.
    value: root.modelValue
    onModelValueChanged: if (!root.pressed) root.value = root.modelValue;
    onPressedChanged: if (!root.pressed) root.value = root.modelValue;

    from: 0
    to: 100
    stepSize: 1
    implicitWidth: 380
    implicitHeight: 56
    padding: 0
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    activeFocusOnTab: true

    property string accessibleName: qsTr("Volume")

    Accessible.role: Accessible.Slider
    Accessible.name: root.accessibleName
    Accessible.description: qsTr("%1 percent").arg(Math.round(root.value))
    opacity: root.enabled ? 1 : Theme.disabledOpacity
    // Qualified as T.Slider: the enum belongs to the type this derives from,
    // and the unqualified `Slider` would need a QtQuick.Controls import that
    // this file has no other reason to carry.
    snapMode: T.Slider.SnapAlways

    background: Rectangle {
        radius: Theme.radiusSm
        color: root.hovered ? Qt.lighter(Theme.surfaceRaised, 1 + Theme.hoverOverlay)
                            : Theme.surfaceRaised

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        border.width: root.visualFocus ? Theme.borderWidthFocus : 0
        border.color: Theme.focus
        clip: true

        // Filled portion: the design's warm gradient, not a flat bar.
        Rectangle {
            width: parent.width * root.position
            height: parent.height
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.92) }
                GradientStop { position: 1.0; color: Theme.primary }
            }
        }

        // Tick marks, drawn across the whole track so they read on the filled
        // side and the empty side alike. Repeater over an Item rather than a
        // Row: with a fixed span each tick can be positioned arithmetically,
        // which avoids the delegate having to ask its parent for a width.
        Item {
            id: tickSpan

            anchors.left: parent.left
            anchors.leftMargin: 46
            anchors.right: parent.right
            anchors.rightMargin: 62
            anchors.verticalCenter: parent.verticalCenter
            height: 18

            Repeater {
                model: root.tickCount

                delegate: Rectangle {
                    required property int index

                    width: 1
                    height: tickSpan.height
                    x: tickSpan.width * (index + 0.5) / root.tickCount
                    color: Theme.surfaceDeep
                    opacity: 0.45
                }
            }
        }

        StIcon {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing4
            anchors.verticalCenter: parent.verticalCenter
            name: root.glyph
            size: 20
            // Sits on the filled part of the track, which is near-white at
            // the left end, so it takes the dark ink rather than the light.
            color: Theme.surfaceDeep
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StLabel {
                text: String(Math.round(root.value))
                level: 2
                color: Theme.textPrimary
                font.weight: Theme.fontWeightBold
                anchors.bottom: parent.bottom
            }
            StLabel {
                text: root.suffix
                level: 0
                tone: "secondary"
                anchors.bottom: parent.bottom
                bottomPadding: 3
            }
        }
    }

    // The track IS the control; there is no separate knob in the design.
    handle: Item {}
}
