# 19. MQTT as the first real transport, as an optional dependency

Status: Accepted

## Context

`IDeviceTransport` has had exactly one implementation since it was written:
`LoopbackDeviceTransport`, which answers after a delay and drops a
configurable share of commands. It is a good simulator and it is still a
simulator. `docs/competitive-gap.md` calls the absence of a real protocol "the
one that defines everything else" and names MQTT as the cheapest way to close
it: a broker is free, Zigbee2MQTT and the common Matter bridges already speak
it, and it needs no radio.

The constraint is that MQTT arrives as a dependency — Qt MQTT is a separate
module, not part of a default Qt install, and the RK3328 build image may not
have it. The project already has this exact problem twice over: Quick3D
(ADR-0016) and Quick Particles (ADR-0017) are both optional, both detected at
configure time, and both isolated so that their absence costs a feature rather
than the build.

## Decision

**MQTT is a third transport, not a replacement.** Loopback stays the default
and stays in the tree: it is what the tests run against, what a demo without a
broker runs against, and the only transport that can be told to fail on
purpose.

**It is an optional dependency, detected at configure time**, following the
pattern the two existing optional modules established: `find_package(Qt6
Mqtt QUIET)` → a `Capabilities` flag → the implementation compiled only when
the module is present. A build without Qt MQTT has no MQTT transport, says so
once at startup, and is otherwise identical.

**Topics are configuration, not code.** Zigbee2MQTT, Tasmota, ESPHome and a
Matter bridge each publish a different topic shape, and hard-coding one would
make the transport support exactly one ecosystem. The mapping lives in a small
topic template read from settings.

**Selected by command line, not by autodetection.** `--transport mqtt://host`
picks it. A transport that silently switches itself because a broker happens
to be reachable is a panel whose behaviour depends on what else is on the
network.

## Consequences

**The layers above get exercised for real.** Reported-versus-desired
(ADR-0010) stops being a design position and becomes observable: a retained
topic that disagrees with what was asked for is exactly the pending state the
UI already renders, and now something other than a simulated delay produces
it.

**Telemetry gets a source.** `MonitoringService` and `ReadingListModel` exist
and are fed from configured consumption figures — the Statistics screen says
so on its own face. A broker carrying real readings is the missing input, and
no layer above has to change to accept them.

**Two transports is what proves the seam.** An interface with one
implementation is a guess. The first thing writing a second one found was
whether `IDeviceTransport` had accidentally been shaped around the loopback's
conveniences — which is the whole argument for writing it before Matter, where
the same discovery would be far more expensive.

**A broker is a dependency the product now has.** Not for the default build,
but a panel configured for MQTT is a panel that stops controlling anything
when the broker is down. That is honest for a local-first system and it is
still a failure mode the UI has to show, which it does: undeliverable commands
are already surfaced as unreachable devices rather than as silence.
