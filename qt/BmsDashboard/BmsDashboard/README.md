# BmsDashboard

A GUIv2 UI plugin that shows two JK BMS side by side as batteries on a Venus OS GX.
Appears under **Settings → Integrations → UI Plugins → BmsDashboard**.

![BmsDashboard running on an Ekrano GX](images/live.jpg)

## What it shows (per battery)

- **4 cell voltages** with green/amber/red thresholds and a 3.3 V nominal marker
- **Status:** Charge / Discharge / Balance / Heater (LED + state)
- **Three temperatures:** two battery probes + MOSFET
- **State of Charge, voltage, current, power, min/max cell, delta, cycles, remaining/consumed Ah**

## Files

```
BmsDashboard/
├── BmsDashboard_PageSettings.qml   Entry page (bmsList + layout)
└── BmsPanel.qml                    One BMS panel (status, stats, temps, battery)
```

Only the two QML files are deployed to the device.

## Configure your BMS

Edit `bmsList` in `BmsDashboard_PageSettings.qml` with your own dbus service names.
Find them on the device with:

```bash
dbus -y | grep com.victronenergy.battery
```

```qml
readonly property var bmsList: [
    { service: "dbus/com.victronenergy.battery.ble_XXXXXXXXXXXX", label: "JK BMS 1", mac: "..:.." },
    { service: "dbus/com.victronenergy.battery.ble_YYYYYYYYYYYY", label: "JK BMS 2", mac: "..:.." }
]
```

`gui-v2` expects the `dbus/` prefix on the service UID.

## Deploy

```bash
ssh root@<gx-ip> "mkdir -p /data/apps/available/BmsDashboard"
scp BmsDashboard/*.qml root@<gx-ip>:/data/apps/available/BmsDashboard/

ssh root@<gx-ip>
cd /data/apps/available/BmsDashboard
python3 /opt/victronenergy/gui-v2/gui-v2-plugin-compiler.py \
    -n BmsDashboard \
    --min-required-version v1.2.13 \
    --settings BmsDashboard_PageSettings.qml
mkdir -p gui-v2 && mv -f BmsDashboard.json gui-v2/
ln -sf /data/apps/available/BmsDashboard /data/apps/enabled/BmsDashboard
svc -t /service/start-gui   # or: reboot
```

The device only reads `gui-v2/BmsDashboard.json` (it decodes a base64 `.rcc`
embedded inside it). Requirements are listed in the [project README](../README.md).

## Color coding

| Color | Range | Meaning |
|---|---|---|
| 🟢 Green | 3.10 V < V < 3.50 V | OK |
| 🟡 Amber | V ≥ 3.50 or V ≤ 3.10 | Warning |
| 🔴 Red | V ≥ 3.60 or V ≤ 3.00 | Critical |

Adjust the thresholds in `cellColor()` in `BmsPanel.qml`.

See [`images/mockup.svg`](images/mockup.svg) for a vector mockup of the layout.
