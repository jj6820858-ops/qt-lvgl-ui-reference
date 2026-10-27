# Build notes — Qt 6.8 traps encountered

Six real failures hit while bringing this template up against Qt 6.8.8 on
macOS. Each is recorded with the symptom, the actual cause, and the fix,
because in every case the error message pointed somewhere other than the bug.

---

## 1. `qmltyperegistrar` emits the header BASENAME

**Symptom**
```
smarton_backend_qmltyperegistrations.cpp:23:34:
error: use of undeclared identifier 'smarton'
    qmlRegisterTypesAndRevisions<smarton::backend::DesignTokens>(...)
```

**Cause** — For every `QML_ELEMENT` type the generated file contains:
```cpp
#if __has_include(<DesignTokens.h>)
#  include <DesignTokens.h>
#endif
```
It always uses the **basename**, never the path given to `target_sources()`.
With an `include/<ns>/<layer>/Name.h` layout the basename is not on the include
path, `__has_include` is false, and the include is **silently dropped**. There
is no "file not found" anywhere — only an undeclared identifier at the
registration call.

**Fix** — `st_add_header_dirs_for_registrar()` in
`cmake/SmarTonQmlModule.cmake` globs `include/**/*.h` and adds each
containing directory **PRIVATE**. Called automatically by
`st_add_qml_module()`, so no module has to remember it.

**Alternative seen in the wild** — flat forwarding headers duplicated directly
under `include/`. Works, but doubles the header count and the copies drift.

---

## 2. An XML comment may not contain a double hyphen

**Symptom**
```
lrelease error: Parse error at translations/smarton_en.ts:5:29:
Expected '>', but got '[a-zA-Z]'.
```

**Cause** — The `.ts` file carried this inside `<!-- -->`:
```
Regenerate with:  cmake --build <dir> --target update_translations
                        ^^ column 27
```
XML terminates a comment at `--`, so the parser expected `>` and found `b`.
Column 29 is the `b` of `build`. The `<dir>` further along was a red herring.

**Fix** — never put a command line with long options inside an XML comment.

---

## 3. `qt_add_translations()` needs the LinguistTools package

**Symptom**
```
CMake Error at translations/CMakeLists.txt:5 (qt_add_translations):
  Unknown CMake command "qt_add_translations".
```

**Fix** — `find_package(Qt6 COMPONENTS LinguistTools)`. Requested `QUIET` and
guarded, because minimal and cross-compiled Qt installs frequently ship
without the host tools and a missing translator should not fail the build.

---

## 4. `on` + capital letter is a signal handler, not a property

**Symptom**
```
Main.qml:19:5: Type DashboardScreen unavailable
  DashboardScreen.qml:37:13: Type StatusPill unavailable
    StatusPill.qml: Type Theme unavailable
      Theme.qml:20:29: Cannot assign a value to a signal
```

**Cause** — `readonly property color onBackground: "#E6EEF1"` is parsed as a
handler for a signal named `background`. Material Design token names
(`onBackground`, `onSurface`, `onPrimary`, `onError`) are all unusable as QML
property names.

**Fix** — `textPrimary` / `textSecondary`.

**The wider lesson** — one broken singleton produced four errors. **Read QML
error stacks bottom-up**; the last line is the cause, the first is only where
the cascade surfaced.

---

## 5. `setContextProperty` contradicts `UnqualifiedAccess=error`

A context property is an unqualified lookup in QML, so the project's own lint
gate would have rejected the pattern the project used. It also defeats the QML
compiler — the type is unknown at compile time.

**Fix** — `engine.setInitialProperties()` plus `required property var …` on the
root object. See ADR-0005.

---

## 6. `label: label` on a delegate is a self-referential binding

`StGaugeDial` already declares `label`, `value`, `minimum`, `maximum`,
`severity`. Redeclaring them as `required property` in the delegate is a
duplicate-property error, and `label: label` refers to itself.

**Fix** — `required property var model`, then `label: model.label`. Keeps
bindings qualified, satisfies qmllint, and a renamed role fails loudly at load.

---

## 7. `mouseClick()` does not reliably trigger a `TapHandler`

**Symptom**
```
FAIL!  : StGaugeDial::test_emitsActivatedOnTap() Compared values are not the same
   Actual   (): 0
   Expected (): 1
```

**Cause** — `TestCase::mouseClick()` sends press and release with the same
timestamp. `TapHandler` is a pointer handler with its own event-point state
machine and does not reliably recognise a zero-duration press. The control is
fine; the test was wrong.

**Fix** — drive the two events separately and wait for delivery rather than
asserting synchronously:

```qml
mousePress(dial, dial.width / 2, dial.height / 2)
mouseRelease(dial, dial.width / 2, dial.height / 2)
spy.wait(1000)
compare(spy.count, 1)
```

Also assert the preconditions (`dial.width > 0`, `spy.valid`) so a future
failure names the broken assumption instead of printing `0 != 1`.

**Then it failed again**, with a different message:

```
FAIL!  : StGaugeDial::test_emitsActivatedOnTap()
         'wait for signal activated' returned FALSE. ()
```

That is a *different* failure and it exonerates the control. `SignalSpy.wait()`
blocks until the signal is emitted **after** the call. Once press and release
were separated the tap fired synchronously inside `mouseRelease()`, so by the
time `wait()` ran the signal had already arrived — and it timed out waiting for
a second one.

**Correct fix** — poll the accumulated count instead of blocking for a new
emission:

```qml
tryCompare(spy, "count", 1, 1000);
```

**The general rule:** `spy.wait()` is for a signal you expect *later*.
`tryCompare(spy, "count", n)` is for "this should have happened by now" — it
succeeds immediately if the count is already right. Reaching for `wait()` when
you mean `tryCompare()` produces a passing control that looks broken.

Three attempts, three different causes, and only the first was real:
`mouseClick` genuinely does not drive a `TapHandler`; the other two were the
test harness being used wrongly.

---

## 8. A copied `CMakeLists.txt.user` hijacks the new project's build directory

**Symptom**
```
The source ".../SmarTon/CMakeLists.txt" does not match the source
".../caseStudy/CMakeLists.txt" used to generate cache.
Re-run cmake with a different source directory.
```

**Cause** — `CMakeLists.txt.user` is Qt Creator's per-project state and it
records an **absolute build path**. Copying a project directory carries it
along, so Qt Creator opens the new project and tries to build it into the
*original* project's build tree. CMake sees a cache generated from a different
source directory and refuses.

`.gitignore` lists the file, but a `cp`/`tar` copy does not read `.gitignore` -
only git does.

**Fix** — delete it and reopen the project:

```bash
rm -f CMakeLists.txt.user*
rm -rf build/
```

Exclude it when copying, and `scripts/rename-project.sh` now refuses to run
when it finds one:

```bash
tar -cf - -C <template> --exclude='./build' --exclude='./docs/html' \
      --exclude='./.git' --exclude='./CMakeLists.txt.user*' \
      --exclude='./.qtcreator' . | tar -xf - -C <destination>
```

**The general lesson** — IDE state is not source. Anything holding an absolute
path (`CMakeLists.txt.user`, `.qtcreator/`, `.vscode/settings.json`,
`compile_commands.json`) must never travel with a copied project.

---

## Still expected

`all_qmllint` has never been run. Expect findings — most likely around the
`Canvas` block in `StGaugeDial` and the `T.Overlay` usage in
`StConfirmDialog`. That is the gate doing its job, not a defect.
