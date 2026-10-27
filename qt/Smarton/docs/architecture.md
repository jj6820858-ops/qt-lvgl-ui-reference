# Architecture

## 1. Context

SmarTon is a layered Qt 6 / QML reference application. It renders live
sensor readings as gauges, targets Windows, macOS and desktop Linux from one
codebase, and cross-compiles to aarch64 Embedded Linux (Rockchip RK3328).

| | |
|---|---|
| **Qt** | 6.8 LTS |
| **Language** | C++20, QML |
| **Build** | CMake 3.28+, Ninja |
| **Targets** | Windows, macOS, Linux, aarch64 Embedded Linux |

## 2. Layers

Dependencies point downward only. Never sideways, never up.

```
                       ┌───────────────────────────┐
                       │  app/     composition root│  wires everything, once
                       └─────────────┬─────────────┘
        ┌────────────────────────────┴────────────────────────────┐
        │                     ui/  (QML modules)                  │
        │   Screens → Dialogs → Navigation → Components →         │
        │   Layouts → Controls → Helpers → Theme                  │
        └────────────────────────────┬────────────────────────────┘
                       ┌─────────────┴─────────────┐
                       │  models/   VIEW MODELS    │  ← the QML/C++ boundary
                       │  backend/  design tokens  │
                       └─────────────┬─────────────┘
                       ┌─────────────┴─────────────┐
                       │  infrastructure/          │  transports, simulators
                       ├───────────────────────────┤
                       │  services/                │  orchestration, rules
                       ├───────────────────────────┤
                       │  domain/                  │  entities, value objects
                       ├───────────────────────────┤
                       │  core/                    │  framework primitives
                       ├───────────────────────────┤
                       │  common/                  │  vocabulary types
                       └───────────────────────────┘
```

### Enforced, not aspirational

Each layer is a separate CMake target with an explicit link list. `domain`
links `Qt6::Core` and `SmarTon::common` — nothing else. Adding a QML
dependency to it is a visible change to a `CMakeLists.txt`, not a quiet
`#include`. That is the whole mechanism, and it is enough.

### Dependency inversion at the service boundary

`services/IReadingSource.h` declares the interface. `infrastructure/`
implements it. Services depend on the interface, never on the transport —
which is why the whole application can be driven by a stub in a test with no
hardware present. `tst_monitoringservice.cpp` does exactly that.

## 3. The QML module graph

`ui/CMakeLists.txt` adds each module in dependency order. A module may only
import modules listed above it there.

| Module | Contains | May import |
|---|---|---|
| `SmarTon.Ui.Theme` | design tokens singleton | `SmarTon.Backend` |
| `SmarTon.Ui.Helpers` | pure JS, no visual types | — |
| `SmarTon.Ui.Controls` | atoms: label, button, pill, gauge | Theme, Helpers |
| `SmarTon.Ui.Layouts` | page frame, responsive grid | Theme |
| `SmarTon.Ui.Components` | molecules built from atoms | Theme, Controls, Layouts |
| `SmarTon.Ui.Navigation` | nav rail | Theme, Controls |
| `SmarTon.Ui.Dialogs` | modal surfaces | Theme, Controls, Layouts |
| `SmarTon.Ui.Screens` | full pages | everything above **+ Models** |

**Only `Screens` may import `SmarTon.Models`.** Controls and Components
know nothing about the application, which is what lets the gallery render
every one of them in isolation. A control that reaches for a view model is a
screen wearing a control's name.

### Why submodules rather than one big module

- **Enforced direction.** `Controls` cannot accidentally use a `Screen`,
  because the CMake target does not link it.
- **Honest reuse.** `Controls` and `Layouts` can be lifted into the next
  project as-is. A single module would drag the whole application along.
- **Faster builds.** Touching a screen does not rebuild the control library.
- **Legible ownership.** The module list *is* the architecture diagram.

`st_add_qml_module()` mirrors each module's URI into
`${CMAKE_BINARY_DIR}/qml/SmarTon/Ui/Controls/...`, and that tree is added
to `QML_IMPORT_PATH`, so Qt Creator, `qmlls` and `qmllint` resolve every type
without running the application.

## 4. The QML/C++ boundary

