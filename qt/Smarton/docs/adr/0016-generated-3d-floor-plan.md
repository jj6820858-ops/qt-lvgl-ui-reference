# 16. A generated, optional 3D floor plan

Status: Accepted

## Context

ADR-0014's map view lays rooms out as a squarified treemap in proportion to
floor area — the only spatial fact the model holds. It answers "which room is
big, which devices are where" and does it in two dimensions.

Two things it cannot do. It cannot show more than one storey, because a flat
plan has one plane and a house may have several; and it cannot answer "what is
above the kitchen", which is the question a multi-storey plan exists for.

Qt Quick 3D is available in the user's Qt. It is not available in every Qt.

## Decision

Extrude the same generated geometry into stacked storeys, rendered with Qt
Quick 3D, and keep the 2D plan as an equal alternative rather than as dead
code. `Room` gains an integer `floor`; each storey is squarified on its own
footprint and drawn at its own height.

Quick3D is an **optional** dependency, detected at configure time. A build
without it gets the 2D plan and no toggle.

## Consequences

**Optional, not required, and that is the load-bearing decision.** Qt Quick 3D
needs the RHI with a working GPU backend; a minimal Qt build, a headless CI
container and some embedded images ship without the module at all. Making it
`REQUIRED` would mean an application that will not build at all for someone who
did not want a 3D floor plan — a poor trade for one view. So the root
`CMakeLists` detects it, `SmarTon.Ui.Map3D` is only added when it is found, and
`backend::Capabilities::mapView3D` reports which world this build is in.

**The 3D view is loaded by URL, not imported.** An `import SmarTon.Ui.Map3D`
at the top of `RoomsScreen` would make the WHOLE screen fail to load in a build
without the module — the opposite of a graceful fallback, and a worse failure
than the missing feature. A `Loader` with a source string is the only shape QML
offers for an optional dependency. The module is still *linked* when present,
because a resource nothing links against is not compiled into the binary.

**Its own QML module, not a file in Components.** Putting a Quick3D import in
`SmarTon.Ui.Components` would make every card, chip and top bar in the app
un-buildable on a Qt without the module. The dependency stops at the module
boundary.

**3D earns its place only above one storey**, and the toggle says so by
existing. On a bungalow the flat plan is easier to read: no perspective
foreshortening, no occlusion, labels always legible. The 3D view is the default
where it is available because that is what was asked for, and the 2D view is
one tap away rather than deleted.

**Labels are 2D, projected.** Text rendered *into* a 3D scene has to be a
texture or extruded geometry; both look wrong at a glancing camera angle and
neither stays readable at the far end of the plan. So the geometry is 3D and
the labels are ordinary Qt Quick items positioned with
`View3D::mapFrom3DScene`. They stay screen-aligned and crisp at any zoom.

That projection has a trap worth recording: `mapFrom3DScene` is a *function*,
so a binding that calls it records no dependency on the camera — orbit the
model and the labels would sit where they were. `projectionEpoch` reads the
camera's position, rotation and the viewport size into one property so the
dependency is explicit, in one place rather than once per label. Labels behind
the camera (`z <= 0`) are hidden, because there `x` and `y` are meaningless and
drawing them puts labels in mirror positions on the far side of the screen.

**The composition is a SECTIONED model, not extruded rectangles.** The first
version drew four full-height walls per room, which is what a floor plan
extruded naively looks like: a tray of pigeonholes, doubled walls at every
shared boundary, and no way to see inside. An architectural model solves the
same problem by cutting, so this one does too — a continuous slab per storey
that OVERHANGS the footprint (the cantilevered horizontal is the strongest cue
that something is a building rather than a diagram), interior partitions at
waist height rather than to the ceiling (the sectioning convention: the plan
stays legible from above and the device markers stay visible), full-height
glazing with dark mullions around the perimeter (the one wall type that can be
full height without occluding anything), and a roof on the top storey only, so
the stack is closed rather than open like a bookshelf.

**A site, and a plinth between it and the building.** Without a ground plane
the model floats in the void and the key light's shadow lands on nothing. The
ground sits well below the slab rather than flush with it — coplanar surfaces
cannot be separated by the depth buffer and show up as the shimmering patchwork
that every z-fight looks like. The plinth's height is derived from the gap
rather than written as a constant, so neither end floats and neither
intersects.

**Three lights, filmic tonemapping, and ambient occlusion.** One light leaves
the far walls black; two leave the silhouette dead against the background. A
linear tonemap blows the emissive device markers and the lit slab out to flat
white, so the concrete stops reading as a surface. AO is the cheapest thing
that makes separate boxes look like one built object — without it the
partitions appear to float a millimetre above the slab. Shadows follow
`Theme.shadowsEnabled`, so the one genuinely expensive pass is the one the user
can already turn off.

**Glass casts no shadow, deliberately.** Physically it would cast a faint one;
in a shadow map it lands as an opaque black slab across the floor, which is
worse than none. Its material also disables back-face culling — culled glass
looks like a flat blue card rather than a box.

**One material per state, shared.** A unique material per room is a unique
shader binding, and a panel with an RK3328 is not the place to find out that
thirty of them cost a frame.

**Picking is one ray cast, not thirty hit areas.** A single `TapHandler` over
the view calls `View3D::pick()`. The hit object's `objectName` carries an
explicit `room:` or `device:` tag rather than the bare id, because seed data
and generated ids use different prefixes and anything that sniffs an id's shape
works for one and silently not the other.

**`floor` is an int, not a name.** "Ground / First / Second" differ by country
— a US first floor is a UK ground floor — and a translated label is not
something to sort or stack by. The number is the fact; the wording is a
presentation choice, made in `RoomsScreen::floorLabel()`.

**Bounded to −2..20.** A basement and a tower block. Outside that it is a typo,
and a plan that stacks forty empty storeys to reach one room is not a plan.

## Alternatives considered

**A real floor plan editor** — drag rooms, draw walls, set adjacency. Rejected
for now: it is a product in itself, and it would replace generated geometry
with geometry the user has to maintain by hand before the map shows anything at
all. The generated plan is useful with zero input, which is what makes it worth
having on a panel.

**Importing a floor plan image and pinning devices onto it.** Closer to what
frame 18 draws, and rejected because the panel has no file browser worth the
name and no way to calibrate an arbitrary image to room records. It stays the
obvious next step if survey data ever arrives.

**Making the 3D view the only map.** Rejected: it would make an optional Qt
module a hard requirement for a screen that already worked.
