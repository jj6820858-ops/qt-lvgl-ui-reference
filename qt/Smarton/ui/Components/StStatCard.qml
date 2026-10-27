import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StStatCard
    \inqmlmodule SmarTon.Ui.Components
    \brief Caption, big figure, and a signed delta. Figma frame 26.

    The delta's colour follows its SIGN, not whether it is good news: the
    design shows "+7.45%" green on consumption, which is MORE usage. Colouring by
    direction keeps the component honest and lets the caller decide meaning by
    choosing which number to pass.
*/
Item {
    id: root

    property string caption: ""
    property string value: ""
    property string unit: ""
    property real   delta: 0
    property bool   showDelta: true

    implicitWidth: 168
    implicitHeight: 150

    StShadow { anchors.fill: parent; radius: Theme.radiusLg }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceRaised
        border.width: Theme.borderWidth
        border.color: Theme.outline

        StLabel {
            id: captionLabel
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Theme.spacing5
            text: root.caption
            level: 1
            tone: "secondary"
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing5
            anchors.top: captionLabel.bottom
            anchors.topMargin: Theme.spacing2
            spacing: 4

            StLabel {
                text: root.value
                level: 4
                anchors.baseline: unitLabel.baseline
            }
            StLabel {
                id: unitLabel
                text: root.unit
                level: 2
                tone: "secondary"
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing5
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacing5
            spacing: Theme.spacing2
            visible: root.showDelta

            StIcon {
                anchors.verticalCenter: parent.verticalCenter
                // The direction is the data. Colour follows the sign, not
                // whether the number is good news - see the class note.
                name: root.delta >= 0 ? "chevronUp" : "chevronDown"
                size: 16
                color: root.delta >= 0 ? Theme.success : Theme.danger
            }

            StLabel {
                text: (root.delta >= 0 ? "+" : "") + root.delta.toFixed(2) + "%"
                level: 1
                color: root.delta >= 0 ? Theme.success : Theme.danger
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
