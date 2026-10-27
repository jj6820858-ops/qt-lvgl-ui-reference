import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme

/*!
    \qmltype StSearchField
    \inqmlmodule SmarTon.Ui.Controls
    \brief Search input with a trailing magnifier. Figma frames 16 and 17.
*/
T.TextField {
    id: root

    /*! Marks this as a place a person can type. Read by Helpers/Focus.js to
        decide where focus lands when a screen or a wizard step opens. */
    readonly property bool stTextInput: true

    implicitWidth: 480
    implicitHeight: Theme.controlHeight
    leftPadding: Theme.spacing5
    rightPadding: Theme.spacing10

    hoverEnabled: true
    activeFocusOnTab: true

    Accessible.role: Accessible.EditableText
    Accessible.name: root.placeholderText
    selectByMouse: true
    renderType: Text.QtRendering

    placeholderText: qsTr("Search")
    color: Theme.textPrimary
    placeholderTextColor: Theme.textMuted
    selectionColor: Theme.primary
    selectedTextColor: Theme.textPrimary
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeBody
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        radius: Theme.radius
        color: root.hovered && !root.activeFocus
               ? Qt.lighter(Theme.surface, 1 + Theme.hoverOverlay)
               : Theme.surface
        border.width: root.activeFocus ? Theme.borderWidthFocus : Theme.borderWidth
        border.color: root.activeFocus ? Theme.focus
                    : root.hovered     ? Theme.fieldBorderHover
                                       : Theme.fieldBorder

        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
        Behavior on color        { ColorAnimation { duration: Theme.durationFast } }
    }

    /*!
        The placeholder, drawn.

        T.TextField declares \c placeholderText and \c placeholderTextColor but
        does NOT render them - in Qt Quick Controls the placeholder is a Text
        item supplied by the STYLE's TextField.qml, alongside background and
        contentItem. This control defines its own visuals and never provided
        one, so every placeholder in the app was a property being set and read
        by nothing: the fields simply looked empty.

        Mirrors the input's own metrics rather than approximating them - same
        font, same padding, same vertical centring - because a placeholder that
        sits even a pixel off the caret line reads as a rendering fault the
        moment someone starts typing.
    */
    Text {
        id: placeholder

        x: root.leftPadding
        y: root.topPadding
        width: root.width - root.leftPadding - root.rightPadding
        height: root.height - root.topPadding - root.bottomPadding

        text: root.placeholderText
        font: root.font
        color: root.placeholderTextColor
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        renderType: root.renderType

        // preeditText matters for CJK and any other input method that composes
        // before committing: the field has no `length` yet but the person is
        // visibly typing into it, and a placeholder under their composition is
        // the classic broken-looking case.
        visible: root.length === 0 && root.preeditText.length === 0
    }

    StIcon {
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing5
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        size: 20
        color: root.activeFocus ? Theme.textPrimary : Theme.textMuted
    }
}
