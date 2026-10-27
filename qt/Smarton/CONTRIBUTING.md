# Contributing

## Setup

```bash
cmake --preset host-debug
cmake --build --preset host-debug
ctest --preset host-debug
```

## Where does my code go?

| It is… | It belongs in |
|---|---|
| A type both UI and logic need | `common/` |
| A data structure with no domain meaning | `core/` |
| A business entity or value object | `domain/` |
| A rule about how entities interact | `services/` |
| Anything touching hardware, network or disk | `infrastructure/` |
| Something QML binds to | `models/` |
| A colour, metric or brand value | `backend/` then `ui/Theme` |
| A visual atom with no app knowledge | `ui/Controls/` |
| Two or more atoms combined | `ui/Components/` |
| A whole page | `ui/Screens/` |

If a thing seems to belong in two layers, it belongs in the lower one.

## Branching and commits

Trunk-based. `main` always builds and passes tests. Feature branches live days.

[Conventional Commits](https://www.conventionalcommits.org/):

```
feat(controls): add tick marks to StGaugeDial
fix(models): guard overallSeverity against redundant emission
perf(controls): repaint Canvas only on tone change
test(services): cover detach path
docs(adr): record the submodule split
build(cmake): add aarch64 cross-compile preset
ci: make qmllint a blocking gate
```

Body explains **what and why**. The diff shows how.

## Before opening a pull request

- [ ] `./scripts/lint.sh` passes
- [ ] New behaviour has a test; every fixed bug has a regression test
- [ ] New QML types appear in the gallery
- [ ] `cmake --build … --target st_qml_catalog` re-run if types changed
- [ ] Public C++ has Doxygen comments; public QML has qdoc comments
- [ ] An ADR added if an architectural decision changed
- [ ] `CHANGELOG.md` updated under `[Unreleased]`

## Review standards

Reviewers check, in order: does it belong in this layer; is the `NOTIFY`
emission guarded; is there a test; does `qmllint` pass; is the public API
documented; does the QML module import only modules above it.

## Releasing

1. Move `[Unreleased]` into a version heading in `CHANGELOG.md`
2. Bump `VERSION` in the root `CMakeLists.txt`
3. `git tag -a v1.2.0 -m "Release 1.2.0"`
4. `git push --follow-tags`
