import QtQuick
import QtQuick.Controls.Basic as QQC
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Layouts
import SmarTon.Ui.Components

/*!
    \qmltype RoomOverviewScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief One room and its devices. Figma frame 19.

    Pushed onto the shell's stack rather than replacing it, so the back arrow
    and Escape both return to the room list.

    The room is addressed by ID, never by a copied record: the dashboard can
    still be toggling a device in this room while this screen is open, so the
    screen re-reads what it needs whenever the view model says that room or
    one of its devices changed.
*/
Item {
    id: root

    /*!
        True only when this screen was pushed onto something that can be
        popped.

        Read from the enclosing StackView's LIVE depth rather than hard-coded.
        Every screen with a back arrow used to assert it unconditionally,
        including the ones the sidebar opens as a root destination - so Members
        and Statistics drew a back button that could not do anything, and
        pressing it did nothing at all. A control that is visible and inert is
        worse than one that is absent: it teaches people the app ignores them.

        The attached property resolves because THIS item is what was pushed;
        it is null in the gallery, where screens are shown outside a stack.
    */
    readonly property bool canGoBack:
        QQC.StackView.view !== null && QQC.StackView.view.depth > 1

    /*! smarton::models::HomeViewModel. */
    required property var viewModel
    required property string roomId

    property var roomData: ({})

    signal backRequested()
    signal deviceRequested(string deviceId)

    function reload(): void {
        root.roomData = root.viewModel.room(root.roomId);
    }

    Component.onCompleted: {
        root.viewModel.setRoomFilter(root.roomId);
        root.reload();
    }

    Connections {
        target: root.viewModel
        function onRoomChanged(changedId) {
            if (changedId === root.roomId)
                root.reload();
        }
    }

    /*!
        Which of the two room designs to show.

        Frames 19 and 20 are the same room two ways - cards on the page
        ground, and the room photographed with its devices pinned onto it.
        Both are real frames and neither supersedes the other: a photograph is
        faster to RECOGNISE and a list is faster to SCAN, and which one you
        want depends on whether you know what you are looking for. So it is a
        view mode, the same shape as map-vs-list on the Rooms screen.
    */
    property bool photoView: true

    // ---- frame 20: the room as a photograph -----------------------------
    Item {
        // No page margin. Frame 20's photograph is full bleed - it starts at
        // the sidebar and runs off the right and top of the window - so the
        // margin every other screen carries would frame the room in a dark
        // gutter the design does not have.
        anchors.fill: parent
        visible: root.photoView

        StTopBar {
            id: photoHeader

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            // The bar carries its own 20 px inset, and the frame puts the back
            // button 40 from the panel edge; the difference is this margin.
            anchors.leftMargin: Theme.spacing5
            anchors.rightMargin: Theme.spacing5
            // Transparent: the photograph IS the header background in this
            // frame, and a band over it would cut the room in half.
            transparent: true
            showBack: root.canGoBack
            eyebrow: root.viewModel.spaceName
            title: root.roomData.name === undefined ? "" : root.roomData.name
            onBackRequested: root.backRequested()
            z: 2

            trailing: Component {
                StSegmentedControl {
                    model: [qsTr("Photo"), qsTr("List")]
                    currentIndex: root.photoView ? 0 : 1
                    onSelected: index => root.photoView = index === 0
                }
            }
        }

        StRoomPhotoView {
            anchors.fill: parent
            room: root.roomData
            devices: root.viewModel.roomDevices
            // The device LIST MODEL hands out imageSource unresolved, unlike
            // HomeViewModel::room(), which resolves it. Every other screen
            // resolves it at the call site; so does this one.
            imageUrlFor: path => root.viewModel.imageUrl(path)
            operable: root.viewModel.canOperate
            // Keeps the pins out from under the transparent bar drawn on top.
            topInset: photoHeader.height
            onDeviceActivated: deviceId => root.deviceRequested(deviceId)
            onDevicePowerToggled: (deviceId, on) =>
                root.viewModel.setDevicePower(deviceId, on)
        }
    }

    StScrollView {
        id: scroller

        anchors.fill: parent
        visible: !root.photoView
        contentHeight: column.implicitHeight + Theme.spacing8 * 2

        Column {
            id: column

            x: Theme.bandBleed
            y: Theme.spacing4
            width: scroller.width - Theme.bandBleed * 2
            spacing: Theme.spacing5

            // ---- header band ------------------------------------------------
            StTopBar {
                id: header

                width: parent.width
                showBack: root.canGoBack
                eyebrow: root.viewModel.spaceName
                title: root.roomData.name === undefined ? "" : root.roomData.name
                onBackRequested: root.backRequested()

                trailing: Component {
                    StSegmentedControl {
                        model: [qsTr("Photo"), qsTr("List")]
                        currentIndex: root.photoView ? 0 : 1
                        onSelected: index => root.photoView = index === 0
                    }
                }

                // The room photograph bleeds off the right edge of the band,
                // masked by the band's own corner radius.
                Image {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * 0.28
                    source: root.roomData.image === undefined ? "" : root.roomData.image
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 600
                    smooth: true
                    asynchronous: true
                    opacity: 0.9
                }

                bottomContent: Component {
                    Row {
                        spacing: Theme.spacing3

                        StAmbientCard {
                            glyph: "temperature"
                            caption: qsTr("Current temperature\nin the %1")
                                        .arg(root.roomData.name === undefined
                                             ? "" : root.roomData.name)
                            value: qsTr("%1°").arg(root.roomData.temperature === undefined
                                                   ? 0 : root.roomData.temperature)
                        }

                        StAmbientCard {
                            glyph: "humidity"
                            caption: qsTr("Current humidity\nin the %1")
                                        .arg(root.roomData.name === undefined
                                             ? "" : root.roomData.name)
                            value: qsTr("%1%").arg(root.roomData.humidity === undefined
                                                   ? 0 : root.roomData.humidity)
                        }
                    }
                }
            }

            // ---- rename ------------------------------------------------------
            StEditableLabel {
                text: root.roomData.name === undefined ? "" : root.roomData.name
                level: 3
                onCommitted: name => root.viewModel.renameRoom(root.roomId, name)
            }

            // ---- devices -----------------------------------------------------
            Row {
                x: Theme.pageMargin - Theme.bandBleed
                spacing: Theme.spacing3

                StLabel {
                    text: qsTr("Your Devices")
                    level: 3
                    anchors.verticalCenter: parent.verticalCenter
                }

                StCountPill {
                    value: root.viewModel.roomDevices.count
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Grid {
                id: deviceGrid

                x: Theme.pageMargin - Theme.bandBleed
                width: parent.width - (Theme.pageMargin - Theme.bandBleed) * 2
                columns: 3
                columnSpacing: Theme.cardGap
                rowSpacing: Theme.cardGapV

                readonly property real cellWidth:
                    (deviceGrid.width - deviceGrid.columnSpacing * (deviceGrid.columns - 1))
                    / deviceGrid.columns

                Repeater {
                    id: roomDevices
                    // The room-scoped model, not the full one filtered by
                    // `visible`: an invisible delegate is still constructed,
                    // still binds, and still holds a texture.
                    model: root.viewModel.roomDevices

                    delegate: StDeviceCard {
                        required property var model
                        required property int index

                        width: deviceGrid.cellWidth
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
                            root.viewModel.roomDevices.setPower(index, requested)
                        onActivated: root.deviceRequested(model.deviceId)
                        onRenamed: newName =>
                            root.viewModel.roomDevices.rename(index, newName)
                    }
                }
            }
        }
    }

    // Mini player, pinned bottom-right exactly as frame 19 shows it.
    // Frame 19 ONLY: it lives at screen scope rather than inside the scroller
    // (it is pinned, not scrolled), so it needs the same view-mode gate the
    // scroller carries or it floats over frame 20's ambient footer.
    StMediaCard {
        visible: !root.photoView
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacing6
        width: 420
        mini: true
        track: qsTr("My life")
        artist: qsTr("STRASFERA")
        playing: true
        artworkSource: "qrc:/qt/qml/SmarTon/Resources/images/rooms/living-interior.png"
        onPlayPauseRequested: playing = !playing
    }

    /*! Icon, two-line caption, big brand-coloured reading. Frame 19 only. */
    component StAmbientCard: Rectangle {
        id: ambient

        /*! Icon stem from the set, not a file path. The humidity card was
            pointing at a 48 px PNG that read as an emoji next to a 14 px
            caption; the set has the same glyph on the same grid as everything
            else on this screen. */
        property string glyph: ""
        property string caption: ""
        property string value: ""

        width: 340
        height: 76
        // Measured #35363A on frame 19: white @15% over the band, the same
        // treatment as the conditions strip. Drawn as `surface` it was a
        // different, heavier grey than the design's.
        radius: Theme.radiusXs
        color: Theme.overlaySubtle

        StIcon {
            id: ambientIcon
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing4
            anchors.verticalCenter: parent.verticalCenter
            name: ambient.glyph
            size: 32
            color: Theme.primary
        }

        StLabel {
            anchors.left: ambientIcon.right
            anchors.leftMargin: Theme.spacing4
            anchors.right: ambientValue.left
            anchors.rightMargin: Theme.spacing3
            anchors.verticalCenter: parent.verticalCenter
            text: ambient.caption
            level: 1
            tone: "secondary"
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
        }

        StLabel {
            id: ambientValue
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing5
            anchors.verticalCenter: parent.verticalCenter
            text: ambient.value
            level: 3
            tone: "brand"
        }
    }
}
