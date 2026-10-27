# Verification

Everything here is a claim the repository makes about itself. This document is
how those claims get proven, and `scripts/verify.sh` is the proof, automated.

```bash
./scripts/verify.sh
```

One command: configure, build, test, lint, format-check, generate docs, inspect
git hygiene, then print a scorecard out of 100 and exit non-zero below 95.

Every row is scored from an **actual result**. The presence of a test file
earns nothing; a passing test earns the points. This is deliberate — "the code
exists" and "it is proven to work" are different claims, and only the second
one is worth anything to a reviewer.

## Prerequisites

| Tool | Needed for | Install (macOS) |
|---|---|---|
| Qt 6.8 | everything | Qt online installer |
| CMake 3.28+, Ninja | build | `brew install cmake ninja` |
| clang-format | formatting row | ships with Xcode / `brew install clang-format` |
| doxygen, graphviz | docs row | `brew install doxygen graphviz` |

Without clang-format or doxygen the run still works; those rows score partial
and say why.

## The five steps, and what each one earns

### 1. Configure and build — gate for 34 points

```bash
cmake --preset host-debug
cmake --build --preset host-debug --parallel
```

Nothing below this line can score until the build is green. Six criteria worth
34 points depend on it, which is why a repository that has never compiled caps
out around 65.

Presets: `host-debug`, `host-release`, `ci` (warnings are errors), `rk3328`
(aarch64 cross-compile). In-source builds are refused.

### 2. Tests — 18 points

```bash
ctest --preset host-debug
```

Runs both frameworks through one runner:

- **Qt Test** — `domain`, `core`, `services`, `models`. Data-driven cases,
  `QSignalSpy` emission **counts**, `QAbstractItemModelTester` conformance.
- **Qt Quick Test** — controls and layouts, headless via `-platform offscreen`.

The tests that matter most assert that signals do **not** fire:
`identicalUpdateEmitsNothing`, `severityEmitsOnlyOnChange`. A redundant
`NOTIFY` re-evaluates every attached binding, and counting is the only way to
catch it.

Single suite: `ctest --preset host-debug -R readinglistmodel`
QML functions: `./build/host-debug/bin/tst_qml -functions`

### 3. qmllint — 6 points

```bash
cmake --build build/host-debug --target all_qmllint
```

The target is generated automatically by `qt_add_qml_module()`, so every one of
the eight `SmarTon.Ui.*` modules is covered without listing them.

`.qmllint.ini` promotes to **error**: `UnqualifiedAccess`, `DeprecatedProperty`,
`MissingProperty`, `MissingType`, `IncompatibleType`, `PropertyAliasCycles`.

`UnqualifiedAccess=error` is the one that matters. Unqualified access forces a
scope-chain lookup on every evaluation and defeats the QML compiler; on an
embedded GPU that is the difference between 60 fps and visible stutter.

Expect findings on the first run. That is the gate working.

### 4. Formatting — 4 points

```bash
./scripts/format.sh      # clang-format + qmlformat, in place
./scripts/lint.sh        # check-only, what CI runs
```

Committing `.clang-format` earns half. Applying it earns the rest.

### 5. Documentation — 6 points

```bash
cd docs && doxygen Doxyfile      # -> docs/html/
```

`EXTRACT_ALL = NO` and `WARN_IF_UNDOCUMENTED = YES` on purpose: undocumented
code should look undocumented. QML types carry qdoc comments and are indexed
by `cmake --build build/host-debug --target st_qml_catalog`.

Full credit needs a **live URL**. Push to GitHub and enable Pages — the
`docs.yml` workflow publishes on every push to `main`.

## The last two points

```bash
./scripts/capture-gallery.sh
```

Builds and runs the gallery, captures the window to `docs/images/gallery.png`,
and prints the markdown line to paste under the README title. More people will
judge the project on that image than will read the source.

## Getting to 100

| Step | Earns |
|---|---:|
| Build green | unlocks everything below |
| `ctest` passing | 18 |
| `all_qmllint` clean | 6 |
| `./scripts/format.sh` | 2 |
| `doxygen` locally | 3 |
| Push to GitHub, Actions green on 3 platforms | 10 |
| Enable Pages | 3 |
| `./scripts/capture-gallery.sh` + paste | 2 |

**65 → 100 without writing a line of new code.** Re-run `./scripts/verify.sh`
after each step and paste the final scorecard into `docs/repo-audit.md`.

## In CI

`ci.yml` runs the same gates on Linux, Windows and macOS. `verify.sh` is the
local mirror of that pipeline — if it passes on your machine, CI should agree.
