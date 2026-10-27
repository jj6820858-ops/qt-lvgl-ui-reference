# 13. One SVG icon set, tinted at runtime

Status: Accepted

## Context

Every glyph in SmarTon was painted by hand on a `Canvas`: seven route icons in
`StNavIcon`, seven more in `StIconButton`, plus an eye, a magnifier, two ticks,
a pencil, a speaker, a trend arrow and a play/pause pair scattered across
individual controls.

That works, and it does not scale past about ten. By thirty it had produced:

* **Drifting stroke weights.** 1.5 in one file, 1.6 in another, 1.7 in the
  calendar, 1.8 in the combobox. Nothing enforced a value and nobody could see
  them side by side.
* **Inconsistent optical size.** Each glyph was drawn to fill its own box, so a
  20 px "settings" and a 20 px "back" carried visibly different weight.
* **Duplicate concepts.** The sidebar's `spaces` and the empty state's house
  meant the same thing and looked nothing alike.
* **Repaint on recolour.** A `Canvas` repaints when its ink changes, so hover
  on a nav row re-rasterised the glyph.
* **Rotation as authoring.** "Next track" was the back arrow at
  `rotation: 180`, which is fine for an arrow and wrong for anything with an
  asymmetric detail.

## Decision

31 SVGs in `resources/icons/ui/`, one specification: 24×24 viewBox, 1.5
stroke, round caps and joins, geometry on whole or half pixels.

`StIcon` is the only way one is drawn. It rasterises at
`size × devicePixelRatio` — an SVG decoded at 24 and drawn at 24 on a 2× panel
is visibly soft — and tints with `MultiEffect` colorization.

**Authored white, coloured at runtime.** One file serves muted-in-a-rail,
white-when-active, orange-on-a-link and `danger`-on-a-delete. Shipping a
coloured copy per state is how a set ends up with four almost-identical trash
cans that fall out of sync.

**Four legal sizes**: 16 inline, 20 in controls, 24 default, 32 in empty
states. An icon set with arbitrary sizes stops looking like a set.

`StNavIcon` survives, reduced to what it was actually for: translating a
*route* to an *icon name*. `spaces` is a house; that mapping is real and worth
having in one place.

## Consequences

+ One stroke weight, one grid, one place to change any of it.
+ Recolouring is a shader uniform, not a repaint.
+ The gallery renders the whole set at once, so a mismatched icon is visible
  immediately rather than on the screen that uses it.
− `MultiEffect` per icon is a GPU pass. Icons are small and few per screen, but
  this shares the cost concern in ADR-0008 and would be the second thing to
  look at if the panel is fill-rate bound.
− `Canvas` remains where a drawing is genuinely data-driven and not an icon:
  the line chart, the ruler's ticks, the welcome screen's orbit rings, and the
  provider marks, which are third-party logos rather than part of this set.
