# Changelog

[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) ·
[Semantic Versioning](https://semver.org/)

## [Unreleased]

### Added
- **More than one space.** `StSpacePicker` has had a `spaces` list property and
  a "+ Create a new space" row since it was written; every screen passed it
  nothing and nothing handled the action, so the dropdown showed one unchanging
  row and an action that did nothing. `HomeService` now keeps a list of spaces
  with the active one loaded into the fields it already had.
  - **One space is live at a time, and that is a position rather than a
    limitation.** A panel screwed to a wall controls the building it is screwed
    to; the second space is somewhere else, over a network its Zigbee mesh does
    not reach. Switching is looking at another house, not extending this one —
    which is why nothing that reads `rooms()` or `devices()` had to change.
  - **The migration is that the old shape is still a legal one.** A snapshot
    written before there could be two spaces *is* a single space's model, so it
    becomes the only entry in the array. No conversion pass, no version number,
    nothing to get wrong on the one run that does it.
  - Members are the household's, not a building's: they survive a switch. A
    person with an account does not stop being one because the panel is showing
    the cabin.
  - `createSpace` in the view model now branches on whether a space exists,
    because `HomeService::createSpace` fills the *active* space — running it
    with a space already there would rename the house you are standing in
    instead of adding another.
- **Low batteries say so.** `Device.batteryPercent` has been stored, seeded and
  shown as a figure on one screen since the model was written, and nothing ever
  mentioned it — a battery is the one thing about a device that stops mattering
  the moment you notice it and starts mattering badly if you never do. Devices
  at or below 20% now carry a warning on their card and an amber battery on
  their page. The threshold lives in `HomeService`, so every surface that
  mentions a battery agrees about what "low" means, and a mains-powered device
  reporting -1 is not treated as one at zero.
- **Scenes act on devices, not just rooms.** `Scene` gains a list of actions —
  a device, whether to switch it on, and optionally a level or a temperature —
  so "Movie Night" can dim the lamp to 20% and set the air conditioner to 22°C
  rather than switching a whole room on. The scene wizard's third step already
  *looked* like this: it had a device list and a per-device panel, and a note
  admitting the values went nowhere because the model stored scenes per room.
  They go somewhere now.
  - **The migration is that the old shape is still a legal value.** A snapshot
    written before this has no `actions` key, reads as an empty list, and
    means "the whole room" — which is what it did before and also a scene
    people genuinely want, so the fallback earns its place rather than being a
    compatibility shim.
  - Ending a scene switches its devices off; it does not put a brightness
    back, because nothing recorded what it was. The UI says so rather than
    inventing a number and calling it yours.
  - Scene cards now say what a scene drives — "4 devices" or "whole room" —
    which is the one thing they could never tell you.
- **An activity log.** Every switch, every scene, every sign-in, with who did
  it, in Profile → Activity. Bounded at 400 entries in its own file, written
  with `QSaveFile` because it is written on every light switch on a device
  whose power can be cut mid-write.
  - **Nothing below `main.cpp` knows it exists.** The services already emitted
    everything it needs; the composition root connects those signals to a
    recorder. That is also the only place that can name an actor —
    `HomeService` knows the signed-in role and `AuthService` knows the name,
    and neither knows both. See ADR-0021.
  - A scene the house ran at 6 am has no name against it. Attributing it to
    whoever happened to be signed in would be a lie in the one record people
    read to find out what happened.
- **The auto-lock is a setting, not a command-line flag.** `--idle-lock` was a
  setting for whoever starts the process rather than whoever lives with the
  panel, and on a device with no shell prompt that is nobody. Never / 1 / 5 /
  15 / 30 minutes, in Profile → Preferences, persisted by the composition root.
- **Tile shadows can be turned off**, and `Theme.shadowsEnabled` finally reads
  the preference that has been stored since the settings layer was written —
  it returned a hard-coded `true`. It is a GPU blur pass per raised tile and a
  dozen of them on a dashboard, which makes it the largest single item on the
  panel's frame budget; separate from the render tier because somebody may
  well want the glass theme's gradients without it.
- **`--msaa 2|4|8`**, off by default. Qt Quick already antialiases rounded
  geometry in the vertex shader, which is what makes the tile corners smooth;
  a multisample buffer on top costs bandwidth the Mali GPU does not have.
- **The scene graph is pinned to OpenGL on direct-to-framebuffer platforms**
  (eglfs, linuxfb, kms) and left to Qt everywhere else — forcing OpenGL on
  macOS would swap a first-class Metal backend for a deprecated one. The
  chosen platform, backend and MSAA state are logged at startup.
- **You can walk through the 3D home.** A first-person mode with a thumbstick,
  a drag-to-look surface and a floor switcher, sized for a touchscreen rather
  than for WASD — the keyboard still works where there is one. Walls rise to
  the ceiling with a doorway cut through each, the roof closes, the storey gap
  collapses, and only the floor you are on is drawn. Tapping a room walks you
  to it, which is also the answer to the one thing a generated plan cannot
  guarantee: two rooms that share a boundary but not a full edge get doorways
  that do not line up, and pretending otherwise would mean getting stuck. See
  ADR-0020.
- **The storey is 132 units instead of 62.** The generated rooms are 300–400
  across; a room four times wider than it is tall is a crawlspace, and it is
  the first thing you notice standing in one. The sectioned orbit view is
  unaffected, because the section is still cut at the waist.
- **Walls, and a wall mode.** Section (waist height, the default, so the plan
  stays readable from above) or full height. Full height with the roof on is a
  sealed box, so the roof comes off when you are outside and goes back on when
  you are inside.
- **An exploded view and a room drawer-pull.** Stacked / Split / Exploded for
  the storeys, and a selected room rises out of the slab — which is the only
  kind of exploded view that means anything in a bungalow, where separating
  the storeys separates nothing.
- **Lamps that are on light the house.** Real point lights, capped at six and
  off below render tier 1. Turn the living-room lamp off from the dashboard
  and the living room goes dark, which is the single strongest cue that the
  model is your house rather than a picture of one.
- **Devices have shapes.** A floor lamp, a squat speaker, a wall unit up near
  the ceiling, a small box on the floor — instead of five identical pegs,
  which told you how many devices a room had and nothing about which.
- **Device names float beside them while you walk**, for the storey you are on
  and only within reach, and **holding a device operates it** — tap opens it,
  hold switches it. Standing next to a lamp, the thing you want is the switch,
  and a first-person view has nowhere to put one.
- **Member roles are enforced.** They had been stored and ignored since
  v0.11.0 — a Viewer could toggle every device an Administrator could, which
  is the data model claiming a capability the code did not honour.
  `HomeService` now holds the actor's role and gates every mutation:
  `mayOperate()` for power, targets, modes, levels and scenes;
  `mayAdminister()` for anything that changes what the house *is*. It defaults
  to Viewer, because an authorisation default that is convenient is an
  authorisation default that ships, and the composition root raises it on
  sign-in. The scheduler passes `Actor::System` — a schedule that only fires
  while an administrator is looking at the panel is not a schedule.
- **The UI disables what your role cannot do** rather than letting the service
  refuse afterwards: switches grey out for a Viewer, and administration rows
  and buttons are hidden. Refusals that do get through are said out loud once,
  at the shell — along with undeliverable device commands, which had been
  silent since the transport was written.
- **Backup and restore.** `exportModel` / `importModel` over the existing JSON
  snapshot, with an entry point in Profile → Preferences and a confirmation
  step before a restore replaces everything. The home model only: password
  verifiers and session tokens stay on the panel, because a backup is a file
  people carry around on a USB stick. A backup that cannot be read is refused
  before anything is touched, and a read that fails puts the old model back.
- **An MQTT transport**, as an optional dependency detected at configure time
  — the same pattern Quick3D and Quick Particles already use. `--transport
  mqtt://host` swaps it in; the loopback stays the default, stays in the tree,
  and remains the only transport that can be told to fail on purpose. Topics
  are templates rather than hard-coded, so it is the MQTT transport and not
  the Zigbee2MQTT one. See ADR-0019.
- **ADR-0018** — Matter is the intended transport and plugs in at
  `IDeviceTransport`; Thread is explicitly not a radio this panel terminates;
  certification is not claimed. The gap analysis ranked the *silence* on this
  second, and it was right to.
- **The Map view page (frame 09) and the dashboard card that opens it.** The
  plan was only reachable from Rooms; frame 07 has a "Your space map" card
  beside Members and the layout already left the half-width hole for it. The
  card's thumbnail is the USER'S plan drawn in preview mode, not a stock house
  — the same squarified layout the map page draws, with captions and pins off.
  The page adds what the Rooms half does not have: every device in the space
  in a scrolling row under the plan, each with its own switch, so the map
  answers "where are my rooms" and the row answers "and what is on".
- **`StRoomMap`** — the plan, its storey strip and the optional 3D loader,
  extracted from RoomsScreen so the second caller could reach it. Two copies
  of a Loader that pulls in an optional module by URL is how one copy gets
  fixed and one does not.
- **The link-device customise step (frame 11).** Tapping + on a nearby device
  now opens a page that names it and places it, instead of linking it into
  whichever room happened to be first under whatever name the manufacturer
  chose. Skip is the old behaviour, kept deliberately: nothing on the page is
  required.
- **The link search panel (frame 17b).** The grid filters in place, which
  answers "show me the lamps"; the panel answers "is my lamp already
  connected?", which it can only do by looking at devices the grid does not
  contain — that is why the frame draws a panel instead of filtering.
- **Per-device controls on the detail page.** `Device` gains `levelPercent` —
  brightness on a lamp, mist output on a humidifier, diffusion on a diffuser,
  fan speed on a conditioner — with the word chosen once in the view model so
  the screens that show it cannot disagree. Kept separate from
  `volumePercent`: loudness and output answer different questions and a device
  can have both.
- **Renaming, moving and removing a device, from the device.** All three have
  been in the model since the wizard was written and none of them were
  reachable outside it: the answer to "this lamp is in the wrong room" was to
  delete it and set it up again.

### Fixed
- **The device page overflowed the panel.** The left column is about 436 px
  tall on a 1024x600 screen and a speaker wants five control rows; at the
  design's 96 px each that is 480, and a Column anchored to the bottom that
  does not fit grows upwards — through the header. The row height is now
  derived from the column and the number of rows the device actually has,
  floored at the touch target so a row that fits is still a row you can hit.
  It looked correct on a desktop window and was broken on the only screen that
  matters.
- **The room photo view's device pins all landed in the same place** on the
  panel. The frame is 1024 tall and the panel is 600; unscaled, the card row
  and footer took 411 px of it and left a two-pixel band for the pins. The
  frame's vertical measurements now scale with the height available (widths do
  not — a narrower panel gets fewer cards, not smaller ones).
