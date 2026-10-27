# 11. Scenes run on edges, and apply to a room

Status: Accepted

## Context

A scene stored days, a time range and an enabled flag, and nothing evaluated
them. `SceneScheduler` is that evaluation. Three questions had to be answered
before it could be written.

**What does a scene apply to?** The design's scene editor (frames 24–25) has a
per-device panel, implying a scene-to-device table. That table does not exist,
and the editor cannot populate it yet.

**Continuously, or on edges?** Should the scheduler assert its devices every
tick while the window is open, or only as it opens and closes?

**What about the time the panel was off?** A wall panel is power-cycled.

## Decision

**A scene applies to every device in its room**, or to the whole space when it
names no room. A deliberate limitation, recorded so it is not mistaken for an
oversight: the alternative is inventing a schema nothing writes to.

**Edges, not levels.** Devices are driven when a window opens and when it
closes, never in between. Re-asserting continuously makes a light impossible to
switch off by hand for the duration of a scene, and "the house fights me" is a
worse failure than a scene that can be overridden. A user turning something off
mid-scene means it, and it stays off. `tst_scenescheduler` pins this.

**A window already open on start is applied; one that opened and closed while
the panel was off is not.** Walking in should find the house as the scene
describes; it should not replay last night's schedule at breakfast.

Disabling a scene stops it managing its devices — it does not switch them off.
Turning a scene off is not a command about the lights.

The clock is injectable, so every rule above is tested at specific instants
rather than by sleeping. Stored day and time strings are parsed with the **C**
locale, because they are storage: a panel switched to another language must
still read scenes written before the switch.

## Consequences

+ Scenes actually run, including the ones that wrap midnight — the seeded
  "Sleeping, 12:00 PM – 08:00 AM" silently never fired before.
+ The whole thing is testable in milliseconds.
+ A scene-to-device table is additive: `applyScene()` is the only method that
  would change.
− A room-granular scene will turn on devices a user did not mean to include.
  Visible in the UI, and the reason the per-device panel exists in the design.
− One tick a minute means up to 60 seconds of lag at a boundary. Correct for
  schedules expressed in minutes; wrong if seconds ever matter.
