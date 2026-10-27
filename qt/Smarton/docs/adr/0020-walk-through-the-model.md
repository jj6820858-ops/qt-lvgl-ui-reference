# 20. The 3D map is also somewhere you can stand

Status: Accepted

## Context

[ADR-0016](0016-generated-3d-floor-plan.md) settled what the 3D map claims:
the model holds no survey data, so the plan is *generated* from room area and
the geometry is honest about being a diagram with mass. The result was a
sectioned architectural model — waist-height walls, a cantilevered slab, glass
around the perimeter — read from a fixed three-quarter orbit.

Two things were then asked of it that it could not do. Devices in a room were
five identical pegs, which tells you how many there are and nothing about
which. And the model could only be looked at, never entered: a wall panel
mounted in a hallway is the one screen in a house where "show me the living
room from inside it" is a reasonable thing to want.

The obstacle is that the sectioned model and a first-person view want opposite
geometry. Waist walls exist so the plan stays readable from above and no
device is hidden; at eye height they read as an open-plan office. Full-height
walls fix the interior and seal the exterior.

## Decision

**Two camera modes, and the geometry follows the mode.** Orbit keeps the
sectioned model exactly as ADR-0016 specified. Walk raises every wall to the
ceiling, closes the roof, collapses the storey separation to zero, hides the
storeys you are not on, and cuts a doorway through each wall.

**The storey height went from 62 to 132 units.** 62 was a proportion nobody
lives in: the generated rooms are 300–400 units across, and a room four times
wider than it is tall is a crawlspace. The orbit view loses nothing, because
the section is still cut at the waist.

**One geometry pass, in `built`.** Wall rectangles, room footprints and device
positions are solved once in JavaScript and handed to the delegates. This is
not primarily a performance decision: the collision test and the walls you can
see have to be the same rectangles, and computing them twice is how a player
ends up walking through a wall that is drawn, or stopping in a doorway that is
not.

**Walking cannot dead-end.** Doorways are cut in the middle of each room's own
walls, and two rooms that share a boundary but not a full edge — which a
squarified layout does produce — get two openings that do not line up. Rather
than pretend otherwise, tapping a room's floor walks you to it.

**On-screen controls, not WASD.** The target is a 7-inch touchscreen. A
thumbstick and a drag-to-look surface; the keyboard still works where there is
one, because that is where this is developed.

**Lamps that are on light the scene**, capped at six and off below render tier
1. This is the one thing here that makes the model read as *your* house rather
than as a picture of a house — turn the living-room lamp off from the
dashboard and the living room goes dark.

**Devices have shapes.** A floor lamp, a squat speaker, a wall unit near the
ceiling, a small box on the floor. Still abstractions; nobody will mistake a
cone on a stick for their lamp. But they are distinguishable across a room,
which is the job.

## Consequences

**The honesty rule from ADR-0016 is now doing more work, not less.** A
first-person view of a house implies you are seeing your house. You are not:
you are seeing rooms in proportion to their floor area, in an order a treemap
chose, with furniture standing for devices. That was defensible for a plan and
needs saying louder for a walkthrough, which is why the room labels, the empty
state and this record all keep saying it.

**The look surface must not swallow taps.** It carries a `DragHandler` and
nothing else, so a press that becomes a drag looks around and a press that
does not falls through to picking. A `MouseArea` there would have taken every
tap and left every device unclickable — which would remove the reason to be in
the room.

**Costs are bounded by the same tiers as everything else.** Shadows follow
`Theme.shadowsEnabled`, lamp lights are capped and tier-gated, and walking
draws one storey instead of all of them. The RK3328 constraint from ADR-0017
has not been relaxed to buy this.

**The controls needed a band of their own.** They used to float over the view;
over the 2D plan they fought its room rectangles for every tap near that
corner, so switching to 2D could leave you unable to switch back. A reserved
56 px strip removes the class of problem rather than the instance.