- **Switches and icon buttons were too small to hit reliably.** A 28 px switch
  track and a 36 px icon button are what the frames draw and are both under
  the 44 px a touchscreen needs. The drawn size is unchanged; the ITEM is now
  the target with the drawing centred in it. The 2D plan's 18 px device pins
  get the same treatment through the handler's `margin`, which grows a hit
  area without growing the dot into a blob.
- **The room photograph shimmered along its edges.** It is minified from a
  source far larger than the panel — the case a GPU without mipmaps handles
  worst — and was the one image in the app without them.
- **The 3D map could not be made taller than the screen.** The walkthrough
  asked for 660 px inside a 600 px panel, which put the thumbstick inside a
  Flickable that scrolled out from under it.
- **The 3D/2D toggle could not be tapped over the 2D plan.** The map's controls
  floated in the card's top-right corner over whichever view was showing, and
  over the plan they fought its room rectangles for every tap near that corner
  — so switching to 2D could leave you unable to switch back. They have a
  reserved band of their own now, which removes the class of problem rather
  than the instance.
- **The volume slider did nothing.** It had no handler at all — the track
  moved under the finger, nothing was sent, and letting go put it back. A
  control that can be operated and does nothing is worse than one that is
  absent. `StSlider` also gains `modelValue`, because a T.Slider writes to
  `value` while dragging and so silently destroys a binding on it: bound
  directly, every slider in the app followed its model exactly once.
