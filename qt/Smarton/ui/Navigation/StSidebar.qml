import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Components

/*!
    \qmltype StSidebar
    \inqmlmodule SmarTon.Ui.Navigation
    \brief Persistent navigation rail. Figma: Home overview, 278 px of 1440.

    Reflowed to 198 px of 1024 - the same 19.3% of screen width, so the visual
    balance against the content area is preserved on the wider panel.

    Owns no navigation state: it reports the tapped route and renders whatever
    \l currentRoute it is given. That is what keeps it reusable and testable.
*/
Rectangle {
    id: root

    property var    model: []
    property string currentRoute: ""
    property string userName: ""
    property string userGreeting: qsTr("Welcome home,")
    property url    avatarSource: ""

    signal navigate(string route)
    signal settingsRequested()
    signal logoutRequested()

    implicitWidth: Theme.sidebarWidth
    // Under glass the rail is a translucent film over the aurora rather than
    // a solid panel, so the page's colour runs the full height of the window
    // instead of stopping at a hard vertical edge.
    color: Theme.glass ? Qt.rgba(0, 0, 0, 0.28) : Theme.surfaceDeep

    StGlass {
        anchors.fill: parent
        visible: Theme.glass
        radius: 0
        // Large, permanent, one per window - the same three reasons the header
        // band is frosted. See StGlass.frosted.
        frosted: true
    }

    // ---- brand ----------------------------------------------------------
    Image {
        id: wordmark
        source: "qrc:/qt/qml/SmarTon/Resources/images/brand/logo-wordmark.png"
        anchors.top: parent.top
        anchors.topMargin: Theme.spacing5
        // CENTRED, not left-anchored. The rail is resizable, and a wordmark
        // pinned to the left inset drifts further from the middle of the rail
        // the wider it gets - which reads as the logo sliding sideways rather
        // than the panel growing.
        anchors.horizontalCenter: parent.horizontalCenter
        // Never wider than the rail minus its insets, so dragging the split
        // narrow shrinks the wordmark instead of clipping it.
        width: Math.min(150, root.width - Theme.navItemInset * 2)
        fillMode: Image.PreserveAspectFit
        // Decode at the largest size it is ever drawn at, so shrinking is a
        // downscale (clean) rather than an upscale (soft).
        sourceSize.width: 150
        smooth: true
        mipmap: true
    }

    Rectangle {
        id: brandRule
        anchors.top: wordmark.bottom
        anchors.topMargin: Theme.spacing4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.navItemInset
        anchors.rightMargin: Theme.navItemInset
        height: 1
        color: Theme.surfaceRaised
        opacity: 0.6
    }

    // ---- account --------------------------------------------------------
    // Tappable. The avatar and name are the most profile-looking thing on the
    // screen, so people tap them expecting the profile - and it was inert,
    // which reads as the app ignoring them. Routes to the same place the
    // "Profile & Settings" row does.
    Item {
        id: account
        anchors.top: brandRule.bottom
        anchors.topMargin: Theme.spacing4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.navItemInset
        anchors.rightMargin: Theme.navItemInset
        height: 44

        // Behind the content so it never intercepts the avatar's own hit area.
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -Theme.spacing3
            anchors.rightMargin: -Theme.spacing3
            anchors.topMargin: -Theme.spacing2
            anchors.bottomMargin: -Theme.spacing2
            radius: Theme.radiusSm
            color: accountHover.hovered ? Qt.rgba(1, 1, 1, Theme.hoverOverlay)
                                        : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        HoverHandler {
            id: accountHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.settingsRequested()
        }

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Open your profile")
        Accessible.onPressAction: root.settingsRequested()

        StAvatar {
            id: avatar
            anchors.verticalCenter: parent.verticalCenter
            size: 36
            source: root.avatarSource
            name: root.userName
        }

        Column {
            anchors.left: avatar.right
            anchors.leftMargin: Theme.spacing3
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            StLabel { text: root.userGreeting; level: 0; tone: "muted"; width: parent.width }
            StLabel {
                text: root.userName
                level: 1
                width: parent.width
                font.weight: Theme.fontWeightBold
            }
        }
    }

    // ---- primary navigation --------------------------------------------
    Column {
        id: navColumn
        anchors.top: account.bottom
        anchors.topMargin: Theme.spacing5
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.spacing1

        Repeater {
            model: root.model

            delegate: StSidebarItem {
                required property var modelData

                width: parent.width
                route: modelData.route
                label: modelData.label
                current: modelData.route === root.currentRoute
                onActivated: root.navigate(modelData.route)
            }
        }
    }

    // ---- secondary --------------------------------------------------------
    // Figma places a rule and "Profile & Settings" directly under the primary
    // group, and pins "Log out" to the bottom edge - not both in one footer
    // block. Log out sits apart because it leaves the app; grouping it with a
    // navigation entry is how people tap it by accident.
    Rectangle {
        id: footerRule

        anchors.top: navColumn.bottom
        anchors.topMargin: Theme.spacing5
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.navItemInset
        anchors.rightMargin: Theme.navItemInset
        height: 1
        color: Theme.surfaceRaised
        opacity: 0.6
    }

    StSidebarItem {
        anchors.top: footerRule.bottom
        anchors.topMargin: Theme.spacing4
        anchors.left: parent.left
        anchors.right: parent.right
        route: "settings"
        label: qsTr("Profile & Settings")
        current: root.currentRoute === "settings"
        onActivated: root.settingsRequested()
    }

    StSidebarItem {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacing5
        anchors.left: parent.left
        anchors.right: parent.right
        route: "logout"
        label: qsTr("Log out")
        onActivated: root.logoutRequested()
    }

    /*!
        One sidebar row. An inline component rather than a copied Row: the
        primary entries, Profile & Settings and Log out are the same row with
        different data, and an inline component is its OWN scope, so it takes
        what it needs as properties instead of reaching for the file's ids -
        which .qmllint.ini treats as an error.
    */
    component StSidebarItem: Item {
        id: entry

        property string route: ""
        property string label: ""
        property bool   current: false

        signal activated()

        height: Theme.navItemHeight

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Theme.navItemInset
            anchors.rightMargin: Theme.navItemInset
            radius: Theme.radiusSm
            // Three states, not two. With only current/transparent the rail
            // gave no feedback at all until you committed - every other
            // control in the app answers the pointer, and the one you navigate
            // with was the one that did not. Hover sits deliberately BELOW
            // the selected fill so it reads as "you could go here", never as
            // "you are here".
            color: entry.current      ? Theme.surfaceAlt
                 : entryHover.hovered ? Qt.rgba(1, 1, 1, Theme.hoverOverlay)
                                      : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        HoverHandler {
            id: entryHover
            cursorShape: Qt.PointingHandCursor
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.navItemInset + Theme.spacing3
            anchors.right: parent.right
            anchors.rightMargin: Theme.navItemInset
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing3

            StNavIcon {
                name: entry.route
                stroke: entry.current      ? Theme.textOnActive
                      : entryHover.hovered ? Theme.textSecondary
                                           : Theme.textMuted
                anchors.verticalCenter: parent.verticalCenter
            }

            StLabel {
                text: entry.label
                level: 1
                color: entry.current      ? Theme.textOnActive
                     : entryHover.hovered ? Theme.textSecondary
                                          : Theme.textMuted
                font.weight: entry.current ? Theme.fontWeightMedium
                                           : Theme.fontWeightRegular
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        TapHandler {
            onTapped: entry.activated()
        }
    }
}
