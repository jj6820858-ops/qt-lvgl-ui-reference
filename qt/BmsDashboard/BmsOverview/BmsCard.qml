/*
** BmsOverview - one compact summary card for a BMS.
** Shows label, overall status dot, SoC, voltage and min/max cell.
** Emits clicked() so the overview can open the full detail panel.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

Rectangle {
	id: card

	property string serviceUid: ""
	property string label: ""
	property string mac: ""
	signal clicked()

	color: cardMouse.pressed ? "#1b1b1e" : "#141416"
	border.color: "#28282c"
	border.width: 1
	radius: 12

	function cellColor(v) {
		if (typeof v !== "number" || isNaN(v)) return "#404040"
		if (v >= 3.6 || v <= 3.0) return "#e0463b"
		if (v >= 3.5 || v <= 3.1) return "#f5a623"
		return "#4caf50"
	}

	VeQuickItem { id: soc;     uid: card.serviceUid + "/Soc" }
	VeQuickItem { id: voltage; uid: card.serviceUid + "/Dc/0/Voltage" }
	VeQuickItem { id: minCell; uid: card.serviceUid + "/System/MinCellVoltage" }
	VeQuickItem { id: maxCell; uid: card.serviceUid + "/System/MaxCellVoltage" }

	// Overall status: the most severe of the min/max cell colors.
	readonly property color statusColor: {
		var lo = minCell.valid ? cellColor(minCell.value) : "#404040"
		var hi = maxCell.valid ? cellColor(maxCell.value) : "#404040"
		if (lo === "#e0463b" || hi === "#e0463b") return "#e0463b"
		if (lo === "#f5a623" || hi === "#f5a623") return "#f5a623"
		if (lo === "#4caf50" || hi === "#4caf50") return "#4caf50"
		return "#404040"
	}

	ColumnLayout {
		anchors.fill: parent
		anchors.margins: 14
		spacing: 6

		// header: status dot + label + mac
		RowLayout {
			Layout.fillWidth: true
			spacing: 8
			Rectangle { width: 12; height: 12; radius: 6; color: card.statusColor }
			Label { text: card.label; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
			Label { text: "(" + card.mac + ")"; font.pixelSize: 12; color: "#7a7a82" }
		}

		// big SoC
		Label {
			Layout.alignment: Qt.AlignHCenter
			Layout.topMargin: 4
			text: soc.valid ? soc.value.toFixed(0) + " %" : "—"
			font.pixelSize: 38
			font.bold: true
			color: "#e8e8ea"
		}
		Label {
			Layout.alignment: Qt.AlignHCenter
			text: voltage.valid ? voltage.value.toFixed(2) + " V" : "—"
			font.pixelSize: 15
			color: "#a6a6ac"
		}

		Item { Layout.fillHeight: true }

		// min / max cell
		RowLayout {
			Layout.fillWidth: true
			Label { text: "min"; color: "#85858c"; font.pixelSize: 11 }
			Label {
				text: minCell.valid ? minCell.value.toFixed(3) : "—"
				color: card.cellColor(minCell.valid ? minCell.value : NaN)
				font.pixelSize: 14; font.bold: true; Layout.fillWidth: true
			}
			Label { text: "max"; color: "#85858c"; font.pixelSize: 11 }
			Label {
				text: maxCell.valid ? maxCell.value.toFixed(3) : "—"
				color: card.cellColor(maxCell.valid ? maxCell.value : NaN)
				font.pixelSize: 14; font.bold: true
			}
		}

		Label {
			Layout.alignment: Qt.AlignHCenter
			text: "Tap for details ›"
			font.pixelSize: 11
			color: "#6a6a72"
		}
	}

	MouseArea {
		id: cardMouse
		anchors.fill: parent
		onClicked: card.clicked()
	}
}
