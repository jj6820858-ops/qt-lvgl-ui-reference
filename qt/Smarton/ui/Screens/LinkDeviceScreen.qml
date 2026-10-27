import QtQuick
import SmarTon.Ui.Helpers
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Components

/*!
    \qmltype LinkDeviceScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief Name a device and say where it lives, on the way in. Figma frame 11.

    The step the link grid used to skip. Tapping + on frame 17 linked the
    device into whichever room happened to be first and kept whatever name the
    manufacturer gave it, and the code said so: "Step 5 is where they get
    moved, because assigning here would mean a room picker on every card."
    Frame 11 is the design's answer to that objection - not a picker on every
    card, but a page for the one device you just tapped.

    It is genuinely optional. Skip links the device with the defaults, which
    is the old behaviour, and nothing here is a required field: a house where
    every lamp is called "Smart Lamp" is a house someone can still use.

    THE COMMIT IS ON THE WAY OUT, not on each keystroke. Everything else in
    the wizard writes as it goes because each step is a separate fact, but a
    half-typed name and a room chosen before the name is not a state worth
    persisting - and a device that appears in the space the moment you open
    its setup page is one that "Skip" cannot honestly undo.
*/
Item {
    id: root

    /*! smarton::models::HomeViewModel. */
    required property var viewModel
    /*! Id from HomeViewModel::availableDevices(). */
    required property string availableId

    signal finished()
    signal cancelled()

    /*! The catalogue row for this device: name, kind, image. Read once - the
        nearby list does not change while its own setup page is open. */
    readonly property var candidate: {
        const all = root.viewModel.availableDevices();
        for (let i = 0; i < all.length; ++i) {
            if (all[i].deviceId === root.availableId)
                return all[i];
        }
        return null;
    }

    readonly property var rooms: root.viewModel.roomChoices()

    /*! Which room chip is lit. Defaults to the first, which is what linking
        did silently before this page existed - the difference is that it is
        now visible and changeable. */
    property int roomIndex: 0

    function _commit(customised: bool): void {
        if (root.candidate === null) {
            root.cancelled();
            return;
        }

        const room = root.rooms.length > root.roomIndex && root.roomIndex >= 0
                   ? root.rooms[root.roomIndex].id : "";
        if (!root.viewModel.linkDevice(root.availableId, room)) {
            Notifications.error(qsTr("Could not link this device"),
                                qsTr("It is no longer in the nearby list."));
            root.cancelled();
            return;
        }

        // linkDevice keeps the catalogue id, so the linked device answers to
        // the same one - which is what makes renaming it here a second call
        // rather than a second API.
        const chosen = nameField.text.trim();
        if (customised && chosen.length > 0 && chosen !== root.candidate.name)
            root.viewModel.renameDevice(root.availableId, chosen);

        Notifications.success(qsTr("Device linked"),
                              qsTr("%1 is in your space.")
                                  .arg(customised && chosen.length > 0
                                       ? chosen : root.candidate.name));
        root.finished();
    }

    StTopBar {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        showBack: true
        centred: true
        title: qsTr("Link new device")
        subtitle: qsTr("Connect with your space")
        onBackRequested: root.cancelled()
    }

    // ---- the product, standing in its rings ---------------------------------
    Item {
        id: heroArea

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: form.top
        anchors.topMargin: Theme.spacing5

        // Two flat discs rather than the detail page's drawn rings: the frame
        // has a solid outer disc with a lighter one inside it, which reads as
        // a spotlight the product is standing in.
        Rectangle {
            id: outerDisc

            anchors.centerIn: parent
            width: Math.max(0, Math.min(340, heroArea.height, heroArea.width))
            height: width
            radius: width / 2
            color: Theme.textPrimary
            opacity: 0.10
        }

        Rectangle {
            anchors.centerIn: outerDisc
            width: outerDisc.width * 0.68
            height: width
            radius: width / 2
            color: Theme.textPrimary
            opacity: 0.06
        }

        Image {
            anchors.centerIn: outerDisc
            width: outerDisc.width * 0.62
            height: width
            source: root.candidate === null ? "" : root.candidate.image
            fillMode: Image.PreserveAspectFit
            sourceSize.height: 480
            smooth: true
            asynchronous: true
        }
    }

    // ---- name and room --------------------------------------------------------
    Column {
        id: form

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: actions.top
        anchors.bottomMargin: Theme.spacing8
        // Capped and centred. Full-width, a single-line name field on a 1440
        // panel is a 1300 px box for eleven characters.
        width: Math.min(480, root.width - Theme.pageMargin * 2)
        spacing: Theme.spacing3

        StLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("What is your device name?")
            level: 1
            tone: "secondary"
        }

        StTextField {
            id: nameField

            width: parent.width
            placeholderText: qsTr("Device name")
            text: root.candidate === null ? "" : root.candidate.name
            accessibleName: qsTr("Device name")
        }

        Item { width: 1; height: Theme.spacing4 }

        StLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Where is your device located?")
            level: 1
            tone: "secondary"
            visible: root.rooms.length > 0
        }

        Flow {
            width: parent.width
            spacing: Theme.spacing3
            visible: root.rooms.length > 0

            Repeater {
                model: root.rooms

                delegate: StChip {
                    required property var modelData
                    required property int index

                    text: modelData.name
                    selected: root.roomIndex === index
                    onClicked: root.roomIndex = index
                }
            }
        }

        StLabel {
            width: parent.width
            visible: root.rooms.length === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("This space has no rooms yet. The device is linked without one, and you can move it from its own page later.")
            level: 0
            tone: "muted"
        }
    }

    StActionBar {
        id: actions

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        hint: qsTr("Customize and link your new device")
        secondaryText: qsTr("Skip")
        primaryText: qsTr("Continue")
        // Skip is not cancel. The frame puts both on a page whose whole
        // purpose is linking, so Skip links with the defaults - the behaviour
        // the + button had before this page existed - and only the back arrow
        // leaves without linking.
        onSecondaryTriggered: root._commit(false)
        onPrimaryTriggered: root._commit(true)
    }

    Component.onCompleted: FocusHelper.focusFirstField(form)
}
