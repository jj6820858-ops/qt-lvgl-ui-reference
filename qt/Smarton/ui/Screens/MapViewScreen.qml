import QtQuick
import QtQuick.Controls.Basic as QQC
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Layouts
import SmarTon.Ui.Components

/*!
    \qmltype MapViewScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief The space from above, with every device under it. Figma frame 09.

    Frame 09 is not frame 18 with a different toggle position. It is a page of
    its own, opened from the Spaces dashboard's "Your space map" card: the
    sidebar stays on Spaces, the header carries a back arrow, and BELOW the
    plan it lists every device in the space - which the Rooms screen's map
    half does not.

    That row is the reason the page exists. The plan answers "where are my
    rooms"; the row under it answers "and what is on right now", and the two
    together are the closest thing SmarTon has to a status board. Both halves
    operate the house directly - a room opens, a pin opens its device, and a
    card's switch turns it on without leaving the page.
*/
Item {
    id: root

    /*! smarton::models::HomeViewModel. */
    required property var viewModel

    /*! True only when this screen was pushed onto something that can be
        popped. Read from the live StackView depth, not asserted: a back arrow
        that does nothing teaches people the app ignores them. */
    readonly property bool canGoBack:
        QQC.StackView.view !== null && QQC.StackView.view.depth > 1

    signal backRequested()
    /*! The Rooms destination. Emitted rather than navigated to, because this
        screen does not own the sidebar - see ShellScreen. */
    signal roomsRequested()
    signal roomRequested(string roomId)
    signal deviceRequested(string deviceId)
    signal addRoomRequested()
    /*! The picker's "Create a new space" row. */
    signal addSpaceRequested()

    StScrollView {
        id: scroller

        anchors.fill: parent
        contentHeight: column.implicitHeight + Theme.spacing8 * 2

        Column {
            id: column

            // The band bleeds wider than the content column, as measured on
            // the frame - the same relationship the dashboard has.
            x: Theme.bandBleed
            y: Theme.spacing4
            width: scroller.width - Theme.bandBleed * 2
            spacing: Theme.spacing5

            // ---- header band ------------------------------------------------
            StTopBar {
                width: parent.width
                showBack: root.canGoBack
                eyebrow: root.viewModel.spaceName
                title: qsTr("Map view")
                onBackRequested: root.backRequested()

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
                        // No confirm dialog here, unlike the dashboard: this
                        // page shows every device's state at once, so an
                        // accidental all-off is visible the instant it happens
                        // and undoing it is one tap away in the row below.
                        onLightsToggled: root.viewModel.setAllLights(
                                             !root.viewModel.anyLightOn)
                    }
                }
            }

            // ---- rooms header -------------------------------------------------
            Item {
                x: Theme.pageMargin - Theme.bandBleed
                width: parent.width - (Theme.pageMargin - Theme.bandBleed) * 2
                height: 44

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing3

                    StLabel {
                        text: qsTr("Your Rooms")
                        level: 3
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StCountPill {
                        value: root.viewModel.roomCount
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StSegmentedControl {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    model: [qsTr("Map view"), qsTr("List view")]
                    currentIndex: 0
                    // The list of rooms IS the Rooms destination, and it has a
                    // sidebar entry of its own. Drawing a second copy of it
                    // here would give the app two Rooms lists that can drift;
                    // going there is the same result with one implementation.
                    onSelected: index => { if (index === 1) root.roomsRequested(); }
                }
            }

            // ---- the plan -----------------------------------------------------
            StRoomMap {
                id: map

                x: Theme.pageMargin - Theme.bandBleed
                width: parent.width - (Theme.pageMargin - Theme.bandBleed) * 2
                // See RoomsScreen: walking wants every pixel it can get.
                // See RoomsScreen: bounded by the screen, not the design.
                height: map.immersive ? Math.max(360, root.height - 150)
                                      : Math.min(460, root.height - 200)

                Behavior on height {
                    NumberAnimation { duration: Theme.durationNormal
                                      easing.type: Easing.OutCubic }
                }

                // Pushed once per model change, not bound: floorPlan() walks
                // every device to group them by room, and a binding would
                // re-run that walk on every resize frame.
                function refresh(): void {
                    map.rooms = root.viewModel.floorPlan();
                    map.floors = root.viewModel.floors();
                }

                Component.onCompleted: map.refresh()

                Connections {
                    target: root.viewModel
                    function onCountsChanged() { map.refresh(); }
                    function onSpaceChanged()  { map.refresh(); }
                    function onRoomChanged()   { map.refresh(); }
                    // The pins, the furniture and the lamp lights are baked
                    // into the plan rows rather than bound to the device
                    // model, so a device changing state has to be pushed in.
                    //
                    // It rebuilds every delegate in the scene to do it, which
                    // is a visible hitch on an RK3328 and the honest cost of a
                    // JS-array model. The fix is a real QAbstractListModel for
                    // the plan; until then a stutter when a lamp is switched
                    // beats pins that quietly show yesterday's state.
                    function onDeviceChanged() { map.refresh(); }
                }

                onRoomActivated: roomId => root.roomRequested(roomId)
                onDeviceActivated: deviceId => root.deviceRequested(deviceId)
                onDeviceToggleRequested: deviceId =>
                    root.viewModel.toggleDevicePower(deviceId)
                onAddRoomRequested: root.addRoomRequested()
            }

            // ---- every device in the space --------------------------------------
            Row {
                x: Theme.pageMargin - Theme.bandBleed
                spacing: Theme.spacing3

                StLabel {
                    text: qsTr("Devices")
                    level: 3
                    anchors.verticalCenter: parent.verticalCenter
                }

                StCountPill {
                    value: root.viewModel.deviceCount
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            /*!
                A scrolling row, not a grid.

                The frame runs the cards off the right edge, and that is the
                right shape for it: this is a strip under a map, not the
                Devices page. It is clipped at the panel edge so the cut-off
                card reads as "there are more" rather than as a card escaping
                the window.
            */
            ListView {
                id: deviceRow

                width: parent.width
                height: 214
                orientation: ListView.Horizontal
                spacing: Theme.cardGap
                boundsBehavior: Flickable.StopAtBounds
                pixelAligned: true
                clip: true
                visible: root.viewModel.deviceCount > 0
                leftMargin: Theme.pageMargin - Theme.bandBleed
                rightMargin: Theme.pageMargin - Theme.bandBleed
                model: root.viewModel.devices

                delegate: StDeviceCard {
                    required property var model
                    required property int index

                    width: 294
                    height: deviceRow.height
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
                    onRenamed: newName =>
                        root.viewModel.devices.rename(index, newName)
                }
            }

            StEmptyState {
                width: parent.width
                // An explicit height: StEmptyState centres itself in the box
                // it is given and has no implicit size of its own, so in a
                // Column it would be 320 px of nothing without this.
                height: 320
                visible: root.viewModel.deviceCount === 0
                title: qsTr("No devices in this space yet.")
                detail: qsTr("Link the devices around you and they appear here, and on the map inside the room they belong to.")
                imageSource: "qrc:/qt/qml/SmarTon/Resources/images/illustrations/smart-house-devices.png"
                imageSize: 200
            }
        }
    }
}
