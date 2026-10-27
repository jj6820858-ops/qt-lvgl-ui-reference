# 4. Split the UI into SmarTon.Ui.* submodules

Status: Accepted

## Context

One `qt_add_qml_module` for the whole UI is simpler to set up and works fine
until the UI has thirty types. Then: any file can use any other file, the
dependency graph becomes a mesh, "reusable" controls quietly reference
application singletons, and every UI change rebuilds everything.

## Decision

Eight modules, added in dependency order in `ui/CMakeLists.txt`:

```
Theme → Helpers → Controls → Layouts → Components → Navigation → Dialogs → Screens
```

A module may import only modules listed above it. **Only `Screens` may import
`SmarTon.Models`.** Each is a separate CMake target, so an import that
points the wrong way fails to link.

`st_add_qml_module()` mirrors each URI into `${CMAKE_BINARY_DIR}/qml/...`, and
that tree goes on `QML_IMPORT_PATH` so Qt Creator, `qmlls` and `qmllint`
resolve types without running the app.

## Consequences

+ Reuse is real: `Controls` and `Layouts` lift into the next project as-is.
+ The gallery can render every control, because no control needs the app.
+ Touching a screen does not rebuild the control library.
+ The module list is the architecture diagram, and it cannot drift.
− Eight `CMakeLists.txt` files instead of one.
− Adding a type means deciding which module it belongs in. That decision is
  the value, but it is not free.
− Pure-QML modules need `NO_PLUGIN` or you deploy eight pointless plugins.
