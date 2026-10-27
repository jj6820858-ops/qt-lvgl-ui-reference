import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme

/*!
    \qmltype StButton
    \inqmlmodule SmarTon.Ui.Controls
    \brief Primary action button. Figma: 480x54, fill #E25319, radius 12.

    Derives from T.Button so focus, keyboard activation and accessibility come
    from Qt rather than being reimplemented on a Rectangle.
*/
T.Button {
    id: root

    /*! primary | secondary | ghost | danger */
    property string variant: "primary"

    /*!
        Icon stem from the set, drawn before the label. Empty for no icon.

        Exists because three screens spelled their icon as the CHARACTER "+"
        inside the label text ("+  Add new scene"). That renders in whatever
        the UI font has at that codepoint - a different weight from the icon
        set, a different optical size, no way to align it to the cap height,
        and on some systems a coloured emoji. An icon is a glyph from the set
        or it is not an icon.

        NOT called `icon`: AbstractButton already has a FINAL grouped `icon`
        property (icon.name, icon.source, ...), and shadowing it is a hard
        error rather than an override.
    */
    property string iconName: ""
    /*! Matched to the label's cap height rather than the button's height, so
        the pair reads as one word-and-mark instead of a badge beside text. */
    property int iconSize: 20

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Theme.controlHeight
    leftPadding: Theme.spacing6
    rightPadding: Theme.spacing6
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    activeFocusOnTab: true

    // Screen readers get the label and the state. Qt Quick Templates supplies
    // the Button role and the pressed/enabled state; the NAME is the one thing
    // it cannot infer, because the label lives in a contentItem we replaced.
    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Accessible.onPressAction: root.clicked()

    /*! One place, so the icon cannot end up a different colour from the label
        it sits next to - which is the failure mode of tinting them separately. */
    readonly property color foreground:
        !root.enabled ? Theme.textDisabled
      : root.variant === "primary" ? Theme.textOnPrimary
      : root.variant === "ghost"   ? Theme.primary
      : root.variant === "danger"  ? Theme.textOn(Theme.danger)
                                   : Theme.textSecondary

    // An Item wrapping a centred Row, not the Row directly. T.Button stretches
    // its contentItem to availableWidth, and a stretched Row lays its children
    // out from the LEFT - so making the content a Row without this would
    // left-align the label on every button in the app.
    contentItem: Item {
        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        Row {
            id: content

            anchors.centerIn: parent
            spacing: root.iconName.length > 0 ? Theme.spacing2 : 0

            StIcon {
                id: glyph

                name: root.iconName
                size: root.iconSize
                color: root.foreground
                visible: root.iconName.length > 0
                // Qualified: .qmllint.ini treats an unqualified lookup as an
                // error, and it also defeats the QML compiler.
                width: glyph.visible ? root.iconSize : 0
                anchors.verticalCenter: parent.verticalCenter
            }

            StLabel {
                text: root.text
                level: 1
                font.weight: Theme.fontWeightMedium
                color: root.foreground
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    background: Rectangle {
        radius: Theme.radius
        // One state ladder for every variant: disabled beats pressed beats
        // hovered beats idle. Writing it as a ladder rather than nested
        // ternaries per variant is what stops a variant quietly missing one.
        color: {
            const base = root.variant === "danger"    ? Theme.danger
                       : root.variant === "secondary" ? Theme.surface
                       : root.variant === "ghost"     ? "transparent"
                                                      : Theme.primary;
            if (root.variant === "ghost")
                return root.down    ? Qt.rgba(1, 1, 1, Theme.pressOverlay)
                     : root.hovered ? Qt.rgba(1, 1, 1, Theme.hoverOverlay)
                                    : "transparent";
            if (!root.enabled)
                return Theme.disabledFill(base);
            if (root.down)
                return Theme.pressedFill(base);
            return Theme.hoveredFill(base, root.hovered);
        }
        border.width: root.visualFocus ? Theme.borderWidthFocus
                    : root.variant === "secondary" ? Theme.borderWidth : 0
        border.color: root.visualFocus ? Theme.focus
                    : root.hovered     ? Theme.fieldBorderHover : Theme.outline
        opacity: root.enabled ? 1 : Theme.disabledOpacity

        Behavior on color        { ColorAnimation { duration: Theme.durationFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
        Behavior on opacity      { NumberAnimation { duration: Theme.durationFast } }
    }
}
