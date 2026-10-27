import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme

/*!
    \qmltype StLinkButton
    \inqmlmodule SmarTon.Ui.Controls
    \brief Inline text link. Figma: "Forget password?", "Resend Code".
*/
T.Button {
    id: root

    property bool emphasised: false

    implicitWidth: label.implicitWidth
    implicitHeight: Math.max(Theme.touchTarget, label.implicitHeight)
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    activeFocusOnTab: true

    Accessible.role: Accessible.Link
    Accessible.name: root.text
    Accessible.onPressAction: root.clicked()
    background: null

    contentItem: StLabel {
        id: label
        text: root.text
        level: 1
        color: !root.enabled ? Theme.textDisabled
             : root.down      ? Theme.pressedFill(Theme.primary)
             : root.hovered   ? Qt.lighter(Theme.primary, 1.18)
                              : Theme.primary
        font.weight: root.emphasised ? Theme.fontWeightBold : Theme.fontWeightRegular
        // Underlined on hover as well as focus: a link with no underline and
        // no cursor change is indistinguishable from coloured text.
        font.underline: root.visualFocus || root.hovered

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
