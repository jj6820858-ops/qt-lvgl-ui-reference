import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme

/*!
    \qmltype StRadioOption
    \inqmlmodule SmarTon.Ui.Controls
    \brief Bordered radio pill. Figma frame 14, "size in m² / size in ft²".

    Derives from T.RadioButton so exclusivity within a ButtonGroup, keyboard
    activation and accessibility come from Qt.
*/
T.RadioButton {
    id: root

    implicitWidth: label.implicitWidth + 78
    implicitHeight: Theme.controlHeight
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    activeFocusOnTab: true

    Accessible.role: Accessible.RadioButton
    Accessible.name: root.text
    Accessible.checked: root.checked
    Accessible.onPressAction: root.toggle()
    opacity: root.enabled ? 1 : Theme.disabledOpacity

    indicator: Rectangle {
        id: dot
        x: Theme.spacing5
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: 9
        color: "transparent"
        border.width: 2
        border.color: root.checked ? Theme.primary : Theme.outline

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: Theme.primary
            visible: root.checked
        }

        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    }

    contentItem: StLabel {
        id: label
        text: root.text
        level: 1
        leftPadding: dot.width + Theme.spacing5 + Theme.spacing3
        color: root.checked ? Theme.primary : Theme.textSecondary
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: Theme.radiusSm
        color: root.down    ? Qt.rgba(1, 1, 1, Theme.pressOverlay)
             : root.hovered ? Qt.rgba(1, 1, 1, Theme.hoverOverlay)
                            : "transparent"
        border.width: root.visualFocus ? Theme.borderWidthFocus : Theme.borderWidth
        border.color: root.visualFocus ? Theme.focus
                    : root.checked     ? Theme.primary
                    : root.hovered     ? Theme.fieldBorderHover : Theme.outline

        Behavior on color        { ColorAnimation { duration: Theme.durationFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    }
}
