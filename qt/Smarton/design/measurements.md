# Measured geometry

Extracted from the Figma PNG exports by scanning for colour transitions, not
by eye. Every number here is a pixel index in the 1440x1024 frame.

Re-run the extraction after any design update rather than trusting this file.

## Frame 07 — home dashboard

| Element | x | y | Size | Fill | Radius |
|---|---|---|---|---|---|
| Sidebar | 0..278 | full | 279 wide | `#101113` | — |
| Header band | 320..1400 | 0..239 | 1080 x 239 | `#101113` | square top, rounded bottom |
| Content column | 350..1370 | — | 1020 | — | — |
| Space picker | 1050..1370 | 30..85 | **320 x 55** | **`#2A3240`** | **10** |
| — border | | | 1 px | **`#808B9A`** | |
| — thumbnail | 1065..1098 | | 34, inset 15 | | circle |
| Readings card | 350..790 | 115..214 | **440 x 100** | white @15% on band | **8** |
| Quick action | 813..1080 | 115..214 | **267 x 100** | same | 8 |
| — gap | | | **23** | | |
| Device card | 350..673 | 333..568 | **324 x 236** | `#40464D` | **12** |
| — gaps | | | **h 25, v 28** | | |
| Members card | 350..850 | 859..993 | **500 x 135** | **transparent** | 12 |
| — border | | | 1 px `#40464D` | | |
| Space-map card | 870..1370 | 859..993 | 500 x 135 | transparent | 12 |
| — gap | | | **20** | | |
| Sidebar active pill | 30..249 | 250..296 | 220 x 46 | `#2D3239` | 8 |

## Frame 03 — login

| Element | Size | Radius |
|---|---|---|
| Text field | 484 x 58 (52 + 2 px ring each side) | **12** |
| Primary button | 480 x 54 | **12** |

## Frame 18 — rooms

| Element | Size | Radius |
|---|---|---|
| Segmented track | 253 x 44 | pill |

## Corrections this produced

1. **Radii were wrong.** `radiusLg` was 16; cards measure 12–13. Strip cards
   measure 8, not 12. The picker is 10, not 12.
2. **The conditions strip cards are LIGHTER than the band**, not darker. They
   were drawn as `surfaceDeep` at 85% on a `surfaceDeep` band — invisible.
3. **Members and space-map cards are outlined, not filled.** They were solid
   `surface`.
4. **The header band bleeds 30 px wider than the content column** on each
   side. Everything shared one margin.
5. **Device cards are 324 x 236**, aspect 0.728. They were drawn at 0.75.
6. **Sidebar pill inset is 30 of 279** (10.8%), i.e. 21 px on the 198 px rail.
   It was 16.
7. **The space picker is `surfaceAlt` with a light `#808B9A` border**, not
   `surface` with `outline`.
