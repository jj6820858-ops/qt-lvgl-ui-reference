# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.8.3]

### Changed
- LVGL updated from 9.5.0 to 9.6.0. Deprecated APIs are migrated: per-flag
  setters (`lv_obj_set_hidden()` etc.) replace `lv_obj_add_flag()` /
  `lv_obj_remove_flag()`, and the Wi-Fi scan and timezone lists are flex-column
  containers instead of `lv_list`.
- `espressif/mqtt` updated from 1.0.0 to 1.1.0 and `espressif/esp_lcd_ili9341`
  from 2.0.2 to 2.1.0.

## [1.8.2]

### Changed
- ThingsBoard offline queue now actually queues: the publish timer keeps
  running while the broker is unreachable, and the queue is kept across
  history-fetch restarts (cleared only when the broker URI or token changes).
- MQTT publishing runs on one shared 4 KB task instead of the shared
  `esp_timer` task, so a blocked publish no longer delays other timers.
- The Domoticz and Home Assistant history parsers allocate their working
  state only during the fetch, freeing about 7.8 KB of RAM the rest of the time.
- Settings-screen status timers are paused while the settings screen is not
  shown.

### Fixed
- OTA version check now requires HTTP 200, parses the manifest as JSON, and a
  scheduled check no longer starts while a manual one is running.
- BSEC calibration state is saved before the OTA reboot.
- Dew point on the main screen uses the shared calculation, and 0 % humidity
  no longer produces `-inf` (also affects the MQTT dew point).

### Removed
- Unused code: `has_pressure()`, `tb_mqtt_last_confirmed()`,
  `bsec_sensor_get_accuracy()`, `wifi_manager_get_rssi_pct()`.

## [1.8.1]

### Added
- "Screen 180°" checkbox in Settings (under Display Units): rotates the
  display and the touch input by 180° at once, and the choice is kept across
  reboots.

## [1.8.0]

### Added
- Domoticz HTTP push: readings can now be sent to Domoticz through its JSON
  API (`udevice`) every 30 s, independently of the MQTT connection. New
  "Domoticz HTTP" section in Settings with an enable checkbox, a status line
  showing the target URL, and a "Configure Domoticz HTTP" screen with its own
  base URL, username/password and Temp/Hum/Baro and Air Quality/CO2 device
  IDX values. A push counts as successful only if Domoticz answers `OK`
  (it replies 200 even for an unknown IDX).
- "History Chart Source" button on the Domoticz HTTP screen, opening the same
  history window as Configure Domoticz; its Back button returns to the screen
  it was opened from.

## [1.7.6]

### Fixed
- ThingsBoard 24h history chart was shifted one 10-minute slot to the right
  and dropped its newest point: TB stamps each aggregated point at the middle
  of its interval, and `llround()` rounded that up into the next slot. Now
  uses `floor()`. Humidity is also stored whether or not the slot already has
  a temperature, so the order of the arrays in the response no longer matters.
- Possible use-after-free when MQTT was stopped or restarted (history fetch,
  saving settings) while a publish was running on the timer task:
  `mqtt_base` now guards the publish callback and teardown with a mutex.
- A WiFi drop no longer freezes the system event loop for up to 30 s: the
  reconnect back-off now runs on a one-shot `esp_timer` instead of
  `vTaskDelay()` inside the event handler, so `GOT_IP`, scan results, MQTT
  start and the history fetch are no longer delayed.
- ThingsBoard publish interval above 4294 s wrapped around to a much smaller
  value (32-bit overflow). The interval is now limited to 5–3600 s, both when
  saved in the UI and when read from NVS.
- Handing the BME680 over to BSEC could lock the I2C bus forever, freezing
  BSEC and SCD4x readings: `vTaskSuspend()` could stop the bmx280 task
  mid-transfer while it held the bus lock. The task now exits cleanly between
  measurement cycles, and the handover waits for it.

## [1.7.5]

### Fixed
- OTA rollback actually works now: `CONFIG_BOOTLOADER_APP_ROLLBACK_ENABLE` is
  enabled, and the new firmware is marked valid only after 30 s of uptime
  (previously right after `ota_manager_init()`, before WiFi/UI started), so an
  update that crashes or boot-loops early is reverted to the previous image.
  Rollback lives in the bootloader, so devices must be flashed once over USB
  to get it — OTA updates the app only.

