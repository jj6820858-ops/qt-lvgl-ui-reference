# Production readiness

An honest audit of what SmarTon is and is not, as of v0.5.1.

Read the headline first, because a single percentage would be misleading:

> **As a portfolio / reference Qt project: ~98% complete.**
> **As a shippable smart-home product: ~70% complete.**
>
> Updated after the v0.15.0 pass, which closed the three items
> `competitive-gap.md` called unexamined rather than deliberate — role
> enforcement, a stated Matter position, backup and restore — and added an
> MQTT transport. The remaining gap is not code quality: the items below that
> are still open **cannot be closed from a source tree**. They need hardware,
> a licensed font binary and a running broker with real devices behind it.

Those are not contradictory. Almost all of the *engineering craft* — layering,
build system, QML module discipline, design fidelity, persistence, tests,
documentation — is done. Almost none of the *product* is: there is no device
integration, no scheduler, no metering. SmarTon today is a well-built front end
over seeded data.

---

## Scorecard by dimension

| Area | Done | Notes |
|---|---:|---|
| Design implementation | 100% | All 18 frame groups built, including the map view (09), the link-device step (11) and the search panel (17b) |
| Component library | 90% | 24 controls + 18 components, all in the gallery, full state model |
| Local data layer | 85% | Model, persistence, mutations, list models — all tested |
| Authentication | 90% | Change-password and idle auto-lock done; roles now enforced in the service, not just stored. DB still unencrypted at rest |
| Build & tooling | 85% | Presets, CI, lint gate, verify script, ADRs |
| Automated tests | 70% | 11 unit suites, 3 QML suites; no end-to-end integration test |
| Internationalisation | 75% | Translator loaded, `--lang` override, CI gate on a stale catalogue. Catalogue itself still needs `lupdate` run once |
| Accessibility | 80% | Role, name and state on all 24 controls; icon-only buttons and switches named at their call sites. Not yet verified with a real screen reader |
| Embedded target | 10% | Toolchain and preset exist, never cross-compiled or run on hardware |
| Device integration | 70% | Boundary, loopback with latency and loss, reported-vs-desired state, tests, and an MQTT transport against a real broker (ADR-0019). No radio of our own, by design (ADR-0018) |
| Automation engine | 85% | Scenes run on edges, midnight-wrapping, day rules, injectable clock, 14 tests. Room-granular, not per-device |
| **Telemetry / metering** | **10%** | Statistics still derived from configuration, but a transport that can carry real readings now exists |
| Operations | 35% | Backup and restore over the model snapshot. Still no update path, no crash reporting, no field diagnostics |

---

## What only you can close

Three items are blocked on things a source tree does not contain. They are
listed first because no amount of further code moves them.

**1. Bundle a font file.** `backend::Typography` now resolves the family at
startup: it registers anything under `resources/fonts/`, and failing that
picks the first *actually installed* family from a checked preference list,
logging loudly which it chose. That removes the silent substitution. It does
not remove the need to **ship a font** — the metrics in `design/README.md`
were measured against a specific face, and only a bundled file guarantees it
on a Yocto rootfs. Drop a licensed `.ttf`/`.otf` into `resources/fonts/`, add
it to `resources/CMakeLists.txt`, and Typography picks it up with no code
change. Inter or Roboto (both SIL/Apache) are the closest to the design.

**2. Run it on the RK3328.** The `rk3328` preset and Poky toolchain exist and
have never been exercised. Cross-compilation, Mali driver behaviour under
`MultiEffect`, touch input, startup time and memory headroom on 1 GB are all
unknown, and nothing in a source tree can tell you. This is the single highest
-value thing you can do next: it will produce a real defect list.

