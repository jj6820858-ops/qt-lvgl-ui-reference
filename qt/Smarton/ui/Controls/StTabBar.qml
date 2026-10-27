import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StTabBar
    \inqmlmodule SmarTon.Ui.Controls
    \brief Underlined tabs over a hairline rule. Figma frame 27.

    The active tab is brand orange with a 3 px orange underline that slides;
    the rule beneath spans the full width. Distinct from StSegmentedControl,
    which is a pill track - the design uses both, for section tabs and for
    filters respectively.
*/
Item {
    id: root

    property var model: []
    property int currentIndex: 0

    signal selected(int index)

    implicitHeight: 52

    Accessible.role: Accessible.PageTabList
    Accessible.name: qsTr("Sections")

    Row {
        id: row
        anchors.left: parent.left
        anchors.bottom: rule.top
        spacing: 0

        Repeater {
            model: root.model

            delegate: Item {
                id: tab

                required property int index
                required property var modelData

                readonly property bool current: tab.index === root.currentIndex

                width: tabLabel.implicitWidth + Theme.spacing8 * 2
                height: root.implicitHeight - 3

                StLabel {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: tab.modelData
                    level: 1
                    color: tab.current ? Theme.primary : Theme.textSecondary
                    font.weight: tab.current ? Theme.fontWeightBold
                                             : Theme.fontWeightRegular
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                TapHandler {
                    onTapped: root.selected(tab.index)
                }
            }
        }
    }

    Rectangle {
        id: rule
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.outline
        opacity: 0.6
    }

    // The moving underline. Animating x and width rather than re-rendering
    // per tab keeps the motion continuous when tabs differ in width.
    Rectangle {
        id: indicator

        anchors.bottom: parent.bottom
        height: 3
        radius: 1.5
        color: Theme.primary
        x: currentTab ? currentTab.x : 0
        width: currentTab ? currentTab.width : 0

        readonly property Item currentTab:
            root.currentIndex >= 0 && root.currentIndex < row.children.length
                ? row.children[root.currentIndex] : null

        Behavior on x     { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
    }
}
