import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StCountPill
    \inqmlmodule SmarTon.Ui.Controls
    \brief Dark rounded badge holding a number. Figma: "Your Devices (6)".
*/
Rectangle {
    id: root

    property int value: 0
    /*! Optional dot before the number, as on the room cards' "4 devices". */
    property bool showDot: false
    property string suffix: ""

    implicitWidth: content.implicitWidth + Theme.spacing3 * 2
    implicitHeight: 26
    radius: height / 2
    color: Theme.surfaceDeep

    // One announcement for the whole pill. Without this the dot, the number
    // and the noun are three separate nodes and read as "8 devices" split
    // across three stops.
    Accessible.role: Accessible.StaticText
    Accessible.name: root.suffix.length > 0
                     ? qsTr("%1 %2").arg(root.value).arg(root.suffix)
                     : String(root.value)

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacing2

        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: Theme.primary
            visible: root.showDot
            anchors.verticalCenter: parent.verticalCenter
        }

        StLabel {
            text: root.suffix.length > 0
                  ? qsTr("%1 %2").arg(root.value).arg(root.suffix)
                  : String(root.value)
            level: 1
            font.weight: Theme.fontWeightMedium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
