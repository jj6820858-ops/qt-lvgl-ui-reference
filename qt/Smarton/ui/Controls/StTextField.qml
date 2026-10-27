import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme

/*!
    \qmltype StTextField
    \inqmlmodule SmarTon.Ui.Controls
    \brief Text input. Figma: 478x52, fill #2D3542, focus ring #1268CC 2 px.

    STATE MODEL, in the order a control actually moves through it:

    \table
    \header \li State \li Border \li Fill
    \row \li idle     \li 1 px \c outline        \li \c surface
    \row \li hover    \li 1 px \c outlineSubtle  \li \c surface, lifted
    \row \li focused  \li 2 px \c focus          \li \c surface
    \row \li error    \li 2 px \c danger         \li \c surface
    \row \li disabled \li 1 px \c outline @45%   \li muted, whole item at 45%
    \endtable

    The idle border is the important one. The first version drew it in the
    same colour as the fill, which is the same as drawing no border: the field
    read as a flat panel and there was nothing to say it could be typed into.
    An input needs an edge even when nothing is happening to it.

    KEYBOARD. \c activeFocusOnTab is on, so Tab reaches it without every
    screen wiring an explicit chain; screens that want a specific order still
    set KeyNavigation.tab. Enter emits accepted(). The reveal toggle is
    reachable with Tab too - a password field whose only way to unmask is a
    mouse is unusable on a panel with a hardware keyboard and no pointer.
*/
T.TextField {
    id: root

    /*! Marks this as a place a person can type. Read by Helpers/Focus.js to
        decide where focus lands when a screen or a wizard step opens. */
    readonly property bool stTextInput: true

    /*! Shown below the field in danger colour. Empty means no error. */
    property string errorText: ""
    /*! Set true to mask input and show the reveal toggle. */
    property bool password: false
    /*! Bound by the reveal toggle. */
    property bool revealed: false

    readonly property bool hasError: root.errorText.length > 0

    implicitWidth: Theme.fieldWidth
    implicitHeight: Theme.controlHeight
    leftPadding: Theme.spacing5
    rightPadding: root.password ? Theme.spacing10 + Theme.spacing2 : Theme.spacing5
    topPadding: 0
    bottomPadding: 0

    hoverEnabled: true
    activeFocusOnTab: true

    /*! Spoken label. Falls back to the placeholder, which is usually the only
        label these fields have - the design labels very few of them visibly. */
    property string accessibleName: root.placeholderText

    Accessible.role: root.password ? Accessible.EditableText : Accessible.EditableText
    Accessible.name: root.accessibleName
    Accessible.passwordEdit: root.password
    // The error, not the contents: never announce a password field's text.
    Accessible.description: root.hasError ? root.errorText : ""
    selectByMouse: true
    persistentSelection: true

    echoMode: root.password && !root.revealed ? TextInput.Password : TextInput.Normal
    passwordCharacter: "•"
    passwordMaskDelay: 0

    color: root.enabled ? Theme.textPrimary : Theme.textDisabled
    placeholderTextColor: Theme.textMuted
    selectionColor: Theme.primary
    selectedTextColor: Theme.textPrimary
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeBody
    verticalAlignment: TextInput.AlignVCenter
    // Qt rendering, not Native: the fields animate their borders and sit
    // inside Flickables at fractional offsets, where NativeRendering shimmers.
    renderType: Text.QtRendering

    opacity: root.enabled ? 1 : Theme.disabledOpacity

    background: Rectangle {
        radius: Theme.radius
        color: root.enabled && root.hovered && !root.activeFocus
               ? Qt.lighter(Theme.surface, 1 + Theme.hoverOverlay)
               : Theme.surface

        border.width: root.activeFocus || root.hasError
                      ? Theme.borderWidthFocus : Theme.borderWidth
        border.color: root.hasError    ? Theme.danger
                    : root.activeFocus ? Theme.focus
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

    // Reveal / hide toggle, drawn as a crossed eye to match the Figma icon.
    Item {
        id: revealToggle

        visible: root.password
        width: Theme.touchTarget
        height: Theme.touchTarget
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing2
        anchors.verticalCenter: parent.verticalCenter
        activeFocusOnTab: root.password

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Theme.radiusSm
            color: hoverArea.hovered ? Qt.rgba(1, 1, 1, Theme.hoverOverlay) : "transparent"
            border.width: revealToggle.activeFocus ? Theme.borderWidthFocus : 0
            border.color: Theme.focus

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        StIcon {
            anchors.centerIn: parent
            // Two icons, not one drawn two ways: "hidden" is a distinct glyph
            // with the slash baked into its geometry, so the strokes meet
            // correctly instead of a line being laid over a drawing.
            name: root.revealed ? "eye" : "eyeOff"
            size: 20
            color: hoverArea.hovered ? Theme.textPrimary : Theme.textMuted
        }

        HoverHandler { id: hoverArea }

        TapHandler {
            onTapped: root.revealed = !root.revealed
        }

        // Space and Enter work once Tab has landed here.
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                    || event.key === Qt.Key_Enter) {
                root.revealed = !root.revealed;
                event.accepted = true;
            }
        }
    }

    // Error text sits BELOW the field and outside it, so it never shortens the
    // input's own height and never reflows the form when it appears.
    StLabel {
        anchors.top: parent.bottom
        anchors.topMargin: Theme.spacing1
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacing1
        anchors.right: parent.right
        text: root.errorText
        level: 0
        color: Theme.danger
        visible: root.hasError
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }
}
