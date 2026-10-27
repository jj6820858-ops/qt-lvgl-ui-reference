# 17. Two themes over one token layer, with render tiers

Status: Accepted

## Context

Every colour, radius, spacing and duration in SmarTon comes from `Theme`,
which reads `DesignTokens` — the Figma file transcribed into C++. That is a
design system on paper. Nothing had ever tested it, because there was only one
skin, and a token layer that has never been re-skinned is a token layer nobody
knows works.

A second, glass-styled look was wanted: translucent surfaces, gradients,
backdrop blur, glow, drifting particles.

Two things make that non-trivial. The target is a Waveshare RK3328 — a
Mali-4xx GPU with no compute shaders and memory bandwidth shared with the CPU,
where backdrop blur and particles are the two most expensive things available.
And the measured Figma fidelity (ADR-0008, `design/measurements.md`) is a
substantial part of what this project demonstrates; replacing it would throw
that away.

## Decision

**Two themes, not a replacement.** `figma` stays the default and the reference.
`glass` is a second skin over the same tokens, selectable in Preferences.

**Three render tiers**, detected at first run and overridable: 0 flat, 1
gradients and glow, 2 full glass with blur and particles.

**Blur is opt-in per surface**, not a property of the theme.

## Consequences

**The second theme is the test.** Re-skinning found exactly what a re-skin is
supposed to find: components that hard-coded a treatment instead of asking for
a token. `Theme.surfaceFor()` and `Theme.borderFor()` exist so a component asks
"what should a card look like here" once, rather than twenty components each
writing `Theme.glass ? … : …` and the twenty-first forgetting.

**Tiering is detected from the PLATFORM PLUGIN, not the GPU.** The obvious
approach — create a GL context, read `GL_RENDERER`, match the slow families —
is wrong twice on Qt 6: the scene graph runs on the RHI, so on macOS that is
Metal and on Windows D3D11, and a GL renderer string would describe a backend
the app never uses. `eglfs` / `linuxfb` mean the application owns the
framebuffer with no compositor, which in practice means an embedded board.
Coarse, and wrong in the safe direction — an unrecognised platform gets the
good-looking path, the panel does not, and the answer is overridable.

**Blur defaults to off even at tier 2, and this is the load-bearing decision.**
Qt has no backdrop filter, so frosting means blurring a live *copy* of a
nominated source: a texture plus a multi-pass blur, **per surface, per frame**.
Nine device cards on the dashboard would be eighteen render targets. That does
not scale on any GPU.

It also is not necessary. Three things make a surface read as glass — a lit
rim, a gradient across the film, and a backdrop blur — and the blur has by far
the worst cost-to-effect ratio of the three. So it is spent deliberately on the
large permanent surfaces where a moving backdrop is actually visible through
them (the header band, the navigation rail: one of each per window) and
ordinary cards get the two free thirds. The fallback on a slow machine is then
not a different-looking component; it is the same component with its most
expensive layer switched off.

**The vibrance lives in the BACKDROP, not the surfaces.** A frosted panel over
a flat `#202326` is a slightly lighter flat `#202326` — the blur has nothing to
blur. So the colour is in `StAurora` and the surfaces stay neutral. That is
also the legibility argument: the usual way a glass UI becomes unreadable is by
putting colour in the panels, which then have to carry text. Colour in the page
means every surface keeps a consistent contrast against its own content however
saturated the wallpaper gets.

**A singleton holds the backdrop reference.** There is exactly one backdrop per
window, so it is a fact about the window rather than a parameter of a card —
and threading it through twenty screens, most inside Loaders, would be a
property on every one of them that those screens have no reason to care about.
`StAurora` clears it on destruction, because a singleton holding a pointer to a
deleted Item is the one way this pattern fails, and it fails exactly when a
screen is being torn down.

**Particles are an optional module, like Quick3D (ADR-0016).** `QtQuick.Particles`
ships with qtdeclarative but is not present in every packaging, and an `import`
of a missing module fails the whole component that imports it. A backdrop
flourish must never be able to take a screen down, so `StDustLayer` lives in
`SmarTon.Ui.Effects`, built only when found and loaded by URL.

**Particles are deliberately sparse.** Forty motes over a whole page, drifting
upward at roughly walking pace. Anything faster or denser stops being
atmosphere and becomes something the eye tracks instead of reading the screen —
which on a control panel is a usability regression dressed as a feature.

## Alternatives considered

**Replace the Figma theme.** Rejected: it discards the measured-fidelity
argument the project rests on, for one visual identity instead of a
demonstration that the token layer is real.

**One custom `ShaderEffect` sampling a single pre-blurred backdrop**, so N
surfaces cost one blur instead of N. This is the correct answer at scale and
the reason it was not taken is honest rather than principled: it needs `.frag`
shaders compiled through `qsb` and build machinery that could not be verified
here. If the blur ever needs to go on cards, this is the way to do it.

**Glass on showcase screens only.** Rejected: a half-themed app looks
unfinished rather than deliberate.
