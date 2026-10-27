import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StSceneCard
    \inqmlmodule SmarTon.Ui.Components
    \brief Scene row: name, schedule, toggle. Figma frames 21 and 23.

    Frame 23 outlines the ENABLED scenes in orange, so the border tracks
    \l enabled rather than selection - a scene that is running is the thing
    worth spotting across the grid.
*/
Item {
    id: root

    property string name: ""
    property string days: ""
    property string timeRange: ""
    property bool   enabled: false
    property bool   compact: false
    /*! Devices the scene names, or 0 when it takes its whole room. What a
        scene DOES is the one thing the card could not say, and "Movie Night,
        Mon Fri, 8-10" tells you when without ever telling you what. */
    property int    deviceCount: 0

    signal toggled(bool on)
    signal activated()
    signal renamed(string name)

    implicitWidth: 498       // measured, gap 24
    implicitHeight: root.compact ? 76 : 90   // measured 239..329

    StShadow {
        anchors.fill: parent
        radius: Theme.radiusLg
        visible: Theme.shadowsEnabled && !root.compact
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: root.compact ? "transparent" : Theme.surfaceRaised
        border.width: root.enabled && !root.compact ? Theme.borderWidthFocus : 0
        border.color: Theme.primary

        Behavior on border.width { NumberAnimation { duration: Theme.durationFast } }

        StEditableLabel {
            id: nameLabel
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing5
            anchors.right: sceneSwitch.left
            anchors.rightMargin: Theme.spacing3
            anchors.bottom: parent.verticalCenter
            text: root.name
            level: 2
            onCommitted: name => root.renamed(name)
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing5
            anchors.top: parent.verticalCenter
            anchors.topMargin: 2
            spacing: Theme.spacing2

            StLabel { text: root.days; level: 1; tone: "secondary" }
            StLabel { text: "|"; level: 1; tone: "muted" }
            StLabel { text: root.timeRange; level: 1; tone: "secondary" }
            StLabel { text: "|"; level: 1; tone: "muted"; visible: !root.compact }
            StLabel {
                visible: !root.compact
                text: root.deviceCount === 0
                      ? qsTr("whole room")
                      : qsTr("%n device(s)", "", root.deviceCount)
                level: 1
                tone: "secondary"
            }
        }

        StSwitch {
            id: sceneSwitch
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing5
            anchors.verticalCenter: parent.verticalCenter
            value: root.enabled
            accessibleName: root.name
            onToggleRequested: requested => root.toggled(requested)
        }

        TapHandler {
            enabled: !nameLabel.editing
            onTapped: root.activated()
        }
    }
}
