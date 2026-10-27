import QtQuick
import QtQuick.Controls.Basic as QQC
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Layouts
import SmarTon.Ui.Components

/*!
    \qmltype StatisticsScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief Electricity usage. Figma frame 26.

    THE NUMBERS ARE DERIVED, NOT MEASURED, and the screen says so. SmarTon has
    no metering hardware and no history table, so HomeViewModel::energySeries()
    returns a deterministic shape scaled from the rooms' seeded consumption.
    A chart that looked measured would be the most quietly dishonest thing in
    the app - people make decisions from these.
*/
Item {
    id: root

    /*!
        True only when this screen was pushed onto something that can be
        popped.

        Read from the enclosing StackView's LIVE depth rather than hard-coded.
        Every screen with a back arrow used to assert it unconditionally,
        including the ones the sidebar opens as a root destination - so Members
        and Statistics drew a back button that could not do anything, and
        pressing it did nothing at all. A control that is visible and inert is
        worse than one that is absent: it teaches people the app ignores them.

        The attached property resolves because THIS item is what was pushed;
        it is null in the gallery, where screens are shown outside a stack.
    */
    readonly property bool canGoBack:
        QQC.StackView.view !== null && QQC.StackView.view.depth > 1

    /*! smarton::models::HomeViewModel. */
    required property var viewModel

    readonly property var periods: [qsTr("Today"), qsTr("Week"), qsTr("Month"),
                                    qsTr("Year"), qsTr("Quarter")]
    property int periodIndex: 1

    readonly property var axisLabels: {
        switch (root.periodIndex) {
        case 0:  return ["00", "03", "06", "09", "12", "15", "18", "21"];
        case 2:  return [qsTr("W1"), qsTr("W2"), qsTr("W3"), qsTr("W4")];
        case 3:  return ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];
        case 4:  return [qsTr("Q1"), qsTr("Q2"), qsTr("Q3"), qsTr("Q4")];
        default: return ["M", "T", "W", "T", "F", "S", "S"];
        }
    }

    property var series: []
    property int selectedIndex: 3

    signal backRequested()
    signal roomRequested(string roomId)

    function reloadSeries(): void {
        root.series = root.viewModel.energySeries(root.periods[root.periodIndex]);
        root.selectedIndex = Math.min(root.selectedIndex, root.series.length - 1);
    }

    Component.onCompleted: root.reloadSeries()

    StScrollView {
        id: scroller

        anchors.fill: parent
        contentHeight: column.implicitHeight + Theme.spacing8 * 2

        Column {
            id: column

            x: Theme.bandBleed
            y: Theme.spacing4
            width: scroller.width - Theme.bandBleed * 2
            spacing: Theme.spacing5

            StTopBar {
                width: parent.width
                showBack: root.canGoBack
                titleRowHeight: 92
                eyebrow: qsTr("Statistics")
                title: qsTr("Electricity Usage")
                onBackRequested: root.backRequested()

                trailing: Component {
                    Row {
                        spacing: Theme.spacing3

                        Repeater {
                            model: root.periods

                            delegate: StChip {
                                required property int index
                                required property var modelData

                                text: modelData
                                selected: index === root.periodIndex
                                onClicked: {
                                    root.periodIndex = index;
                                    root.reloadSeries();
                                }
                            }
                        }
                    }
                }
            }

            // ---- chart + side stats ---------------------------------------
            Item {
                width: parent.width
                height: 360

                StShadow { anchors.fill: parent; radius: Theme.radiusLg }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusLg
                    color: Theme.surfaceDeep

                    StLineChart {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: sideStats.left
                        anchors.margins: Theme.spacing5
                        values: root.series
                        labels: root.axisLabels
                        selectedIndex: root.selectedIndex
                        onPointSelected: index => root.selectedIndex = index
                    }

                    Column {
                        id: sideStats

                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.spacing5
                        width: 172
                        spacing: Theme.spacing4

                        StStatCard {
                            width: parent.width
                            height: (parent.height - Theme.spacing4) / 2
                            caption: qsTr("This %1").arg(root.periods[root.periodIndex])
                            value: String(Math.round(
                                        root.viewModel.energyTotal(root.periods[root.periodIndex])))
                            unit: qsTr("kW")
                            delta: 7.45
                        }

                        StStatCard {
                            width: parent.width
                            height: (parent.height - Theme.spacing4) / 2
                            caption: qsTr("Total Loss")
                            value: (root.viewModel.energyTotal(root.periods[root.periodIndex])
                                    * 0.06).toFixed(1)
                            unit: qsTr("kW")
                            delta: -3.35
                        }
                    }
                }
            }

            // Honest about where the figures come from. Removed the day a
            // meter is wired in - not before.
            StLabel {
                width: parent.width
                text: qsTr("Derived from configured room consumption. SmarTon has no metering hardware yet, so these figures are a preview of the view, not measurements.")
                level: 0
                tone: "muted"
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }

            // Health belongs next to energy: this is the operational view a
            // homeowner opens to spot a dead sensor or a stale gateway, not a
            // hidden installer-only counter.
            Rectangle {
                width: parent.width
                implicitHeight: healthRow.implicitHeight + Theme.spacing5 * 2
                radius: Theme.radiusLg
                color: Theme.surfaceDeep

                Row {
                    id: healthRow
                    anchors.fill: parent
                    anchors.margins: Theme.spacing5
                    spacing: Theme.spacing6

                    Repeater {
                        model: [
                            { label: qsTr("Offline"), value: root.viewModel.offlineDeviceCount,
                              detail: root.viewModel.offlineDeviceNames().join(", ") },
                            { label: qsTr("Stale data"), value: root.viewModel.staleDeviceCount,
                              detail: root.viewModel.staleDeviceNames().join(", ") },
                            { label: qsTr("Low battery"), value: root.viewModel.lowBatteryCount,
                              detail: root.viewModel.lowBatteryNames().join(", ") }
                        ]
                        delegate: Column {
                            required property var modelData
                            width: (healthRow.width - healthRow.spacing * 2) / 3
                            spacing: Theme.spacing1
                            StLabel { text: modelData.label; level: 1; tone: "secondary" }
                            StLabel { text: String(modelData.value); level: 3 }
                            StLabel {
                                width: parent.width
                                visible: modelData.value > 0
                                text: modelData.detail
                                level: 0; tone: "muted"; elide: Text.ElideRight
                            }
                            StLabel {
                                visible: modelData.value === 0
                                text: qsTr("No action needed")
                                level: 0; tone: "muted"
                            }
                        }
                    }
                }
            }

            // ---- per-room consumption -------------------------------------
            Row {
                x: Theme.pageMargin - Theme.bandBleed
                spacing: Theme.spacing3

                StLabel {
                    text: qsTr("Your Rooms")
                    level: 3
                    anchors.verticalCenter: parent.verticalCenter
                }
                StCountPill {
                    value: root.viewModel.roomCount
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Grid {
                id: roomGrid

                x: Theme.pageMargin - Theme.bandBleed
                width: parent.width - (Theme.pageMargin - Theme.bandBleed) * 2
                columns: 3
                columnSpacing: Theme.cardGap
                rowSpacing: Theme.cardGapV

                readonly property real cellWidth:
                    (roomGrid.width - roomGrid.columnSpacing * (roomGrid.columns - 1))
                    / roomGrid.columns

                Repeater {
                    model: root.viewModel.rooms

                    delegate: StRoomCard {
                        required property var model

                        width: roomGrid.cellWidth
                        height: Math.round(width * 0.74)
                        name: model.name
                        imageSource: root.viewModel.imageUrl(model.image)
                        deviceCount: model.deviceCount
                        energyKw: model.energyKw
                        footer: "energy"
                        onActivated: root.roomRequested(model.roomId)
                    }
                }
            }
        }
    }
}
