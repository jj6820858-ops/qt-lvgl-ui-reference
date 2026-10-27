import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme

/*!
    \qmltype StSwitch
    \inqmlmodule SmarTon.Ui.Controls
    \brief The orange pill toggle. Figma: every device card and scene row.

    THIS CONTROL DOES NOT OWN ITS STATE, AND THAT IS THE WHOLE POINT.

    A plain Switch flips its own \c checked on click. Bind \c checked to model
    data and the first click destroys the binding - Qt replaces it with the
    value the control just assigned. From then on the switch shows what it was
    last clicked to, not what the device actually did, and a device that fails
    to turn on still reads as on. On a home-automation panel that is the worst
    class of bug there is: the UI lying about hardware.

    So the visuals read \l value, which the owner binds to the model, and a
    click only ASKS, via \l toggleRequested. The switch moves when the model
    says it moved. \c checked is kept in step for accessibility only.
*/
T.Switch {
    id: root

    /*! The displayed state. Bind this to the model. */
    property bool value: false
    /*! Frame 21 labels the thumb "ON" when on. */
    property bool showStateText: false
    /*! A command is in flight. The track pulses; the thumb does NOT move,
        because the device has not moved. */
    property bool pending: false
    /*! The device is not answering. Shown, not disabled: the user must still
        be able to retry, and a greyed switch says "you cannot", not
        "it is not listening". */
    property bool unreachable: false

    /*! A click happened; @a requested is the state the user is asking for. */
    signal toggleRequested(bool requested)

    /*!
        The track's own size - what the design draws.

        SEPARATE FROM the item's size, which is the touch target. The design's
        track is 28 px tall and 28 px is a target people miss on a
        touchscreen; the figure everyone converges on is 44, and a switch is
        the most-tapped control in this app by a wide margin. So the ITEM is
        44 tall and the TRACK stays 28, centred in it: the visual is the
        design's and the target is the panel's.

        Callers that want a bigger switch set these rather than the implicit
        size, which is now derived from them.
    */
    property int trackWidth: 52
    property int trackHeight: 28

    implicitWidth: Math.max(root.trackWidth, Theme.touchTarget)
    implicitHeight: Math.max(root.trackHeight, Theme.touchTarget)
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    activeFocusOnTab: true

    /*! What this switch controls, e.g. "Smart Lamp". Icon-and-state only
        otherwise, which announces as an unnamed switch. */
    property string accessibleName: ""

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    // Reads `value`, not `checked`: value is the model's truth, and checked is
    // only kept in step for exactly this reason.
    Accessible.checked: root.value
    Accessible.description: root.unreachable ? qsTr("Not responding")
                          : root.pending     ? qsTr("Changing")
                          : root.value       ? qsTr("On") : qsTr("Off")
    Accessible.onPressAction: root.toggleRequested(!root.value)
    opacity: root.enabled ? 1 : Theme.disabledOpacity

    checked: root.value
    // Re-assert after a click has broken the binding above, so screen readers
    // and Accessible.checked keep telling the truth.
    onValueChanged: root.checked = root.value
    onClicked: root.toggleRequested(!root.value)

    indicator: Rectangle {
        id: track

        implicitWidth: root.trackWidth
        implicitHeight: root.trackHeight
        // Centred in the item both ways, because the item is the target and
        // the track is only the picture of it.
        x: root.leftPadding + (root.availableWidth - width) / 2
        y: root.topPadding + (root.availableHeight - height) / 2
        radius: height / 2
        // OFF is surfaceDeep, not surfaceRaised. Raised (#40464D) sits one
        // step ABOVE the card it is drawn on (#2D3542), so an off switch was a
        // barely-lighter smudge with a white dot floating in it - the track
        // read as nothing and the control looked broken rather than off. A
        // recessed track plus a rim gives "off" a shape of its own, which is
        // what makes it legible next to an on switch at a glance.
        readonly property color trackOff: Theme.surfaceDeep

        color: !root.enabled ? Theme.disabledFill(root.value ? Theme.primary
                                                             : track.trackOff)
             : root.down     ? Theme.pressedFill(root.value ? Theme.primary
                                                            : track.trackOff)
                             : Theme.hoveredFill(root.value ? Theme.primary
                                                            : track.trackOff,
                                                 root.hovered)
        // The rim is what separates the off track from the card behind it.
        // Only when off: an on track is its own strong colour and a border on
        // it just muddies the edge.
        border.width: root.visualFocus ? Theme.borderWidthFocus
                    : root.value       ? 0 : Theme.borderWidth
        border.color: root.visualFocus ? Theme.focus : Theme.outlineSubtle

        Behavior on color {
            ColorAnimation { duration: Theme.durationFast }
        }

        StLabel {
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("ON")
            level: 0
            color: Theme.textOnPrimary
            font.weight: Theme.fontWeightBold
            visible: root.showStateText && root.value
        }

        // Pulse while a command is unconfirmed. Opacity, not position: moving
        // the thumb early is exactly the lie this control exists to avoid.
        SequentialAnimation on opacity {
            running: root.pending
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.55; duration: 420; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0;  duration: 420; easing.type: Easing.InOutSine }
        }

        // Dashed-looking edge when the device is not answering.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.warning
            visible: root.unreachable && !root.pending
        }

        Rectangle {
            x: root.value ? parent.width - width - 3 : 3
            y: 3
            width: parent.height - 6
            height: width
            radius: width / 2
            // Off, the knob steps back to the muted text tone. At pure white
            // it was the highest-contrast element on the card while meaning
            // "nothing is happening here".
            color: root.value ? Theme.textPrimary : Theme.textMuted

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            Behavior on x {
                NumberAnimation {
                    duration: Theme.durationFast
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    contentItem: Item {}
}
