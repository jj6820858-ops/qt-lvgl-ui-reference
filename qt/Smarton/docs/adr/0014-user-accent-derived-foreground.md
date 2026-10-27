# 14. One user-changeable colour, with its foreground derived

Status: Accepted

## Context

The panel ships one dark theme (ADR-0004). The request was to let a user pick
the accent colour for the whole application, which raises three questions the
obvious implementation answers badly.

**Where does the choice live?** `DesignTokens` is the Figma file transcribed
into C++, every value `CONSTANT`, and it is the reference the built UI is
checked against — the programmatic pixel comparisons in `design/measurements.md`
are only meaningful because it is verbatim. Making `primary` mutable would mean
the file documenting the design no longer describes what is on screen.

**How much is changeable?** Surfaces, text and state colours are not eight
independent choices; they are a contrast system designed together. Letting
someone set the page background is how a wall panel becomes unreadable from
across a room, and no amount of preview UI prevents it.

**What sits on the accent?** A primary button's label was `Theme.textPrimary` —
white — which is correct for exactly as long as the accent stays dark. Pick the
design's own `warning` amber (#F5BA41) and white-on-amber is 1.75:1: legally
present, practically invisible.

## Decision

A separate `backend::Appearance` singleton holds the override. `DesignTokens`
stays immutable and remains the default; `Theme.primary` reads from
`Appearance`, so every control already bound to that token follows the choice
with no further work — which is what the token existed for.

Only the accent is changeable.

The foreground is **derived, never chosen**: `Appearance.readableOn()` measures
WCAG relative luminance for white and for `surfaceDeep` against the candidate
and returns whichever wins, exposed as `Theme.textOnPrimary` and `Theme.textOn()`.

A colour is refused if its best foreground is under 3:1, or if it is under 3:1
against the page background (WCAG 1.4.11, the non-text floor).

## Consequences

**Rejecting the naive brightness test.** `qGray()` and HSV `value()` both weight
the channels equally. Pure blue then reads as mid-grey and is given white text
it cannot carry; pure yellow reads the same and is given white text on a
near-white ground. The WCAG coefficients (0.2126 / 0.7152 / 0.0722) are what
the eye actually uses, and `tst_appearance` pins all four corner cases.

**The 3:1 floor is measured against the page, not every surface.** Against
`surfaceRaised` (#40464D) the brand orange itself only reaches 2.49:1. A rule
demanding 3:1 everywhere would reject the design's own accent — which would
mean the rule was wrong, not the colour. The page background is where accent
strokes and accent text actually sit on these screens.

**The foreground clause never fires, deliberately.** Because the two candidates
are white and near-black #101113, they span almost the whole luminance range:
swept over the RGB cube, the worst any colour does against the better of them
is 4.35:1 (around #248C0C). So the background clause is the one that rejects
anything. The foreground clause is kept as a guard on the *invariant* — if
`surfaceDeep` is ever lightened toward a mid tone, real colours begin to fail
and `tst_appearance::foregroundRuleCannotFailForAnyColour` says so first.

**The default accent is the one documented exception.** Measured, white on the
brand orange is 3.83:1 and near-black is 4.93:1 — so a purely derived foreground
would flip every primary button in the app to dark text the moment this feature
landed, and stop matching the Figma. Restyling the brand is a design decision,
not something an accent picker should do on its way past. `DesignTokens::`
`primaryForeground()` holds the design's white, `Appearance::foregroundFor()`
returns it while the accent is the default, and a user-chosen accent — which the
design never reviewed — gets the measured answer. `tst_appearance::`
`defaultAccentKeepsTheDesignsForeground` pins both the exception and the numbers
behind it, so tidying the special case away fails a test rather than changing a
screenshot.

Worth stating plainly rather than burying: white-on-#E25319 clears the 3:1 that
button-sized text needs and does not clear the 4.5:1 that body text would. That
is a property of the supplied design, recorded here, not something this change
introduced or silently corrected.

**One preset was replaced.** `accentViolet` (#734497) is 2.26:1 on the page and
fails its own rule, so the swatch list offers `accentVioletSoft` instead. A test
asserts every offered preset passes — a swatch the setter then refuses is the
worst outcome available, because the user clicks and nothing happens.

**Refusal is visible.** `isAcceptableAccent()` is public and the hex field binds
its error text to it, so a rejected colour says why before it is committed. A
setter that silently ignores input is indistinguishable from a broken one.

**Preferences are injected statically.** A QML singleton is constructed by the
engine, so there is no constructor to pass the store to; `main.cpp` calls
`Appearance::setPreferences()` before `loadFromModule`. Without it the class
still works and simply forgets the choice on exit.

**The stored value is a string, not a QColor.** `IPreferences` lives in
`services`, which links Qt Core only. Keeping the field a `QString` means a
headless test of the preference layer does not drag Qt Gui in for one setting;
the colour type belongs at the edge that cares about colour.

## Alternatives considered

**A full theme editor.** Rejected: it moves the contrast guarantee from the
design to the user, and the failure mode is a panel nobody can read.

**A free colour wheel as the primary affordance.** Rejected as the default
surface; the presets come from `DesignTokens` so every offered choice already
belongs to the theme. A hex field is available for anyone who wants it, behind
the same contrast rule.

**Storing the derived foreground.** Rejected: two stored values that must agree
is a bug waiting for the first hand-edit of the settings file. It is a pure
function of the accent, so it is computed.
