import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Layouts
import SmarTon.Ui.Components

/*!
    \qmltype RoomsScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief The Rooms destination. Figma frame 18.

    Same header band as the dashboard, then a Map view / List view segmented
    control over a grid of room cards.

    THE MAP IS GENERATED, not drawn. The frame shows an isometric house
    diagram keyed to a floor plan SmarTon has no data for - the model holds
    names and areas, not geometry - so rather than ship a picture that ignores
    the user's actual rooms, \l StRoomMap lays the rooms out in proportion to
    their area and pins each room's devices inside it. See ADR-0016 for what
    that does and does not claim to know.
*/
Item {
    id: root

    /*! smarton::models::HomeViewModel. */
    required property var viewModel

    property int viewIndex: 1        // 0 map, 1 list — list is the default

    signal roomRequested(string roomId)
    /*! A device pin on the map was tapped. */
    signal deviceRequested(string deviceId)

    signal editRoomRequested(string roomId)
    signal addRoomRequested()
    /*! The picker's "Create a new space" row. */
    signal addSpaceRequested()

    StScrollView {
        id: scroller

        anchors.fill: parent
        contentHeight: column.implicitHeight + Theme.spacing8 * 2

        Column {
            id: column

            x: Theme.bandBleed
            y: Theme.spacing4
            width: scroller.width - Theme.bandBleed * 2
            spacing: Theme.spacing5

            StTopBar {
                width: parent.width
                title: qsTr("Rooms")

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
                        onLightsToggled:
                            root.viewModel.setAllLights(!root.viewModel.anyLightOn)
                    }
                }
            }

            // ---- section heading + view switch ---------------------------
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

                StButton {
                    id: addRoomButton
                    anchors.right: viewSwitch.left
                    anchors.rightMargin: Theme.spacing3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 200
                    variant: "secondary"
                    iconName: "plus"
                    text: qsTr("Add new rooms")
                    // Adding a room is administration. Hidden, not disabled:
                    // an action a Viewer will never be able to take is not
                    // information, it is furniture.
                    visible: root.viewModel.canAdminister
                    onClicked: root.addRoomRequested()
                }

                StSegmentedControl {
                    id: viewSwitch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    model: [qsTr("Map view"), qsTr("List view")]
                    currentIndex: root.viewIndex
                    onSelected: index => root.viewIndex = index
                }
            }

            // ---- list view ------------------------------------------------
            Grid {
                id: roomGrid

                x: Theme.pageMargin - Theme.bandBleed
                width: parent.width - (Theme.pageMargin - Theme.bandBleed) * 2
                columns: 3
                columnSpacing: Theme.cardGap
                rowSpacing: Theme.cardGapV
                visible: root.viewIndex === 1

                readonly property real cellWidth:
                    (roomGrid.width - roomGrid.columnSpacing * (roomGrid.columns - 1))
                    / roomGrid.columns

                Repeater {
                    model: root.viewModel.rooms

                    delegate: StRoomCard {
                        required property var model

                        width: roomGrid.cellWidth
                        height: Math.round(width * 0.74)

                        name: model.name
                        imageSource: root.viewModel.imageUrl(model.image)
                        deviceCount: model.deviceCount
                        areaSqm: model.areaSqm
                        footer: "devices"
                        showEdit: true

                        onActivated: root.roomRequested(model.roomId)
                        onEditRequested: root.editRoomRequested(model.roomId)
                    }
                }
            }

            // ---- map view -------------------------------------------------
            StRoomMap {
                id: mapView

                x: Theme.pageMargin - Theme.bandBleed
                width: parent.width - (Theme.pageMargin - Theme.bandBleed) * 2
                // Taller while walking. Technically the same feature through
                // a 420 px letterbox, and not remotely the same experience:
                // a first-person view is mostly peripheral vision, and this
                // is the only place in the app where the height of a card
                // changes what it is for.
                // Bounded by the screen, not by the design. At 660 on a
                // 600 px panel the walkthrough is inside a Flickable that
                // scrolls it out from under the thumbstick.
                height: mapView.immersive ? Math.max(360, root.height - 150)
                                          : Math.min(420, root.height - 200)
                visible: root.viewIndex === 0

                Behavior on height {
                    NumberAnimation { duration: Theme.durationNormal
                                      easing.type: Easing.OutCubic }
                }

                // Pushed once per model change, not bound: floorPlan() walks
                // every device to group them by room, and a binding would
                // re-run that walk on every resize frame.
                function refresh(): void {
                    mapView.rooms = root.viewModel.floorPlan();
                    mapView.floors = root.viewModel.floors();
                }

                Component.onCompleted: mapView.refresh()

                Connections {
                    target: root.viewModel
                    function onCountsChanged() { mapView.refresh(); }
                    function onSpaceChanged()  { mapView.refresh(); }
                    function onRoomChanged()   { mapView.refresh(); }
                    // The pins, the furniture and the lamp lights are baked
                    // into the plan rows rather than bound to the device
                    // model, so a device changing state has to be pushed in.
                    //
                    // It rebuilds every delegate in the scene to do it, which
                    // is a visible hitch on an RK3328 and the honest cost of a
                    // JS-array model. The fix is a real QAbstractListModel for
                    // the plan; until then a stutter when a lamp is switched
                    // beats pins that quietly show yesterday's state.
                    function onDeviceChanged() { mapView.refresh(); }
                }

                onRoomActivated: roomId => root.roomRequested(roomId)
                onDeviceActivated: deviceId => root.deviceRequested(deviceId)
                onDeviceToggleRequested: deviceId =>
                    root.viewModel.toggleDevicePower(deviceId)
                onAddRoomRequested: root.addRoomRequested()
            }
        }
    }
}
