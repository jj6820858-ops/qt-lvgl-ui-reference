# 3. Incremental model updates over full reset

Status: Accepted

## Context

The first `ReadingListModel::setReadings()` wrapped every update in
`beginResetModel()` / `endResetModel()`. Three lines, obviously correct.

Also wrong at 60 Hz. A reset destroys and recreates every delegate: visible
stutter on the embedded target, scroll position lost every frame, focus lost,
and delegate animations restarting continuously.

## Decision

`setReadings()` compares incoming rows against current rows.

- **Same row count** — update only rows that differ, then emit `dataChanged()`
  for the affected span with the specific roles that changed. If no row
  differs, emit nothing at all.
- **Different row count** — structural change; reset the model.

`MonitoringService::overallSeverity` is recomputed on every update but only
emits when the value genuinely changes.

## Consequences

+ Delegates persist; scroll position, focus and animations survive.
+ Frame cost drops from O(rows) to O(changed rows).
+ An idle system emits nothing, so no binding re-evaluates.
− Row diffing is our responsibility and needs its own tests. Three tests in
  `tst_readinglistmodel.cpp` cover it.
− `Reading::operator==` must compare every field or the diff silently misses
  updates. `equalityComparesEveryField()` guards that.
