# 21. The activity log is composed at the root, not written by the services

Status: Accepted

## Context

The panel could not answer "what happened here". A light was off and there
was no way to tell whether somebody switched it off, a scene ended, or the
transport dropped the command. Every competitor has some form of this — Home
Assistant's logbook is a headline feature — and for a wall panel in a shared
household it is the difference between a control surface and a device you
trust.

The obvious implementation is the wrong one. Give each service a logger and
call it from every mutation: `HomeService::setDevicePower` records a line,
`AuthService::signIn` records a line, and so on. It works, and it puts a
log-shaped dependency through every class in the services layer — so the first
thing anyone wants to change, which is *what gets logged*, means editing all
of them.

There is also a fact none of those classes has. `HomeService` knows the
signed-in ROLE, because that is what gates its mutations. `AuthService` knows
the NAME. Neither knows both, and "who did this" is the question the log
exists to answer.

## Decision

**The log listens; nothing announces to it.** `HomeService` already emits
`devicePowerChanged`, `SceneScheduler` already emits `sceneActivated`, and
`AuthService` already emits `signedIn`. The composition root connects those to
`ActivityLog::record`. Nothing below `main.cpp` knows the log exists.

**The root names the actor**, because composing those two services is its job
and it is the only place that can.

**Scene lines come from the scheduler, not from the devices it drives.** One
line saying "Movie Night ran" is what a person wants; six lines saying six
lamps changed is what they get if the log listens further down.

**A scene the house ran has no actor.** Attributing it to whoever happened to
be signed in would be a lie in the one record people read to find out what
happened, and "by the panel" is the true answer.

**Bounded at 400 entries**, in its own file, written whole on every append.
Not in the home model's snapshot: a log is append-only where the model is a
fixed shape that gets edited, and mixing them would mean every light switch
rewriting the whole house — and a restored backup (ADR-0019's sibling feature)
carrying somebody else's history, which is the wrong answer to "what happened
here".

**`QSaveFile`, not `QFile`.** This is written on every light switch on a
device whose power can be cut at any moment, and a half-written JSON array is
a log that will not load again — losing the whole history to save the last
line of it.

## Consequences

**What gets logged is one file's worth of decisions.** Adding an event is a
connection in the root; removing one is deleting a connection. Neither touches
a service.

**The log can only record what is already announced.** That is a real
constraint and it has already bitten once: level and target changes emit
`deviceChanged`, which carries an index and no indication of what changed, so
they are not logged. Fixing that means a richer signal from `HomeService` —
which is the right place for the change to land, and exactly the pressure this
arrangement is supposed to apply.

**Two things now write per-mutation.** `HomeService::persist()` writes the
model and `ActivityLog::persist()` writes the log, so a device toggle is two
file writes. On the panel that is two small writes to eMMC on an interaction
that happens a few times an hour, which is affordable — but it is a number
that goes up if the log ever starts recording sensor readings, and that is the
point at which this needs a buffer rather than a bigger file.

**The list model resets rather than inserts**, which is the opposite of
ADR-0003. A log grows only at the front and drops off the back, and the list
is a page nobody watches while the house changes underneath it; a reset costs
a rebuild of the rows actually on screen, which is about eight. A live ticker
on the dashboard would make that wrong.