- **The device hero was sized by a constant fraction of its column.** How many
  control rows there are depends on what the device can do, so 0.44 of the
  height was a hero that overlapped the first row on the device with the most
  capabilities. It takes what the controls leave instead.
- **The room photo view leaked out of its panel.** The device row was left
  unclipped on the theory that a half-visible card advertises that the row
  scrolls; what it actually did was draw cards over the sidebar and off the
  right edge of the window. The row is clipped now, and the inset moved from
  the anchors to the view's own content margins, so the cut-off card appears
  at the row's edge - the affordance the comment claimed - with the drop
  shadows still having somewhere to fall.
- **Device cards in the photo view showed no product image.** The device list
  model returns `imageSource` unresolved, unlike `HomeViewModel::room()`;
  every other screen resolves it through `viewModel.imageUrl()` and this one
  bound the raw relative path. `StRoomPhotoView` now takes the resolver.
- **The mini player floated over the photo view.** It is a frame 19 element
  pinned at screen scope rather than inside the scroller, so it never saw the
  view-mode gate the scroller carries and sat on top of frame 20's ambient
  footer.
- **The photo view's geometry was approximated, not measured.** Re-read off
  the frame: the photograph is full bleed to the panel edges with square
  corners and the header floating on it, the cards are 320 x 240 with a 24 gap
  starting 40 in from the panel edge, the product sits on its disc at the
  quarter mark rather than centred, and the two ambient readings are equal
  blocks with right-aligned values instead of a centred row - so the two
  numbers line up with each other in every language, not only in English.
- **Device pins overlapped each other and hid under the top bar.** Pins are
  now placed on a grid, one device per cell with the id hash jittering it
  inside its own cell, in a band measured from the header height and the card
  row rather than from a guessed fraction of the height.

## [0.13.0] - 2026-08-31

### Added
- **A glass theme, alongside the measured one.** Translucent surfaces with lit
  rims and gradient films, a lit aurora backdrop, backdrop blur on the header
  and navigation rail, and a sparse drifting dust layer. Selectable in Profile
  → Preferences; the measured Figma treatment stays the default and the
  reference. See [ADR-0017](docs/adr/0017-two-themes-and-render-tiers.md).
- **Render tiers** (plain / balanced / full), detected at first run from the
  platform plugin and overridable. Blur and particles are off below tier 2, so
  the glass theme is honest on an RK3328 instead of unusable on it.
- `Theme.surfaceFor()` / `borderFor()` — a component asks what a surface should
  look like once, instead of twenty components branching on the theme and the
  twenty-first forgetting.
- `docs/competitive-gap.md` — what Home Assistant, Hubitat, Homey, Aqara and
  the Echo Hub ship that SmarTon does not, and which of those absences are
  deliberate scope versus unexamined gaps.

### Changed
- `IPreferences::themeName()` has two legal values instead of one. It existed
  so that a second theme would be a settings change rather than a grep; that
  turned out to be worth it.
- Qt Quick Particles joins Quick3D as an optional dependency, detected at
  configure time and isolated in its own QML module.

## [0.12.0] - 2026-08-30