## [1.7.4]

### Fixed
- Domoticz's 24h history fetch could fail outright with `Incomplete data
  received` partway through the response. Initially looked like a slow
  Domoticz-side graph query and chased by raising the read-stall timeout
  (15s→30s→60s→180s), but each bump just pushed the failure point further out
  without ever succeeding. Real-hardware captures showed the actual cause:
  all three MQTT clients failing (`tcp_write` EAGAIN, then even `getaddrinfo()`
  failing for a literal IP — a sign of the device being out of heap/sockets,
  not a slow network) tens of seconds into every attempt, because this was the
  one 24h-history fetch that didn't pause them first (unlike ThingsBoard/Home
  Assistant, added in 1.7.1/1.7.3, on the reasoning that a plain-HTTP request
  has no TLS memory pressure — true, but beside the point: three live MQTT
  clients plus one long-lived HTTP socket were still exhausting shared
  heap/sockets between them). `fetch_domoticz()` now stops and restarts all
  three MQTT clients around the fetch, same as the other two sources; the
  read-stall timeout is left at a bounded 30s rather than raised further.

## [1.7.3]

### Added
- 24h history chart backfill now supports **Home Assistant** as a source (in
  addition to ThingsBoard and Domoticz). Settings → Configure Home Assistant →
  new "History Chart Source" sub-screen (Base URL, Long-Lived Access Token,
  temperature/humidity entity IDs — separate from the existing MQTT broker
  settings). Unlike ThingsBoard/Domoticz, Home Assistant's history API does
  no server-side aggregation, so the fetch streams and averages raw
  per-change records into 10-minute buckets itself. Most local Home
  Assistant installs are reached over plain HTTP, so this backfill typically
  never touches the TLS-layer memory ceiling documented for ThingsBoard.

## [1.7.2]

### Fixed
- ThingsBoard's 24h history telemetry fetch is now split into two 12h/72-slot
  requests instead of one 24h/144-slot request. The single-request version
  (1.7.1) intermittently failed reading the response with `Dynamic Impl:
  alloc(~14 KB) failed` at the raw TLS layer — a coin flip across boots of
  identical firmware. Repeated back-to-back test boots after the split
  reproduced no failures, where the single-request version had failed
  roughly half the time. Still best-effort, not a structural guarantee — a segment can still fail on a particularly fragmented boot,
  in which case it's simply skipped and the other segment still seeds its
  half of the chart.

## [1.7.1]

### Added
- 24h history chart backfill now supports **ThingsBoard** as a source (in
  addition to Domoticz from 1.7.0). Settings → Configure ThingsBoard → new
  "History Chart Source" sub-screen (Base URL, user login, Device ID —
  separate from the existing MQTT broker/token settings). The fetch logs in
  as a real ThingsBoard user (device access tokens can't read history) to get
  a JWT, then pulls the last 24h of temperature/humidity via the telemetry
  REST API. **Best-effort**: on this device's tight memory budget, reading
  the telemetry response can occasionally fail outright (see Known Issues);
  when that happens the graphs are simply left to fill in the normal way.

### Fixed
- On this device's tight memory budget, a TLS handshake for the history fetch
  could fail outright (`PSA_ERROR_INSUFFICIENT_MEMORY`) while all three MQTT
  clients were also connected — `history_fetch` now briefly stops and restarts
  all three MQTT clients around the fetch, freeing up enough heap that the
  handshakes usually succeed (not always — see Known Issues).

### Known Issues
- ThingsBoard's telemetry response can still fail to read with
  `Dynamic Impl: alloc(~14 KB) failed` at the raw TLS layer, on some boots but
  not others, seemingly tied to heap fragmentation at that moment rather than
  anything the request itself controls. Every mitigation tried (dynamic TLS
  buffers, smaller cert bundle, pausing MQTT during the fetch, reusing one
  HTTP connection for both requests) narrowed this without eliminating it.
  Fails gracefully — a warning is logged and that boot's graphs are left
  unseeded, same as if the feature were off.

## [1.7.0]

### Added
- 24h history chart backfill: the main screen's temperature/humidity graphs are
  now pre-filled from a backend right after boot, instead of starting empty and
  taking 24h to fill via local sampling. Selectable in Settings → 24h History
  Chart (Off / ThingsBoard / Domoticz / Home Assistant) — only Domoticz is
  implemented so far; ThingsBoard and Home Assistant are selectable but no-op.
  New `components/history_fetch/` component, `sensor_history_seed_24h()`, and
  a Domoticz-specific "History Chart Source" sub-screen (History URL,
  username, password — separate from the existing MQTT broker settings).
- Domoticz's **Setup → Settings → Security → API Protection → "Allow
  Basic-Auth authentication over plain HTTP (API only)"** must be enabled for
  the history fetch to authenticate; otherwise every request 401s.

### Fixed
- Two settings sub-screens open at once (a "sub-screen" reached from within
  another overlay, both left resident) could exhaust LVGL's fixed memory pool
  while the on-screen keyboard was drawn, freezing the UI with no recovery.
  Affected overlays now explicitly tear down the parent screen (including its
  own timers, which `lv_obj_delete()` doesn't free) before opening the next
  one.

## [1.6.9]

### Added
- Possibility to switch Celsius / Fahrenheit degrees

## [1.6.8]

### Added
- The Firmware Update screen now points at a default OTA URL out of the box
  (`http://iot.scorpionzzz.com/sensorstation3/firmware/sensorstation3.latest.bin`)
  instead of requiring one to be entered manually before update checks work.
