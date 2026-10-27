import QtQuick
import QtQuick.Window
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Layouts
import SmarTon.Ui.Components

/*!
    Every control in the library, in every state that matters, with nothing
    else on screen.

    This is the cheapest quality tool in a component library: it proves each
    control works without the application around it, it is what a designer
    reviews against the Figma frames, and it makes an unusable component
    obvious in seconds. scripts/capture-gallery.sh turns it into the image set
    in docs/.

    RULE: a control is not finished until it appears here in its default,
    focused, disabled and error states. Adding a control without adding it here
    is how a component library ends up with three buttons that look different.
*/
Window {
    id: root

    width: 1024
    height: 760
    visible: true
    color: Theme.background
    title: qsTr("SmarTon — component gallery")

    StScrollView {
        anchors.fill: parent
        contentHeight: content.implicitHeight + Theme.spacing8 * 2

        Column {
            id: content

            x: Theme.spacing8
            y: Theme.spacing8
            width: parent.width - Theme.spacing8 * 2
            spacing: Theme.spacing6

            StLabel { text: qsTr("Buttons"); level: 3 }

            // Hover each of these with a pointer and hold one down: every
            // variant must lift on hover and sink on press, not just primary.
            Row {
                spacing: Theme.spacing4
                StButton { text: qsTr("Primary");   width: 160 }
                StButton { text: qsTr("Secondary"); width: 160; variant: "secondary" }
                StButton { text: qsTr("Ghost");     width: 160; variant: "ghost" }
                StButton { text: qsTr("Danger");    width: 160; variant: "danger" }
                StButton { text: qsTr("Disabled");  width: 160; enabled: false }
            }

            Row {
                spacing: Theme.spacing6
                StLinkButton { text: qsTr("Forget password?") }
                StLinkButton { text: qsTr("Sign up for free"); emphasised: true }
                StLinkButton { text: qsTr("Disabled link"); enabled: false }
            }

            StLabel { text: qsTr("Provider buttons — disabled by design (ADR-0007)"); level: 3 }

            Row {
                spacing: Theme.spacing3
                StSocialButton { width: 200; provider: "google";   text: qsTr("Google") }
                StSocialButton { width: 200; provider: "facebook"; text: qsTr("Facebook") }
                StSocialButton { width: 200; provider: "apple";    text: qsTr("Apple") }
            }

            StLabel {
                text: qsTr("Text fields — idle, filled, password, error, disabled")
                level: 3
            }

            // Tab through this row to check the focus ring and the order; the
            // password field's reveal toggle is in the chain too.
            Row {
                spacing: Theme.spacing4
                StTextField { width: 200; placeholderText: qsTr("Email") }
                StTextField { width: 200; text: "jackconev@gmail.com" }
                StTextField { width: 200; placeholderText: qsTr("Password"); password: true }
                StTextField {
                    width: 200
                    text: "nope"
                    errorText: qsTr("Passwords do not match")
                }
                StTextField {
                    width: 200
                    placeholderText: qsTr("Disabled")
                    enabled: false
                }
            }

            Item { width: 1; height: Theme.spacing4 }   // clears the error line

            StLabel { text: qsTr("Combo box — open it, then use Up/Down/Enter"); level: 3 }

            Row {
                spacing: Theme.spacing4

                StComboBox {
                    width: 260
                    model: [qsTr("My Home"), qsTr("Beach House"), qsTr("Office")]
                    actionText: qsTr("+  Create a new space")
                }

                StComboBox {
                    width: 260
                    model: [qsTr("Disabled")]
                    enabled: false
                }
            }

            StLabel { text: qsTr("Checkbox"); level: 3 }

            Row {
                spacing: Theme.spacing8
                StCheckBox { text: qsTr("Unchecked") }
                StCheckBox { text: qsTr("Checked"); checked: true }
                StCheckBox { text: qsTr("Disabled"); enabled: false }
            }

            StLabel { text: qsTr("Verification code"); level: 3 }

            StOtpField { width: 400; height: 60 }

            StLabel { text: qsTr("Password rules — 0, 1, 2 and 3 rules met"); level: 3 }

            Row {
                spacing: Theme.spacing8
                StPasswordRules { width: 230; password: "" }
                StPasswordRules { width: 230; password: "abcdefgh" }
                StPasswordRules { width: 230; password: "abcdefgH" }
                StPasswordRules { width: 230; password: "abcdefgH1" }
            }

            StLabel { text: qsTr("Divider"); level: 3 }

            StDivider { width: parent.width; text: qsTr("or") }
            StDivider { width: parent.width }

            StLabel { text: qsTr("Switch — the controlled toggle"); level: 3 }

            Row {
                spacing: Theme.spacing8

                // Bound to a local, so the gallery demonstrates the real
                // contract: the switch moves only because the value changed.
                StSwitch {
                    id: demoSwitch
                    property bool state: false
                    value: demoSwitch.state
                    onToggleRequested: requested => demoSwitch.state = requested
                }
                StSwitch { value: true; showStateText: true }
                StSwitch { value: false; enabled: false }
            }

            StLabel { text: qsTr("Chips and segments"); level: 3 }

            Row {
                spacing: Theme.spacing3
                StChip { text: qsTr("Living room"); selected: true }
                StChip { text: qsTr("Kitchen") }
                StChip { text: qsTr("Bedroom") }
            }

            StSegmentedControl {
                model: [qsTr("Map view"), qsTr("List view")]
                currentIndex: 1
            }

            StLabel { text: qsTr("Icon set — 24px grid, 1.5 stroke, tinted at runtime"); level: 3 }

            // The whole set, at the four legal sizes and in the theme's ink
            // colours. If two icons here look like they came from different
            // families, that is the bug this page exists to catch.
            Flow {
                width: parent.width
                spacing: Theme.spacing4

                Repeater {
                    model: ["home", "rooms", "devices", "members", "statistics",
                            "settings", "logout", "back", "forward", "close",
                            "more", "plus", "edit", "trash", "search", "image",
                            "chevronDown", "chevronUp", "check", "eye", "eyeOff",
                            "play", "pause", "skipBack", "skipForward", "volume",
                            "battery", "temperature", "humidity", "bell", "link"]

                    delegate: Column {
                        required property var modelData
                        spacing: 4

                        StIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: modelData
                            size: 24
                            color: Theme.textPrimary
                        }
                        StLabel {
                            text: modelData
                            level: 0
                            tone: "muted"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            StLabel { text: qsTr("Sizes — 16 / 20 / 24 / 32, and the ink colours"); level: 3 }

            Row {
                spacing: Theme.spacing6

                Row {
                    spacing: Theme.spacing3
                    StIcon { name: "settings"; size: 16 }
                    StIcon { name: "settings"; size: 20 }
                    StIcon { name: "settings"; size: 24 }
                    StIcon { name: "settings"; size: 32 }
                }

                Row {
                    spacing: Theme.spacing3
                    StIcon { name: "trash"; color: Theme.textPrimary }
                    StIcon { name: "trash"; color: Theme.textMuted }
                    StIcon { name: "trash"; color: Theme.primary }
                    StIcon { name: "trash"; color: Theme.danger }
                    StIcon { name: "trash"; color: Theme.success }
                }
            }

            StLabel { text: qsTr("Icon buttons"); level: 3 }

            Row {
                spacing: Theme.spacing3
                StIconButton { glyph: "back" }
                StIconButton { glyph: "edit";  stroke: Theme.primary }
                StIconButton { glyph: "close" }
                StIconButton { glyph: "more" }
                StIconButton { glyph: "plus" }
                StIconButton { glyph: "image" }
                StIconButton { glyph: "chevronDown" }
                StIconButton { glyph: "trash"; stroke: Theme.danger }
                StIconButton { glyph: "search"; enabled: false }
            }

            StLabel { text: qsTr("Count pills"); level: 3 }

            Row {
                spacing: Theme.spacing4
                StCountPill { value: 6 }
                StCountPill { value: 4; suffix: qsTr("devices"); showDot: true }
            }

            StLabel { text: qsTr("Cards"); level: 3 }

            Row {
                spacing: Theme.spacing4

                StDeviceCard {
                    width: 260; height: 200
                    name: qsTr("Smart Lamp")
                    roomName: qsTr("Living Room")
                    on: true
                    imageSource: "qrc:/qt/qml/SmarTon/Resources/images/devices/pendant-lamp-teal.png"
                }

                StRoomCard {
                    width: 260; height: 208
                    name: qsTr("Living Room")
                    deviceCount: 4
                    showEdit: true
                    imageSource: "qrc:/qt/qml/SmarTon/Resources/images/rooms/living-sofa.png"
                }

                StRoomCard {
                    width: 260; height: 208
                    name: qsTr("Kitchen")
                    areaSqm: 12
                    footer: "area"
                    imageSource: "qrc:/qt/qml/SmarTon/Resources/images/rooms/kitchen-hob.png"
                }
            }

            StLabel {
                text: qsTr("Avatars and rounded images — genuinely masked")
                level: 3
            }

            // `clip: true` on a rounded Rectangle clips to the BOUNDING BOX,
            // not the radius. Every avatar in the app used to be a square
            // image sitting on a circle nobody could see. These are masked.
            Row {
                spacing: Theme.spacing5

                StAvatar {
                    size: 96
                    name: "Adesh"
                    source: "qrc:/qt/qml/SmarTon/Resources/images/avatars/default-profile.jpeg"
                }
                StAvatar {
                    size: 64
                    name: "Adesh"
                    source: "qrc:/qt/qml/SmarTon/Resources/images/avatars/default-profile.jpeg"
                    ringColor: Theme.primary
                }
                StAvatar {
                    size: 48
                    name: "Adesh"
                    source: "qrc:/qt/qml/SmarTon/Resources/images/avatars/default-profile.jpeg"
                    showPresence: true
                    online: true
                }
                // No source: the fallback initial, not a hole.
                StAvatar { size: 48; name: "Vasilisa" }
                StAvatar { size: 40; name: "Dina"; showPresence: true }

                StRoundedImage {
                    width: 140
                    height: 96
                    radius: Theme.radiusLg
                    source: "qrc:/qt/qml/SmarTon/Resources/images/rooms/living-sofa.png"
                }
            }

            StLabel { text: qsTr("Space picker"); level: 3 }

            StSpacePicker {
                spaceName: qsTr("My Home")
                thumbnailSource: "qrc:/qt/qml/SmarTon/Resources/images/rooms/house-exterior.png"
            }

            StLabel { text: qsTr("Volume slider"); level: 3 }

            StSlider { width: 420; modelValue: 70 }

            StLabel { text: qsTr("Tabs"); level: 3 }

            StTabBar {
                width: parent.width
                model: [qsTr("Account information"), qsTr("Change Password"),
                        qsTr("Notifications"), qsTr("Preferences")]
                currentIndex: 0
            }

            StLabel { text: qsTr("Editable label — tap the pencil"); level: 3 }

            StEditableLabel {
                id: renameDemo
                property string current: qsTr("Living Room")
                text: renameDemo.current
                level: 3
                onCommitted: name => renameDemo.current = name
            }

            StLabel { text: qsTr("Stat cards — rising and falling"); level: 3 }

            Row {
                spacing: Theme.spacing4
                StStatCard { caption: qsTr("This Week"); value: "50"; unit: qsTr("kW"); delta: 7.45 }
                StStatCard { caption: qsTr("Total Loss"); value: "30.2"; unit: qsTr("kW"); delta: -3.35 }
            }

            StLabel { text: qsTr("Scene card — enabled shows the orange border"); level: 3 }

            Row {
                spacing: Theme.spacing4
                StSceneCard {
                    width: 420
                    name: qsTr("Movie Night"); days: qsTr("Mon, Fri")
                    timeRange: "08:00 PM - 10:00 PM"; enabled: true
                }
                StSceneCard {
                    width: 420
                    name: qsTr("Morning coffee"); days: qsTr("Everyday")
                    timeRange: "08:15 AM - 09:00 AM"; enabled: false
                }
            }

            StLabel { text: qsTr("Line chart"); level: 3 }

            StLineChart {
                width: parent.width
                height: 300
                values: [6, 5, 4.5, 17, 9, 10, 3]
                labels: ["M", "T", "W", "T", "F", "S", "S"]
                selectedIndex: 3
            }

            StLabel { text: qsTr("Empty state"); level: 3 }

            StEmptyState {
                width: parent.width
                height: 380
                title: qsTr("Looks like you have no spaces set up.")
                detail: qsTr("Add your house and start your smart life!")
                imageSource: "qrc:/qt/qml/SmarTon/Resources/images/illustrations/smart-house-devices.png"
                imageSize: 200
                actionText: qsTr("Set up your space")
            }
        }
    }
}
