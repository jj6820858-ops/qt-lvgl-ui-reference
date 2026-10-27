import QtQuick
import QtQuick.Controls.Basic as QQC
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Layouts
import SmarTon.Ui.Components

/*!
    \qmltype OperationsScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief The wall-panel's day-to-day operations view.

    This is intentionally not a hidden technician page. An owner needs one
    calm place to answer: is anything unsafe, has a device fallen offline, and
    what should be serviced? It only presents reported state; it never
    pretends that a panel without a gateway can repair an appliance.
*/
Item {
    id: root

    required property var viewModel
    signal deviceRequested(string deviceId)

    StScrollView {
        id: scroller
        anchors.fill: parent
        contentHeight: column.implicitHeight + Theme.spacing8 * 2

        Column {
            id: column
            x: Theme.spacing6
            y: Theme.spacing6
            width: scroller.width - Theme.spacing6 * 2
            spacing: Theme.spacing5

            StTopBar {
                width: parent.width
                eyebrow: qsTr("Panel operations")
                title: qsTr("Home health")
                subtitle: qsTr("Safety, device availability and maintenance at a glance")
            }

            Rectangle {
                width: parent.width
                visible: root.viewModel.criticalAlerts.length > 0
                implicitHeight: alarmColumn.implicitHeight + Theme.spacing5 * 2
                radius: Theme.radiusLg
                color: Theme.danger

                Column {
                    id: alarmColumn
                    anchors.fill: parent
                    anchors.margins: Theme.spacing5
                    spacing: Theme.spacing3
                    StLabel { text: qsTr("ACTIVE SAFETY ALERT"); level: 2; color: "white" }
                    Repeater {
                        model: root.viewModel.criticalAlerts
                        delegate: StButton {
                            required property var modelData
                            text: modelData.name + qsTr(" — open device")
                            variant: "secondary"
                            onClicked: root.deviceRequested(modelData.deviceId)
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.cardGap
                Repeater {
                    model: [
                        { title: qsTr("Offline"), value: root.viewModel.offlineDeviceCount,
                          detail: root.viewModel.offlineDeviceNames().join(", ") },
                        { title: qsTr("Stale reports"), value: root.viewModel.staleDeviceCount,
                          detail: root.viewModel.staleDeviceNames().join(", ") },
                        { title: qsTr("Low battery"), value: root.viewModel.lowBatteryCount,
                          detail: root.viewModel.lowBatteryNames().join(", ") }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - parent.spacing * 2) / 3
                        height: 142
                        radius: Theme.radiusLg
                        color: Theme.surfaceDeep
                        border.width: modelData.value > 0 ? Theme.borderWidth : 0
                        border.color: modelData.value > 0 ? Theme.warning : Theme.outline
                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.spacing5
                            spacing: Theme.spacing2
                            StLabel { text: modelData.title; level: 1; tone: "secondary" }
                            StLabel { text: String(modelData.value); level: 4 }
                            StLabel {
                                width: parent.width
                                text: modelData.value > 0 ? modelData.detail : qsTr("No action needed")
                                level: 0; tone: "muted"; elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                implicitHeight: serviceColumn.implicitHeight + Theme.spacing5 * 2
                radius: Theme.radiusLg
                color: Theme.surfaceDeep
                Column {
                    id: serviceColumn
                    anchors.fill: parent
                    anchors.margins: Theme.spacing5
                    spacing: Theme.spacing3
                    StLabel { text: qsTr("Installer handoff"); level: 2 }
                    StLabel {
                        width: parent.width
                        text: qsTr("For support, collect the privacy-safe bundle from the panel or over SSH. It includes service status, recent logs, software and network facts—but never passwords, MQTT credentials, Wi-Fi keys or account data.")
                        level: 1; tone: "secondary"; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    }
                    StLabel {
                        width: parent.width
                        text: qsTr("Command: scripts/collect-support-bundle.sh root@10.42.0.130")
                        level: 0; tone: "muted"; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone
                    }
                }
            }

            StLabel {
                width: parent.width
                text: qsTr("Health indicators use the device's last reported data. A stale or offline marker means the panel is retaining the last known state, not confirming that the appliance is safe.")
                level: 0; tone: "muted"; wrapMode: Text.WordWrap; elide: Text.ElideNone
            }
        }
    }
}