### Added
- **A 3D map view, built as a sectioned architectural model.** Continuous
  cantilevered slabs per storey, waist-height interior partitions (so the plan
  stays legible from above), full-height perimeter glazing with dark mullions,
  a roof on the top storey, a site and plinth underneath, three-point lighting
  with filmic tonemapping and ambient occlusion, and device markers standing on
  the floor in the same on/off/pending/unreachable vocabulary the cards use.
  Orbit camera, and a storey strip that dims the floors you are not looking at. `Room` gains an
  integer `floor`, each storey is squarified on its own footprint, and the add-
  room sheet has a floor stepper so a multi-storey home can actually be built.
  See [ADR-0016](docs/adr/0016-generated-3d-floor-plan.md).
- Qt Quick 3D is an **optional** dependency. Detected at configure time; a
  build without it gets the 2D plan and no toggle, rather than not building.
  `backend::Capabilities::mapView3D` reports which build this is, the 3D module
  is only added when Quick3D is found, and `RoomsScreen` loads it by URL — an
  `import` would make the whole screen fail to load on a Qt without it.
- `HomeViewModel::floors()` and `setRoomFloor()`; `HomeService::addRoom()`
  overload taking a storey, clamped to −2..20.

## [0.11.0] - 2026-08-30

### Fixed
- **Placeholder text never rendered on any field.** `StTextField` and
  `StSearchField` derive from `T.TextField`, which declares `placeholderText`
  and `placeholderTextColor` but does not draw them — in Qt Quick Controls the
  placeholder is a `Text` item supplied by the STYLE's `TextField.qml`,
  alongside `background` and `contentItem`. Both controls define their own
  visuals and never provided one, so every placeholder in the app was a
  property being set and read by nothing.
- **The scene wizard's summary card overlapped its header** — the same
  `-Theme.spacing6` top margin fixed in the space wizard, which had its own
  copy of it.
- `SqliteUserRepository::migrate()` tested one column and returned early if it
  was present, so the second migration ever added would never run on a database
  that had already taken the first. It is column-by-column now.

### Added
- **Members can be real accounts.** The Add-member form collects name
  (required), email, mobile and a photo, plus an optional password — and when
  a password is given, `AuthService::createAccount()` creates a genuine
  sign-in account through the same PBKDF2 hasher and the same policy as the
  operator's own. There is no second, weaker path for "just a member". The
  member record links to it by id; the credential stays in the accounts table,
  so a factory reset of the home model does not take accounts with it.
- Member cards show a "Can sign in" badge. "Member" now covers two genuinely
  different things, and a list that does not distinguish them cannot be
  audited.
- `IUserRepository::createUser()` returns the new row id, so the member record
  can link to the account without a second lookup racing a rename.

### Changed
- StackView transitions assigned `null` on both stacks. A cross-fade between
  two full screens costs a composited layer per side for the length of the
  animation, which on the RK3328 is a visible hitch on the action that should
  feel instant.
- The Members screen's scope note no longer says members "are not accounts" —
  because now some of them are. It states the actual rule: a member with a
  password can sign in, one without is a name and a face on the household list.

## [0.10.0] - 2026-08-30

### Fixed
- **"Remember information" did nothing.** The checkbox has been on the login
  screen since the first UI pass because frame 03 draws one, and no code read
  it — so the panel asked for a username and password on every restart. It now
  issues a rotating session token; the password is still never stored in any
  form. See [ADR-0015](docs/adr/0015-remembered-sessions.md).
- **The back button appeared on screens with nothing behind them.** Members and
  Statistics are sidebar destinations, so their back arrow could not do
  anything and pressing it did nothing at all. `showBack` now reads the
  enclosing StackView's live depth instead of being asserted per screen.
