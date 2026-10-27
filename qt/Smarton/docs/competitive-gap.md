# What competitors ship that SmarTon does not

Researched August 2026. Sources at the bottom.

The point of this document is **not** to argue SmarTon should become Home
Assistant. It is a one-developer portfolio project and the comparison is
absurd on volume. The point is to know which absences are *deliberate scope*
and which are *unexamined gaps* — because in an interview those are two very
different answers, and only one of them is a good one.

---

## The field

| Product | Shape | The thing it is known for |
|---|---|---|
| **Home Assistant** | Open-source hub + dashboards | 3,000+ integrations, everything local, enormous community |
| **Hubitat C-8 Pro** | Local hub, no dashboard hardware | Rule Machine — conditional automation entirely on-device |
| **Homey Pro (2026)** | Local hub with seven native radios | Z-Wave, Zigbee, Thread, Matter, WiFi, BLE and IR in one box |
| **Aqara Hub M3** | PoE hub, six native protocols | Bridges all five major voice ecosystems at once |
| **Amazon Echo Hub** | 8" wall panel | The closest thing to SmarTon's *form factor* — and cloud-dependent |

SmarTon's form factor is the Echo Hub's. Its architecture ambition is Home
Assistant's. Its actual feature set today is neither.

---

## Gaps that matter, ranked by whether they are worth closing

### 1. No real device protocol — the one that defines everything else

Every product above ships radios. Homey has seven; Aqara has six; Home
Assistant takes any of them over USB. SmarTon has `LoopbackDeviceTransport`,
which simulates latency and packet loss against seeded data.

This is *correctly scoped* — the boundary exists (`IDeviceTransport`),
reported-vs-desired state is modelled (ADR-0010), and swapping in a real
transport is three lines in `main.cpp`. But "the boundary is right" is not the
same as "it works", and the honest framing is that SmarTon is a well-built
front end over a simulator.

**Worth closing:** yes, and cheaply. An **MQTT** transport against a real
broker makes the whole stack real without touching a radio. It was the single
highest-value thing on this list.

**Shipped in v0.15.0** as an optional dependency —
[ADR-0019](adr/0019-mqtt-transport.md). `--transport mqtt://host` swaps it in;
the loopback stays the default. The honest framing is now "a well-built front
end with a real transport it has been run against", which is a different
sentence.

### 2. Matter and Thread — table stakes since 2023

Every hub in the field supports Matter. It is now the interoperability
baseline, and its absence is the first thing anyone in the industry will ask
about.

**Worth closing:** as a *stated position*, yes — immediately and for free.
Implementing Matter is a certification programme, not a weekend.

**Closed in v0.15.0** by [ADR-0018](adr/0018-matter-and-thread-position.md),
which says where it plugs in, why Thread is not a radio this panel terminates,
and that no compatibility will be claimed before something passes a compliance
run.

### 3. No voice — and this is now the default interaction

Home Assistant has spent three years on local voice ("Year of the Voice",
2023 → local LLM integration, 2025). Aqara bridges Alexa, Google, HomeKit,
SmartThings and Home Assistant simultaneously. Every competitor assumes voice
is how people actually operate a smart home.

**Worth closing:** not by building it. A wall panel that also listens is a
different product with a different privacy story. Worth *one paragraph* saying
that deliberately.

### 4. Real telemetry — the gap SmarTon already admits

The Statistics screen derives its figures from configured room consumption.
`production-readiness.md` scores this **0%** and says so on the screen itself,
which is the right call. Competitors meter actual draw.

**Worth closing:** yes, and it pairs with MQTT — a real transport gives real
readings, and `MonitoringService` + `ReadingListModel` already exist to receive
them.

### 5. Multi-user is half-built

Members can now sign in (v0.11.0) with Viewer / Operator / Administrator roles
— but **the roles are stored and never enforced**. A Viewer can toggle every
device an Administrator can. Competitors ship guest access, per-room
permissions and time-limited access.

**Worth closing:** yes, and this was the most embarrassing item on the list,
because the data model claimed a capability the code did not honour.

**Closed in v0.15.0.** `HomeService` holds the actor's role and gates every
mutation behind `mayOperate()` or `mayAdminister()`; a Viewer may read the
house, an Operator may run it, an Administrator may rearrange it. The default
is Viewer — an authorisation default that is convenient is an authorisation
default that ships — and the composition root raises it on sign-in. Per-room
permissions and time-limited access are still not there.

### 6. No cameras

Every competitor streams them; Home Assistant has a whole NVR ecosystem around
object detection.

**Worth closing:** no. Video is a genuinely large subsystem and the design has
no frame for it. Scope it out explicitly.

### 7. No backup or restore, no update path, no diagnostics

Home Assistant has per-location backup retention policies. SmarTon has a
SQLite file and no way to export it, no OTA path and no crash reporting.
`production-readiness.md` scores Operations at 10%.

**Worth closing:** backup/restore, yes — it is a day's work over an existing
SQLite file and it is the difference between a demo and something you would
mount on a wall. OTA, no.

**Backup and restore shipped in v0.15.0**; OTA and crash reporting did not,
and are still correctly out of scope.

