/*
** BmsDashboard - JK BMS dashboard for Venus OS GUIv2.
** Two JK BMS rendered as classic batteries, side by side.
** Per-BMS UI lives in BmsPanel.qml.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

Page {
	id: root

	title: "BMS Dashboard"

	// Hardcoded dbus service names. gui-v2 uses the "dbus/" prefix on serviceUid.
	// >>> Replace the service UIDs and MAC labels below with your own BMS. <<<
	// Find your service names on the device with:  dbus -y | grep battery
	readonly property var bmsList: [
		{ service: "dbus/com.victronenergy.battery.ble_001122334455", label: "JK BMS 1", mac: "44:55" },
		{ service: "dbus/com.victronenergy.battery.ble_aabbccddeeff", label: "JK BMS 2", mac: "EE:FF" }
	]

	RowLayout {
		anchors.fill: parent
		anchors.margins: 12
		spacing: 12

		Repeater {
			model: root.bmsList

			delegate: BmsPanel {
				Layout.fillWidth: true
				Layout.fillHeight: true
				serviceUid: modelData.service
				label: modelData.label
				mac: modelData.mac
			}
		}
	}
}
