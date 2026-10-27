# 10. Show what devices report, not what the user asked for

Status: Accepted

## Context

Until now `Device` had one power field, and `setDevicePower()` changed it. That
is fine while nothing is being controlled, and wrong the moment something is.

A real device is remote, slow and sometimes gone. Between the tap and the
answer there is a window of tens of milliseconds on Wi-Fi and multiple seconds
on a congested Zigbee mesh. Three ways to spend that window:

**Optimistic — move the switch immediately.** What most home apps do, and the
source of the most common complaint about all of them: the command fails, the
UI never hears, and the panel now states that a light is on that is off.
Someone leaves the house believing they turned the heating down. The failure
is silent, and it is a failure about the physical world.

**Blocking — wait for the answer.** Honest, and unusable: the render thread
stops for as long as the mesh takes.

**Split intent from state.** Two fields, and the gap between them is a UI
state in its own right.

## Decision

`Device` carries `on` (last **reported**) and `desiredOn` (last **requested**),
plus `reachability`. `pending()` is simply `on != desiredOn`.

- `HomeService::setDevicePower()` records intent and asks `IDeviceTransport`.
  `on` does not move.
- `on` moves only in `onPowerReported()`, which is also where `desiredOn` is
  re-synced: a device switched at the wall makes the panel's idea of intent
  stale, not authoritative.
- A failed command rolls `desiredOn` back to `on` and marks the device
  offline. Left pending forever, the switch sits half-way with no way to retry.
- With **no** transport attached, intent is state immediately. Nothing is being
  controlled, so there is nothing to wait for, and adding latency to a
  simulation only makes it feel broken.

`StSwitch` already only *requested* rather than toggling itself — that decision
was made for binding reasons, and this is what it was really for. It now
renders `pending` as a pulse on the track, with the thumb deliberately not
moving, and `unreachable` as a warning edge rather than a disabled control:
greyed out says "you cannot", when what is true is "it is not listening".

## Consequences

+ The panel cannot claim a state the hardware has not confirmed.
+ Latency and loss are exercised on a developer's desk, because
  `LoopbackDeviceTransport` has both by design and is deterministic under a
  seed.
+ Adding MQTT is a new `IDeviceTransport` and three lines in the composition
  root. No layer above changes.
− Every device-facing surface must now decide which field it reads. That is
  more thought per screen, and it is the thought that was missing.
− A device that never reports leaves the UI showing the old state with a
  warning edge. That is correct, and it will read as "broken" to someone who
  expects optimistic behaviour. It is the right kind of broken.
