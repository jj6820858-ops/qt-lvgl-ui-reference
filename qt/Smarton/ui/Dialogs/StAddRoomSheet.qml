import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Layouts

/*!
    \qmltype StAddRoomSheet
    \inqmlmodule SmarTon.Ui.Dialogs
    \brief Right-hand drawer for creating a room. Figma frame 14.

    A side sheet rather than a centred dialog because the design keeps the
    wizard visible behind it - you are adding to a list you can still see, and
    that context is the point.

    Slides in from the right edge. On the 600 px panel the sheet scrolls
    internally rather than shrinking its controls, since the ruler and the
    artwork picker both stop being usable below their designed size.
*/
T.Drawer {
    id: root

    property string roomName: ""
    property real   areaSqm: 20
    property bool   metric: true
    property var    artwork: []
    property int    artworkIndex: 0
    /*! Storey. 0 is the ground floor. Present so a multi-storey home can
        actually be built - without it every room lands on one floor and the
        map's floor support has nothing to show. */
    property int    floor: 0

    readonly property real areaInDisplayUnits:
        root.metric ? root.areaSqm : root.areaSqm * 10.7639

    /*! Emitted with the values to create. */
    signal submitted(string name, real areaSqm, string imageSource, int floor)

    function reset(): void {
        root.roomName = "";
        root.areaSqm = 20;
        root.metric = true;
        root.artworkIndex = 0;
        // NOT reset. Someone adding a first floor is adding several rooms to
        // it, and making them re-pick the storey each time is the kind of
        // thing that makes a form feel hostile.
        // root.floor stays as it was.
    }

    /*!
        Which storey the room goes on.

        A stepper, not a free number field: storeys are a small ordered set and
        the two things anyone does with them are "one up" and "one down". A
        text box would invite "1st" and "ground" as input and then need
        parsing rules for both.
    */
    component StFloorPicker: Row {
        id: picker

        property int floor: 0

        signal floorPicked(int floor)

        spacing: Theme.spacing3

        StLabel {
            text: qsTr("Floor")
            level: 1
            tone: "secondary"
            anchors.verticalCenter: parent.verticalCenter
        }

        StIconButton {
            glyph: "chevronDown"
            size: 40
            accessibleName: qsTr("Down one floor")
            // -2 and 20 match HomeService's clamp. A control that offers a
            // value the service then silently changes is worse than one that
            // stops.
            enabled: picker.floor > -2
            anchors.verticalCenter: parent.verticalCenter
            onClicked: picker.floorPicked(picker.floor - 1)
        }

        StLabel {
            text: picker.floor === 0 ? qsTr("Ground")
                : picker.floor < 0   ? (picker.floor === -1 ? qsTr("Basement")
                                        : qsTr("Basement %1").arg(-picker.floor))
                                     : qsTr("Floor %1").arg(picker.floor)
            level: 1
            font.weight: Theme.fontWeightMedium
            anchors.verticalCenter: parent.verticalCenter
        }

        StIconButton {
            glyph: "chevronUp"
            size: 40
            accessibleName: qsTr("Up one floor")
            enabled: picker.floor < 20
            anchors.verticalCenter: parent.verticalCenter
            onClicked: picker.floorPicked(picker.floor + 1)
        }
    }

    edge: Qt.RightEdge
    width: 540
    height: parent ? parent.height : 600
    modal: true
    dragMargin: 0            // opened programmatically, never by an edge swipe

    background: Rectangle {
        color: Theme.surfaceDeep
        border.width: Theme.borderWidth
        border.color: Theme.outline
    }

    T.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    contentItem: Item {
        Item {
            id: sheetHeader

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 76

            StLabel {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacing6
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Add a room")
                level: 2
                font.weight: Theme.fontWeightBold
            }

            StIconButton {
                glyph: "close"
                size: 40
                accessibleName: qsTr("Close")
                fill: "transparent"
                stroke: Theme.textSecondary
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing5
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.close()
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.outline
                opacity: 0.5
            }
        }

        StScrollView {
            id: sheetScroller

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: sheetHeader.bottom
            anchors.bottom: submitButton.top
            anchors.margins: Theme.spacing5
            contentHeight: sheetColumn.implicitHeight

            Column {
                id: sheetColumn

                width: sheetScroller.width
                spacing: Theme.spacing4

                // ---- artwork ------------------------------------------------
                Rectangle {
                    width: parent.width
                    height: 180
                    radius: Theme.radiusSm
                    color: Theme.surface
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.artworkIndex < root.artwork.length
                                ? root.artwork[root.artworkIndex].url : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 1080
                        smooth: true
                        asynchronous: true
                    }

                    // Cycles the shipped artwork. There is no file picker,
                    // because there is no filesystem the user can browse on
                    // the panel - offering one would offer nothing.
                    StIconButton {
                        glyph: "image"
                        size: 44
                        accessibleName: qsTr("Change room artwork")
                        fill: Theme.textPrimary
                        stroke: Theme.primary
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacing3
                        onClicked: root.artworkIndex =
                            (root.artworkIndex + 1) % Math.max(1, root.artwork.length)
                    }
                }

                StLabel { text: qsTr("What's your room name?"); level: 1; tone: "secondary" }

                StTextField {
                    id: nameField
                    width: parent.width
                    text: root.roomName
                    placeholderText: qsTr("Living room")
                    onTextChanged: root.roomName = nameField.text
                }

                StLabel { text: qsTr("What's your room size?"); level: 1; tone: "secondary" }

                Row {
                    spacing: Theme.spacing3

                    StRadioOption {
                        text: qsTr("size in m²")
                        checked: root.metric
                        onClicked: root.metric = true
                    }

                    StRadioOption {
                        text: qsTr("size in ft²")
                        checked: !root.metric
                        onClicked: root.metric = false
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    StLabel {
                        text: String(Math.round(root.areaInDisplayUnits))
                        level: 4
                        tone: "brand"
                        anchors.baseline: unitLabel.baseline
                    }
                    StLabel {
                        id: unitLabel
                        text: root.metric ? qsTr("m²") : qsTr("ft²")
                        level: 1
                        tone: "brand"
                    }
                }

                StRuler {
                    width: parent.width
                    from: 1
                    to: 60
                    value: root.areaSqm
                    onMoved: next => root.areaSqm = next
                }

                StTextField {
                    id: areaField
                    width: parent.width
                    text: String(Math.round(root.areaInDisplayUnits))
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 5000 }
                    onEditingFinished: {
                        const entered = parseInt(areaField.text, 10);
                        if (!isNaN(entered))
                            root.areaSqm = root.metric ? entered : entered / 10.7639;
                    }
                }

                Item { width: 1; height: Theme.spacing2 }
            }
        }

        StFloorPicker {
            id: floorPicker

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: submitButton.top
            anchors.margins: Theme.spacing5
            anchors.bottomMargin: Theme.spacing4
            floor: root.floor
            onFloorPicked: next => root.floor = next
        }

        StButton {
            id: submitButton

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacing5
            text: qsTr("Continue")
            enabled: root.roomName.trim().length > 0
            onClicked: {
                root.submitted(root.roomName, root.areaSqm,
                               root.artworkIndex < root.artwork.length
                                   ? root.artwork[root.artworkIndex].image : "",
                               root.floor);
                root.close();
            }
        }
    }
}
