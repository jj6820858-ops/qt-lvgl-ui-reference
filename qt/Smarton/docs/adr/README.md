# Architecture Decision Records

One file per significant decision. Numbered, immutable once accepted. If a
decision is reversed, add a **new** ADR that supersedes it — never edit history.

Four headings: Context, Decision, Consequences, Status. Half a page each. If it
takes longer, the decision needs splitting.

| # | Decision | Status |
|---|---|---|
| [0001](0001-layer-boundaries.md) | Enforce layer boundaries with CMake link lists | Accepted |
| [0002](0002-clamp-instead-of-reject.md) | Clamp out-of-range values instead of rejecting | Accepted |
| [0003](0003-incremental-model-updates.md) | Incremental model updates over full reset | Accepted |
| [0004](0004-qml-submodules.md) | Split the UI into SmarTon.Ui.* submodules | Accepted |
| [0005](0005-initial-properties-over-context.md) | setInitialProperties over setContextProperty | Accepted |
| [0006](0006-password-hashing.md) | PBKDF2-HMAC-SHA512 for password storage | Accepted |
| [0007](0007-social-login-disabled.md) | Provider sign-in buttons rendered but disabled | Accepted |
| [0008](0008-reflow-not-scale.md) | Reflow the design for the panel; do not scale it | Accepted |
| [0009](0009-home-model-snapshot.md) | Store the home model as one JSON snapshot | Accepted |
| [0010](0010-reported-state-over-optimistic-ui.md) | Show what devices report, not what the user asked for | Accepted |
| [0011](0011-scene-scheduling.md) | Scenes run on edges, and apply to a room | Accepted |
| [0012](0012-pluggable-sql-driver.md) | SQLite by default, any Qt SQL driver by configuration | Accepted |
| [0013](0013-svg-icon-set.md) | One SVG icon set, tinted at runtime | Accepted |
| [0014](0014-user-accent-derived-foreground.md) | One user-changeable colour, with its foreground derived | Accepted |
| [0015](0015-remembered-sessions.md) | Remembered sign-ins as rotating split tokens | Accepted |
| [0016](0016-generated-3d-floor-plan.md) | A generated, optional 3D floor plan | Accepted |
| [0017](0017-two-themes-and-render-tiers.md) | Two themes over one token layer, with render tiers | Accepted |
| [0018](0018-matter-and-thread-position.md) | Matter is the intended transport; Thread is not our radio | Accepted |
| [0019](0019-mqtt-transport.md) | MQTT as the first real transport, as an optional dependency | Accepted |
| [0020](0020-walk-through-the-model.md) | The 3D map is also somewhere you can stand | Accepted |
| [0021](0021-activity-log-composed-at-the-root.md) | The activity log is composed at the root, not written by the services | Accepted |
