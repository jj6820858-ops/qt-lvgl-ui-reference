# SmarTon

A smart-home control application for a **Waveshare 7" (1024 × 600) panel**,
built with Qt 6.8 LTS and QML. Local accounts in SQLite, PBKDF2-HMAC-SHA512
password verification, and a UI built to a Figma design set that ships with the
repository.

It is also a working reference for how a Qt project is put together: nine QML
submodules, seven C++ layers, a component gallery, two test frameworks, ADRs
for the decisions that were not obvious, and a one-command verification
scorecard. Structure and documentation are part of the deliverable, not
paperwork bolted on afterwards.

| | |
|---|---|
| Target | Waveshare 7", 1024 × 600, Rockchip RK3328, Embedded Linux |
| Also runs on | macOS, Windows, desktop Linux |
| Design source | `design/screens/` + [`design/README.md`](design/README.md) |
| Theme | One dark theme. No light variant, no runtime switch. |

## Requirements

Qt **6.8 LTS** (Core, Gui, Qml, Quick, QuickControls2, **Sql**, **Network**,
Test, QuickTest) ·
CMake **3.28+** · Ninja · a C++20 compiler

## Build

```bash
cmake --preset host-debug
cmake --build --preset host-debug
```

Presets: `host-debug`, `host-release`, `ci`, `rk3328`.
In-source builds are refused by design.

## First run

There is **no default account and no default password**. A shipped default
credential is the most common way an embedded product gets owned, so the app
refuses to invent one. Create the first administrator explicitly:

```bash
# macOS builds a bundle; the binary is inside it
BIN=./build/host-debug/bin/smarton.app/Contents/MacOS/smarton   # macOS
BIN=./build/host-debug/bin/smarton                              # Linux / Windows

$BIN --create-account admin
```

It prompts twice on the terminal with echo off. The password is never taken on
the command line — `ps` shows every process's arguments — and never stored: it
is hashed with PBKDF2-HMAC-SHA512, 210,000 iterations, per-user 16-byte random
salt. Policy: 8+ characters, upper and lower case, and a digit or symbol.
See [ADR-0006](docs/adr/0006-password-hashing.md).

Then run normally, from a terminal, from Qt Creator, or by double-clicking:

```bash
$BIN
$BIN --database /tmp/scratch.db     # throwaway store
```

For an unattended first boot on the panel, where nobody is at a terminal, the
same provisioning happens from the environment:

```bash
SMARTON_BOOTSTRAP_PASSWORD='...' SMARTON_BOOTSTRAP_USER='admin' $BIN
```

> Environment variables are **not** passed on by Qt Creator's Run button or by
> double-clicking a macOS `.app`. If you launch either of those ways, use
> `--create-account` from a terminal first. An unprovisioned app says so on the
> login screen rather than claiming your password is wrong.

The database lives in the per-user application-data location — not next to the
binary, where it would end up inside the build tree and then inside a commit.
On macOS that is `~/Library/Application Support/SmarTon/SmarTon/accounts.db`;
delete it to start over.

## Test

```bash
ctest --preset host-debug                 # everything
ctest --preset host-debug -R reading      # one suite
./build/host-debug/bin/tst_qml -functions # list QML test functions
```

## Component gallery

```bash
./build/host-debug/bin/smarton_gallery
```

Renders every control in isolation, in every state that matters: buttons in
all four variants plus disabled, text fields empty / filled / masked / in
error, the password-rule list at 0, 1, 2 and 3 rules met, and the provider
buttons in the disabled state [ADR-0007](docs/adr/0007-social-login-disabled.md)
requires. A control is not finished until it appears here.

## Verify everything at once

```bash
./scripts/verify.sh
```

Configures, builds, runs both test frameworks, runs `qmllint`, checks
formatting, generates docs, inspects git hygiene — then prints a scorecard out
of 100 and exits non-zero below 95. Every row is scored from an actual result,
never from a file existing. See [docs/verification.md](docs/verification.md).

## Lint and format

```bash
./scripts/lint.sh      # clang-format check + qmllint + ctest
./scripts/format.sh    # clang-format + qmlformat, in place
```

`qmllint` treats unqualified property access as an **error**.

## Embedded target

```bash
source /opt/poky/<version>/environment-setup-aarch64-poky-linux
cmake --preset rk3328
cmake --build --preset rk3328
BOARD=192.168.1.42 ./scripts/deploy-to-board.sh
```

