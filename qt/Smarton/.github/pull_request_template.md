## What and why

<!-- What changed and the reason. The diff already shows how. -->

## Layer

<!-- Which layer(s) does this touch, and does it respect the dependency rule? -->

## Checklist

- [ ] `./scripts/lint.sh` passes
- [ ] CI green on Linux, Windows and macOS
- [ ] New behaviour has a test; fixed bugs have a regression test
- [ ] New QML types are in the gallery
- [ ] QML modules import only modules above them in `ui/CMakeLists.txt`
- [ ] Public C++ documented for Doxygen; public QML documented for qdoc
- [ ] ADR added if an architectural decision changed
- [ ] CHANGELOG.md updated

## Verification

<!-- Test names, profiler numbers, target hardware. -->
