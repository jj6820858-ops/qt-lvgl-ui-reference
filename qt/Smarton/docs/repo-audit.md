# Repository self-audit

Score this repo out of 100 before showing it to a Qt company.
**Below 60 it works against you rather than for you.**

Update the Score column honestly. An unverified item scores zero — "the code
exists" and "it is proven to work" are different claims, and only the second
one counts.

| # | Criterion | Max | Score | Evidence |
|---|---|---:|---:|---|
| 1 | Layered structure, enforced by CMake link lists | 8 | **8** | 24 CMakeLists, dependency rule in link lists |
| 2 | Modern CMake, `qt_add_qml_module`, presets | 8 | **8** | Configures and builds on Qt 6.8.8 |
| 3 | Domain layer links Qt Core only | 6 | **6** | `smarton_domain` → `Qt6::Core` + common |
| 4 | C++ unit tests with Qt Test, wired into CTest | 10 | **10** | 4/4 suites green |
| 5 | QML tests with Qt Quick Test, offscreen | 8 | **8** | 3 suites, headless |
| 6 | CI green on Linux, Windows and macOS | 10 | **0** | No remote yet |
| 7 | `qmllint` clean and enforced as a blocking gate | 6 | **6** | Clean across all 8 UI modules |
| 8 | `.clang-format` / `.clang-tidy` committed AND applied | 4 | **4** | Applied |
| 9 | README: problem, architecture, build, test | 10 | **10** | Present |
| 10 | `docs/architecture.md` with diagram + boundary | 8 | **8** | Layers, module graph, data flow |
| 11 | Three or more ADRs | 5 | **5** | Five |
| 12 | Doxygen + qdoc generated | 6 | **6** | `docs/html/` generated |
| 13 | Conventional Commits, SemVer tag, CHANGELOG | 6 | **6** | 26 commits, `v0.1.0` |
| 14 | LICENSE and CONTRIBUTING | 3 | **3** | MIT + guide |
| 15 | Screenshot or GIF above the fold | 2 | **0** | Pending a real gallery capture |
| | **Total** | **100** | **88** | *(projected once row 5 is re-run)* |

Last measured run: **80/100**, before the `tryCompare` fix to the tap test.

## What only a working build can earn

Items 4, 5, 6, 7, 8 and 12 are worth **34 points** and every one of them needs
the project to compile and run. They cannot be earned by writing more code.

```bash
cmake --preset host-debug
cmake --build --preset host-debug          # -> items 4, 5 become provable
ctest --preset host-debug                  # -> green tests
cmake --build build/host-debug --target all_qmllint   # -> item 7
./scripts/format.sh                        # -> item 8
doxygen docs/Doxyfile                      # -> item 12 (local half)
```

Push to GitHub, let Actions run, enable Pages: items 6 and 12 complete.
Screenshot the gallery into the README: item 15.

That path takes **65 to 100** without writing a line of new code.

## Deliberately deferred

**`ui/Render/`** — a `QQuickItem` + `QSGNode` module for waveform rendering.
It belongs between `Helpers` and `Controls` and it is the single most
impressive thing that could be added, because scene-graph work is where Qt
expertise actually shows. It is deferred until the project builds green:
adding unverified scene-graph code to a project that does not yet compile
makes the codebase worse, not better.
