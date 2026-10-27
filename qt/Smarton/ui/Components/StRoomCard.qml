import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StRoomCard
    \inqmlmodule SmarTon.Ui.Components
    \brief Room tile. Figma frames 13, 18 and 26.

    The same card serves three frames with different footers, so the footer is
    a mode rather than three near-identical components:
    \list
    \li \c "devices" - the "N devices" pill (frame 18)
    \li \c "area"    - the square-metre caption and an overflow button (13)
    \li \c "energy"  - consumption on the right (26)
    \endlist
*/
Item {
    id: root

    property string name: ""
    property url    imageSource: ""
    property int    deviceCount: 0
    property real   areaSqm: 0
    property real   energyKw: 0
    /*! devices | area | energy */
    property string footer: "devices"
    property bool   showEdit: false

    signal activated()
    signal editRequested()
    signal menuRequested()

    implicitWidth: 300
    implicitHeight: 240

    StShadow { anchors.fill: parent; radius: Theme.radiusLg }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceRaised
        border.width: Theme.borderWidth
        border.color: Theme.surfaceRaised
        clip: true

        Rectangle {
            width: parent.width * 0.78
            height: width
            radius: width / 2
            color: Theme.textPrimary
            opacity: 0.05
            x: parent.width * 0.02
            y: -height * 0.16
        }

        Image {
            source: root.imageSource
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Theme.spacing4
            width: parent.width * 0.72
            height: parent.height * 0.58
            fillMode: Image.PreserveAspectFit
            sourceSize.height: 260
            smooth: true
            asynchronous: true
        }

        StIconButton {
            glyph: "edit"
            size: 40
            accessibleName: qsTr("Rename %1").arg(root.name)
            fill: "transparent"
            stroke: Theme.primary
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Theme.spacing4
            borderColor: Theme.primary
            borderWidth: Theme.borderWidth
            visible: root.showEdit
            onClicked: root.editRequested()
        }

        StLabel {
            id: nameLabel
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing5
            anchors.bottom: footerRow.top
            anchors.bottomMargin: Theme.spacing2
            text: root.name
            level: 2
            font.weight: Theme.fontWeightMedium
        }

        Item {
            id: footerRow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.spacing5
            anchors.rightMargin: Theme.spacing5
            anchors.bottomMargin: Theme.spacing5
            height: 26

            StCountPill {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                value: root.deviceCount
                suffix: qsTr("devices")
                showDot: true
                visible: root.footer === "devices"
            }

            StLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("%1 m²").arg(root.areaSqm)
                level: 1
                tone: "muted"
                visible: root.footer === "area"
            }

            StIconButton {
                glyph: "more"
                size: 32
                accessibleName: qsTr("More actions for %1").arg(root.name)
                fill: "transparent"
                stroke: Theme.textSecondary
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.footer === "area"
                onClicked: root.menuRequested()
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                visible: root.footer === "energy"

                StLabel {
                    text: String(root.energyKw)
                    level: 3
                    anchors.baseline: unitLabel.baseline
                }
                StLabel {
                    id: unitLabel
                    text: qsTr("kW")
                    level: 1
                    tone: "secondary"
                }
            }
        }

        TapHandler {
            onTapped: root.activated()
        }
    }
}
