# Operations screen

The **Operations** sidebar tab is the daily health view for a SmarTon panel.
It is designed to remain useful before physical adapters are connected and to
be truthful once they are:

- **Active safety alert** lists leak, smoke, gas, carbon-monoxide, intrusion
  and panic devices whose reported alarm state is active. It remains visible
  until that device reports clear; it is not a dismissible notification.
- **Offline** means an adapter has marked a device unreachable or a command
  timed out. The displayed state is last-known, not confirmed.
- **Stale reports** means no current device report is available. This differs
  from offline, particularly for battery devices that sleep between reports.
- **Low battery** uses the configured panel threshold and lists affected
  device names.

For a support handoff, an installer can run:

```sh
cd /home/adesh-singh/Smarton
scripts/collect-support-bundle.sh root@10.42.0.130
```

The bundle intentionally excludes account data, password verifiers, MQTT
credentials, Wi-Fi keys and token files. It contains service status, recent
application logs, version information, storage/memory and network-interface
facts. Do not use it as a substitute for real device and safety-system tests.
