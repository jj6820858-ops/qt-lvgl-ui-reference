# Production implementation backlog

The items below are ordered by safety and operational value. They are a
deliberately small architecture: retain `HomeService` as the state authority,
add adapters at `IDeviceTransport`, and keep QML unaware of protocol details.

## Done in this production baseline

- [x] Desired versus reported power state; pending and offline states.
- [x] Persistent model, account database, backup/restore, role enforcement.
- [x] Scene scheduler, activity log, command-failure audit event.
- [x] MQTT endpoint and credentials loaded from a root-only environment file.
- [x] RK3328 EGLFS/software renderer deployment and conservative systemd
  sandboxing.
- [x] Rounded/circular image crop on both GPU (`MultiEffect`) and software
  (`Canvas`) renderers; profile images no longer become square on RK3328.
- [x] Device replacement keeps the room/name/safety limit and updates
  per-device scene references to the replacement hardware identity.
- [x] Per-device command timeout rolls unconfirmed intent back to the last
  reported state and marks the device offline for an explicit retry.
- [x] Manual protocol-ready device provisioning and a capability catalogue,
  allowing UI/safety/scene setup before a physical adapter is connected.
- [x] Meter-ready device and room telemetry: watts, kWh, voltage, current,
  MQTT mapping, aggregation, and device-detail presentation.
- [x] Device offline/recovery and safety-timeout alerts appear on the panel
  and in the persistent activity history.
- [x] Operations sidebar: persistent safety alerts, offline/stale/low-battery
  health summaries, and a privacy-safe installer support-bundle handoff.
- [x] Deployment, rollback, broker, and appliance safety runbook.

## P0 — required before real switching

- [ ] Validate one Zigbee2MQTT bridge with real light, plug, motion, contact,
  temperature, leak, and power-meter devices.
- [ ] Add availability, battery, link-quality, and retained-state mapping from
  the selected gateway; show last-seen time in the device UI.
- [ ] Add an end-to-end hardware test: command, device report, app restart,
  broker restart, and power-cycle recovery.
- [ ] Move the service to an unprivileged `smarton` user after confirming DRM,
  input, and state-directory permissions on the image.
- [ ] Establish signed release artifacts, rollback image, and recovery-media
  procedure.

## P1 — appliance capability slice

- [ ] Add capability-specific adapters for thermostat, level, sensor, meter,
  lock, cover, and valve reports instead of modelling all devices as switches.
- [ ] Add a durable command timeout/retry policy with an expiry per command.
- [ ] Add per-device scene actions and automation history with “why it ran”.
- [ ] Add max-run-time protection for relays controlling pumps, valves, and
  heaters, with independent physical failsafes where required.
- [ ] Add mobile/installer notification routing for critical alarms.

## P2 — ecosystem and fleet

- [ ] Matter/Thread commissioning after a Thread radio/border-router decision.
- [ ] OTA update workflow with signed artifacts, progress, maintenance window,
  and rollback.
- [x] Privacy-reviewed diagnostics bundle and on-panel local fleet-health view.
- [ ] Optional remote fleet health reporting (requires a selected backend and
  explicit household support opt-in).
- [ ] Multi-panel synchronization and installer provisioning flow.

## Definition of done for every new appliance

1. Its reported state, unreachable state, and command-failure state are visible.
2. The adapter has contract tests with recorded gateway payloads.
3. A real-device test covers reboot, network loss, and a manual physical change.
4. Hazardous actions have explicit guardrails and an audit event.
5. Credentials are absent from source, process arguments, logs, and backups.
