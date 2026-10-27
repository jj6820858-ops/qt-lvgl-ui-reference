import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StWalkPad
    \inqmlmodule SmarTon.Ui.Map3D
    \brief On-screen movement for walking through the 3D home.

    THE TARGET HAS NO KEYBOARD. Every first-person control scheme worth
    copying assumes WASD and a mouse, and the panel this runs on is a 7-inch
    touchscreen screwed to a wall. So the controls are a thumbstick and a
    drag-to-look surface, sized for a thumb rather than a cursor - the stick
    is 156 px across because anything smaller is a control you have to look at
    to use, and looking at the control is looking away from the room.

    THE LOOK SURFACE DOES NOT SWALLOW TAPS. It carries a DragHandler and
    nothing else: a handler stays passive until its gesture is recognised, so
    a press that turns into a drag looks around and a press that does not
    falls through to the picking TapHandler behind it. A MouseArea here would
    have taken every tap and left the devices in the room unclickable, which
    is the whole reason there is a 3D view to walk around in.

    Keyboard still works where there is one - see StFloorPlan3D. This is the
    other half of the same controls, not a replacement for them.
*/
Item {
    id: root

    /*! Name of the storey being walked, for the floor switcher. */
    property string storeyLabel: ""
    property bool canGoUp: false
    property bool canGoDown: false

    /*! Both in -1..1. \a forward is positive away from the camera. */
    signal moveRequested(real strafe, real forward)
    /*! Pixels dragged since the last emission, not since the press. */
    signal lookRequested(real dx, real dy)
    signal floorUpRequested()
    signal floorDownRequested()

    // ---- look ---------------------------------------------------------------
    Item {
        anchors.fill: parent

        DragHandler {
            id: look

            // target: null - this handler moves nothing on screen, it reports.
            // With a target it would drag the surface itself around the view.
            target: null
            property point last: Qt.point(0, 0)

            onActiveChanged: if (look.active) look.last = Qt.point(0, 0)
            onActiveTranslationChanged: {
                root.lookRequested(look.activeTranslation.x - look.last.x,
                                   look.activeTranslation.y - look.last.y);
                look.last = Qt.point(look.activeTranslation.x,
                                     look.activeTranslation.y);
            }
        }
    }

    // ---- crosshair ------------------------------------------------------------
    // Small, dim, and centred. It says where a tap will land, which in a view
    // with no cursor is not obvious - and it is the difference between
    // "tapping about where the lamp is" and aiming at it.
    Item {
        anchors.centerIn: parent
        width: 18
        height: 18
        opacity: 0.55

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: 1
            color: Theme.textPrimary
        }
        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: parent.height
            color: Theme.textPrimary
        }
    }

    // ---- the thumbstick --------------------------------------------------------
    Item {
        id: stick

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacing6
        width: 156
        height: 156

        property real offsetX: 0
        property real offsetY: 0
        readonly property real reach: stick.width / 2 - knob.width / 2

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(Theme.surfaceDeep.r, Theme.surfaceDeep.g,
                           Theme.surfaceDeep.b, 0.42)
            border.width: Theme.borderWidth
            border.color: Theme.outlineSubtle
        }

        Rectangle {
            id: knob

            width: 62
            height: 62
            radius: width / 2
            x: stick.width / 2 - width / 2 + stick.offsetX
            y: stick.height / 2 - height / 2 + stick.offsetY
            color: stickDrag.active ? Theme.primary : Theme.surfaceRaised
            border.width: Theme.borderWidth
            border.color: Theme.outline

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            // Only when the finger is off it: animating the knob under a drag
            // makes the stick feel like it is on elastic.
            Behavior on x { enabled: !stickDrag.active
                            NumberAnimation { duration: Theme.durationFast } }
            Behavior on y { enabled: !stickDrag.active
                            NumberAnimation { duration: Theme.durationFast } }
        }

        DragHandler {
            id: stickDrag

            target: null
            // The whole circle, not the knob: a 62 px target you have to find
            // first is a 62 px target you miss.
            onActiveChanged: {
                if (stickDrag.active)
                    return;
                stick.offsetX = 0;
                stick.offsetY = 0;
                root.moveRequested(0, 0);
            }
            onActiveTranslationChanged: {
                let dx = stickDrag.activeTranslation.x;
                let dy = stickDrag.activeTranslation.y;
                const length = Math.sqrt(dx * dx + dy * dy);
                if (length > stick.reach && length > 0) {
                    dx = dx / length * stick.reach;
                    dy = dy / length * stick.reach;
                }
                stick.offsetX = dx;
                stick.offsetY = dy;
                // Up the screen is forward, which is why dy is negated: screen
                // y grows downwards and walking does not.
                root.moveRequested(dx / stick.reach, -dy / stick.reach);
            }
        }

        StLabel {
            // ABOVE the stick. Below it is off the bottom of the view, which
            // is where the stick already is.
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: Theme.spacing2
            text: qsTr("Move")
            level: 0
            tone: "muted"
        }
    }

    // ---- storey switcher --------------------------------------------------------
    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacing6
        spacing: Theme.spacing2

        StIconButton {
            glyph: "chevronUp"
            size: 56
            radius: Theme.radiusSm
            fill: Qt.rgba(Theme.surfaceDeep.r, Theme.surfaceDeep.g,
                          Theme.surfaceDeep.b, 0.72)
            borderColor: Theme.outlineSubtle
            borderWidth: Theme.borderWidth
            enabled: root.canGoUp
            accessibleName: qsTr("Go up a floor")
            onClicked: root.floorUpRequested()
        }

        Rectangle {
            width: 56
            height: 34
            radius: Theme.radiusXs
            color: Qt.rgba(Theme.surfaceDeep.r, Theme.surfaceDeep.g,
                           Theme.surfaceDeep.b, 0.72)
            border.width: Theme.borderWidth
            border.color: Theme.outlineSubtle

            StLabel {
                anchors.centerIn: parent
                text: root.storeyLabel
                level: 0
                elide: Text.ElideRight
                width: parent.width - Theme.spacing2 * 2
                horizontalAlignment: Text.AlignHCenter
            }
        }

        StIconButton {
            glyph: "chevronDown"
            size: 56
            radius: Theme.radiusSm
            fill: Qt.rgba(Theme.surfaceDeep.r, Theme.surfaceDeep.g,
                          Theme.surfaceDeep.b, 0.72)
            borderColor: Theme.outlineSubtle
            borderWidth: Theme.borderWidth
            enabled: root.canGoDown
            accessibleName: qsTr("Go down a floor")
            onClicked: root.floorDownRequested()
        }
    }

    // ---- what the controls do ------------------------------------------------
    // Shown once, at the top, small. A first-person view inside a home-control
    // app is not a thing anyone has used before, and "drag to look" is not
    // discoverable by looking.
    Rectangle {
        // At the TOP. The bottom of the view is the stick on one side and the
        // floor switcher on the other, and a centred banner between them fits
        // on a 1024 panel and not on anything narrower.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.spacing4
        width: Math.min(hint.implicitWidth + Theme.spacing5 * 2,
                        root.width - Theme.spacing6 * 2)
        height: hint.implicitHeight + Theme.spacing3 * 2
        radius: Theme.radiusXs
        color: Qt.rgba(Theme.surfaceDeep.r, Theme.surfaceDeep.g,
                       Theme.surfaceDeep.b, 0.72)
        border.width: Theme.borderWidth
        border.color: Theme.outlineSubtle

        StLabel {
            id: hint
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - Theme.spacing5 * 2)
            text: qsTr("Drag to look  ·  tap a room to walk there  ·  tap a device to open it, hold to switch it")
            level: 0
            tone: "muted"
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
