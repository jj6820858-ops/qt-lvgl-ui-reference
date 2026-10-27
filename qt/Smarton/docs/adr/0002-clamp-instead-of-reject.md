# 2. Clamp out-of-range values instead of rejecting them

Status: Accepted

## Context

A `Reading` has a valid range, and input can arrive outside it: a sensor
glitch, a decode error, a unit mismatch. Either reject the value and keep the
previous one, or clamp it into range.

Rejecting is more correct in a data-processing sense. But this is an HMI: a
gauge with nothing to show is a worse failure than a gauge pinned at maximum,
and an operator seeing a needle at redline understands something is wrong.

## Decision

`Range::clamp()` is applied in the `Reading` constructor and in `setValue()`.
Out-of-range input is silently clamped. Degenerate ranges (`maximum <=
minimum`) return `minimum` with a progress of `0.0` rather than dividing by
zero.

## Consequences

+ The UI can never be handed an unrenderable value.
+ No null or optional handling anywhere in QML.
− A genuinely broken sensor looks like a saturated one. A project needing to
  distinguish these should add an explicit validity flag to `Reading` — not
  change the clamping.
− Clamping is silent. Anything that must know about out-of-range input has to
  observe it before it reaches `Reading`.
