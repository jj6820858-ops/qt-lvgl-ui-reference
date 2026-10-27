import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StOtpField
    \inqmlmodule SmarTon.Ui.Controls
    \brief Segmented verification-code entry. Figma: four boxes on Verify Code.

    Focus advances on entry and retreats on backspace, which is what makes a
    segmented field usable at all - especially with an on-screen keyboard,
    where tapping the right box between digits is not realistic.

    TWO THINGS HERE ARE DELIBERATE AND EASY TO "SIMPLIFY" INTO BUGS.

    \list
    \li \l code is assigned by \c _syncCode() rather than declared as a
        binding over every cell. As a binding it would be re-evaluated by the
        engine at an unspecified point relative to the cell's own
        onTextChanged, so \c completed() could fire against a stale value on
        the last digit - the exact digit that matters.
    \li The cell's focus helper is called \c focusCell(), not
        forceActiveFocus(). Item already has a method by that name, and
        shadowing it from QML is not a thing to rely on.
    \endlist
*/
FocusScope {
    id: root

    property int digits: 4

    /*! The assembled code. Read-only from outside. */
    readonly property string code: root._code
    readonly property bool complete: root.code.length === root.digits

    /*! Emitted once, when the last empty cell is filled. */
    signal completed(string code)

    /*! Empty every cell and return focus to the first. */
    function clear(): void {
        for (let i = 0; i < repeater.count; ++i)
            repeater.itemAt(i).cellText = "";
        root._syncCode();
        if (repeater.count > 0)
            repeater.itemAt(0).focusCell();
    }

    property string _code: ""

    function _syncCode(): void {
        let out = "";
        for (let i = 0; i < repeater.count; ++i)
            out += repeater.itemAt(i).cellText;
        root._code = out;
    }

    Accessible.role: Accessible.EditableText
    Accessible.name: qsTr("Verification code")
    Accessible.description: qsTr("%n of %1 digits entered", "", root.code.length)
                                .arg(root.digits)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacing4

        Repeater {
            id: repeater
            model: root.digits

            delegate: Rectangle {
                id: cell

                required property int index
                property alias cellText: input.text

                function focusCell(): void { input.forceActiveFocus(); }

                width: 56
                height: 56
                radius: Theme.radius
                color: Theme.surface
                border.width: input.activeFocus ? Theme.borderWidthFocus : Theme.borderWidth
                border.color: input.activeFocus ? Theme.focus : Theme.surface

                TextInput {
                    id: input
                    anchors.fill: parent
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    maximumLength: 1
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: RegularExpressionValidator { regularExpression: /[0-9]/ }
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSubtitle
                    font.weight: Theme.fontWeightMedium
                    selectByMouse: false
                    cursorVisible: activeFocus

                    onTextChanged: {
                        root._syncCode();
                        if (input.text.length === 1 && cell.index + 1 < repeater.count)
                            repeater.itemAt(cell.index + 1).focusCell();
                        if (root.complete)
                            root.completed(root.code);
                    }

                    Keys.onPressed: function (event) {
                        // Backspace on an EMPTY cell steps back and clears the
                        // previous one. On a filled cell TextInput deletes the
                        // digit itself, which is what people expect.
                        if (event.key === Qt.Key_Backspace && input.text.length === 0
                                && cell.index > 0) {
                            const prev = repeater.itemAt(cell.index - 1);
                            prev.cellText = "";
                            prev.focusCell();
                            root._syncCode();
                            event.accepted = true;
                        }
                    }
                }

                // Placeholder dash, shown only while the cell is empty and cold.
                StLabel {
                    anchors.centerIn: parent
                    text: "–"
                    level: 2
                    tone: "disabled"
                    visible: input.text.length === 0 && !input.activeFocus
                }

                Behavior on border.color {
                    ColorAnimation { duration: Theme.durationFast }
                }
            }
        }
    }

    Component.onCompleted: if (repeater.count > 0) repeater.itemAt(0).focusCell()
}
