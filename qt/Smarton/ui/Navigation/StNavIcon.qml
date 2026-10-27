import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StNavIcon
    \inqmlmodule SmarTon.Ui.Navigation
    \brief Maps a route name to its icon.

    Thin, and deliberately so. It used to be 70 lines of Canvas drawing seven
    glyphs by hand, which made the sidebar its own private icon library: the
    strokes were a different weight from every other icon in the app, and
    "spaces" looked nothing like the house in an empty state even though they
    mean the same thing.

    All it does now is translate a ROUTE to an ICON NAME. That translation is
    real work worth having in one place - `spaces` is drawn as a house - and it
    is the only thing here.
*/
Item {
    id: root

    /*! spaces | rooms | devices | members | statistics | operations | settings | logout */
    property string name: "spaces"
    /*! Named `stroke` for source compatibility with the Canvas version. */
    property color stroke: Theme.textMuted
    property int size: 20

    implicitWidth: root.size
    implicitHeight: root.size

    readonly property string iconName: {
        switch (root.name) {
        case "spaces":     return "home";
        case "rooms":      return "rooms";
        case "devices":    return "devices";
        case "members":    return "members";
        case "statistics": return "statistics";
        case "operations": return "bell";
        case "settings":   return "settings";
        case "logout":     return "logout";
        default:           return "home";
        }
    }

    StIcon {
        anchors.fill: parent
        name: root.iconName
        size: root.size
        color: root.stroke
    }
}