- The Firmware Update screen now triggers an immediate version check — instead
  of waiting for the next scheduled check (first at +60 s, then every 6 h) —
  both when the screen is opened and when the firmware URL is edited and
  saved. The result is shown right away: the latest version if the `.json`
  manifest was read successfully, or "N/A" if it's unreachable or malformed.
- `ota_manager_check_now()` / `ota_manager_derive_check_url()` in
  `ota_manager`, backing the above; `main.c`'s boot-time check now reuses the
  same derivation helper instead of duplicating the `.bin`→`.json` swap.

## [1.6.7]

### Fixed
- Fixed a boot loop on devices with no BME280/BME680/SCD4x sensor connected.
  `sensor_hub_init()`/`sensor_history_init()` were only called when a sensor
  was detected, leaving `sensor_history`'s internal mutex uninitialized; the
  ThingsBoard, Domoticz, and Home Assistant MQTT modules all call
  `sensor_history_get_snapshot()` unconditionally on their first publish tick
  after connecting, which asserted on the NULL mutex and rebooted the device.
  Both are now initialized unconditionally — the history task already no-ops
  gracefully when no sensor data is available.

## [1.6.6]

### Changed
- LVGL's timer task is now pinned to core 1 (`xTaskCreatePinnedToCore`), instead
  of floating free on either core, so it doesn't contend with WiFi/LWIP on
  core 0.
- The Domoticz Temp+Hum(+Baro) IDX field's placeholder text now reflects the
  connected sensor's actual capabilities ("Temp+Hum+Baro IDX", "Temp+Hum IDX",
  or "Temperature IDX") instead of always reading "Temp+Hum+Baro IDX",
  matching the device type `domoticz_mqtt` actually publishes.

### Fixed
- The Domoticz settings screen's Username and Password fields (and the Save
  button, on sensors with a CO2 IDX field) could end up hidden behind the
  on-screen keyboard once focused. The content area is now a scrollable
  container that shrinks to the space above the keyboard while it's open and
  scrolls the focused field into view, then returns to full height when the
  keyboard closes.

## [1.6.4]

### Added
- New `mqtt_base` component — a shared MQTT lifecycle layer (service-namespaced
  client-id generation, IP-event-gated first start, publish timer, the
  connect/disconnect/published/error event handling, and teardown) now used by
  all three telemetry integrations. Each module supplies only its NVS settings
  and payload builders through callbacks; topics, payloads, QoS, retain, LWT,
  auth, and cadence stay under module control.
- `mqtt_diag_fields()` in `sensor_hub`, single-sourcing the rssi/uptime/
  backlight/ldr_mv diagnostic fields shared by the ThingsBoard and Home
  Assistant payloads.
- MQTT connection-refused failures (bad token/credentials) are now logged with
  the broker return code instead of failing silently behind a reconnect loop.

### Changed
- The ThingsBoard, Domoticz, and Home Assistant MQTT modules were refactored
  onto `mqtt_base`, removing the duplicated lifecycle scaffolding (net −492/+270
  lines). Their on-the-wire output — topics, payloads, client IDs, QoS, retain,
  discovery, availability — is unchanged.

