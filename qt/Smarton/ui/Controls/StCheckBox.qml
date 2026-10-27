import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme

/*!
    \qmltype StCheckBox
    \inqmlmodule SmarTon.Ui.Controls
    \brief Square checkbox with label. Figma: "Remember information" on Login.
*/
T.CheckBox {
    id: root

    implicitWidth: indicatorItem.width + labelItem.implicitWidth + Theme.spacing3
    implicitHeight: Math.max(Theme.touchTarget, labelItem.implicitHeight)
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    activeFocusOnTab: true

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.text
    Accessible.checked: root.checked
    Accessible.onToggleAction: root.toggle()
    opacity: root.enabled ? 1 : Theme.disabledOpacity

    indicator: Rectangle {
        id: indicatorItem
        width: 18
        height: 18
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        radius: 4
        color: !root.enabled ? Theme.disabledFill(Theme.surface)
             : root.checked  ? (root.down ? Theme.pressedFill(Theme.primary)
                                          : Theme.hoveredFill(Theme.primary, root.hovered))
                             : Theme.hoveredFill(Theme.surface, root.hovered)
        border.width: root.visualFocus ? Theme.borderWidthFocus : Theme.borderWidth
        border.color: root.visualFocus ? Theme.focus
                    : root.checked     ? Theme.primary
                    : root.hovered     ? Theme.fieldBorderHover : Theme.outline

        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

        StIcon {
            anchors.centerIn: parent
            name: "check"
            size: 16
            // On the accent fill, not on the page - so it follows the accent.
            color: Theme.textOnPrimary
            visible: root.checked
        }

        Behavior on color {
            ColorAnimation { duration: Theme.durationFast }
        }
    }

    contentItem: StLabel {
        id: labelItem
        text: root.text
        level: 1
        tone: "secondary"
        leftPadding: indicatorItem.width + Theme.spacing3
        verticalAlignment: Text.AlignVCenter
    }
}
