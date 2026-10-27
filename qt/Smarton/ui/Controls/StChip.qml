import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme

/*!
    \qmltype StChip
    \inqmlmodule SmarTon.Ui.Controls
    \brief Outlined selectable pill. Figma: name suggestions (10), room
           picker (11), segment tabs (23, 26).

    Selected uses the design's amber, not the brand orange: in these frames
    orange means "the primary action on this screen", and a selected filter is
    not that. Using orange for both would leave two competing primaries.
*/
T.Button {
    id: root

    property bool selected: false

    implicitWidth: label.implicitWidth + Theme.spacing6 * 2
    implicitHeight: 44
    checkable: true
    checked: root.selected
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    activeFocusOnTab: true

    Accessible.role: Accessible.RadioButton
    Accessible.name: root.text
    Accessible.checked: root.selected
    Accessible.onPressAction: root.clicked()

    contentItem: StLabel {
        id: label
        text: root.text
        level: 1
        color: root.selected ? Theme.surfaceDeep : Theme.textSecondary
        font.weight: root.selected ? Theme.fontWeightMedium : Theme.fontWeightRegular
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: Theme.radiusSm
        color: !root.enabled  ? Theme.disabledFill(Theme.surface)
             : root.selected  ? (root.down ? Theme.pressedFill(Theme.warning)
                                           : Theme.hoveredFill(Theme.warning, root.hovered))
             : root.down      ? Theme.pressedFill(Theme.surface)
                              : Theme.hoveredFill(Theme.surface, root.hovered)
        border.width: root.visualFocus ? Theme.borderWidthFocus
                    : root.selected    ? 0 : Theme.borderWidth
        border.color: root.visualFocus ? Theme.focus
                    : root.hovered     ? Theme.fieldBorderHover : Theme.outline
        opacity: root.enabled ? 1 : Theme.disabledOpacity

        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

        Behavior on color {
            ColorAnimation { duration: Theme.durationFast }
        }
    }
}
