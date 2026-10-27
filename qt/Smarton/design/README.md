# Design source of truth

Figma exports live in `screens/`, numbered in flow order. Everything in this
file is **measured from those exports**, not sampled from a screenshot and not
estimated. When code and this file disagree, this file is wrong — fix it here
and in `backend/include/smarton/backend/theme/DesignTokens.h` together.

## Canvas

| | Figma | Target panel |
|---|---|---|
| Size | 1440 × 1024 | 1024 × 600 (Waveshare 7") |
| Aspect | 1.41 : 1 | 1.71 : 1 |

The design is **reflowed, not scaled** — see
[ADR-0008](../docs/adr/0008-reflow-not-scale.md) for why, and for the list of
what is preserved verbatim.

## Palette

Exact values, taken from the Figma colour picker. These are the single source;
`DesignTokens.h` holds them in C++ and `Theme.qml` re-exports them to QML. No
other file may contain a colour literal.

### Surfaces

| Token | Hex | Used for |
|---|---|---|
| `background` | `#202326` | Page ground |
| `surfaceDeep` | `#101113` | Sidebar |
| `surface` | `#2D3542` | Input fills, cards, OTP cells |
| `surfaceAlt` | `#2A3240` | Active sidebar row |
| `surfaceRaised` | `#40464D` | Rules, tracks, pressed states |
| `outline` | `#555C67` | Dividers, orbit rings |
| `outlineSubtle` | `#606873` | Provider-button border |
| `overlay` | `#FFFFFF` @ 20% | Scrims |

### Text

| Token | Hex | Used for |
|---|---|---|
| `textPrimary` | `#FFFFFF` | Headlines, button labels |
| `textSecondary` | `#D9DFE6` | Body copy |
| `textMuted` | `#B3BECD` | Inactive nav, placeholders |
| `textDisabled` | `#606873` | Disabled labels |
| `textOnActive` | `#D1E6FF` | Active nav row |

### Accent and state

| Token | Hex | Used for |
|---|---|---|
| `primary` | `#E25319` | Primary buttons, links |
| `focus` | `#1268CC` | 2 px focus ring |
| `info` | `#1874FF` | Informational |
| `infoDeep` | `#0C4180` | Info ground |
| `infoSoft` | `#74B4FF` | Info on dark |
| `success` | `#31AA7A` | Met password rules |
| `successSoft` | `#9EEACC` | Success on dark |
| `warning` | `#F5BA41` | Partial strength |
| `warningSoft` | `#FFD67B` | Warning on dark |
| `danger` | `#E31D1C` | Errors, destructive |
| `accentViolet` | `#734497` | Illustration accents |
| `accentVioletSoft` | `#D6BCFA` | Illustration accents |

## Measured geometry

> Numbers below are the summary. The full extraction — every bounding box and
> corner radius, taken by scanning the exports for colour transitions rather
> than by eye — is in [measurements.md](measurements.md). Trust that file over
> this table, and re-run the extraction after any design change.

| Element | Figma (1440) | In code |
|---|---|---|
| Text input | 484 × 58 incl. ring, radius **12** | 52 high, radius 12 |
| Focus ring | 2 px `#1268CC` | `Theme.borderWidthFocus` |
| Primary button | 480 × 54, radius **12** | 480 × 52 |
| Space picker | **320 × 55**, `#2A3240`, 1 px `#808B9A`, radius **10** | 300 × 55 |
| Conditions card | **440 / 267 / 267 × 100**, white @15%, radius **8**, gap 23 | ratio-preserved |
| Device card | **324 × 236** (0.728), radius **12**, gaps h 25 / v 28 | same ratio |
| Members / map card | **500 × 135, outlined** 1 px `#40464D` | outlined |
| Header band | x 320..1400 — **30 px wider than content** each side | `Theme.bandBleed` |
| Sidebar | 279 wide (19.4%) | 198 (19.4%) |
| Active nav pill | 220 × 46, inset **30 of 279** (10.8%) | 46 high, inset **21** |
| Segmented track | 253 × 44 | 44 high |

## Frame inventory

| # | Frame | Status |
|---|---|---|
| 01 | Splash | Built — `SplashScreen.qml` |
| 02 | Welcome | Built — `WelcomeScreen.qml` |
| 03 | Login | Built — `LoginScreen.qml` (providers disabled, [ADR-0007](../docs/adr/0007-social-login-disabled.md)) |
| 04 | Verify code | Built — `VerifyCodeScreen.qml` |
| 05 | Reset password | Built — `ResetPasswordScreen.qml` |
| 06 | Home / no spaces | Built — `SpacesScreen.qml` empty branch |
| 07 | Home dashboard | Built — `SpacesScreen.qml` dashboard branch |
| 08 | Notification dialog | Built — `StDeviceDialog.qml` |
| 09 | Home map | Not built — needs room geometry the model does not hold |
| 10–17 | Space setup wizard | Built — `SpaceWizardScreen.qml` + `StAddRoomSheet.qml` |
| 18 | Room list | Built — `RoomsScreen.qml` (list view; map view states the gap) |
| 19–20 | Room overview | Built — `RoomOverviewScreen.qml` |
| 21–22 | Device detail | Built — `DeviceDetailScreen.qml` |
| 23 | Scenarios | Built — `ScenariosScreen.qml` |
| 24–25 | Scene editor | Built — `SceneWizardScreen.qml` (stored, not executed) |
| 26 | Statistics — electricity | Built — `StatisticsScreen.qml` (figures derived, labelled) |
| 27 | Account | Built — `ProfileScreen.qml` (first tab; others state the gap) |
| — | Members | Built — `MembersScreen.qml` (no dedicated frame; reuses 07 and 17) |

Unbuilt destinations route to `PlaceholderScreen`, which names the frame it is
waiting for. Every sidebar entry navigates; none is silently dead.

## Interaction states

Every interactive component moves through the same four states, with the
amounts defined once in `Theme` rather than per control.

| State | Fill | Border |
|---|---|---|
| idle | base | 1 px `outline` |
| hover | `hoveredFill()` — base lifted ~14% | 1 px `outlineSubtle` |
| pressed | `pressedFill()` — base darkened 12% | unchanged |
| focused | base | **2 px `#1268CC`** |
| disabled | `disabledFill()` — desaturated toward `surfaceRaised`, item at 45% | 1 px, dimmed |

Disabled moves the colour as well as the opacity. At 45% opacity alone an
orange button is still the most saturated thing on screen and still reads as
the primary action.

Inputs carry a visible border when idle. Without one a field is just a filled
rectangle and nothing says it can be typed into.

## Elevation

Tiles sit on a soft drop shadow, drawn by `StShadow` with `MultiEffect`. That
is a GPU blur pass per elevated tile — free on a desktop, not free on the
panel's Mali GPU with a dozen tiles on screen. `Theme.shadowsEnabled` turns
the whole system off in one place for the embedded build; without it the cards
keep their border and still read correctly, because the shadow carries depth,
not information.

| Token | Value |
|---|---|
| `shadowColor` | black @ 55% |
| `shadowBlur` | 0.85 |
| `shadowOffsetY` | 6 |
| `shadowMaxBlur` | 28 |

## Assets

`resources/images/` is organised by role — `brand/`, `illustrations/`,
`devices/`, `rooms/` — and `resources/icons/` holds single-purpose glyphs.
Sidebar icons are **not** assets: `StNavIcon` draws them on a Canvas so they
stay crisp at any size and recolour with the theme.
