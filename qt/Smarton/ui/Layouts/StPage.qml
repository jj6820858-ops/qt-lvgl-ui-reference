import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StPage
    \inqmlmodule SmarTon.Ui.Layouts
    \brief Content frame for every screen inside the signed-in shell.

    Holds the page padding in one place so no screen invents its own margins.
    Deliberately nothing else: the Figma content frames have no shared header
    bar, and a header slot that no screen uses is a slot that rots. It is added
    the day two screens need the same one.
*/
Item {
    id: root

    /*! Page body. Default property. */
    default property alias content: contentSlot.data

    property int padding: Theme.spacing8

    Item {
        id: contentSlot
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
