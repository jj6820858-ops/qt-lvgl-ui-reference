import QtQuick
import SmarTon.Ui.Helpers
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StFloorPlan
    \inqmlmodule SmarTon.Ui.Components
    \brief The map view. Figma frame 18.

    Rooms as proportional rectangles with their devices pinned inside them.
    The geometry comes from \c FloorPlanHelper, which derives it from room
    AREA - see that file for why a generated plan is the honest answer when
    the product holds no survey data, and why it is generated in the view
    rather than stated as a fact about the home.

    WHAT A PIN MEANS. Filled with the accent when the device reports itself
    on, hollow when off, amber-rimmed when it is not answering, pulsing while
    a command is unconfirmed - the same vocabulary the device cards use, so
    the map is a different VIEW of the same state rather than a second opinion
    about it.

    Pins are laid out on a grid inside each room, not scattered: a device has
    no real position either, and randomising one would imply a precision that
    does not exist. A tidy grid reads as "these are in here", which is exactly
    what is known.
*/
Item {
    id: root

    /*! From HomeViewModel::floorPlan(). */
    property var rooms: []
    /*! Mortar between rooms, so adjacent walls read as two rooms not one. */
    property int gap: 6
    property string selectedRoomId: ""
    /*!
        Shapes only - no captions, no device pins, no hit targets.

        For the dashboard card, where the whole plan is about 170 px wide. A
        room name at that size is a smudge that reads as a rendering fault
        rather than as a name, and a tap target inside a card that is itself
        one tap target is two answers to the same gesture.
    */
    property bool preview: false

    signal roomActivated(string roomId)
    signal deviceActivated(string deviceId)

    /*! Recomputed on resize and whenever the rooms change. Deliberately a
        plain property, not a binding inside the Repeater: the layout is one
        calculation for the whole set, and evaluating it per delegate would
        run it once per room per frame of a resize. */
    readonly property var cells:
        FloorPlanHelper.layout(root.rooms, root.width, root.height)

    Repeater {
        model: root.cells

        delegate: Rectangle {
            id: cell

            required property var modelData

            readonly property bool selected: root.selectedRoomId === cell.modelData.roomId
            readonly property bool tight: cell.width < FloorPlanHelper.minCell
                                          || cell.height < FloorPlanHelper.minCell

            // The gap is taken out of the cell rather than added between them,
            // so the plan still fills its box exactly and the outer edge stays
            // flush with the card it sits in.
            x: cell.modelData.x + root.gap / 2
            y: cell.modelData.y + root.gap / 2
            width: Math.max(0, cell.modelData.w - root.gap)
            height: Math.max(0, cell.modelData.h - root.gap)

            radius: Theme.radiusSm
            color: cell.selected  ? Qt.rgba(1, 1, 1, Theme.hoverOverlay * 2.4)
                 : hover.hovered  ? Qt.rgba(1, 1, 1, Theme.hoverOverlay * 1.4)
                                  : Theme.surface
            border.width: cell.selected ? Theme.borderWidthFocus : Theme.borderWidth
            border.color: cell.selected ? Theme.primary : Theme.outlineSubtle

            Behavior on color        { ColorAnimation { duration: Theme.durationFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            // ---- label ----------------------------------------------------
            Column {
                id: caption

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.spacing3
                spacing: 1
                visible: !root.preview

                StLabel {
                    width: parent.width
                    text: cell.modelData.name
                    level: 1
                    font.weight: Theme.fontWeightMedium
                    elide: Text.ElideRight
                }

                StLabel {
                    width: parent.width
                    // Hidden in a cell too small to carry two lines. A room
                    // that is 6 m² of a large house genuinely gets a small
                    // box, and cramming its area in makes both lines
                    // unreadable rather than one line readable.
                    visible: !cell.tight
                    text: qsTr("%1 m²  ·  %2")
                            .arg(Math.round(cell.modelData.areaSqm))
                            .arg(cell.modelData.deviceCount === 1
                                 ? qsTr("1 device")
                                 : qsTr("%1 devices").arg(cell.modelData.deviceCount))
                    level: 0
                    tone: "muted"
                    elide: Text.ElideRight
                }
            }

            // ---- device pins ----------------------------------------------
            Grid {
                id: pins

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.spacing3
                // Never overlaps the caption: what does not fit is not drawn,
                // and the count in the caption still tells the truth.
                height: Math.max(0, cell.height - caption.height
                                    - Theme.spacing3 * 3)
                clip: true
                visible: !root.preview

                readonly property int cellSize: 18
                columns: Math.max(1, Math.floor((pins.width + pins.spacing)
                                                / (pins.cellSize + pins.spacing)))
                spacing: Theme.spacing2
                verticalItemAlignment: Grid.AlignVCenter

                Repeater {
                    // Emptied rather than hidden in preview: an invisible
                    // delegate is still constructed, still binds and still
                    // runs its pending animation.
                    model: root.preview ? 0 : cell.modelData.devices

                    delegate: Rectangle {
                        id: pin

                        required property var modelData

                        width: pins.cellSize
                        height: pins.cellSize
                        radius: width / 2
                        color: pin.modelData.on ? Theme.primary : "transparent"
                        border.width: Theme.borderWidth
                        border.color: pin.modelData.offline ? Theme.warning
                                    : pin.modelData.on      ? Theme.primary
                                                            : Theme.outlineStrong

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                        // Same pulse as the switches: unconfirmed, not off.
                        SequentialAnimation on opacity {
                            running: pin.modelData.pending
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 0.45; duration: 420; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0;  duration: 420; easing.type: Easing.InOutSine }
                        }

                        Accessible.role: Accessible.Button
                        Accessible.name: pin.modelData.name
                        Accessible.description: pin.modelData.offline ? qsTr("Not responding")
                                              : pin.modelData.on      ? qsTr("On") : qsTr("Off")
                        Accessible.onPressAction: root.deviceActivated(pin.modelData.deviceId)

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            // The dot is 18 px because that is what reads as a
                            // pin at this scale; 18 px is also a target people
                            // miss on a touchscreen. `margin` extends where the
                            // handler accepts a press beyond the item's bounds,
                            // which grows the TARGET to the 44 the panel needs
                            // without growing the dot to a blob.
                            margin: (Theme.touchTarget - pins.cellSize) / 2
                            onTapped: root.deviceActivated(pin.modelData.deviceId)
                        }
                    }
                }
            }

            HoverHandler { id: hover; enabled: !root.preview }
            TapHandler {
                // Bound to the CELL, so a tap on a pin is handled by the pin's
                // own handler and never also opens the room behind it.
                enabled: !root.preview
                onTapped: root.roomActivated(cell.modelData.roomId)
            }

            Accessible.role: root.preview ? Accessible.NoRole : Accessible.Button
            Accessible.name: qsTr("%1, %2 square metres, %3 devices")
                                .arg(cell.modelData.name)
                                .arg(Math.round(cell.modelData.areaSqm))
                                .arg(cell.modelData.deviceCount)
            Accessible.onPressAction: root.roomActivated(cell.modelData.roomId)
        }
    }
}
