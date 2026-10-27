# 8. Reflow the design for the panel; do not scale it

Status: Accepted

## Context

The Figma frames are 1440 × 1024 — a tall desktop canvas. The target is a
Waveshare 7" panel at 1024 × 600: 71% of the width and 59% of the height, and
a completely different aspect ratio (2.4:5 becomes 5:3).

Two ways to get from one to the other.

**Scale everything by a factor.** One line of code: a root `scale`, or every
metric multiplied by `width / 1440`. It is also wrong twice over. The factors
differ per axis, so either the design distorts or the shorter axis wins and a
third of the screen goes to waste. And a uniform 0.71 turns a 52 px input into
37 px — 5.5 mm on a 169 ppi panel, below the 7 mm minimum for a reliable
finger target. A design scaled onto a touch panel becomes a design people
mis-tap.

**Reflow: keep the physical sizes, re-compose the layout.**

## Decision

Preserved verbatim from Figma, because they carry the design's meaning and its
touch ergonomics:

* the full colour palette, as exact hex in `DesignTokens.h` (see `design/README.md`);
* control heights — input 52, primary button 54, nav row 46;
* corner radii — 12 on controls, 8 on nav rows;
* border weights, including the 2 px `#1268CC` focus ring;
* the auth column width, 480;
* the sidebar's proportion of screen width, 19.3% (278/1440 → 198/1024).

Re-composed for the new aspect ratio:

* type sizes tightened one step where a 1024 px canvas had room a 600 px one
  does not — the display size is 30, not 34;
* vertical rhythm tightened: `Theme.spacing8` where the frame used 40–48 px of
  air;
* the Login screen's three provider buttons become one row of three instead of
  a column, with labels shortened to the provider name because 152 px will not
  hold "Login with Facebook" at 14 px without eliding;
* `StEmptyState` sizes its illustration from the height actually left over
  after the headline and the button, rather than from a fixed number — so the
  call to action is never pushed off the bottom.

Every reflow is commented in the file that makes it, naming the Figma frame.

## Consequences

+ Touch targets stay above the ergonomic minimum on the real hardware.
+ The design reads as designed: same colours, same weight, same proportions.
+ The layout survives a different panel. Nothing depends on 1024 × 600 except
  `Theme.screenWidth` / `screenHeight`.
− "Does it match the Figma?" stops being a pixel diff and becomes a judgement.
  That is what the component gallery and `design/README.md` are for: the
  invariants are written down, so the judgement is reviewable rather than
  personal.
