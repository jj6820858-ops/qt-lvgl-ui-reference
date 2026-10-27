# Testing strategy

## What we test, in priority order

1. **`domain/` and `core/`** — pure C++, no Qt Quick, milliseconds to run.
   Highest value per line of test code.
2. **`services/`** — orchestration and rules, driven by a stub `IReadingSource`.
   No hardware, no timers, no sleeping.
3. **`models/`** — role exposure, signal emission *counts*, incremental-update
   correctness, `QAbstractItemModelTester` conformance.
4. **`ui/Controls` and `ui/Layouts`** — property contracts and behaviour.
5. **Regression cases** — every fixed bug gets a test that fails without the fix.

## What we deliberately do NOT test

- **Pixel positions and appearance.** Brittle, and they prove almost nothing.
  The gallery covers visual review; a human looks at it.
- **Qt itself.** We do not test that `Behavior` animates.
- **Screens end to end.** Composition is verified in the gallery and by the
  components underneath being correct.

Stating what you do not test, and why, is as much a part of a strategy as a
coverage number.

## Frameworks

| Layer | Framework | Location |
|---|---|---|
| C++ | Qt Test | `tests/unit/tst_*.cpp` |
| QML | Qt Quick Test | `tests/qml/tst_*.qml` |
| Runner | CTest | `ctest --preset host-debug` |

QML tests are discovered by filename and run with `-platform offscreen`, so
they work on a headless CI runner.

## Conventions

- One test executable per class; `st_add_unit_test()` registers it with CTest.
- Prefer data-driven tests — `_data()` in C++, a returned array in QML.
- Use `QSignalSpy` to assert emission **counts**. Counting is what catches
  redundant emissions; merely checking a signal fired does not.
- Name tests after behaviour: `identicalUpdateEmitsNothing()`, not `test2()`.
- Never sleep. `SimulatedReadingSource::tick()` is public precisely so tests
  can step the simulation instead of waiting on a timer.

## Stubs over mocks

`tst_monitoringservice.cpp` defines a 20-line `StubSource` implementing
`IReadingSource`. No mocking framework. When a layer is small enough to stub by
hand, a hand-written stub is clearer and never goes stale.

## Coverage

Measured on the Linux GCC job with `--coverage` and `lcov`.

**Target: 70% on `domain/`, `services/` and `models/`.** We do not chase a
whole-project number — coverage of UI composition code is a vanity metric.
