import QtQuick
import QtQuick.Controls.Basic as QQC
import SmarTon.Ui.Helpers
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Layouts
import SmarTon.Ui.Components
import SmarTon.Ui.Dialogs

/*!
    \qmltype SpaceWizardScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief "Create a new space", steps 1-7. Figma frames 10 through 17.

    ONE SCREEN, NOT SEVEN. Every frame shares the same three pieces - centred
    header with a step counter, the pale summary card, the bottom action bar -
    and differs only in the middle. Seven screens would mean seven copies of
    that chrome and seven chances for them to drift apart. The step is a
    property; the body is a Loader over it.

    THE STEPS ARE NOT A TRANSACTION. Each step commits as it goes: naming the
    space creates it, adding a room adds it. That is deliberate. A wizard that
    holds everything in memory until a final Done loses the lot when the panel
    is unplugged halfway through, and "Skip" would have to mean "discard".
    Here Skip means "I am done with this step", and closing the wizard early
    leaves exactly what was already made.

    The design numbers seven steps but draws five distinct bodies (10, 12/13,
    16/17, members, 15). Steps 5 and 6 are the members and confirm pages; the
    frames for the two intermediate ones are not in the set, so they are
    folded rather than invented.
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

    property int step: 1
    readonly property int stepCount: 7

    /*! A nearby device was tapped. The customise page (frame 11) names it and
        places it; this screen does not link it itself any more. */
    signal customiseDeviceRequested(string availableId)

    signal finished()
    signal cancelled()

    readonly property var summaryCounts: [
        { value: root.viewModel.roomCount,   noun: qsTr("Rooms"),   accent: Theme.success },
        { value: root.viewModel.deviceCount, noun: qsTr("Devices"), accent: Theme.accentViolet },
        { value: root.viewModel.memberCount, noun: qsTr("Members"), accent: Theme.warning }
    ]

    function back(): void {
        if (root.step > 1)
            root.step -= 1;
        else
            root.cancelled();
    }

    function advance(): void {
        if (root.step < root.stepCount)
            root.step += 1;
        else
            root.finished();
    }

    // ---- chrome -------------------------------------------------------------
    StTopBar {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacing6
        anchors.bottomMargin: 0
        titleRowHeight: 100
        centred: true
        showBack: root.canGoBack
        title: qsTr("Create a new space")
        subtitle: {
            switch (root.step) {
            case 1:  return qsTr("Add the first details");
            case 2:  return qsTr("Where is it?");
            case 3:  return qsTr("Organise your space");
            case 4:  return qsTr("Connect your devices");
            case 5:  return qsTr("Assign your devices");
            case 6:  return qsTr("Invite your household");
            default: return qsTr("Confirm your choices");
            }
        }
        onBackRequested: root.back()

        trailing: Component {
            Column {
                spacing: 0

                StLabel {
                    text: qsTr("Step")
                    level: 1
                    tone: "secondary"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 2
                    anchors.horizontalCenter: parent.horizontalCenter

                    StLabel {
                        text: String(root.step)
                        level: 1
                        font.weight: Theme.fontWeightBold
                    }
                    StLabel { text: "|"; level: 1; tone: "muted" }
                    StLabel { text: String(root.stepCount); level: 1; tone: "secondary" }
                }
            }
        }
    }

    // The summary card appears from step 3, once there is a space to summarise.
    StSummaryHeader {
        id: summary

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.margins: Theme.spacing6
        // Was -Theme.spacing6, which pulled the pale card 24 px UP into the
        // header band so it cut across the bottom of the artwork and sat over
        // the title row's baseline. Whatever that was reaching for, on screen
        // it reads as two panels colliding. A normal gap instead.
        anchors.topMargin: Theme.spacing4
        visible: root.step >= 3 && root.viewModel.hasSpace
        title: root.viewModel.spaceName
        subtitle: root.viewModel.spaceAddress
        thumbnailSource: root.viewModel.spaceImage
        counts: root.summaryCounts
        onRenamed: name => root.viewModel.renameSpace(name)
    }

    Loader {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: summary.visible ? summary.bottom : header.bottom
        anchors.bottom: actions.top
        anchors.margins: Theme.spacing6
        // Each step is a different Component, so focus has to be placed again
        // every time the body swaps - onCurrentItemChanged in the shell only
        // fires once, when the wizard itself is pushed.
        onLoaded: FocusHelper.focusFirstField(body)
        sourceComponent: {
            switch (root.step) {
            case 1:  return nameStep;
            case 2:  return addressStep;
            case 3:  return roomsStep;
            case 4:  return devicesStep;
            case 5:  return assignStep;
            case 6:  return membersStep;
            default: return confirmStep;
            }
        }
    }

    StActionBar {
        id: actions

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacing6
        hint: {
            switch (root.step) {
            case 1:  return qsTr("Name your new space");
            case 2:  return qsTr("Tell us where it is");
            case 3:  return qsTr("Add all your rooms and go to the next step.");
            case 4:  return qsTr("Add all your devices and go to the next step.");
            case 5:  return qsTr("Put each device in a room.");
            case 6:  return qsTr("Invite the people who live here.");
            default: return qsTr("Check all the information and start with your new space.");
            }
        }
        secondaryVisible: root.step >= 3 && root.step < root.stepCount
        primaryText: root.step === root.stepCount ? qsTr("Done") : qsTr("Continue")
        primaryEnabled: root.step !== 1 || nameHolder.value.trim().length > 0
        onSecondaryTriggered: root.advance()
        onPrimaryTriggered: {
            // Step 1 is the only one that has to commit before advancing:
            // everything after it needs a space to attach to.
            if (root.step === 1)
                root.viewModel.createSpace(nameHolder.value, addressHolder.value);
            else if (root.step === 2)
                root.viewModel.setSpaceAddress(addressHolder.value);
            root.advance();
        }
    }

    // Field state outlives the Loader, which destroys the step body whenever
    // the step changes. Holding it here is what makes Back non-destructive.
    QtObject {
        id: nameHolder
        property string value: root.viewModel.spaceName
    }

    QtObject {
        id: addressHolder
        property string value: root.viewModel.spaceAddress
    }

    StAddRoomSheet {
        id: addRoomSheet
        parent: root
        artwork: root.viewModel.roomArtwork()
        onSubmitted: (name, area, image, floor) =>
            root.viewModel.addRoomOnFloor(name, area, image, floor)
    }

    // ---- step 1: name -------------------------------------------------------
    Component {
        id: nameStep

        Item {
            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width, 640)
                spacing: Theme.spacing4

                // StRoundedImage, not a rounded Rectangle with clip:true.
                // `clip` clips to the BOUNDING BOX, never to the corner
                // radius, so the rounded rectangle was drawn and then covered
                // corner-to-corner by a square photograph. Same trap as the
                // avatars; this one survived because a 240 px card reads as
                // "nearly right" at a glance.
                StRoundedImage {
                    width: parent.width
                    height: 240
                    radius: Theme.radiusLg
                    source: "qrc:/qt/qml/SmarTon/Resources/images/rooms/house-exterior.png"
                    fillMode: Image.PreserveAspectCrop
                }

                StLabel {
                    width: parent.width
                    text: qsTr("What's your house name?")
                    level: 1
                    tone: "secondary"
                    horizontalAlignment: Text.AlignHCenter
                }

                StTextField {
                    id: spaceNameField
                    width: parent.width
                    text: nameHolder.value
                    placeholderText: qsTr("My Home")
                    onTextChanged: nameHolder.value = spaceNameField.text
                }

                StLabel {
                    width: parent.width
                    text: qsTr("No inspiration? Try one of these names.")
                    level: 1
                    tone: "secondary"
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacing3

                    Repeater {
                        model: [qsTr("Home"), qsTr("Office"), qsTr("My happy place")]

                        delegate: StChip {
                            required property var modelData
                            text: modelData
                            selected: nameHolder.value === modelData
                            onClicked: nameHolder.value = modelData
                        }
                    }
                }
            }
        }
    }

    // ---- step 2: address ----------------------------------------------------
    Component {
        id: addressStep

        Item {
            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width, 640)
                spacing: Theme.spacing4

                StLabel {
                    width: parent.width
                    text: qsTr("Where is %1?").arg(nameHolder.value)
                    level: 3
                    horizontalAlignment: Text.AlignHCenter
                }

                StLabel {
                    width: parent.width
                    text: qsTr("The address is shown on the space card and nowhere else. It is stored on this device only.")
                    level: 1
                    tone: "secondary"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }

                StTextField {
                    id: addressField
                    width: parent.width
                    text: addressHolder.value
                    placeholderText: qsTr("Street and number")
                    onTextChanged: addressHolder.value = addressField.text
                }
            }
        }
    }

    // ---- step 3: rooms ------------------------------------------------------
    Component {
        id: roomsStep

        Item {
            Item {
                id: roomsHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 56

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StLabel { text: qsTr("Add rooms"); level: 3 }
                    StLabel {
                        text: qsTr("Organize your space by adding and customizing rooms")
                        level: 1
                        tone: "secondary"
                    }
                }

                StButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 220
                    variant: "secondary"
                    iconName: "plus"
                    text: qsTr("Add new rooms")
                    onClicked: {
                        addRoomSheet.reset();
                        addRoomSheet.open();
                    }
                }
            }

            StEmptyState {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: roomsHeader.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: Theme.spacing4
                visible: root.viewModel.roomCount === 0
                title: ""
                detail: qsTr("You have 0 rooms added to your space")
                imageSource: "qrc:/qt/qml/SmarTon/Resources/images/illustrations/empty-spaces.png"
                imageSize: 260
            }

            StScrollView {
                id: roomScroller

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: roomsHeader.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: Theme.spacing4
                visible: root.viewModel.roomCount > 0
                contentHeight: wizardRoomGrid.implicitHeight

                Grid {
                    id: wizardRoomGrid

                    width: roomScroller.width
                    columns: 3
                    columnSpacing: Theme.cardGap
                    rowSpacing: Theme.cardGapV

                    readonly property real cellWidth:
                        (wizardRoomGrid.width
                         - wizardRoomGrid.columnSpacing * (wizardRoomGrid.columns - 1))
                        / wizardRoomGrid.columns

                    Repeater {
                        model: root.viewModel.rooms

                        delegate: StRoomCard {
                            required property var model

                            width: wizardRoomGrid.cellWidth
                            height: Math.round(width * 0.74)
                            name: model.name
                            imageSource: root.viewModel.imageUrl(model.image)
                            areaSqm: model.areaSqm
                            footer: "area"
                            onMenuRequested: root.viewModel.removeRoom(model.roomId)
                        }
                    }
                }
            }
        }
    }

    // ---- step 4: link devices ----------------------------------------------
    Component {
        id: devicesStep

        Item {
            id: devicesStepRoot

            // Snapshotted once per visit: linking removes an entry, and
            // re-reading the list mid-iteration would reshuffle the grid under
            // the finger that just tapped it.
            property var available: root.viewModel.availableDevices()
            /*! Everything already in the space. Only the search panel needs
                it, and only to say "connected" against a name you typed. */
            property var linked: root.viewModel.linkedDevices()

            Connections {
                target: root.viewModel
                function onCountsChanged() {
                    devicesStepRoot.available = root.viewModel.availableDevices();
                    devicesStepRoot.linked = root.viewModel.linkedDevices();
                }
            }

            /*!
                Frame 17b: what the search field finds, across BOTH lists.

                The grid behind it filters in place, which answers "show me the
                lamps". This answers a different question - "is my lamp already
                connected?" - and it can only answer it by looking at devices
                the grid does not contain. That is the whole reason the frame
                draws a panel instead of just filtering.
            */
            readonly property var results: {
                const query = deviceSearch.text.trim().toLowerCase();
                if (query.length === 0)
                    return [];
                const hits = [];
                for (let i = 0; i < devicesStepRoot.linked.length; ++i) {
                    const d = devicesStepRoot.linked[i];
                    if (d.name.toLowerCase().indexOf(query) !== -1)
                        hits.push({ device: d, connected: true });
                }
                for (let j = 0; j < devicesStepRoot.available.length; ++j) {
                    const a = devicesStepRoot.available[j];
                    if (a.name.toLowerCase().indexOf(query) !== -1)
                        hits.push({ device: a, connected: false });
                }
                return hits;
            }

            Item {
                id: devicesHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 56

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StLabel { text: qsTr("Link smart devices"); level: 3 }
                    StLabel {
                        text: qsTr("Current devices nearby")
                        level: 1
                        tone: "secondary"
                    }
                }

                StSearchField {
                    id: deviceSearch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 420
                }
            }

            StScrollView {
                id: deviceScroller

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: devicesHeader.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: Theme.spacing4
                contentHeight: linkGrid.implicitHeight

                Grid {
                    id: linkGrid

                    width: deviceScroller.width
                    columns: 3
                    columnSpacing: Theme.cardGap
                    rowSpacing: Theme.cardGapV

                    readonly property real cellWidth:
                        (linkGrid.width - linkGrid.columnSpacing * (linkGrid.columns - 1))
                        / linkGrid.columns

                    Repeater {
                        model: devicesStepRoot.available

                        delegate: StLinkDeviceCard {
                            required property var modelData

                            width: linkGrid.cellWidth
                            height: Math.round(width * 0.728)
                            name: modelData.name
                            imageSource: modelData.image
                            visible: deviceSearch.text.length === 0
                                     || modelData.name.toLowerCase()
                                        .indexOf(deviceSearch.text.toLowerCase()) !== -1
                            // Opens frame 11 rather than linking here. The
                            // old comment on this line said a room picker on
                            // every card was the only alternative to linking
                            // into the first room; the design's answer is a
                            // page for the one device that was tapped, and
                            // Skip on that page is the old behaviour intact.
                            onLinkRequested:
                                root.customiseDeviceRequested(modelData.deviceId)
                        }
                    }
                }
            }

            // ---- frame 17b: the search panel --------------------------------
            Item {
                id: resultsPanel

                anchors.right: parent.right
                anchors.top: devicesHeader.bottom
                anchors.topMargin: Theme.spacing2
                width: deviceSearch.width
                height: Math.min(360, resultList.contentHeight + Theme.spacing4 * 2)
                visible: devicesStepRoot.results.length > 0
                // Above the grid it covers, and above the grid's own hover
                // states - a row you are pointing at must not also light a
                // card underneath it.
                z: 2

                StShadow { anchors.fill: parent; radius: Theme.radiusLg }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusLg
                    color: Theme.surfaceRaised
                    border.width: Theme.borderWidth
                    border.color: Theme.outlineSubtle

                    ListView {
                        id: resultList

                        anchors.fill: parent
                        anchors.margins: Theme.spacing4
                        clip: true
                        spacing: 0
                        model: devicesStepRoot.results

                        header: StLabel {
                            width: ListView.view.width
                            text: qsTr("All results")
                            level: 1
                            tone: "secondary"
                            bottomPadding: Theme.spacing2
                        }

                        delegate: Item {
                            id: hit

                            required property var modelData
                            required property int index

                            width: ListView.view.width
                            height: 76

                            Row {
                                anchors.left: parent.left
                                anchors.right: hitAction.left
                                anchors.rightMargin: Theme.spacing3
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacing3

                                StRoundedImage {
                                    width: 48
                                    height: 48
                                    radius: 24
                                    source: hit.modelData.device.image
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    StLabel {
                                        text: hit.modelData.device.name
                                        level: 2
                                        font.weight: Theme.fontWeightMedium
                                    }

                                    Row {
                                        spacing: Theme.spacing2

                                        StIcon {
                                            name: hit.modelData.connected ? "check" : "close"
                                            size: 16
                                            color: hit.modelData.connected
                                                   ? Theme.success : Theme.textMuted
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StLabel {
                                            text: hit.modelData.connected
                                                  ? qsTr("connected")
                                                  : qsTr("not connected")
                                            level: 1
                                            color: hit.modelData.connected
                                                   ? Theme.success : Theme.textMuted
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            StIconButton {
                                id: hitAction

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: hit.modelData.connected ? "close" : "plus"
                                size: 40
                                radius: 20
                                fill: "transparent"
                                borderColor: "transparent"
                                stroke: hit.modelData.connected
                                        ? Theme.textSecondary : Theme.primary
                                accessibleName: hit.modelData.connected
                                                ? qsTr("Unlink %1").arg(hit.modelData.device.name)
                                                : qsTr("Link %1").arg(hit.modelData.device.name)
                                onClicked: {
                                    if (hit.modelData.connected) {
                                        root.viewModel.unlinkDevice(
                                            hit.modelData.device.deviceId);
                                    } else {
                                        // Same page the grid's + opens. A
                                        // second, quieter path that linked
                                        // without naming would be two answers
                                        // to one gesture.
                                        root.customiseDeviceRequested(
                                            hit.modelData.device.deviceId);
                                    }
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Theme.outlineSubtle
                                // Between rows, not under the last one: a rule
                                // above the panel's own bottom edge reads as a
                                // row that failed to render.
                                visible: hit.index < resultList.count - 1
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- step 5: assign devices to rooms -----------------------------------
    Component {
        id: assignStep

        Item {
            StLabel {
                id: assignTitle
                anchors.left: parent.left
                anchors.top: parent.top
                text: qsTr("Which room is each device in?")
                level: 3
            }

            ListView {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: assignTitle.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: Theme.spacing4
                clip: true
                spacing: Theme.spacing3
                model: root.viewModel.devices

                delegate: StCard {
                    required property var model
                    required property int index

                    width: ListView.view.width
                    height: 80

                    Image {
                        id: assignThumb
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacing4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 48
                        source: root.viewModel.imageUrl(model.image)
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 96
                        smooth: true
                        asynchronous: true
                    }

                    Column {
                        anchors.left: assignThumb.right
                        anchors.leftMargin: Theme.spacing4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        StLabel { text: model.name; level: 2 }
                        StLabel { text: model.roomName; level: 1; tone: "secondary" }
                    }

                    StIconButton {
                        glyph: "close"
                        size: 40
                        fill: "transparent"
                        stroke: Theme.danger
                        accessibleName: qsTr("Remove")
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacing4
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.viewModel.unlinkDevice(model.deviceId)
                    }
                }
            }
        }
    }

    // ---- step 6: members ----------------------------------------------------
    Component {
        id: membersStep

        Item {
            Row {
                id: inviteRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Theme.spacing3

                StTextField {
                    id: memberName
                    width: (inviteRow.width - inviteRow.spacing * 2) * 0.32
                    placeholderText: qsTr("Name")
                }

                StTextField {
                    id: memberEmail
                    width: (inviteRow.width - inviteRow.spacing * 2) * 0.45
                    placeholderText: qsTr("Email")
                    inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
                }

                StButton {
                    width: (inviteRow.width - inviteRow.spacing * 2) * 0.23
                    text: qsTr("Invite")
                    enabled: memberName.text.trim().length > 0
                    onClicked: {
                        root.viewModel.addMember(memberName.text, memberEmail.text);
                        memberName.text = "";
                        memberEmail.text = "";
                    }
                }
            }

            // No invitation is sent: there is no mail transport. The record is
            // local, which is exactly what a household member list is here.
            StLabel {
                id: inviteNote
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: inviteRow.bottom
                anchors.topMargin: Theme.spacing2
                text: qsTr("Members are stored on this panel. No email is sent — there is no mail transport in SmarTon.")
                level: 0
                tone: "muted"
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }

            ListView {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: inviteNote.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: Theme.spacing4
                clip: true
                spacing: Theme.spacing3
                model: root.viewModel.members

                delegate: StCard {
                    required property var model

                    width: ListView.view.width
                    height: 72

                    StAvatar {
                        id: memberAvatar
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacing4
                        anchors.verticalCenter: parent.verticalCenter
                        size: 44
                        name: model.name
                        source: model.avatar
                    }

                    Column {
                        anchors.left: memberAvatar.right
                        anchors.leftMargin: Theme.spacing4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        StLabel { text: model.name; level: 2 }
                        StLabel { text: model.email; level: 1; tone: "secondary" }
                    }

                    StIconButton {
                        glyph: "close"
                        size: 40
                        fill: "transparent"
                        stroke: Theme.danger
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacing4
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.viewModel.removeMember(model.memberId)
                    }
                }
            }
        }
    }

    // ---- step 7: confirm ----------------------------------------------------
    Component {
        id: confirmStep

        Row {
            id: confirmRow

            spacing: Theme.spacing5

            readonly property real columnWidth: (confirmRow.width - confirmRow.spacing) / 2

            StCard {
                width: confirmRow.columnWidth
                height: confirmRow.height

                StLabel {
                    id: confirmRoomsTitle
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: Theme.spacing5
                    text: qsTr("Your Rooms")
                    level: 3
                }

                ListView {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: confirmRoomsTitle.bottom
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacing5
                    anchors.topMargin: Theme.spacing3
                    clip: true
                    spacing: Theme.spacing3
                    model: root.viewModel.rooms

                    delegate: Item {
                        required property var model

                        width: ListView.view.width
                        height: 56

                        StRoundedImage {
                            id: confirmRoomThumb
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            height: 44
                            radius: width / 2
                            source: root.viewModel.imageUrl(model.image)
                        }

                        Column {
                            anchors.left: confirmRoomThumb.right
                            anchors.leftMargin: Theme.spacing4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            StLabel { text: model.name; level: 2 }
                            StLabel {
                                text: qsTr("%1 m²").arg(model.areaSqm)
                                level: 1
                                tone: "secondary"
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: Theme.outline
                            opacity: 0.35
                        }
                    }
                }
            }

            StCard {
                width: confirmRow.columnWidth
                height: confirmRow.height

                StLabel {
                    id: confirmDevicesTitle
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: Theme.spacing5
                    text: qsTr("Your Devices")
                    level: 3
                }

                ListView {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: confirmDevicesTitle.bottom
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacing5
                    anchors.topMargin: Theme.spacing3
                    clip: true
                    spacing: Theme.spacing3
                    model: root.viewModel.devices

                    delegate: Item {
                        required property var model

                        width: ListView.view.width
                        height: 56

                        Image {
                            id: confirmDeviceThumb
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 40
                            source: root.viewModel.imageUrl(model.image)
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: 80
                            smooth: true
                            asynchronous: true
                        }

                        Column {
                            anchors.left: confirmDeviceThumb.right
                            anchors.leftMargin: Theme.spacing4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            StLabel { text: model.name; level: 2 }
                            StLabel { text: model.roomName; level: 1; tone: "secondary" }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: Theme.outline
                            opacity: 0.35
                        }
                    }
                }
            }
        }
    }
}