| Direction | Mechanism | Used for |
|---|---|---|
| C++ → QML | `Q_PROPERTY` + `NOTIFY` | scalar state |
| C++ → QML | `QAbstractListModel` roles | collections |
| C++ → QML | `QML_ELEMENT` / `QML_SINGLETON` | type registration |
| QML → C++ | `Q_INVOKABLE` | explicit commands |
| C++ → QML | `setInitialProperties` | injecting the root view model |

**Rules:**

1. QML never sees a domain type. `domain::Reading` stops at `ReadingListModel`.
2. One view model per screen; the screen binds to nothing else.
3. `setInitialProperties`, never `setContextProperty` — a context property is
   an unqualified lookup, which `.qmllint.ini` treats as an error.
4. Every `NOTIFY` emission is guarded by an equality check.

### The unchanged-value guard

```cpp
if (worst == m_overall)
    return;                     // never re-emit an unchanged value
m_overall = worst;
emit overallSeverityChanged(m_overall);
```

Each emission re-evaluates every binding attached to that property. Emitting
when nothing changed is the most common cause of unexplained CPU load in a Qt
Quick application. Two tests assert this so it cannot regress.

### A registration trap worth knowing

For every `QML_ELEMENT` type, `qmltyperegistrar` emits an include using the
header's **basename only** — never the path you listed in `target_sources()`:

```cpp
#if __has_include(<DesignTokens.h>)
#  include <DesignTokens.h>
#endif
```

With an `include/smarton/<layer>/Name.h` layout the basename is not on the
include path, so `__has_include` is **false**, the include is silently dropped,
and the generated file fails with "use of undeclared identifier" — pointing at
the registration call rather than at the missing include. There is no "file not
found" anywhere in the output, which is what makes it hard to diagnose.

Two ways out:

1. **Flat forwarding headers** — duplicate every registered header directly
   under `include/`. Works, but doubles the header count and the copies drift.
2. **Put each leaf directory on the include path** — what this project does.
   `st_add_qml_module()` calls `st_add_header_dirs_for_registrar()`, which globs
   `include/**/*.h` and adds each containing directory **PRIVATE**. Only the
   target's own generated file sees the short names; every other translation
   unit still includes the fully qualified `<smarton/backend/theme/...>`
   path.

It is applied automatically, so a new module never has to remember it.

## 5. Data flow

```
SimulatedReadingSource      MonitoringService      DashboardViewModel        QML
    (infrastructure)            (services)              (models)
         │                          │                       │                 │
         │ readingsChanged          │                       │                 │
         ├─────────────────────────>│                       │                 │
         │                          │ readingsUpdated       │                 │
         │                          ├──────────────────────>│                 │
         │                          │                       │ diff rows       │
         │                          │                       │ dataChanged     │
         │                          │                       ├────────────────>│ delegates
         │                          │                       │                 │ update in place
         │                          │ overallSeverityChanged│                 │
         │                          ├──────────────────────>│ (only on change)│
         │                          │                       ├────────────────>│ pill re-evaluates
```

## 6. Threading

Everything runs on the GUI thread; the data rate is trivial. When a real
transport arrives: decode off the GUI thread, marshal finished values across
with a queued connection, keep models GUI-thread-only. Never touch a model
from a worker thread.

## 7. Performance notes

- `Canvas` in `StNavIcon` and `StTextField` repaints only on the properties the
  drawing reads (`onNameChanged`, `onStrokeChanged`, `onDrawCrossedChanged`).
- Model updates are incremental (ADR-0003); delegates persist.
- No `clip: true` anywhere — it breaks scene graph batching.
- `Image` sets `sourceSize` everywhere: a texture larger than the item wastes
  GPU memory, which is the scarce resource on the panel.
- Sidebar icons are drawn, not shipped: no asset to scale, no atlas pressure.

## 8. Known limitations

- `SimulatedReadingSource` is a simulator, not a transport.
- Accounts persist; nothing else does. Spaces, rooms and devices have no
  storage yet — the schema grows when those screens land.
- Verifying a password blocks the GUI thread for ~200 ms by design. See the
  comment in `AuthViewModel::signIn` before moving it to a worker thread: the
  SQLite connection is thread-affine, so the repository has to move with it.
- Provider sign-in is rendered but disabled (ADR-0007); the verification code
  screen has no mail transport behind it.
- Row diffing is O(rows) — right for tens, wrong for thousands.
- `ui/Render/` does not exist yet; a C++ `QQuickItem` scene-graph module for
  waveform rendering would go there, between `Helpers` and `Controls`.
