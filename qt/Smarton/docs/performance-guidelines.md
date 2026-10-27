# Performance guidelines

Ordered by how often each is the actual cause of a slow Qt Quick UI.

## 1. Redundant NOTIFY emissions

Every emission re-evaluates every binding on that property. Guard the setter,
and assert the guard with `QSignalSpy` — emission counts are testable.

## 2. Model resets instead of incremental updates

`beginResetModel()` destroys and recreates every delegate, loses scroll
position and focus, and costs O(rows) per frame. Use `dataChanged()` for value
changes and `begin/endInsertRows()` for structural ones. See ADR-0003.

## 3. Unqualified property access

Forces a scope-chain lookup on every evaluation and defeats the QML compiler.
`.qmllint.ini` sets it to `error`.

## 4. Binding loops

Qt prints them at runtime; treat each as a bug. Usually a binding writing to a
property that feeds back into itself through `width`/`height` and an anchor.

## 5. Oversized textures

An image decoded at source resolution and scaled down wastes GPU memory, which
is scarce on embedded targets. Always set `sourceSize`.

## 6. clip, opacity layers, layer.enabled

Each breaks scene graph batching and forces an extra render pass. This template
uses `clip` in exactly one place — the gallery `Flickable`, where it is
unavoidable.

## 7. Everything loaded at startup

`Loader { asynchronous: true; active: … }` for non-critical screens.

## 8. Canvas repainting more than it needs to

`Canvas` is expensive. Trigger `requestPaint()` from the specific properties
the drawing reads:

```qml
readonly property real  drawProgress: root.progress
readonly property color drawTone: root.tone
onDrawProgressChanged: arc.requestPaint()
onDrawToneChanged: arc.requestPaint()
```

A generic `onWidthChanged`-style trigger repaints on every layout pass.

## 9. Scene graph work that belongs in C++

Waveforms, spectrograms and anything drawing thousands of points per frame
should be a `QQuickItem` with a custom `QSGNode`, not a `Canvas`. That module
would live at `ui/Render/` — see architecture.md §8.

## Profiling

- **QML Profiler** in Qt Creator — the frame timeline shows which bindings and
  delegates cost time.
- `QSG_RENDER_TIMING=1` — per-frame scene graph timings.
- `QML_DISABLE_DISK_CACHE=1` — measure cold QML compilation cost.
- `QBENCHMARK` for C++ hot paths.

Measure on the **target hardware**. Desktop timings say nothing useful about
an RK3328.
