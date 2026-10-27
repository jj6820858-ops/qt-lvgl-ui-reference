import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StEmptyState
    \inqmlmodule SmarTon.Ui.Components
    \brief Illustration + headline + call to action for a view with no data.

    Figma frames 06 (no spaces), 12 (no rooms) and 16 (no linked devices) are
    the same composition with different copy and artwork, so they are one
    component.

    CENTRED IN WHATEVER SPACE IT IS GIVEN. The first version anchored the
    heading to the top and the button to the bottom, so the block stretched to
    the caller's height: on a screen with room to spare the text sat high, the
    artwork under it, and the bottom two thirds of the panel were empty. An
    empty state is the only thing on the screen - it belongs in the middle of
    it, sized to its own content.

    The artwork then takes whatever the text and the button leave, capped by
    \l imageSize, so it can never push the call to action off the bottom.
*/
Item {
    id: root

    property string title: qsTr("Nothing here yet")
    property string detail: ""
    property url    imageSource: ""
    property string actionText: ""
    /*! Upper bound for the artwork; the real size also respects free height. */
    property int    imageSize: 300

    signal actionTriggered()

    /*! Text and button; whatever is left over is the artwork's. */
    readonly property int _reserved: heading.height + Theme.spacing6 * 2
                                     + (cta.visible ? cta.height : 0)

    Column {
        id: layout

        anchors.centerIn: parent
        width: parent.width
        spacing: Theme.spacing6

        Column {
            id: heading

            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 620)
            spacing: Theme.spacing3

            StLabel {
                width: parent.width
                text: root.title
                level: 4
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideNone
            }

            StLabel {
                width: parent.width
                text: root.detail
                level: 2
                tone: "secondary"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: root.detail.length > 0
                elide: Text.ElideNone
            }
        }

        Image {
            id: art

            anchors.horizontalCenter: parent.horizontalCenter
            source: root.imageSource
            visible: root.imageSource.toString().length > 0
            fillMode: Image.PreserveAspectFit
            // Grows into whatever the text and button leave, up to imageSize.
            // Callers used to pass a deliberately small imageSize to stop the
            // artwork overflowing a fixed-height block; with the block centred
            // and sized to its content that workaround is unnecessary, and the
            // illustration can be the size it was drawn to be read at.
            height: Math.max(0, Math.min(root.imageSize,
                                         root.height - root._reserved))
            width: art.height
            // Decoded at 2x: these are detailed isometric illustrations, and
            // at 1x on a 2x panel they visibly mush.
            sourceSize.height: root.imageSize * 2
            smooth: true
            mipmap: true
            asynchronous: true
        }

        StButton {
            id: cta

            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.fieldWidth               // Figma CTA is 480 wide
            text: root.actionText
            visible: root.actionText.length > 0
            onClicked: root.actionTriggered()
        }
    }
}
