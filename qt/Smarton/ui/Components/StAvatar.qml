import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StAvatar
    \inqmlmodule SmarTon.Ui.Components
    \brief A person, as a circle. The one way a face is drawn in SmarTon.

    Everything an avatar needs, in one place, because it appears in six:
    the sidebar, the profile screen, the members grid and list, the dashboard
    row and the welcome screen - each of which had its own slightly different
    copy of the same broken clip-to-a-rounded-rect.

    \list
    \li A genuine circular crop, via StRoundedImage.
    \li A fallback that is not a broken image: the initial, on a filled disc,
        shown while the picture loads and left in place if it never does.
    \li An optional presence dot and ring, positioned once rather than
        re-derived at every call site.
    \endlist
*/
Item {
    id: root

    property url source: ""
    /*! Used for the fallback initial. */
    property string name: ""
    property int size: 40
    /*! Ring drawn just outside the circle; "transparent" for none. */
    property color ringColor: "transparent"
    property int ringWidth: 2
    /*! Presence dot at the lower right. */
    property bool showPresence: false
    property bool online: false

    implicitWidth: root.size
    implicitHeight: root.size

    // The disc sits BEHIND the picture and shows through while it loads, and
    // stays visible forever if the source is empty or fails. An avatar that
    // renders as a hole is worse than one that renders as a letter.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.surfaceRaised
        antialiasing: true

        StLabel {
            anchors.centerIn: parent
            text: root.name.length > 0 ? root.name.charAt(0).toUpperCase() : "?"
            level: root.size >= 96 ? 4 : root.size >= 48 ? 3 : 1
            font.weight: Theme.fontWeightBold
        }
    }

    StRoundedImage {
        anchors.fill: parent
        source: root.source
        radius: width / 2
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -root.ringWidth
        radius: width / 2
        color: "transparent"
        border.width: root.ringWidth
        border.color: root.ringColor
        visible: root.ringColor.a > 0
        antialiasing: true
    }

    Rectangle {
        width: Math.max(10, root.size * 0.24)
        height: width
        radius: width / 2
        color: root.online ? Theme.success : Theme.textDisabled
        border.width: 2
        border.color: Theme.surface
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.showPresence
        antialiasing: true
    }

    Accessible.role: Accessible.Graphic
    Accessible.name: root.name.length > 0
                     ? qsTr("%1's picture").arg(root.name) : qsTr("Profile picture")
}
