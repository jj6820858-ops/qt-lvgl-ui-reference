# Coding guidelines

Based on Qt's official
[QML Coding Conventions](https://doc.qt.io/qt-6/qml-codingconventions.html) and
[Qt Quick Best Practices](https://doc.qt.io/qt-6/qtquick-bestpractices.html).
Where a rule can be enforced by a tool, it is — see `.qmllint.ini`.

## QML

### Attribute order

Inside every object, separated by blank lines:

1. `id`
2. property declarations
3. signal declarations
4. JavaScript functions
5. object properties
6. child objects

### Rules

| Rule | Enforcement |
|---|---|
| No unqualified access — always go through an `id` | `qmllint` **error** |
| Typed properties; never `property var` for a known type | review |
| `required property` for external data | review |
| Group notation when using several properties of a group | review |
| Named signal handler parameters: `onSelected: index => …` | review |
| Type annotations on functions: `function f(x: int): color` | review |
| Every user-facing string in `qsTr()` | review |
| No deprecated properties | `qmllint` **error** |

### Property naming trap: the `on` prefix

Never name a property `on` + a capital letter. QML parses `onFoo:` as a
**signal handler** for a signal called `foo`:

```qml
readonly property color onBackground: "#E6EEF1"
// Theme.qml:20:29: Cannot assign a value to a signal (expecting a script to be run)
```

This catches anyone importing Material Design token names — `onBackground`,
`onSurface`, `onPrimary`, `onError` are all unusable. Use `textPrimary`,
`textSecondary`, `textOnAccent`.

Worse, the failure **cascades**: the singleton fails to load, so every type
importing it reports "Type Theme unavailable" and the real error is the last
line of the output. **Read QML error stacks bottom-up.**

### Why unqualified access is an error, not a warning

`width: itemWidth` forces a scope-chain lookup at every evaluation and defeats
the QML compiler. `width: root.itemWidth` resolves once. On an embedded GPU
that is the difference between 60 fps and visible stutter.

### Module discipline

- A QML module may import only modules listed **above** it in
  `ui/CMakeLists.txt`.
- Controls and Components never import `SmarTon.Models`. If a control
  needs application data, it takes a property.
- Prefix reusable QML types with `St` (`StButton`, `StTextField`) so an
  application type is never mistaken for a library type in a diff.
- Pure-QML modules use `NO_PLUGIN` — no plugin means no plugin to deploy.

## Qt Quick best practices we follow

- Use existing Qt Quick Controls before writing a custom control. `StButton`
  derives from `T.Button` and inherits focus, keyboard and accessibility.
- Declarative bindings over imperative assignment in handlers.
- State lives in the model, never in a delegate — delegates are created and
  destroyed constantly.
- Prefer explicit interaction signals (`moved`) over value signals
  (`valueChanged`) to avoid cascades.
- Do not customise the native Windows/macOS styles. We set `Basic` and theme
  that instead.
- Scale with anchors and Layouts, never fixed pixel sizes.
- Bundle assets through the resource system.

## C++

- **C++20.** Rule of zero; `= default` and `= delete` explicitly.
- **`const` correctness** everywhere, `[[nodiscard]]` on pure accessors.
- **Ownership:** Qt parent-child for `QObject`s, values elsewhere. Never both
  for the same object.
- **New-style `connect` only.** `SIGNAL()`/`SLOT()` are banned — they fail at
  runtime rather than compile time.
- **`QStringLiteral`** for string constants; `QByteArrayLiteral` for role names.
- **Guard every `NOTIFY` emission** with an equality check.
- **Namespaces mirror directories:** `smarton::domain`,
  `smarton::services`, `smarton::models`.
- **Public headers** live in `include/smarton/<layer>/` and are included
  angle-bracketed. This is load-bearing for QML type registration — see
  architecture.md.
- **Includes:** own header first, then project, then Qt, then standard library.

## Naming

| Kind | Style | Example |
|---|---|---|
| C++ class | PascalCase | `ReadingListModel` |
| C++ member | `m_` + camelCase | `m_overallSeverity` |
| C++ namespace | lowercase | `smarton::domain` |
| CMake target | snake_case | `smarton_ui_controls` |
| CMake alias | Namespaced | `SmarTonUi::controls` |
| QML module | Dotted PascalCase | `SmarTon.Ui.Controls` |
| QML type | `St` + PascalCase | `StTextField` |
| QML property | camelCase | `overallSeverity` |
| Test function | behaviour phrase | `identicalUpdateEmitsNothing()` |