### 8. Automations are room-granular, not device-granular

`SceneScheduler` is genuinely good — edge-triggered, midnight-wrapping,
injectable clock, 14 tests. But a scene acts on a whole room. Hubitat's Rule
Machine and Homey's Flow do per-device conditional logic.

**Worth closing:** yes, and it is mostly a data-shape change: scenes need a
device list rather than a room id.

**Closed in v0.16.0.** `Scene` carries a list of actions - device, power, and
optionally a level or a temperature - and falls back to its room when the list
is empty. Conditional logic (Rule Machine's "if motion and after sunset") is
still not there; this is per-device state, not per-device rules.

### 8b. No record of what happened

Home Assistant's logbook is a headline feature and every hub has some form of
it. Without one, a light being off is indistinguishable from a light somebody
switched off, a scene that ended, and a command the transport dropped.

**Closed in v0.16.0.** An activity log in Profile → Activity, composed at the
root from signals the services already emitted
([ADR-0021](adr/0021-activity-log-composed-at-the-root.md)). It records what
is announced today - power, scenes, sessions - and not level or target
changes, because `deviceChanged` carries an index and no indication of what
changed. That is a real limit and it is written down rather than papered over.

### 9. No to-do lists, presence detection, or "for you" summaries

Home Assistant 2026.1 leads with summary cards and human-readable automation
triggers ("someone arrives home" instead of state-change syntax).

**Worth closing:** presence, eventually — it is the input that makes automation
feel intelligent rather than scheduled. Lists, no.

---

## What SmarTon has that the field mostly does not

Worth stating, because a gap analysis that only lists gaps is a bad one:

- **Reported-vs-desired state as a first-class concept** (ADR-0010). Most
  consumer panels show the state you *asked for* and let the UI lie until a
  refresh. SmarTon shows what the device reported and marks the difference
  pending. This is a correctness position most shipped products do not take.
- **A driver-agnostic persistence layer** (ADR-0012) — SQLite, MySQL or
  PostgreSQL by config string, not by rewrite.
- **Measured design fidelity** — `design/measurements.md` extracts geometry
  programmatically and the implementation is checked against it.
- **A documented decision record** — 16 ADRs, each with the alternatives that
  were rejected and why.
- **Contrast enforced, not assumed** — accent colours are refused if they fail
  WCAG against the page (ADR-0014), swept over the whole RGB cube in tests.

None of that shows up in a feature comparison table, and all of it is what the
project is actually demonstrating.

---

## The short version

Three things were unexamined gaps rather than deliberate scope, and all three
were cheap. **All three are now closed**, and the expensive one has a first
implementation:

1. ~~**Roles are stored but not enforced.**~~ Enforced in `HomeService` as of
   v0.15.0. It holds the actor's role, defaults to Viewer, and gates every
   mutation; the scheduler acts as `Actor::System` so a schedule still fires
   at six in the morning when nobody is signed in. The UI disables what the
   role cannot do rather than letting the service refuse afterwards.
2. ~~**No stated Matter/Thread position.**~~ [ADR-0018](adr/0018-matter-and-thread-position.md):
   Matter over IP is the intended transport and plugs in at `IDeviceTransport`;
   Thread is explicitly not a radio we terminate, because a panel with no
   802.15.4 hardware that grew a dongle would be a border router, which is a
   different product. Certification is not claimed and not planned.
3. ~~**No backup/restore.**~~ `HomeService::exportModel` / `importModel`, with
   an entry point in Profile → Preferences. The home model only: no password
   verifiers leave the panel in a file people carry around.

And the expensive one: **an MQTT transport** ships as an optional dependency
([ADR-0019](adr/0019-mqtt-transport.md)), selected with `--transport
mqtt://host`. Loopback stays the default and stays in the tree — it is what
the tests run against and the only transport that can be told to fail on
purpose. Real telemetry (gap 4) is now a matter of pointing it at a broker
that carries readings, rather than a layer that does not exist.

What is left on this list is either deliberate scope (voice, cameras, OTA,
lists) or genuinely large (per-device automation, presence).

Everything else on this list is correctly out of scope, and should be *said* to
be out of scope rather than left silent.

---

## Sources

- [Home Assistant 2026.1 release notes](https://www.home-assistant.io/blog/2026/01/07/release-20261/)
- [Best Smart Home Hubs 2026 — Smart Home Explorer](https://www.smarthomeexplorer.com/guides/best-smart-home-automation-hubs-2026)
- [Best Smart Home Hubs in 2026: Matter and Thread Compared — The Gadgeteer](https://the-gadgeteer.com/2026/06/13/best-smart-home-hubs-2026/)
- [Home Assistant: Year of the Voice, Chapter 5](https://www.home-assistant.io/blog/2023/12/13/year-of-the-voice-chapter-5/)
- [Building the AI-powered local smart home — Home Assistant](https://www.home-assistant.io/blog/2025/09/11/ai-in-home-assistant/)
- [Home Assistant Wall Panel Guide — Sonoff](https://sonoff.tech/en-us/blogs/news/home-assistant-wall-panel-guide)
