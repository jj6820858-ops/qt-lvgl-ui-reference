import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Helpers
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Layouts
import SmarTon.Ui.Components
import SmarTon.Ui.Dialogs

/*!
    \qmltype SpacesScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief The Spaces destination. Figma frames 06 (empty) and 07 (dashboard).

    Two states of one destination, not two screens: which one shows is a
    property of the data, so it is a Loader over \c hasSpace rather than a
    routing decision the shell has to know about.

    REFLOW. Frame 07 is 1440x1024 and shows a 3x2 device grid with the members
    and space-map cards below it. On the 1024x600 panel the header band and
    the grid alone fill the height, so the content scrolls - which is right
    for a list that grows with every device the user adds. Card sizes come
    from the available width, so the grid is 3 columns here and would be 4 on
    a wider panel without a second layout.
*/
Item {
    id: root

    /*! smarton::models::HomeViewModel. */
    required property var viewModel

    signal setUpSpaceRequested()
    signal roomRequested(string roomId)
    signal deviceRequested(string deviceId)
    signal membersRequested()
    /*! The "Your space map" card was tapped. Frame 07 puts it beside Members;
        frame 09 is what it opens. */
    signal spaceMapRequested()
    /*! The picker's "Create a new space" row. */
    signal addSpaceRequested()

    /*! The generated plan, for the map card's thumbnail.

        Read on model changes rather than bound: floorPlan() walks every device
        to group them by room, and this is a 170 px picture - re-running that
        walk on every resize frame to redraw four rectangles would be the most
        expensive thing on the dashboard.
    */
    property var planPreview: []

    function refreshPlan(): void {
        root.planPreview = root.viewModel.floorPlan();
    }

    Component.onCompleted: root.refreshPlan()

    Connections {
        target: root.viewModel
        function onCountsChanged() { root.refreshPlan(); }
        function onSpaceChanged()  { root.refreshPlan(); }
        function onRoomChanged()   { root.refreshPlan(); }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.viewModel.hasSpace ? dashboard : emptyState
    }

    /*!
        Frame 08. At screen scope, NOT inside the dashboard Component.

        Two reasons, and the second is why the first attempt at this failed to
        load at all. A Component holds exactly one root object, so a dialog
        declared beside the dashboard's StScrollView is an "invalid component
        body" outright. And even where it is legal, the strip that raises this
        lives in the top bar's bottomContent Loader - a dialog whose parent is
        destroyed while it is open takes its callbacks with it.
    */
    StConfirmDialog {
        id: lightsDialog

        parent: root
        title: qsTr("Manage your lights")
        message: qsTr("This turns off every light in %1.")
                    .arg(root.viewModel.spaceName)
        artworkSource: "qrc:/qt/qml/SmarTon/Resources/images/devices/pendant-lamp.png"
        acceptText: qsTr("Turn off")
        rejectText: qsTr("Dismiss")
        destructive: true
        onAccepted: {
            root.viewModel.setAllLights(false);
            Notifications.info(qsTr("Lights off"),
                               qsTr("Every light in %1.").arg(root.viewModel.spaceName));
        }
    }

    // This is deliberately a SmarTon-styled template dialog rather than the
    // platform Basic dialog. The form needs the same deep surface, measured
    // title row and scrim as the rest of the fixed-panel UI.
    T.Dialog {
        id: addDeviceDialog

        parent: T.Overlay.overlay
        modal: true
        title: qsTr("Add device")
        padding: Theme.spacing6
        implicitWidth: Math.min(520, root.width - Theme.spacing8)
        // The RK3328 panel is only 600 px tall. Give this form one explicit
        // panel size instead of letting Dialog's independent header/content/
        // footer slots compete for the same space.
        width: implicitWidth
        height: Math.min(500, parent.height - Theme.spacing6 * 2)
        // Templates do not choose a position. Anchor math does not apply
        // reliably after a Popup reparents to Overlay, so position from the
        // overlay's live size instead.
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

        background: Rectangle {
            radius: Theme.radiusLg
            color: Theme.surfaceDeep
            border.width: Theme.borderWidth
            border.color: Theme.outline
        }

        header: Item {
            width: parent.width
            implicitHeight: 76

            StLabel {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacing6
                anchors.verticalCenter: parent.verticalCenter
                text: addDeviceDialog.title
                level: 2
                font.weight: Theme.fontWeightBold
            }
            StIconButton {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing5
                anchors.verticalCenter: parent.verticalCenter
                glyph: "close"
                size: 40
                accessibleName: qsTr("Close add device")
                fill: "transparent"
                stroke: Theme.textSecondary
                onClicked: addDeviceDialog.close()
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1; color: Theme.outline; opacity: 0.55
            }
        }

        contentItem: Column {
            width: 420
            spacing: Theme.spacing3

            StLabel { text: qsTr("Create a protocol-ready device. You can connect its physical gateway later."); wrapMode: Text.WordWrap; level: 1; tone: "secondary" }
            StTextField { id: manualName; width: parent.width; placeholderText: qsTr("Device name"); accessibleName: qsTr("Device name") }
            StComboBox { id: manualKind; width: parent.width; accessibleName: qsTr("Device type"); model: ["lamp", "conditioner", "thermostat", "sensor", "leak", "lock", "cover", "valve", "pump", "heater", "appliance"] }
            StComboBox { id: manualProtocol; width: parent.width; accessibleName: qsTr("Connection protocol"); model: ["manual", "mqtt", "zigbee2mqtt", "modbus", "ir", "matter"] }
            StComboBox { id: manualRoom; width: parent.width; accessibleName: qsTr("Room"); textRole: "name"; model: root.viewModel.roomChoices() }

            Item { width: 1; height: Theme.spacing2 }
            Rectangle { width: parent.width; height: 1; color: Theme.outline; opacity: 0.55 }
            Row {
                width: parent.width
                spacing: Theme.spacing3
                layoutDirection: Qt.RightToLeft
                StButton {
                    text: qsTr("Add device")
                    enabled: manualName.text.trim().length > 0
                    onClicked: {
                        const rooms = root.viewModel.roomChoices()
                        const roomId = manualRoom.currentIndex >= 0 && manualRoom.currentIndex < rooms.length
                                     ? rooms[manualRoom.currentIndex].id : ""
                        const id = root.viewModel.addManualDevice(manualName.text, manualKind.currentText,
                                                                   roomId, manualProtocol.currentText)
                        if (id.length > 0) {
                            addDeviceDialog.close()
                            Notifications.success(qsTr("Device added"), qsTr("Configure its gateway when hardware is ready."))
                        } else {
                            Notifications.error(qsTr("Could not add device"), qsTr("Check the device name and room."))
                        }
                    }
                }
                StButton { text: qsTr("Cancel"); variant: "secondary"; onClicked: addDeviceDialog.close() }
            }
        }

        T.Overlay.modal: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.55)
        }
    }

    Component {
        id: emptyState

        StPage {
            StEmptyState {
                anchors.fill: parent
                title: qsTr("Looks like you have no spaces set up.")
                detail: qsTr("Add your house and start your smart life!")
                imageSource: "qrc:/qt/qml/SmarTon/Resources/images/illustrations/smart-house-devices.png"
                imageSize: 320
                actionText: qsTr("Set up your space")
                onActionTriggered: root.setUpSpaceRequested()
            }
        }
    }

    Component {
        id: dashboard

        StScrollView {
            id: scroller

            contentHeight: column.implicitHeight + Theme.spacing8 * 2

            // The band bleeds wider than the content column, as measured.
            // One shared margin made the dashboard read as a stack of
            // same-width slabs instead of a band with content inside it.
            Column {
                id: column

                x: Theme.bandBleed
                y: Theme.spacing4
                width: scroller.width - Theme.bandBleed * 2
                spacing: Theme.spacing5

                // ---- header band ------------------------------------------
                StTopBar {
                    width: parent.width
                    title: qsTr("Spaces")
                    
                    trailing: Component {
                        StSpacePicker {
                            spaceName: root.viewModel.spaceName
                            thumbnailSource: root.viewModel.spaceImage
                            // The list and both actions, which the picker has always offered
                            // and nothing ever supplied - so the dropdown showed one
                            // unchanging row and a Create action that did nothing.
                            spaces: root.viewModel.spaces
                            onSpaceSelected: index => {
                                const chosen = root.viewModel.spaces[index];
                                if (chosen !== undefined)
                                    root.viewModel.switchSpace(chosen.spaceId);
                            }
                            onCreateSpaceRequested: root.addSpaceRequested()
                        }
                    }

                    bottomContent: Component {
                        StConditionsStrip {
                            weatherDescription: root.viewModel.weatherDescription
                            temperature: root.viewModel.weatherTemperature
                            humidity: root.viewModel.weatherHumidity
                            allLightsOn: root.viewModel.anyLightOn
                            musicRoom: qsTr("Living room")
                            // Turning everything OFF is asked about; turning
                            // everything on is not. Frame 08 is a confirm
                            // dialog and this is the action it belongs to -
                            // the asymmetry is the point: switching lights on
                            // is trivially undone by looking at the room,
                            // switching them all off in an occupied house is
                            // not, and a one-tap tile is exactly where that
                            // happens by accident.
                            onLightsToggled: {
                                if (root.viewModel.anyLightOn)
                                    lightsDialog.open();
                                else
                                    root.viewModel.setAllLights(true);
                            }
                        }
                    }
                }

                // ---- devices ----------------------------------------------
                // Inset from the band by the measured bleed, so the content
                // column is narrower than the band above it.
                Row {
                    x: Theme.pageMargin - Theme.bandBleed
                    spacing: Theme.spacing3

                    StLabel {
                        text: qsTr("Your Devices")
                        level: 3
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StCountPill {
                        value: root.viewModel.deviceCount
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StButton {
                        text: qsTr("Add device")
                        iconName: "plus"
                        variant: "secondary"
                        visible: root.viewModel.canInstall
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: addDeviceDialog.open()
                    }
                }

                Grid {
                    id: deviceGrid

                    x: Theme.pageMargin - Theme.bandBleed
                    width: parent.width - (Theme.pageMargin - Theme.bandBleed) * 2
                    columns: 3
                    columnSpacing: Theme.cardGap    // measured 25 of 1440
                    rowSpacing: Theme.cardGapV      // measured 28 of 1440

                    readonly property real cellWidth:
                        (deviceGrid.width - deviceGrid.columnSpacing * (deviceGrid.columns - 1))
                        / deviceGrid.columns

                    Repeater {
                        model: root.viewModel.devices

                        // `required property var model` rather than one
                        // required property per role: StDeviceCard already HAS
                        // a `name`, so `required property string name` would
                        // shadow it and `name: name` would bind the property
                        // to itself. Going through `model` cannot collide.
                        delegate: StDeviceCard {
                            required property var model
                            required property int index

                            width: deviceGrid.cellWidth
                            // Measured 324 x 236. It was 0.75, which made every
                            // card 3 px too tall and the grid one row deeper.
                            height: Math.round(width * 0.728)

                            name: model && model.name !== undefined ? model.name : ""
                            kind: model && model.kind !== undefined ? model.kind : ""
                            roomName: model && model.roomName !== undefined ? model.roomName : ""
                            imageSource: root.viewModel.imageUrl(model && model.image !== undefined ? model.image : "")
                            on: model && model.isOn !== undefined ? model.isOn : false
                            pending: model && model.isPending !== undefined ? model.isPending : false
                            unreachable: model && model.isReachable !== undefined ? !model.isReachable : false
                            stale: model && model.isStale !== undefined ? model.isStale : true
                            commandState: model && model.commandState !== undefined ? model.commandState : "idle"
                            operable: root.viewModel.canOperate
                            battery: model && model.battery !== undefined ? model.battery : -1
                            batteryLowAt: root.viewModel.lowBatteryThreshold

                            onToggled: requested =>
                                root.viewModel.devices.setPower(index, requested)
                            onActivated: root.deviceRequested(model.deviceId)
                        }
                    }
                }

                // ---- members and the space map ------------------------------
                // Frame 07's bottom row: two outlined half-width cards side by
                // side. A Row, not two Column children with computed x - the
                // second card used to be positioned by arithmetic against the
                // first, which is a layout that breaks the moment either card
                // changes height.
                Row {
                    id: bottomCards

                    x: Theme.pageMargin - Theme.bandBleed
                    width: parent.width - (Theme.pageMargin - Theme.bandBleed) * 2
                    spacing: Theme.cardGap

                    StCard {
                        width: (bottomCards.width - bottomCards.spacing) / 2
                        height: 118
                        outlined: true
                        interactive: true
                        onClicked: root.membersRequested()

                        StLabel {
                            id: membersTitle
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: Theme.spacing5
                            text: qsTr("Members")
                            level: 2
                            font.weight: Theme.fontWeightMedium
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacing5
                            anchors.top: membersTitle.bottom
                            anchors.topMargin: Theme.spacing3
                            spacing: -Theme.spacing3   // overlapping avatars, as designed

                            Repeater {
                                model: root.viewModel.members

                                delegate: StAvatar {
                                    required property var model

                                    size: 40
                                    name: model.name
                                    source: model.avatar
                                    // The ring is what separates overlapping
                                    // avatars; without it the row reads as one
                                    // blob at this spacing.
                                    ringColor: Theme.surface
                                    ringWidth: 2
                                    showPresence: model.online
                                    online: model.online
                                }
                            }

                            StIconButton {
                                glyph: "plus"
                                size: 40
                                radius: 20
                                fill: "transparent"
                                borderColor: Theme.outline
                                borderWidth: Theme.borderWidth
                                stroke: Theme.textSecondary
                                onClicked: root.membersRequested()
                            }
                        }
                    }

                    /*!
                        Frame 07's second half-width card, and the way into the
                        map (frame 09).

                        The thumbnail is the USER'S PLAN, drawn in preview mode -
                        the same squarified layout the map page draws, at 170 px
                        with the captions and pins off. The frame shows a stock
                        line drawing of a house, which would be a picture of
                        someone else's home on a card that offers to show you
                        yours.
                    */
                    StCard {
                        width: (bottomCards.width - bottomCards.spacing) / 2
                        height: 118
                        outlined: true
                        interactive: true
                        onClicked: root.spaceMapRequested()

                        Column {
                            anchors.left: parent.left
                            anchors.right: planThumb.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.spacing5
                            anchors.rightMargin: Theme.spacing4
                            spacing: Theme.spacing2

                            StLabel {
                                width: parent.width
                                text: qsTr("Your space map")
                                level: 2
                                font.weight: Theme.fontWeightMedium
                            }

                            StLabel {
                                width: parent.width
                                text: qsTr("See your rooms and all the devices that are related to them.")
                                level: 1
                                tone: "secondary"
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                                maximumLineCount: 2
                            }
                        }

                        StFloorPlan {
                            id: planThumb

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: Theme.spacing5
                            width: 170
                            height: parent.height - Theme.spacing5 * 2
                            preview: true
                            gap: 4
                            // Ground floor only. The card is one rectangle set; a
                            // three-storey house drawn as one plan would show
                            // rooms side by side that are on top of each other.
                            rooms: root.planPreview.filter(
                                r => (r.floor === undefined ? 0 : r.floor) === 0)
                        }
                    }
                }
            }
        }
    }
}
