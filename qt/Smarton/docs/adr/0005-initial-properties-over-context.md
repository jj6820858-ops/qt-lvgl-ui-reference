# 5. setInitialProperties over setContextProperty

Status: Accepted

## Context

The usual way to hand a C++ object to QML is
`engine.rootContext()->setContextProperty("viewModel", &vm)`. It works, and
almost every Qt tutorial shows it.

It also creates an **unqualified** name in QML. `.qmllint.ini` sets
`UnqualifiedAccess=error`, so the project's own lint gate would reject the
pattern the project itself used. Beyond consistency, context properties defeat
the QML compiler: the type is unknown at compile time, so every access is a
runtime lookup.

## Decision

The root object declares what it needs:

```qml
Window {
    required property var dashboardViewModel
}
```

and C++ injects it at load:

```cpp
engine.setInitialProperties({
    { QStringLiteral("dashboardViewModel"), QVariant::fromValue(&dashboard) }
});
engine.loadFromModule("SmarTon.App", "Main");
```

## Consequences

+ Qualified access throughout; `qmllint` passes with no exemptions.
+ A missing dependency fails loudly at load, not silently at first use.
+ Screens can be instantiated in tests and in the gallery with a stub view
  model, because the dependency is a property rather than global state.
− Every intermediate component must pass the object down explicitly. That is
  more typing, and it is also the reason the components stay reusable.
