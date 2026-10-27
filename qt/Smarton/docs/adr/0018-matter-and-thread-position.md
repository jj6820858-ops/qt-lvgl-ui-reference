# 18. Matter is the intended transport; Thread is not our radio

Status: Accepted

## Context

Every hub SmarTon would sit beside supports Matter. Homey Pro ships seven
radios, Aqara's M3 six, Home Assistant takes any of them over USB, and Matter
has been the interoperability baseline since 2023. SmarTon ships
`LoopbackDeviceTransport`, which simulates latency and packet loss against
seeded data.

`docs/competitive-gap.md` ranks the absence of a real protocol first, and the
absence of a *stated position on Matter* second — not because implementing
Matter is cheap, but because saying nothing about it reads as not having
thought about it rather than as having scoped it out. Those are different
answers to the same interview question and only one of them is a good one.

Matter is also frequently conflated with Thread, and the conflation is what
makes the scoping decision look harder than it is. Matter is an application
layer: a data model, a commissioning flow and a security model, carried over
IP. Thread is one of the link layers it can run on — 802.15.4 mesh — alongside
Wi-Fi and Ethernet. They are separable, and for a mains-powered wall panel they
separate cleanly.

## Decision

**Matter over IP is the intended transport.** It plugs in at
`services::IDeviceTransport` — the same seam `LoopbackDeviceTransport` and the
MQTT transport (ADR-0019) occupy. Nothing above that interface changes: the
reported-versus-desired split (ADR-0010) is exactly the shape an asynchronous
commissioning-and-report protocol needs, and it was designed for this.

**Thread is out of scope as a radio we terminate.** A Waveshare RK3328 panel
has no 802.15.4 hardware, and adding a dongle makes SmarTon a border router —
a different product with a different power, uptime and network story. Thread
devices reach SmarTon through somebody else's border router, over IP, as
Matter nodes. That is what border routers are for.

**Certification is not claimed and not planned.** Matter interoperability is a
certification programme with test harnesses, a CSA membership and per-device
attestation. A one-developer portfolio project can implement the protocol
against `chip-tool` and open-source SDKs; it cannot honestly print the logo.
Nothing in this repository will claim Matter compatibility until something has
actually passed a compliance run.

**MQTT comes first.** It reaches real hardware today through Zigbee2MQTT and
the Matter bridges people already run, over a broker that costs nothing to
stand up, and it exercises every layer above the transport against real
timing. A Matter transport written second inherits an interface that has been
proven against something other than a simulator.

## Consequences

**The gap is now scoped rather than silent.** "No Matter support" and "Matter
is the intended transport, it plugs in at `IDeviceTransport`, and here is why
Thread is not our radio" are the same feature set and a different project.

**The seam is load-bearing and must stay honest.** `IDeviceTransport` is
deliberately asynchronous, deliberately allowed to never answer, and
deliberately says "sent, not confirmed" — see its header. Every shortcut that
would be convenient for a loopback (a synchronous `bool setPower`, an
assumption that a command that returned true worked) is a shortcut that makes
Matter unimplementable behind it. Reviews of that interface should be strict
for that reason.

**Commissioning has no home yet.** Matter pairing is a QR code, a numeric
setup code and a fabric — none of which the link-device flow (frames 16, 17,
17b, 11) models. When a Matter transport lands, that flow grows a
commissioning step; the flow being ours rather than a vendor SDK's screen is
what makes that a UI change rather than a rewrite.

**Local-only stays true.** Matter over IP does not require a cloud, and
SmarTon will not add one to get it. If a device only works through a
manufacturer's cloud, it is not a device SmarTon supports.
