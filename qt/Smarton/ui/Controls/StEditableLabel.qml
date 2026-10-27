import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StEditableLabel
    \inqmlmodule SmarTon.Ui.Controls
    \brief A heading that turns into a field when you tap the pencil.

    Figma shows the pencil beside "My Home" (frames 13, 15) and beside each
    room name (18). Rather than a modal dialog for a one-field change, the
    label edits in place.

    Rules that make in-place editing safe rather than annoying:
    \list
    \li Enter commits, Escape reverts. Both are expected and neither is
        discoverable, so the frame also gets an explicit tick and cross.
    \li Losing focus COMMITS rather than reverting. Tapping elsewhere after
        typing a name reads as "done", not "throw it away".
    \li An empty or whitespace-only name is refused and reverts, because the
        service refuses it too - the UI must not appear to accept what the
        layer below will drop.
    \endlist
*/
FocusScope {
    id: root

    property string text: ""
    property int level: 3
    property bool editable: true

    /*! Emitted with the trimmed new name, only when it actually changed. */
    signal committed(string name)

    readonly property bool editing: editor.visible

    Accessible.role: Accessible.EditableText
    Accessible.name: root.text
    Accessible.description: root.editable ? qsTr("Editable. Activate to rename.") : ""
    Accessible.onPressAction: root.beginEdit()

    function beginEdit(): void {
        if (!root.editable)
            return;
        editor.text = root.text;
        editor.visible = true;
        editor.forceActiveFocus();
        editor.selectAll();
    }

    function commit(): void {
        const cleaned = editor.text.trim();
        editor.visible = false;
        if (cleaned.length > 0 && cleaned !== root.text)
            root.committed(cleaned);
    }

    function cancel(): void {
        editor.visible = false;
    }

    implicitWidth: editor.visible ? Math.max(240, editor.implicitWidth + 24)
                                  : display.implicitWidth + (root.editable ? 30 : 0)
    implicitHeight: 36

    Row {
        visible: !editor.visible
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing2

        StLabel {
            id: display
            text: root.text
            level: root.level
            anchors.verticalCenter: parent.verticalCenter
        }

        // StIcon rather than StIconButton: this pencil has no background and
        // no press surface of its own - the tap target is the label beside it.
        Item {
            width: 22
            height: 22
            visible: root.editable
            anchors.verticalCenter: parent.verticalCenter

            StIcon {
                anchors.fill: parent
                name: "edit"
                size: 20
                color: Theme.primary
            }

            TapHandler {
                // 22 px of pencil, 44 px of target. `margin` accepts a press
                // outside the item's bounds, which is the only way to grow a
                // hit area without growing the picture.
                margin: (Theme.touchTarget - 22) / 2
                onTapped: root.beginEdit()
            }
        }
    }

    TextInput {
        id: editor

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: false
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: root.level >= 3 ? Theme.fontSizeTitle : Theme.fontSizeBody
        font.weight: Theme.fontWeightBold
        selectionColor: Theme.primary
        selectedTextColor: Theme.textPrimary
        selectByMouse: true
        maximumLength: 48          // matches HomeService::sanitiseName

        onAccepted: root.commit()
        onActiveFocusChanged: if (!editor.activeFocus && editor.visible) root.commit()

        Keys.onEscapePressed: function (event) {
            root.cancel();
            event.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -Theme.spacing2
            z: -1
            radius: Theme.radiusSm
            color: Theme.surface
            border.width: Theme.borderWidthFocus
            border.color: Theme.focus
        }
    }
}
