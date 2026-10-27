import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StSegmentedControl
    \inqmlmodule SmarTon.Ui.Controls
    \brief Row of mutually exclusive segments in one rounded track.

    Figma: "Map view / List view" on frame 18, where the selected segment is
    brand orange inside a bordered track. Distinct from StChip, which is a row
    of separate pills - same job, different visual, and the design uses both.
*/
Item {
    id: root

    property var model: []
    property int currentIndex: 0

    signal selected(int index)

    implicitWidth: row.implicitWidth + 8
    implicitHeight: 44

    Accessible.role: Accessible.PageTabList
    Accessible.name: qsTr("View")

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.outline
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: root.model

            delegate: Item {
                id: segment

                required property int index
                required property var modelData

                readonly property bool current: segment.index === root.currentIndex

                width: Math.max(110, segmentLabel.implicitWidth + Theme.spacing6 * 2)
                height: 36

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: segment.current ? Theme.primary : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                StLabel {
                    id: segmentLabel
                    anchors.centerIn: parent
                    text: segment.modelData
                    level: 1
                    color: segment.current ? Theme.textOnPrimary : Theme.textSecondary
                    font.weight: segment.current ? Theme.fontWeightMedium
                                                 : Theme.fontWeightRegular
                }

                TapHandler {
                    onTapped: root.selected(segment.index)
                }
            }
        }
    }
}
