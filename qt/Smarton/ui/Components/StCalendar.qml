import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StCalendar
    \inqmlmodule SmarTon.Ui.Components
    \brief Month grid with multi-select days. Figma frame 25.

    Seven columns, each cell showing the date over its weekday abbreviation -
    the design's layout, and the reason there is no separate weekday header
    row. Selection is a set of day numbers rather than dates, because a scene
    repeats monthly; the month shown is for orientation.

    Localised through QLocale: month name, weekday abbreviations and the
    first day of the week all come from the system, so this does not silently
    assume a Monday-first Gregorian week.
*/
Item {
    id: root

    property int year: 2024
    property int month: 3
    /*! Selected day numbers, e.g. [3, 4, 10, 11]. */
    property var selectedDays: []

    signal dayToggled(int day)
    signal monthStepped(int delta)

    readonly property int daysInMonth: new Date(root.year, root.month, 0).getDate()
    readonly property string monthLabel:
        Qt.locale().standaloneMonthName(root.month - 1, Locale.LongFormat)
        + " " + root.year

    implicitHeight: header.height + grid.implicitHeight + Theme.spacing6 * 2

    function isSelected(day: int): bool {
        return root.selectedDays.indexOf(day) !== -1;
    }

    StShadow { anchors.fill: parent; radius: Theme.radiusLg }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceRaised
    }

    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacing5
        height: 56

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StLabel { text: root.monthLabel; level: 2; font.weight: Theme.fontWeightBold }
            StLabel { text: qsTr("Select the desired dates"); level: 1; tone: "secondary" }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing2

            StIconButton {
                glyph: "back"
                size: 36
                fill: "transparent"
                stroke: Theme.textSecondary
                accessibleName: qsTr("Previous month")
                onClicked: root.monthStepped(-1)
            }

            StIconButton {
                glyph: "forward"
                size: 36
                accessibleName: qsTr("Next month")
                fill: "transparent"
                stroke: Theme.primary
                onClicked: root.monthStepped(1)
            }
        }
    }

    Grid {
        id: grid

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.margins: Theme.spacing5
        anchors.topMargin: Theme.spacing3
        columns: 7
        spacing: Theme.spacing2

        readonly property real cellWidth:
            (grid.width - grid.spacing * (grid.columns - 1)) / grid.columns

        Repeater {
            model: root.daysInMonth

            delegate: Rectangle {
                id: cell

                required property int index

                readonly property int day: cell.index + 1
                readonly property bool picked: root.isSelected(cell.day)
                readonly property date cellDate: new Date(root.year, root.month - 1, cell.day)

                width: grid.cellWidth
                height: 66
                radius: Theme.radiusSm
                color: cell.picked ? Theme.infoDeep : Theme.surface
                border.width: cell.picked ? Theme.borderWidth : 0
                border.color: Theme.info

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    StLabel {
                        text: String(cell.day)
                        level: 2
                        font.weight: Theme.fontWeightMedium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StLabel {
                        text: Qt.locale().dayName(cell.cellDate.getDay(), Locale.ShortFormat)
                        level: 0
                        color: cell.picked ? Theme.infoSoft : Theme.textMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                TapHandler {
                    onTapped: root.dayToggled(cell.day)
                }
            }
        }
    }
}
