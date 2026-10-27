/*
** BmsOverview - experimental multi-BMS overview with dynamic discovery.
**
** Discovers all dbus-serialbattery batteries automatically:
**   1. Reads com.victronenergy.system/Batteries (the system battery list).
**   2. Builds each service uid via BackendConnection.serviceUidFromName().
**   3. Keeps only services whose /ProductId == 0xBA77 (reserved by Victron
**      for dbus-serialbattery), which filters out the BMV and other monitors.
**
** Each battery is a compact card in a grid; tapping one opens the full
** BmsPanel as a detail page via pageManager.pushPage.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

Page {
	id: root

	title: "BMS Overview"

	// dbus-serialbattery sets this ProductId on all its batteries.
	readonly property int serialBatteryProductId: 0xBA77

	property var candidates: []     // [{uid, name, mac}] from /Batteries (real devices only)
	property var productIds: ({})    // uid -> ProductId
	property int probeTick: 0        // bumped when a ProductId resolves, refreshes serialList

	// Final list: only dbus-serialbattery batteries.
	readonly property var serialList: {
		probeTick // referenced so this re-evaluates when ProductIds resolve
		return root.candidates.filter(function (c) {
			return root.productIds[c.uid] === root.serialBatteryProductId
		})
	}

	// Short id derived from the service name, e.g. "...ble_c8478ceabe78" -> "BE78".
	function shortId(uid) {
		var svc = uid.split("/").pop()    // com.victronenergy.battery.ble_c8478ceabe78
		var tail = svc.split(".").pop()    // ble_c8478ceabe78
		return tail.length >= 4 ? tail.slice(-4).toUpperCase() : tail.toUpperCase()
	}

	function rebuildCandidates() {
		var list = []
		if (batteriesItem.valid && batteriesItem.value) {
			var arr = batteriesItem.value
			for (var i = 0; i < arr.length; ++i) {
				var b = arr[i]
				if (b === undefined || b.instance === undefined)
					continue // skip aggregate / sub-entries without a device instance
				var uid = BackendConnection.serviceUidFromName(b.id, b.instance)
				list.push({ "uid": uid, "name": b.name || b.id, "mac": root.shortId(uid) })
			}
		}
		root.candidates = list
	}

	function setProductId(uid, pid) {
		var m = root.productIds
		m[uid] = pid
		root.productIds = m
		root.probeTick++
	}

	// Column count tuned so common counts fill the screen (2,4,6,8 fit exactly).
	function gridColumns(n) {
		if (n <= 1) return 1
		if (n === 2) return 2
		if (n === 3) return 3
		if (n === 4) return 2
		if (n <= 6) return 3
		return 4
	}

	VeQuickItem {
		id: batteriesItem
		uid: Global.system.serviceUid + "/Batteries"
		onValueChanged: root.rebuildCandidates()
	}

	// Non-visual probes: read /ProductId per candidate to classify it.
	Repeater {
		model: root.candidates
		delegate: Item {
			VeQuickItem {
				uid: modelData.uid + "/ProductId"
				onValueChanged: if (valid) root.setProductId(modelData.uid, value)
			}
		}
	}

	// Detail page shown when a card is tapped.
	Component {
		id: detailPage

		Page {
			id: dp
			property string serviceUid: ""
			property string batteryLabel: ""
			property string batteryMac: ""

			BmsPanel {
				anchors.fill: parent
				anchors.margins: 12
				serviceUid: dp.serviceUid
				label: dp.batteryLabel
				mac: dp.batteryMac
			}
		}
	}

	// Empty / still-discovering state.
	Label {
		anchors.centerIn: parent
		visible: root.serialList.length === 0
		text: "Searching for dbus-serialbattery batteries…"
		color: "#85858c"
		font.pixelSize: 18
	}

	GridLayout {
		anchors.fill: parent
		anchors.margins: 12
		visible: root.serialList.length > 0
		columns: root.gridColumns(root.serialList.length)
		columnSpacing: 10
		rowSpacing: 10

		Repeater {
			model: root.serialList

			delegate: BmsCard {
				Layout.fillWidth: true
				Layout.fillHeight: true
				serviceUid: modelData.uid
				label: modelData.name
				mac: modelData.mac
				onClicked: Global.pageManager.pushPage(detailPage, {
					"title": modelData.name,
					"serviceUid": modelData.uid,
					"batteryLabel": modelData.name,
					"batteryMac": modelData.mac
				})
			}
		}
	}
}