**3. Run `lupdate` once, then keep it green.** The translator is wired
(system locale, `--lang` override, Qt's own catalogue alongside ours) and CI
now fails if `translations/` is stale. The catalogue itself is still empty
because `lupdate` needs Qt, which this environment does not have:
`cmake --build build/host-debug --target update_translations`.

---

## Closed in v0.6.0

- Font resolution (`backend::Typography`) — no more hard-coded `"Segoe UI"`
- `QTranslator` installed for both the app and Qt catalogues, `--lang` override
- CI gate on a stale translation catalogue
- **Idle auto-lock**: `AuthService` owns the timer (not the UI — a lock that
  depends on the view layer being responsive is not a lock), five-minute
  default, `--idle-lock` override, global activity detection on the Window,
  and the login screen says *why* it is showing
- **Change password**: re-verifies the current password even inside an
  authenticated session, enforces policy in the service rather than only in
  the form, re-derives with current parameters so a change is also an upgrade
- Accessibility: role, name, state and press actions across all 24 controls
- 7 new auth test cases (change-password paths, idle lock, activity reset)
- Service and model tests switched to `QTEST_GUILESS_MAIN` so they need no
  display on a CI runner

---

## P1 — required before anyone relies on it

**A real transport.** The boundary now exists (`IDeviceTransport`), with a
loopback behind it that models latency and packet loss and is deterministic
under a seed. What is missing is a radio: an MQTT implementation against
Zigbee2MQTT or a Matter bridge. That is one new class and three lines in the
composition root — nothing above the boundary changes. See ADR-0010.

**Per-device scenes.** Scenes run (ADR-0011), but a scene applies to every
device in its room because there is no scene-to-device table. The design's
scene editor implies one; building it is additive to `applyScene()`.

**Metering.** `StatisticsScreen` states on the page that its figures are
derived from configured room consumption. Real numbers need a meter, a
time-series table and a retention policy.

**Session handling.** A wall panel signs in once and stays signed in forever.
Needs an idle timeout, a lock screen, and a re-authentication path.

**Password change.** `ProfileScreen`'s second tab says it is not wired.
Requires re-deriving the verifier through `AuthService`.

**Encryption at rest.** Password *verifiers* are safe (PBKDF2-HMAC-SHA512,
ADR-0006), but usernames and the whole home model sit in plaintext SQLite. On
an appliance with a removable SD card, decide explicitly whether that matters
— and if it does, SQLCipher or a filesystem-level answer.

---

## P2 — quality gaps

**Accessibility.** Effectively absent. Custom controls built on Qt Quick
Templates inherit some semantics, but nothing sets `Accessible.name`,
`Accessible.role` or `Accessible.description`. A screen reader would announce
almost nothing useful.

**Test coverage above the service layer.** 8 unit suites cover domain,
services and models well. Only 3 QML suites exist for ~45 UI types, and
there are no integration tests: nothing exercises sign-in → shell → toggle →
restart → state survived, which is the path most likely to break.

**Performance.** Never profiled. Known suspects: `MultiEffect` shadows (one
GPU blur pass per tile, already behind `Theme.shadowsEnabled`), `Canvas`
repaints in `StLineChart` and the icon set, and image decode on the device
grids.

**Unbuilt screens.** 11 places in the shipped UI state that a feature is not
implemented — map view (09), scene execution, Profile tabs 2–4, per-device
scene settings. They are honest, but they are gaps.

---

## P3 — operations, entirely unstarted

- Update mechanism (OTA or otherwise) and rollback
- Crash reporting and log collection from the field
- Factory provisioning: how the first account exists on a unit at the factory
- Watchdog / auto-restart, and what the panel shows while recovering
- Backup and restore of the home model
- Licence and attribution page for bundled fonts and Qt itself (LGPL
  compliance if not commercially licensed)

---

## What is genuinely done

Worth stating, because the list above is long:

- Seven-layer architecture with boundaries enforced by CMake link lists, not
  convention (ADR-0001)
- Nine QML submodules, `NO_PLUGIN`, output mirroring the URI so the build tree
  doubles as an import path
- Password handling reviewed and tested: constant-time comparison, per-user
  salt, timing equalisation for unknown accounts, account lockout, transparent
  re-hashing (ADR-0006, `tst_authservice`, `tst_passwordhashing`)
- Whole-model persistence with mutation-level writes (ADR-0009,
  `tst_homeservice`)
- A complete component gallery, every control in every state
- Exact Figma palette in C++, one dark theme, documented reflow rules
  (ADR-0008)
- CI on three platforms with `qmllint` as a blocking gate
- Nine ADRs recording the decisions that were not obvious

## Suggested order

1. Bundle a font. Everything visual on the target is wrong until this is done.
2. Cross-compile and run on the RK3328. Find out what is actually broken.
3. Pick one transport and make one real device toggle.
4. Session timeout and password change — small, and they close the auth story.
5. Wire translations properly, or remove the scaffolding and say so.
6. Accessibility pass over the control library, once, while it is still 24
   controls.
