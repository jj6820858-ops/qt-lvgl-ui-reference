# 9. Store the home model as one JSON snapshot

Status: Accepted

## Context

The first version of home persistence stored only what the user *changed*:
a `device_state` row per toggled device, a `scene_state` row per toggled
scene, an `entity_name` row per rename. The seed supplied the catalogue, the
store supplied the deltas, and the rule was "the seed says what exists, the
store says what you changed".

That rule holds exactly until the user can **add and remove** things — which
the space wizard (frames 10–17) does — and then it stops being expressible:

* a room the user deleted has no row that can represent its *absence*, so the
  seed puts it back on the next start;
* a room the user created has no seed entry to attach a delta to;
* a device moved between rooms is a change to a field the delta schema does
  not model at all.

Every fix is another table and another join, to describe a small object graph
that is always read whole and written whole.

## Decision

The seed becomes what it always really was — **factory defaults**, read once,
on a database with no stored model. After that the store holds the live model,
as a single JSON document in one row of `home_model`.

`HomeService` serialises and deserialises the same shape the seed uses, so a
snapshot can be diffed against defaults by eye. Every mutation persists
immediately: there is no Save button in the design and no session to lose work
from, so deferring the write would only create a window in which the panel
losing power loses the user's rooms.

A snapshot that fails to parse is treated as absent, and the app falls back to
the factory defaults rather than starting with no model at all.

## Consequences

+ Adds, removes, renames, moves and toggles all persist with no per-field
  schema work, and no migration when an entity gains a field.
+ One read and one write per change, on a model that is a few kilobytes.
+ `resetToDefaults()` is one `DELETE`, which is what a factory-reset needs.
− No querying inside the model: "every device across all spaces" would need a
  full parse. That is the signal to normalise, and it has not arrived — there
  is one space.
− The whole document is rewritten on every toggle. On the panel's flash that
  is a few kilobytes per tap, which is why the document is stored compact
  rather than indented. If toggle rates ever make that a wear concern, batch
  writes behind a short timer before reaching for a schema.
