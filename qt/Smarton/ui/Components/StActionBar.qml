import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StActionBar
    \inqmlmodule SmarTon.Ui.Components
    \brief The wizard's bottom bar: a hint, a secondary out, a primary action.
           Figma frames 10-17 and 24-25.

    The hint on the left is not decoration - it is the only place the design
    tells you what the step wants, and it is why the bar exists rather than two
    floating buttons.
*/
Item {
    id: root

    property string hint: ""
    property string secondaryText: qsTr("Skip")
    property string auxiliaryText: ""
    property bool   auxiliaryVisible: false
    property string primaryText: qsTr("Continue")
    property bool   secondaryVisible: true
    property bool   primaryEnabled: true

    signal secondaryTriggered()
    signal auxiliaryTriggered()
    signal primaryTriggered()

    implicitHeight: 96

    StShadow { anchors.fill: parent; radius: Theme.radiusLg }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceDeep

        StLabel {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing6
            anchors.right: actions.left
            anchors.rightMargin: Theme.spacing5
            anchors.verticalCenter: parent.verticalCenter
            text: root.hint
            level: 1
            tone: "secondary"
        }

        Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing5
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing4

            StButton {
                width: 150
                variant: "ghost"
                text: root.auxiliaryText
                visible: root.auxiliaryVisible
                onClicked: root.auxiliaryTriggered()
            }

            StButton {
                width: 220
                variant: "secondary"
                text: root.secondaryText
                visible: root.secondaryVisible
                onClicked: root.secondaryTriggered()
            }

            StButton {
                width: 304
                text: root.primaryText
                enabled: root.primaryEnabled
                onClicked: root.primaryTriggered()
            }
        }
    }
}