- **The switch's off state was invisible.** The off track was `surfaceRaised`
  (#40464D) drawn on a `surface` card (#2D3542) — one step lighter than its
  background, so an off switch was a white dot floating in a smudge and read as
  broken rather than off. Recessed track, a rim, and a muted knob.
- **The wizard's summary card overlapped the header**, from a deliberate
  `-Theme.spacing6` top margin that pulled it 24 px up into the band.
- **The wizard's hero image had square corners** — the same `clip: true`
  bounding-box trap as the avatars, on a rounded `Rectangle` filled
  corner-to-corner by a photograph. Also fixed on the top bar's line artwork,
  which ran square past the band's top-right radius.
- **Device detail's Status switch ran into the scenes panel**: the right column
  was anchored with `leftMargin: 0`, so a right-anchored switch ended exactly
  where the panel began. The concentric rings behind the hero could also size
  taller than their column and push up through the header.
- **Focus never landed anywhere** except on the login screen, so a wizard step
  with one text field swallowed the first keystroke.
- Empty states were pinned to the top of whatever height they were given, so
  the text sat high with two thirds of the panel empty below it.

### Added
- **Map view.** Frame 18, built. Rooms are laid out as a squarified treemap
  (Bruls, Huizing & van Wijk) in proportion to their floor area — the only
  spatial fact the model holds — with each room's devices pinned inside it in
  the same on/off/pending/unreachable vocabulary the device cards use. It is a
  proportional plan, not a survey: see `FloorPlanHelper` for why generating one
  from area is the honest answer to a design that assumes geometry the product
  does not have.
- `FocusHelper` — finds the first typeable field under an item and focuses it,
  wired to the shell's navigation and to both wizards' step loaders. Input
  controls declare `stTextInput` rather than being duck-typed.
- `tst_sessiontokens` — 14 cases over the token lifecycle: single use,
  rotation, expiry, tampering, malformed input, lockout interaction, and that
  a bad token can never lock an account.

### Changed
- **The last emoji and text glyphs are gone.** `"+"` on three buttons and the
  combobox's `"✓"` were literal characters rendered in whatever the UI font
  had at that codepoint; the four conditions-strip icons were 48 px PNGs that
  read as emoji beside a 14 px caption. `StButton` now has a real icon slot,
  and three new SVGs (weather, bulb, music) were authored to the existing
  24×24 / 1.5-stroke spec.
- **The conditions strip is four tiles, not three.** The frame groups weather
  and humidity in one card; reproduced literally at 1024 px that card held two
  icons, two captions and two values as a centred clump with no boundary
  between the readings. One tile per fact, content left-aligned on a shared
  inset and vertically centred, the row scrollable, and the band cut from 100
  to 76 px.

## [0.9.0] - 2026-08-30

### Added
- **A user-chosen accent colour, applied across the whole application.**
  `Theme.primary` now reads from a new `backend::Appearance` singleton rather
  than from `DesignTokens`, so every control already bound to that token
  follows the choice with no per-control work. Chosen from Profile →
  Preferences: eight presets drawn from the design's own palette, a hex field
  for anything else, and a live preview built from the real controls.
  See [ADR-0014](docs/adr/0014-user-accent-derived-foreground.md).
- `Theme.textOnPrimary` and `Theme.textOn(fill)` — the colour to draw ON a
  filled surface, measured by WCAG relative luminance rather than picked. Six
  controls hard-coded white for this and were correct only while the accent
  stayed dark.
- `IPreferences::accentColor()` / `setAccentColor()`, stored under `ui/accent`
  and validated on both read and write, so hand-editing the settings file to
  `ui/accent=blueish` falls back to the brand colour instead of producing a
  black button.
- `tst_appearance` — 12 cases including a sweep of the full RGB cube. It
  computes the WCAG formula longhand from the spec rather than calling the
  production code, so a wrong coefficient cannot pass by grading its own work.

### Changed
- `DesignTokens.primaryForeground` records the white the design draws on the
  brand orange, and the default accent keeps it. Measured, white on #E25319 is
  3.83:1 and near-black is 4.93:1, so deriving the foreground unconditionally
  would have flipped every primary button in the app to dark text. The
  deviation is now one named token with the numbers beside it rather than a
  silent restyle.
- The Orchid preset now offers `accentVioletSoft` (#D6BCFA). The design's
  `accentViolet` (#734497) is 2.26:1 against the page background and fails the
  contrast rule the picker enforces — offering a swatch the setter then refuses
  is worse than not offering it.
- `StButton`, `StCheckBox`, `StSwitch`, `StSegmentedControl`, `StTimeField` and
  the `StMediaCard` mini bar now derive their on-fill text and glyph colour
  instead of assuming white.
- Profile → Preferences replaced its placeholder. Notifications is still a
  placeholder, and still says why.

## [0.8.1] - 2026-08-30

### Fixed
- **Every "circular" avatar in the app was square.** `clip: true` on a
  `Rectangle` clips to the item's BOUNDING BOX, never to its corner radius, so
  a rounded rectangle was drawn and then completely covered by an unclipped
  image. Nine sites: the sidebar, the profile screen, the members grid and
  list, the dashboard members row, both wizards, the combobox thumbnail and
  its delegates, the summary header and the media card. It looks almost right
  at 36 px on a dark background, which is why it survived this long.

### Added
- `StRoundedImage` — a real mask via `MultiEffect` (`maskSource` over a
  layered rounded rectangle), with a pixel of edge softness because a hard cut
  visibly steps on a 36 px circle. In Controls, not Components: it composes
  nothing.
- `StAvatar` — the one way a person is drawn. Circular crop, a fallback
  initial that stays put if the picture never loads, optional ring and
  presence dot. Six screens had their own slightly different copy of the
  broken version.
- The profile picture now appears on the **welcome screen**, the sidebar, the
  members grid, the wizard's member list and the dashboard row. Members with
  no photograph fall back to the bundled default rather than an initial.

## [0.8.0] - 2026-08-30

### Fixed
- **The space picker overlapped the conditions strip on the dashboard.** The
  picker centres in the title row at y=30..85 and the strip was anchored to
  the band's BOTTOM at y=80..180 — five pixels of overlap, from two
  independent guesses about one band's height. `StTopBar` now has a
  `bottomContent` slot and measures itself; no caller sets a band height.
- **The combobox popup was clipped by the dashboard's scroller.** It is now
  reparented to the window overlay and positioned by `mapToItem`, so it can
  never be cut off or drawn under a tile.

### Added
- **A real SVG icon set** (ADR-0013). 31 icons on one 24×24 grid, 1.5 stroke,
  round caps and joins, authored white and tinted at runtime by `StIcon`. This
  replaces ~20 hand-painted `Canvas` glyphs that had drifted to four different
  stroke weights across the codebase. `Canvas` remains only where a drawing is
  genuinely data-driven — the chart, the ruler, the orbit rings.
- **Profile pictures.** `adesh_dp.jpeg` is the bundled default; a file dialog
  sets a new one. The file is *copied into application data* rather than
  referenced where the user browsed to, validated by content rather than
  extension, capped at 8 MB, and its path stored in a new `users.avatar_path`
  column with an `ALTER TABLE` migration for existing databases. A deleted
  file falls back to the default rather than rendering broken.
- **`SplitView` shell** with a resizable sidebar: 168 min (where "Profile &
  Settings" elides), 198 preferred (measured), 320 max (beyond which the rail
  eats the grid it exists to serve). The handle is a 1 px seam at rest.
- **`QSettings` preferences** (`IPreferences` / `QSettingsPreferences`) for
  window size, locale, idle-lock delay and theme — operator settings that must
  survive a factory reset of the home model, kept out of the database on
  purpose. Every getter clamps, because a settings file is hand-editable.
- **Pluggable SQL driver** (ADR-0012). `--database mysql://user:pw@host/db`
  works; SQLite stays the default and the only tested target. Only four
  statements were dialect-specific and all four are now isolated.

### Notes
- MySQL is *supported*, not *verified*: no test runs against a server.

## [0.7.1] - 2026-08-30

### Fixed

Pixel audit. Every number below was extracted by scanning the Figma exports
for colour transitions, not estimated by eye — see `design/measurements.md`.

- **`radiusLg` was 16 and nothing in the design is 16.** The largest measured
  corner is 12–13 on a device card. A card at 16 reads noticeably softer than
  the frame beside it, which was most of why the built screens looked close
  but not right. Radii are now 8 / 10 / 12 / 13, each measured.
- **The conditions-strip cards were invisible.** They are white @15% over the
  band — *lighter* than it. They were drawn as `surfaceDeep` at 85% on a
  `surfaceDeep` band, so the strip showed as bare artwork.
- **The Members and space-map cards are outlined, not filled** — 1 px
  `#40464D` over the page ground. They were solid `surface`, far too heavy
  under the device grid.
- **The header band is 30 px wider than the content column** on each side.
  Everything shared one margin, so the dashboard read as a stack of
  same-width slabs instead of a band with content inside it. Now
  `Theme.bandBleed` / `Theme.pageMargin`.
- **The space picker was a thumbnail stacked on top of a combobox**, with the
  label pushed clear by a hand-computed padding — two components each guessing
  the other's metrics, and the label sat wrong. The thumbnail now lives inside
  `StComboBox`. Measured 320 × 55, `#2A3240`, 1 px `#808B9A`, radius 10.
- **Combobox popup** now matches its anchor: same width, same radius, 55 px
  rows so opening the list does not change the rhythm, capped at four rows
  before scrolling, rounded highlight.
- Device cards were 0.75 aspect; measured 0.728. Grid gaps were uniform; they
  are 25 horizontal and 28 vertical.
- Sidebar nav inset was 16; measured 10.8% of the rail, i.e. 21.

### Added
- `Theme.outlineStrong` (`#808B9A`) and `Theme.overlaySubtle` (white @15%) —
  two values the palette was missing, both measured off the exports.
- `StCard.outlined`.
- `design/measurements.md`.

## [0.7.0] - 2026-08-30

### Added
- **Device transport boundary** (`IDeviceTransport`) and
  `LoopbackDeviceTransport` — deliberately with latency and optional,
  deterministic packet loss, so the layers above are exercised against the
  timing a real mesh has rather than an instant, always-successful fiction.
  `--device-failure-rate` exercises the offline paths.
- **Scene scheduler** (ADR-0011). Scenes now actually run: edge-triggered,
  midnight-wrapping windows, `Everyday` / `Week days` / `Mon, Fri` day rules,
  an already-open window applied on start, and an injectable clock.
  `--no-scheduler` disables it.
- 22 new tests across two suites (`tst_scenescheduler`, `tst_devicetransport`).

### Changed
- **`Device` now separates reported from desired state** (ADR-0010). `on` is
  what the device last reported; `desiredOn` is what the user last asked for;
  `pending()` is the gap. The switch no longer moves on tap — it moves when
  the device confirms. A failed command rolls intent back and marks the device
  offline rather than leaving a switch stuck half-way.
- `StSwitch` renders `pending` as a pulse on the track (the thumb deliberately
  does not move) and `unreachable` as a warning edge rather than a disabled
  control — greyed out says "you cannot", when the truth is "it is not
  listening".
- Device cards show "Not responding" in place of the room name when offline.

## [0.6.0] - 2026-08-30

### Fixed
- **The UI font did not exist on the target.** `Theme.fontFamily` was the
  hard-coded `"Segoe UI"`, which ships only on Windows; everywhere else Qt
  substituted silently, making every measured metric wrong. New
  `backend::Typography` registers any bundled font, otherwise picks the first
  family the system actually reports from a checked list, and logs which it
  chose so a substitution shows up in the boot log.
- **Translations did nothing.** 332 marked strings, no `QTranslator`. Now
  loaded for the system locale (plus Qt's own catalogue), with a `--lang`
  override and a CI gate that fails on a stale `.ts`.

### Added
- Idle auto-lock. `AuthService` owns the timer; five-minute default,
  `--idle-lock <seconds>` to change or disable. Activity is detected globally
  on the Window, and the login screen states that it locked rather than
  looking like a crash.
- Change password (Profile tab 2). Re-verifies the current password inside an
  already-authenticated session, enforces policy in the service, re-derives
  with current KDF parameters.
- Accessibility across the control library: role, name, checked state and
  press actions on all 24 controls, with icon-only buttons and model-driven
  switches named at their call sites.
- 7 auth test cases covering change-password and the idle lock.

### Changed
- Service and model tests use `QTEST_GUILESS_MAIN` — an event loop without a
  display, which is what a headless CI runner can actually provide.

## [0.5.1] - 2026-08-30

### Added
- `StComboBox` — a real `T.ComboBox` with popup, keyboard navigation
  (Up/Down/Home/End/Esc/Enter), type-ahead, a scroll indicator and an optional
  pinned action row.
- `StScrollView` — Flickable with a fading scrollbar, touch-tuned
  deceleration, `StopAtBounds` and `pixelAligned`. Every scrolling surface now
  uses it.
- Interaction-state tokens and helpers in `Theme`: `hoveredFill()`,
  `pressedFill()`, `disabledFill()`, hover/press overlays, `fieldBorder`.

### Fixed
- **Text fields had no visible border when idle** — it was drawn in the same
  colour as the fill, so a field read as a flat panel with nothing to say it
  could be typed into. Now `outline` idle, `outlineSubtle` on hover, 2 px
  `#1268CC` on focus.
- **The space picker was a fake dropdown**: it drew a chevron, reported a tap
  and opened nothing. It is now a real combobox, and its pinned "Create a new
  space" row is the dashboard's only route into the wizard.
- Every control gained hover, pressed and disabled states; buttons, chips,
  checkboxes, switches, icon buttons and links previously only reacted to
  press.
- `StLabel` switched from `NativeRendering` to `QtRendering`. Native is
  sharper only at integer device positions, and these labels live inside
  Flickables and fading cards, where it shimmered frame to frame.
- Explicit `KeyNavigation` chains on the login and reset-password forms. The
  automatic order put the password field's reveal toggle between the two
  inputs.
- Window is now bounded both ways (`Theme.windowMin*` / `windowMax*`) rather
  than only having a floor.

## [0.5.0] - 2026-08-30

### Added
- Space wizard, steps 1–7 (frames 10–17): name, address, rooms, device
  linking, room assignment, members, confirm. One screen with a Loader over
  the step, not seven copies of the same chrome.
- `StAddRoomSheet` — the right-hand drawer from frame 14, with the tick ruler,
  m²/ft² toggle and artwork picker.
- Scene wizard, steps 1–3 (frames 24–25): name and room, calendar schedule
  with AM/PM time fields, per-device panel.
- `MembersScreen`.
- Controls: `StCountChip`, `StSearchField`, `StRuler`, `StRadioOption`,
  `StTimeField`. Components: `StSummaryHeader`, `StActionBar`, `StCalendar`,
  `StLinkDeviceCard`.
- `HomeService` mutations: create space, add/remove room, link/unlink device,
  move device, add/remove scene and member, set schedule. All persist.
- `tst_homeservice` — 16 cases covering load precedence, persistence,
  clamping, and the two cascade rules below.

### Changed
- **Persistence reworked** (ADR-0009): the seed is now factory defaults and
  the store holds the live model as one JSON snapshot. The previous
  delta-per-change tables could not represent a deleted room or a created one.
  `SqliteHomeStateStore` is replaced by `SqliteHomeStore`.
- Rooms screen gains "Add new rooms"; scene cards open the scene editor.

### Notes
- Removing a room returns its devices to the nearby pool rather than deleting
  them — the hardware still exists — and drops its scenes, which could never
  run without it.
- Scenes are stored, not executed: there is no scheduler. The screen says so.

## [0.4.0] - 2026-08-30

### Added
- Screens: room overview (19), device detail (21), scenarios (23), statistics
  (26), profile (27), and the device dialog (08). Drill-downs push onto the
  shell's stack, so back and Escape return one level.
- Editing: rooms, devices, scenes and the space rename in place via
  `StEditableLabel` — Enter commits, Escape reverts, focus loss commits, empty
  is refused. Names persist as id-keyed overrides in `entity_name`, so
  re-seeding never clobbers what the user called something.
- Elevation: `StShadow` (MultiEffect) on every tile, behind one
  `Theme.shadowsEnabled` switch for the embedded build.
- Controls: `StSlider` (ticked volume), `StTabBar` (sliding underline),
  `StEditableLabel`. Components: `StLineChart` (Catmull-Rom spline on Canvas),
  `StStatCard`, `StSceneCard`, `StMediaCard`, `StShadow`.
- `HomeViewModel` gains a second, room-scoped device model, single-entity
  lookups for the detail screens, and `roomFilters()` so QML never indexes a
  model by raw role number.

### Notes
- Statistics figures are DERIVED from configured room consumption, not
  measured — SmarTon has no metering hardware. The screen says so on the page,
  not just in a comment.
- `StCard` and `StControlRow` deliberately have no default-property alias: it
  would capture this file's own `StShadow` into the surface that is supposed
  to cast it.

## [0.3.0] - 2026-08-30

### Added
- Home model: `Space`, `Room`, `Device`, `Scene`, `Member` value types;
  `HomeService` as the single source of truth; `SqliteHomeStateStore` so
  device and scene toggles survive a restart.
- Catalogue seeded from `resources/config/home-seed.json`, matching the Figma
  content exactly. Demo content is data, not code.
- `RoomListModel`, `DeviceListModel`, `SceneListModel`, `MemberListModel` and
  `HomeViewModel`. Power changes emit `dataChanged` for one row, never a model
  reset.
- Spaces dashboard (frame 07) and Rooms list (frame 18).
- Controls: `StSwitch`, `StChip`, `StIconButton` (seven drawn glyphs),
  `StCountPill`, `StSegmentedControl`. Components: `StCard`, `StTopBar`,
  `StDeviceCard`, `StRoomCard`, `StSpacePicker`, `StConditionsStrip`.
- Every new control added to the component gallery.

### Notes
- `StSwitch` deliberately does not own its state. Binding `checked` on a plain
  Switch is destroyed by the first click, after which the switch shows what it
  was last clicked to rather than what the device did — a UI that lies about
  hardware. It renders `value` and only emits `toggleRequested`.

## [0.2.0] - 2026-08-30

### Added
- Local account authentication: `AuthService` with account lockout, timing
  equalisation and transparent re-hashing; `SqliteUserRepository` (prepared
  statements only, WAL); `Pbkdf2PasswordHasher` (PBKDF2-HMAC-SHA512, 210,000
  iterations, per-user 16-byte salt, constant-time compare).
- `AuthViewModel` at the QML/C++ boundary. No `password` property: the
  plaintext is an argument, never stored state.
- Account provisioning: `smarton --create-account <name>` prompts on the
  terminal with echo off (never on the command line, which `ps` exposes), plus
  an unattended `SMARTON_BOOTSTRAP_PASSWORD` path for first boot on the panel.
  No default credential exists.
- `AuthError::NotProvisioned`: an empty account store now says so instead of
  reporting incorrect credentials for a password that was never set.
- Screens built to the Figma set: splash, welcome, login, verify code, reset
  password, and the spaces empty state.
- `ShellScreen` — persistent sidebar plus the shell's own page stack.
- Controls: `StTextField`, `StCheckBox`, `StOtpField`, `StPasswordRules`,
  `StLinkButton`, `StSocialButton`; components `StDivider`, `StEmptyState`;
  navigation `Routes`, `StNavIcon`, `StSidebar`.
- `design/README.md` — the measured palette and geometry, and the frame
  inventory with build status.
- ADR-0006 (password hashing), ADR-0007 (provider buttons disabled),
  ADR-0008 (reflow, do not scale).
- Tests: `tst_authservice` (12 cases incl. lockout, enumeration parity and
  timing equalisation), `tst_authviewmodel`, and QML tests for the OTP field,
  password rules and text field.

### Changed
- Design tokens replaced wholesale with the exact Figma hex values.
- Theme retargeted to 1024 x 600; auth column is the Figma 480.
- Sidebar footer split: Profile & Settings under the primary group, Log out
  pinned to the bottom edge, matching frame 06.

### Removed
- The monitoring demo UI inherited from the template: `DashboardScreen`,
  `SettingsScreen`, `StNavRail`, `StGaugeDial`, `StStatusPill`, `StCardGrid`,
  `StReadingCard` and their QML tests. The monitoring C++ stack stays: it is
  what the designed Statistics screen (frame 26) will bind to.

## [Unreleased]

### Added
- Nothing yet.

## [0.1.0]

### Added
- Seven-layer C++ architecture: `common`, `core`, `domain`, `services`,
  `infrastructure`, `models`, `backend`, with the dependency rule enforced by
  CMake target link lists.
- Eight `SmarTon.Ui.*` QML submodules added in dependency order, each a
  separate target so wrong-direction imports fail to link.
- `st_add_qml_module()` — mirrors each module's URI into a build-tree import
  path so Qt Creator, qmlls and qmllint resolve types without running the app.
- Dependency inversion at the service boundary: `IReadingSource` declared in
  `services`, implemented in `infrastructure`.
- Component gallery executable rendering every control, including edge cases.
- Qt Test suites for domain, core, services and models; Qt Quick Test suites
  for controls and layouts, running headless.
- `CMakePresets.json` with `host-debug`, `host-release`, `ci`, `rk3328`.
- CI workflow: three-platform matrix, blocking qmllint gate, coverage job.
- Five architecture decision records.
- Architecture, coding, testing and performance guideline documents.
- Generated QML catalog target (`st_qml_catalog`).
- `scripts/rename-project.sh` — rewrites tokens, filenames and include
  directories in one pass.

[Unreleased]: https://github.com/USER/REPO/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/USER/REPO/releases/tag/v0.1.0
