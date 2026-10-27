# Fonts

**Nothing is bundled here yet, and that is the last thing standing between
this build and the design.** `backend::Typography` says so on every start:

```
smarton.typography: No font bundled under :/qt/qml/SmarTon/Resources/fonts;
falling back to the system family 'Helvetica Neue'.
```

That fallback is fine on a Mac and wrong on the panel. Every metric in
`design/measurements.md` — control heights, where labels elide, how wide the
sidebar has to be before "Profile & Settings" truncates — was measured against
a specific typeface. A substituted family changes all of them, silently.

## Fixing it

1. Drop a `.ttf` or `.otf` in this directory. Two good choices, both free to
   redistribute:

   | Font | Licence | Why |
   |---|---|---|
   | **Inter** | SIL OFL 1.1 | Closest metrics to the Figma; designed for UI at small sizes |
   | **Roboto** | Apache 2.0 | Slightly narrower; what the design was likely drawn with |

   A variable font (`Inter-VariableFont_slnt,wght.ttf`) covers every weight in
   one file, which is one resource rather than four.

2. Register it in `resources/CMakeLists.txt` under `RESOURCES`:

   ```cmake
   fonts/Inter-VariableFont_slnt,wght.ttf
   ```

3. Rebuild. Nothing else changes: `Typography` registers every font file it
   finds here and takes the first family they provide, so the theme picks it
   up with no code edit. The startup log flips to:

   ```
   smarton.typography: Using bundled font family: Inter
   ```

## Licensing

Whatever you ship, put its licence file in this directory too and list it on
the attribution screen. Both fonts above require the licence text to travel
with the binary — see `docs/production-readiness.md`, P3.
