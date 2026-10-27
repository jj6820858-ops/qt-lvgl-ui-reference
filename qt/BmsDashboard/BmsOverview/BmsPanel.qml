/*
** BmsDashboard - one JK BMS rendered as a classic battery.
** Title, status cluster (Charge/Discharge/Balance/Heater), stats,
** three temperatures, and a battery graphic with four cell chambers.
** All data from dbus-serialbattery via VeQuickItem.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

Rectangle {
	id: panel

	// serviceUid already includes the gui-v2 "dbus/" prefix.
	property string serviceUid: ""
	property string label: ""
	property string mac: ""

	color: "#141416"
	border.color: "#28282c"
	border.width: 1
	radius: 12

	// --- cell voltage color thresholds (the single source of truth) ---
	readonly property real barMinV: 2.8
	readonly property real barMaxV: 3.7

	function cellColor(v) {
		if (typeof v !== "number" || isNaN(v)) return "#404040"
		// tiered classifier: critical is checked before warning, so order matters
		if (v >= 3.6 || v <= 3.0) return "#e0463b"   // critical
		if (v >= 3.5 || v <= 3.1) return "#f5a623"   // warning
		return "#4caf50"                              // ok
	}

	function fmt(item, digits, suffix) {
		return item.valid ? item.value.toFixed(digits) + (suffix || "") : "—"
	}

	// --- dbus bindings ---
	VeQuickItem { id: soc;            uid: panel.serviceUid + "/Soc" }
	VeQuickItem { id: voltage;        uid: panel.serviceUid + "/Dc/0/Voltage" }
	VeQuickItem { id: current;        uid: panel.serviceUid + "/Dc/0/Current" }
	VeQuickItem { id: power;          uid: panel.serviceUid + "/Dc/0/Power" }
	VeQuickItem { id: minCell;        uid: panel.serviceUid + "/System/MinCellVoltage" }
	VeQuickItem { id: maxCell;        uid: panel.serviceUid + "/System/MaxCellVoltage" }
	VeQuickItem { id: cellDiff;       uid: panel.serviceUid + "/Voltages/Diff" }
	VeQuickItem { id: cycles;         uid: panel.serviceUid + "/History/ChargeCycles" }
	VeQuickItem { id: remaining;      uid: panel.serviceUid + "/Capacity" }
	VeQuickItem { id: consumed;       uid: panel.serviceUid + "/ConsumedAmphours" }
	VeQuickItem { id: temp1;          uid: panel.serviceUid + "/System/Temperature1" }
	VeQuickItem { id: temp2;          uid: panel.serviceUid + "/System/Temperature2" }
	VeQuickItem { id: mosTemp;        uid: panel.serviceUid + "/System/MOSTemperature" }
	VeQuickItem { id: allowCharge;    uid: panel.serviceUid + "/Io/AllowToCharge" }
	VeQuickItem { id: allowDischarge; uid: panel.serviceUid + "/Io/AllowToDischarge" }
	VeQuickItem { id: allowBalance;   uid: panel.serviceUid + "/Io/AllowToBalance" }
	VeQuickItem { id: balancing;      uid: panel.serviceUid + "/Balancing" }
	VeQuickItem { id: heating;        uid: panel.serviceUid + "/Heating" }
	VeQuickItem { id: installed;      uid: panel.serviceUid + "/InstalledCapacity" }

	// --- inline component: one status indicator (LED + label + state) ---
	component StatusIndicator: Rectangle {
		id: ind
		property string caption: ""
		property string mode: "off"   // "on" | "off" | "active" | "heat"
		property bool _pulse: false

		Layout.fillWidth: true
		implicitHeight: 42
		radius: 9
		color: "#0f0f10"
		border.color: "#26262a"
		border.width: 1

		readonly property color ledColor: mode === "heat" ? "#f5a623"
			: (mode === "on" || mode === "active") ? "#4caf50" : "#33333a"
		readonly property string stateText: mode === "off" ? "OFF"
			: mode === "active" ? "ACTIVE" : "ON"
		readonly property color stateColor: mode === "heat" ? "#f5b948"
			: (mode === "on" || mode === "active") ? "#5cc46a" : "#6a6a72"

		Timer {
			interval: 600
			running: ind.mode === "active"
			repeat: true
			onTriggered: ind._pulse = !ind._pulse
		}

		ColumnLayout {
			anchors.centerIn: parent
			spacing: 2

			RowLayout {
				Layout.alignment: Qt.AlignHCenter
				spacing: 6
				Rectangle {
					width: 9; height: 9; radius: 4.5
					color: ind.ledColor
					opacity: ind.mode === "active" ? (ind._pulse ? 1 : 0.3) : 1
				}
				Label { text: ind.caption; font.pixelSize: 12; color: "#a6a6ac" }
			}
			Label {
				Layout.alignment: Qt.AlignHCenter
				text: ind.stateText
				font.pixelSize: 12
				font.bold: true
				color: ind.stateColor
			}
		}
	}

	// --- inline component: one temperature chip ---
	component TempChip: Rectangle {
		id: chip
		property string name: ""
		property var item: null

		Layout.fillWidth: true
		implicitHeight: 40
		radius: 8
		color: "#0f0f10"
		border.color: "#26262a"
		border.width: 1

		ColumnLayout {
			anchors.centerIn: parent
			spacing: 2
			Label {
				Layout.alignment: Qt.AlignHCenter
				text: chip.name
				font.pixelSize: 11
				color: "#85858c"
			}
			Label {
				Layout.alignment: Qt.AlignHCenter
				text: (chip.item && chip.item.valid)
					  ? chip.item.value.toFixed(1) + " °C" : "—"
				font.pixelSize: 14
				font.bold: true
				color: "#e8e8ea"
			}
		}
	}

	ColumnLayout {
		anchors.fill: parent
		anchors.margins: 14
		spacing: 10

		// --- title ---
		Label {
			Layout.fillWidth: true
			horizontalAlignment: Text.AlignHCenter
			text: panel.label + "  (" + panel.mac + ")"
			font.pixelSize: 16
			font.bold: true
		}

		// --- status cluster ---
		RowLayout {
			Layout.fillWidth: true
			spacing: 7
			StatusIndicator {
				caption: "Charge"
				mode: (allowCharge.valid && allowCharge.value === 1) ? "on" : "off"
			}
			StatusIndicator {
				caption: "Discharge"
				mode: (allowDischarge.valid && allowDischarge.value === 1) ? "on" : "off"
			}
			StatusIndicator {
				caption: "Balance"
				mode: (balancing.valid && balancing.value === 1) ? "active"
					  : (allowBalance.valid && allowBalance.value === 1) ? "on" : "off"
			}
			StatusIndicator {
				caption: "Heater"
				mode: (heating.valid && heating.value === 1) ? "heat" : "off"
			}
		}

		// --- stats grid (5 rows, 2 label/value pairs each) ---
		GridLayout {
			Layout.fillWidth: true
			columns: 4
			columnSpacing: 14
			rowSpacing: 3

			Label { text: "Remaining"; color: "#85858c"; font.pixelSize: 12 }
			Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: panel.fmt(remaining, 0, " Ah"); font.pixelSize: 14; font.bold: true }
			Label { text: "Consumed"; color: "#85858c"; font.pixelSize: 12 }
			Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: panel.fmt(consumed, 0, " Ah"); font.pixelSize: 14; font.bold: true; color: "#7fb6e0" }

			Label { text: "State of Charge"; color: "#85858c"; font.pixelSize: 12 }
			Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: panel.fmt(soc, 1, " %"); font.pixelSize: 14; font.bold: true }
			Label { text: "Voltage"; color: "#85858c"; font.pixelSize: 12 }
			Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: panel.fmt(voltage, 2, " V"); font.pixelSize: 14; font.bold: true }

			Label { text: "Current"; color: "#85858c"; font.pixelSize: 12 }
			Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: panel.fmt(current, 2, " A"); font.pixelSize: 14; font.bold: true }
			Label { text: "Power"; color: "#85858c"; font.pixelSize: 12 }
			Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: panel.fmt(power, 0, " W"); font.pixelSize: 14; font.bold: true }

			Label { text: "Min cell"; color: "#85858c"; font.pixelSize: 12 }
			Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: panel.fmt(minCell, 3, " V"); font.pixelSize: 14; font.bold: true; color: panel.cellColor(minCell.valid ? minCell.value : NaN) }
			Label { text: "Max cell"; color: "#85858c"; font.pixelSize: 12 }
			Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: panel.fmt(maxCell, 3, " V"); font.pixelSize: 14; font.bold: true; color: panel.cellColor(maxCell.valid ? maxCell.value : NaN) }

			Label { text: "Delta"; color: "#85858c"; font.pixelSize: 12 }
			Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: cellDiff.valid ? (cellDiff.value * 1000).toFixed(0) + " mV" : "—"; font.pixelSize: 14; font.bold: true }
			Label { text: "Cycles"; color: "#85858c"; font.pixelSize: 12 }
			Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: cycles.valid ? cycles.value.toFixed(0) : "—"; font.pixelSize: 14; font.bold: true }
		}

		// --- temperature chips ---
		RowLayout {
			Layout.fillWidth: true
			spacing: 8
			TempChip { name: "Sensor 1"; item: temp1 }
			TempChip { name: "Sensor 2"; item: temp2 }
			TempChip { name: "MOSFET";   item: mosTemp }
		}

		// --- battery graphic ---
		Item {
			Layout.fillWidth: true
			Layout.fillHeight: true
			Layout.topMargin: 4

			Rectangle {
				width: Math.min(parent.width, 340)
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.top: parent.top
				anchors.topMargin: 12
				anchors.bottom: parent.bottom
				radius: 10
				color: "#181b20"
				border.color: "#34373d"
				border.width: 1

				// terminal posts: + left, - right
				Rectangle {
					width: 30; height: 13; radius: 4
					color: "#c23628"
					anchors.bottom: parent.top
					anchors.bottomMargin: -3
					x: 26
				}
				Rectangle {
					width: 30; height: 13; radius: 4
					color: "#7a7a82"
					anchors.bottom: parent.top
					anchors.bottomMargin: -3
					anchors.right: parent.right
					anchors.rightMargin: 26
				}

				ColumnLayout {
					anchors.fill: parent
					anchors.margins: 12
					spacing: 8

					// brand label
					RowLayout {
						Layout.fillWidth: true
						Label { text: "JK B2A8S20P"; font.pixelSize: 12; font.bold: true; color: "#aeb0b6"; Layout.fillWidth: true }
						Label { text: "4S LiFePO4 · " + (installed.valid ? installed.value.toFixed(0) + "Ah" : "280Ah"); font.pixelSize: 11; color: "#6f7178" }
					}

					// four cell chambers
					RowLayout {
						Layout.fillWidth: true
						Layout.fillHeight: true
						spacing: 8

						Repeater {
							model: 4
							delegate: Rectangle {
								id: chamber
								property int cellIndex: index + 1
								Layout.fillWidth: true
								Layout.fillHeight: true
								color: "#0c0d0f"
								border.color: "#2b2e34"
								border.width: 1
								radius: 6
								clip: true

								VeQuickItem {
									id: cellValue
									uid: panel.serviceUid + "/Voltages/Cell" + chamber.cellIndex
								}

								// cell label
								Label {
									anchors.top: parent.top
									anchors.topMargin: 5
									anchors.horizontalCenter: parent.horizontalCenter
									text: "C" + chamber.cellIndex
									font.pixelSize: 11
									color: "#9a9aa2"
									z: 2
								}

								// 3.3 V nominal tick
								Rectangle {
									anchors.left: parent.left
									anchors.right: parent.right
									height: 1
									color: "#41444b"
									opacity: 0.7
									y: parent.height * (1 - (3.3 - panel.barMinV) / (panel.barMaxV - panel.barMinV))
								}

								// fill
								Rectangle {
									id: fill
									anchors.left: parent.left
									anchors.right: parent.right
									anchors.bottom: parent.bottom
									anchors.margins: 2
									radius: 4
									color: panel.cellColor(cellValue.valid ? cellValue.value : NaN)
									height: {
										if (!cellValue.valid) return 0
										var pct = (cellValue.value - panel.barMinV) / (panel.barMaxV - panel.barMinV)
										pct = Math.max(0, Math.min(1, pct))
										// -4 = the 2px top+bottom margin of the fill inside the chamber
										return Math.max(0, (chamber.height - 4) * pct)
									}
									Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
									Behavior on color  { ColorAnimation  { duration: 250 } }
								}

								// value
								Label {
									anchors.bottom: parent.bottom
									anchors.bottomMargin: 5
									anchors.horizontalCenter: parent.horizontalCenter
									text: cellValue.valid ? cellValue.value.toFixed(3) + " V" : "—"
									font.pixelSize: 12
									font.bold: true
									color: "#ffffff"
									z: 2
								}
							}
						}
					}
				}
			}
		}
	}
}
