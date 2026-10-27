import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StLinkDeviceCard
    \inqmlmodule SmarTon.Ui.Components
    \brief A nearby device, with a button to link it. Figma frames 16 and 17.

    Same anatomy as StDeviceCard but a different job, so a different component:
    this one has no power switch (an unlinked device cannot be commanded) and
    its status line reports connection, not a room.
*/
Item {
    id: root

    property string name: ""
    property url    imageSource: ""
    property bool   linked: false

    signal linkRequested()

    implicitWidth: 300
    implicitHeight: 226

    StShadow { anchors.fill: parent; radius: Theme.radiusLg }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceRaised
        border.width: Theme.borderWidth
        border.color: root.linked ? Theme.primary : Theme.outlineSubtle
        clip: true

        Rectangle {
            width: parent.width * 0.62
            height: width
            radius: width / 2
            color: Theme.textPrimary
            opacity: 0.05
            x: parent.width * 0.06
            y: -height * 0.18
        }

        Image {
            source: root.imageSource
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: -parent.width * 0.14
            anchors.top: parent.top
            anchors.topMargin: Theme.spacing4
            height: parent.height * 0.5
            fillMode: Image.PreserveAspectFit
            sourceSize.height: 220
            smooth: true
            asynchronous: true
        }

        StLabel {
            id: nameLabel
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing5
            anchors.right: linkButton.left
            anchors.rightMargin: Theme.spacing3
            anchors.bottom: statusRow.top
            anchors.bottomMargin: 2
            text: root.name
            level: 2
            font.weight: Theme.fontWeightMedium
        }

        Row {
            id: statusRow
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing5
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacing5
            spacing: Theme.spacing2

            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: root.linked ? Theme.success : Theme.textDisabled
                anchors.verticalCenter: parent.verticalCenter
            }

            StLabel {
                text: root.linked ? qsTr("connected") : qsTr("not connected")
                level: 1
                tone: "muted"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        StIconButton {
            id: linkButton
            glyph: "plus"
            size: 44
            accessibleName: qsTr("Link %1").arg(root.name)
            fill: Theme.textPrimary
            stroke: Theme.primary
            borderColor: Theme.primary
            borderWidth: Theme.borderWidth
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing5
            anchors.verticalCenter: statusRow.top
            enabled: !root.linked
            onClicked: root.linkRequested()
        }
    }
}
