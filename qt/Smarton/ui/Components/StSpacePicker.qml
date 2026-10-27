import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StSpacePicker
    \inqmlmodule SmarTon.Ui.Components
    \brief The "My Home" dropdown in the top right. Figma frames 07, 18, 21.

    Measured: 320 x 55, fill `#2A3240`, 1 px `#808B9A` border, radius 10, with
    a 34 px circular thumbnail inset 15 px. See design/measurements.md.

    THIS IS NOW JUST A CONFIGURED StComboBox. The previous version stacked a
    thumbnail Rectangle on TOP of a combobox and pushed the label clear with a
    hand-computed `leftPadding` - which meant two components each guessing the
    other's metrics, and the label sat wrong. The thumbnail belongs inside the
    control, so it moved there.

    SmarTon holds one space today, so the list usually has a single entry.
    What earns the control its place is the pinned action beneath it: "Create
    a new space" is the only route into the wizard from the dashboard.
*/
Item {
    id: root

    property string spaceName: ""
    property url    thumbnailSource: ""
    /*! [{ name, image }, ...]. Defaults to the single current space. */
    property var    spaces: []

    /*! A space was chosen. Named spaceSelected, not activated: T.ComboBox
        already has an `activated` signal, and two of the same name on nested
        types is how a handler gets silently wired to the wrong one. */
    signal spaceSelected(int index)
    signal createSpaceRequested()

    implicitWidth: combo.implicitWidth
    implicitHeight: combo.implicitHeight

    readonly property var _entries:
        root.spaces.length > 0
            ? root.spaces
            : [ { name: root.spaceName, image: root.thumbnailSource } ]

    StComboBox {
        id: combo

        anchors.fill: parent
        model: root._entries
        textRole: "name"
        imageRole: "image"
        leadingImage: root.thumbnailSource
        currentIndex: 0
        accessibleName: qsTr("Space")
        actionText: qsTr("+  Create a new space")

        onActivated: index => root.spaceSelected(index)
        onActionTriggered: root.createSpaceRequested()
    }
}