For an appliance deployment, configure the root-owned MQTT environment file
instead of passing broker credentials on the command line:

```bash
sudo install -d -m 0700 /etc/smarton
sudo install -m 0600 packaging/smarton.env.example /etc/smarton/smarton.env
sudoedit /etc/smarton/smarton.env
sudo systemctl restart smarton
```

See [the production runbook](docs/production-runbook.md) before connecting a
real relay, lock, valve, or HVAC appliance.

Create a privacy-safe board diagnostics bundle when investigating an issue:

```bash
./scripts/collect-support-bundle.sh
```

## Structure

```
common/          vocabulary types            Qt Core only, header-only
core/            framework primitives        RingBuffer
domain/          entities and value objects  User, PasswordHash, Reading, Range
services/        orchestration and rules     AuthService, IUserRepository,
                                             IPasswordHasher, MonitoringService
infrastructure/  the outside world           SqliteUserRepository,
                                             Pbkdf2PasswordHasher, simulator
models/          view models   -> SmarTon.Models     ← QML/C++ boundary
                                             AuthViewModel, DashboardViewModel
backend/         design tokens -> SmarTon.Backend    exact Figma hex
ui/              QML submodules -> SmarTon.Ui.*
  Theme/         design tokens singleton
  Helpers/       pure JS: Formatters, Geometry
  Controls/      atoms: StLabel StButton StTextField StCheckBox StOtpField
                 StLinkButton StSocialButton StPasswordRules
  Layouts/       StPage, StAuthPage
  Components/    molecules: StDivider, StEmptyState
  Navigation/    Routes (singleton), StNavIcon, StSidebar
  Dialogs/       StConfirmDialog
  Screens/       Splash Welcome Login VerifyCode ResetPassword Spaces Shell
resources/       bundled artwork, icons, config, fonts
design/          Figma exports + the measured palette (design/README.md)
app/             executable, composition root
gallery/         component gallery executable
tests/unit/      Qt Test        — domain, services, models
tests/qml/       Qt Quick Test  — controls and layouts, headless
cmake/           reusable modules + aarch64 toolchain
scripts/         rename, format, lint, deploy
docs/            architecture, guidelines, ADRs, Doxyfile
```

Each C++ layer keeps public headers under `include/smarton/<layer>/`, so
they are included as `<smarton/domain/entities/Reading.h>` from anywhere.
That is not decoration — see the qmltyperegistrar note in
[docs/architecture.md](docs/architecture.md#4-the-qmlc-boundary).

## Navigation

Two `StackView`s, answering two different questions.

| Stack | Lives in | Moves between | Verb |
|---|---|---|---|
| Flow | `app/Main.qml` | splash → welcome → login → shell | `replace` |
| Shell | `ui/Screens/ShellScreen.qml` | the five sidebar destinations | `replace` |
| Shell | same | drill-downs (room → device) | `push` / `pop` |

Signing in **replaces** rather than pushes, so there is no back path from
inside the app to a login form still holding a password; logging out replaces
in the other direction so the shell and its view state are destroyed rather
than left resident. Sidebar destinations are siblings, so "back" between them
is meaningless — they replace too. Only a genuine drill-down pushes, which is
what makes Escape and a header back arrow mean exactly one level.

Screens push **route constants** from `Routes` (a QML singleton), never file
paths, so a renamed screen breaks in one place instead of everywhere.

## The dependency rule

Every layer above depends only on layers below it. Enforced by CMake target
link lists, not by convention. `ui/CMakeLists.txt` adds the QML submodules in
dependency order, and a module may import only modules listed above it there.

**Only `SmarTon.Ui.Screens` may import `SmarTon.Models`.** Controls and
Components know nothing about the application — which is exactly what lets the
gallery render them standalone.

## Documentation

- [Architecture](docs/architecture.md) — layers, module graph, QML/C++ boundary, data flow
- [Coding guidelines](docs/coding-guidelines.md) — QML and C++ rules, and which are tool-enforced
- [Testing strategy](docs/testing-strategy.md) — what we test and what we deliberately don't
- [Performance guidelines](docs/performance-guidelines.md) — ordered by real-world frequency
- [Decision records](docs/adr/) — why things are the way they are
- [QML catalog](docs/generated/QmlCatalog.md) — generated, `--target st_qml_catalog`

## Licence

MIT — see [LICENSE](LICENSE).
