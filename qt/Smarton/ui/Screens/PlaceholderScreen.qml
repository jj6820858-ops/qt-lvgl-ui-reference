import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Layouts
import SmarTon.Ui.Components

/*!
    \qmltype PlaceholderScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief Honest stand-in for a destination whose design is not built yet.

    Every sidebar entry navigates somewhere. Rather than disable the entries
    that are not implemented - which hides the product's shape - they route
    here, which states plainly what is coming and which Figma frame it is from.
    Each one is deleted the moment its real screen lands.
*/
StPage {
    id: root

    property string title: ""
    property string detail: ""

    StEmptyState {
        anchors.fill: parent
        title: root.title
        detail: root.detail
    }
}