### Fixed
- Domoticz now publishes temperature and humidity for sensors without a
  barometer (e.g. an SCD41-only setup). The Domoticz device format is chosen
  from the sensor's capabilities — Temp+Hum+Baro, Temp+Hum, or Temperature —
  where previously the Temp/Hum/Baro device required a pressure reading and so
  published nothing for the SCD41. The virtual device configured for the
  `dz_thp_idx` IDX must be of the matching type (create a "Temp+Hum" device for
  an SCD41).

## [1.6.3]

### Added
- SCD41 sensor support
- New `sensor_hub` component — a common layer over the individual sensor
  drivers. Each driver (BMx280/BME680, SCD41, and BSEC as a decorator over
  the BME680) now exposes a uniform interface and registers with the hub,
  which aggregates their capabilities and merges them into a single live
  snapshot. Display and all telemetry integrations (ThingsBoard, Domoticz,
  Home Assistant) read that one snapshot with per-field capability flags
  instead of querying each driver directly.
- CO2 now has its own 30-second rolling average (15 samples × 2 s), matching
  the smoothing already applied to temperature, humidity, and pressure.
- Settings → Device Info lists every connected sensor joined together (e.g.
  `BME680 + SCD41`, up to three) instead of only the BMx280 chip.

### Changed
- `sensor_history` now sources its data from `sensor_hub` rather than reading
  the BMx280/SCD41 drivers directly, and feeds the display numbers, charts,
  and MQTT telemetry from its loop-average buffers.
- The Domoticz CO2 (Air Quality) device IDX can now be configured whenever a
  CO2-capable sensor is present, including an SCD41 — previously it was
  offered only for the BME680.

### Fixed
- An SCD41-only setup no longer reads "Sensor: not connected" on the settings
  screen; the device-info row now recognises the SCD41 (and any combination
  of connected sensors).

## [1.5.10]

### Fixed
- Device rebooted in a loop when no BMx280 sensor was detected at boot:
  `sensor_history_init()` was skipped in that case, leaving its mutex
  uninitialized, while the UI's 500 ms refresh timer still queried
  `sensor_history_get_current()`/`get_24h()` unconditionally.

### Changed
- When no sensor is detected, the temperature, humidity, dew point, and
  pressure panels are replaced by a "Connect sensor and reboot the device"
  message instead of attempting to show readings.

## [1.5.7]

### Changed
- Temperature/humidity trend arrows now compare the momentary reading
  against its own rolling 30-second mean and recompute every 500 ms, instead
  of comparing two successive 30-second means and holding the result fixed
  for 30 seconds. The delta is rounded to one decimal place, and that
  rounded value decides the arrow (up/down/equal).

## [1.5.0]

### Added
- ST7789 display panel support, alongside the existing ILI9341. The panel
  controller is auto-detected at boot by reading its display ID register
  (RDDID) over the existing SPI wiring — both panel families use identical
  pinout on the CYD board, so no configuration is needed. A manual override
  (`CONFIG_SS3_LCD_PANEL` in `idf.py menuconfig`) is available in case
  auto-detection ever picks the wrong driver for a given module.

## [1.4.4]

### Added
- Home Assistant integration via MQTT Discovery: sensors are now
  auto-discovered in Home Assistant — temperature, humidity, pressure, dew
  point, gas resistance, and (on BME680 with BSEC) IAQ / CO2eq / VOC — plus
  diagnostic entities for WiFi signal, uptime, backlight, and light level.
  Configurable from a new Home Assistant section in Settings.

### Fixed
- ThingsBoard, Domoticz, and Home Assistant MQTT clients could repeatedly
  disconnect each other when two of them shared the same broker, because
  none set an explicit client ID and the default was identical for all
  three. Each now uses a unique client ID.
- Home Assistant was receiving sensor updates at QoS 0 instead of QoS 1
  because the discovery config didn't request QoS 1 for its subscriptions.

## [1.3.6]

### Added
- ThingsBoard telemetry: BME680 payloads now include `gas_resistance` (raw
  compensated gas sensor resistance, in Ohms) — sent both when BSEC is active
  and in the non-BSEC BME680 fallback path.

## [1.3.2]
- Last tagged release prior to this changelog's introduction.