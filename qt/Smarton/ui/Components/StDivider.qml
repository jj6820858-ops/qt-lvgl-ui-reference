import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StDivider
    \inqmlmodule SmarTon.Ui.Components
    \brief Hairline rule, optionally broken by a centred caption.

    Figma: the plain rule above "First time here?" and the "or" rule above the
    provider buttons on the Login frame are the same element with and without
    \l text - so they are one component, not two.
*/
Item {
    id: root

    /*! Caption shown in a gap at the centre. Empty draws an unbroken rule. */
    property string text: ""

    implicitHeight: root.text.length > 0
                    ? Math.max(caption.implicitHeight, 1)
                    : 1

    Rectangle {
        id: leftRule
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: root.text.length > 0 ? caption.left : parent.right
        anchors.rightMargin: root.text.length > 0 ? Theme.spacing4 : 0
        height: 1
        color: Theme.outline
        opacity: 0.55
    }

    StLabel {
        id: caption
        anchors.centerIn: parent
        text: root.text
        level: 1
        tone: "secondary"
        visible: root.text.length > 0
    }

    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: caption.right
        anchors.leftMargin: Theme.spacing4
        height: 1
        color: Theme.outline
        opacity: 0.55
        visible: root.text.length > 0
    }
}
