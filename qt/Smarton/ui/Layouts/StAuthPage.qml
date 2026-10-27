import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StAuthPage
    \inqmlmodule SmarTon.Ui.Layouts
    \brief Centred single-column frame used by every pre-login screen.

    The Figma frames are 1440x1024 and stack content down a tall page. The
    panel is 1024x600 - much wider and shorter - so the column is centred and
    vertical rhythm is tightened, while column width, control heights and radii
    stay at their designed values.
*/
Item {
    id: root

    default property alias content: column.data
    property alias spacing: column.spacing
    property int columnWidth: Theme.fieldWidth

    Column {
        id: column
        width: root.columnWidth
        anchors.centerIn: parent
        spacing: Theme.spacing4
    }
}
