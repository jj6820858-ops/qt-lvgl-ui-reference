import QtQuick
import SmarTon.Backend
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StRoomMap
    \inqmlmodule SmarTon.Ui.Components
    \brief The space seen from above - or from inside. Frames 09 and 18.

    EXTRACTED, NOT NEW. Frames 09 and 18 both show this surface - 09 as a page
    of its own under Spaces, 18 as one half of the Rooms view switch - and it
    was written inside RoomsScreen, where the second caller could not reach it.
    Two copies of a Loader that pulls in an optional 3D module by URL is
    exactly the kind of duplication that ends with one copy fixed and one not.

    It takes the PLAN, not the view model: the caller decides when walking
    every device to group them by room is worth doing, which is once per model
    change and never per resize frame.

    THE CONTROLS HAVE THEIR OWN BAND. They used to float in the card's
    top-right corner over whichever view was showing, and over the 2D plan
    that was a bug you could get stuck in: the plan's room rectangles fill the
    card, the toggle sat on top of one of them, and the two fought for every
    tap near that corner - so switching to 2D could leave you unable to switch
    back. Reserving a strip for them costs 56 px and removes the whole class
    of problem, which is the right trade for a control whose entire job is to
    be reachable.
*/
Item {
    id: root

    /*! Rows from HomeViewModel::floorPlan(). */
    property var rooms: []
    /*! Storeys present, from HomeViewModel::floors(). */
    property var floors: [0]
    /*! 3D when this build has Quick3D, unless the caller says otherwise. On
        one storey the 2D plan is genuinely easier to read, so the toggle stays
        available rather than 3D being the only option once it exists. */
    property bool use3D: Capabilities.mapView3D
    /*! -1 shows every storey; otherwise the others dim. */
    property int highlightedFloor: -1
    /*! Selected room, shared by both views. */
    property string selectedRoomId: ""

    /*! section | full. Waist-height sectioning walls, or walls to the ceiling. */
    property string wallMode: "section"
    /*! orbit | walk. Walking is 3D only, for reasons that should not need
        stating and did anyway: there is no inside of a floor plan. */
    property string cameraMode: "orbit"
    /*! Storey separation for the exploded view. Index into \l explodeSteps. */
    property int explodeStep: 0
    readonly property var explodeSteps: [0, 80, 190]

    /*! True while the map wants the whole screen it can get - the caller
        decides whether to give it. Walking a house through a 420 px letterbox
        is technically the same feature and a different experience. */
    readonly property bool immersive: root.cameraMode === "walk"

    signal roomActivated(string roomId)
    signal deviceActivated(string deviceId)
    /*! A device marker was held rather than tapped. */
    signal deviceToggleRequested(string deviceId)
    signal addRoomRequested()

    /*!
        A storey's name.

        Built here rather than stored, because the NUMBER is the fact and the
        wording is a local convention: a US first floor is a UK ground floor,
        and a translated label is not something to sort or stack by.
    */
    function floorLabel(floor: int): string {
        if (floor === 0)
            return qsTr("Ground");
        if (floor < 0)
            return floor === -1 ? qsTr("Basement")
                                : qsTr("Basement %1").arg(-floor);
        return qsTr("Floor %1").arg(floor);
    }

    StCard {
        anchors.fill: parent
        color: Theme.surfaceDeep
        visible: root.rooms.length > 0

        // ---- the control band ------------------------------------------------
        // Its own strip, above the view rather than over it. See the class docs.
        Item {
            id: controlBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacing3
            height: 50

            // Walking, the pad owns the screen and the only control that still
            // makes sense up here is the way out.
            StButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: root.cameraMode === "walk"
                width: 190
                variant: "secondary"
                iconName: "back"
                text: qsTr("Leave the house")
                onClicked: root.cameraMode = "orbit"
            }

            Flow {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.cameraMode !== "walk"
                spacing: Theme.spacing3
                layoutDirection: Qt.RightToLeft

                StButton {
                    // 3D only: there is no inside of a floor plan.
                    visible: root.use3D && Capabilities.mapView3D
                    width: 150
                    variant: "secondary"
                    iconName: "home"
                    text: qsTr("Walk in")
                    onClicked: root.cameraMode = "walk"
                }

                StSegmentedControl {
                    // Hidden entirely when the build has no Quick3D: a toggle
                    // with one reachable state is noise.
                    visible: Capabilities.mapView3D
                    model: [qsTr("3D"), qsTr("2D")]
                    currentIndex: root.use3D ? 0 : 1
                    onSelected: index => root.use3D = index === 0
                }

                StSegmentedControl {
                    // The section height. Full-height walls hide the devices
                    // from above, which is the whole reason the default cuts
                    // them at the waist - so it is offered, not imposed.
                    visible: root.use3D && Capabilities.mapView3D
                    model: [qsTr("Section"), qsTr("Walls")]
                    currentIndex: root.wallMode === "full" ? 1 : 0
                    onSelected: index => root.wallMode = index === 1 ? "full" : "section"
                }

                StSegmentedControl {
                    // Separating the storeys of a bungalow separates nothing,
                    // so this appears only when there is a stack to pull apart.
                    visible: root.use3D && Capabilities.mapView3D
                             && root.floors.length > 1
                    model: [qsTr("Stacked"), qsTr("Split"), qsTr("Exploded")]
                    currentIndex: root.explodeStep
                    onSelected: index => root.explodeStep = index
                }

                // Only when there is more than one storey. A floor picker over
                // a bungalow is a control with one meaningful state.
                StSegmentedControl {
                    visible: root.floors.length > 1
                    model: {
                        const labels = [qsTr("All")];
                        for (let i = 0; i < root.floors.length; ++i)
                            labels.push(root.floorLabel(root.floors[i]));
                        return labels;
                    }
                    currentIndex: root.highlightedFloor === -1
                                  ? 0 : root.floors.indexOf(root.highlightedFloor) + 1
                    onSelected: index => root.highlightedFloor =
                        index === 0 ? -1 : root.floors[index - 1]
                }
            }
        }

        // ---- the view ---------------------------------------------------------
        Item {
            id: viewArea

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: controlBar.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacing3
            anchors.topMargin: Theme.spacing2
            clip: true

            // The 3D view is loaded by URL, not imported.
            //
            // Its module only exists in builds that found Quick3D, and an
            // `import SmarTon.Ui.Map3D` at the top of this file would make the
            // WHOLE component fail to load on a build without it - which is
            // the opposite of a graceful fallback. A Loader with a source
            // string is the only shape QML offers for an optional dependency.
            Loader {
                id: view3D

                anchors.fill: parent
                active: root.use3D && Capabilities.mapView3D
                source: active ? "qrc:/qt/qml/SmarTon/Ui/Map3D/StFloorPlan3D.qml" : ""

                onLoaded: {
                    view3D.item.rooms = Qt.binding(() => root.rooms);
                    view3D.item.floors = Qt.binding(() => root.floors);
                    view3D.item.activeFloor = Qt.binding(() => root.highlightedFloor);
                    view3D.item.wallMode = Qt.binding(() => root.wallMode);
                    view3D.item.cameraMode = Qt.binding(() => root.cameraMode);
                    view3D.item.floorSeparation =
                        Qt.binding(() => root.explodeSteps[root.explodeStep]);
                    // Two-way on the selection: the 3D view sets it when a room
                    // is picked, and the 2D plan has to agree when you switch
                    // back. A plain binding one way would be overwritten by the
                    // first pick and never recover.
                    view3D.item.selectedRoomId = root.selectedRoomId;
                    view3D.item.selectedRoomIdChanged.connect(
                        () => root.selectedRoomId = view3D.item.selectedRoomId);
                    view3D.item.roomActivated.connect(root.roomActivated);
                    view3D.item.deviceActivated.connect(root.deviceActivated);
                    view3D.item.deviceToggleRequested.connect(root.deviceToggleRequested);
                }
            }

            StFloorPlan {
                anchors.fill: parent
                visible: !view3D.active
                selectedRoomId: root.selectedRoomId
                // The 2D plan draws ONE storey. It has no way to show which
                // rooms are above which, so it shows the highlighted floor and
                // the floor strip picks it.
                rooms: root.rooms.filter(
                    r => root.highlightedFloor === -1
                         || (r.floor === undefined ? 0 : r.floor) === root.highlightedFloor)
                onRoomActivated: roomId => {
                    root.selectedRoomId = roomId;
                    root.roomActivated(roomId);
                }
                onDeviceActivated: deviceId => root.deviceActivated(deviceId)
            }
        }
    }

    // Only when there is genuinely nothing to draw. The plan is generated from
    // area, so any room at all produces one.
    StEmptyState {
        anchors.fill: parent
        visible: root.rooms.length === 0
        title: qsTr("No rooms to map yet.")
        detail: qsTr("The map lays your rooms out in proportion to their floor area and pins each room's devices inside it. Add a room and it appears here.")
        imageSource: "qrc:/qt/qml/SmarTon/Resources/images/illustrations/smart-home.png"
        imageSize: 260
        actionText: qsTr("Add new rooms")
        onActionTriggered: root.addRoomRequested()
    }

    // 3D is where walking lives, so dropping to the plan has to leave it.
    onUse3DChanged: if (!root.use3D) root.cameraMode = "orbit"

    // The selection travels BOTH ways between the two views, which is why it
    // is pushed rather than bound: the 3D view writes to its own property when
    // a room is picked, and a one-way binding would be destroyed by the first
    // pick and never recover.
    onSelectedRoomIdChanged: {
        if (view3D.item !== null)
            view3D.item.selectedRoomId = root.selectedRoomId;
    }
}
