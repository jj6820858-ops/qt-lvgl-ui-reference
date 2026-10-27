# Production runbook

This is the small, safe operating baseline for a SmarTon RK3328 panel. It does
not claim that an untested vendor appliance is safe to control; a device is
only added after its adapter and failure behaviour have been tested.

## Deployment checklist

- Build the `rk3328` preset and run its unit tests on the host.
- Install with `scripts/deploy-to-board.sh`; it uses fullscreen EGLFS and the
  software Qt Quick renderer on the current board image.
- The deploy script performs a one-time, non-destructive migration of existing
  `/root/.local/share/SmarTon` state into `/var/lib/smarton` when hardening is
  introduced. It leaves the source state in place as recovery material.
- Confirm `systemctl is-active smarton` and inspect `journalctl -u smarton`.
- Create `/etc/smarton/smarton.env` from `packaging/smarton.env.example`.
  It must be owned by `root:root` and mode `0600`.
- Restart SmarTon after configuration changes. Never put passwords in
  `--transport`, shell history, screenshots, or support bundles.
- Test power loss, network loss, broker restart, and panel reboot before the
  panel controls a real appliance.

## MQTT contract

The app uses device IDs from the persisted home model. The default topics are
`zigbee2mqtt/<device-id>` for reported state and
`zigbee2mqtt/<device-id>/set` for commands. A command is not considered
successful merely because it was published: the device state topic must report
the resulting state. The UI therefore shows pending/offline instead of lying.

Configure only a least-privilege broker account. It should publish to the
panel's command topics and subscribe only to the panel's state topics. Use a
TLS-enabled broker where the network is not physically isolated.

## Appliance safety policy

| Appliance class | Required guard before enabling remote control |
|---|---|
| Lights/plugs | Reported state, offline indication, manual recovery test |
| HVAC | Device feedback, target limits, compressor-cycle rule from vendor |
| Pump/geyser/valve | Maximum run time and an independent leak/no-flow interlock |
| Lock/gate/garage | Explicit confirmation, audit trail, physical state feedback |
| Oven/washer/dishwasher | Vendor-supported remote control and hazard assessment |
| Smoke/CO/gas/leak | Hardware alarm remains authoritative; UI never suppresses it |

Do not connect life-safety equipment, medical equipment, fire suppression, or
unreviewed high-current loads to a general-purpose automation rule.

## Recovery

To return to the prior ThinClient/Weston stack:

```bash
systemctl disable --now smarton.service
systemctl enable --now weston.socket weston.service
systemctl enable --now thinclient.service
```

Keep a verified home-model backup outside the panel before a reset or upgrade.
Account credentials and MQTT secrets are deliberately not included in model
exports.

## Support bundle

Run `scripts/collect-support-bundle.sh` from the development machine to
produce a compressed diagnostics archive. It contains SmarTon status, the last
500 service-log lines, system version, disk/memory data, and network interface
addresses. It deliberately excludes the account database, home model, photos,
MQTT environment file, and any password/token/certificate material.
