# Research: A21-P00 (feature 151)

## Facts (verified in code, 2026-11-17)

The facts of the clarification session hold. VisualCore provides full-screen shader scenes with a GLSL noise, hash,
palette and sRGB library, CPU gradient and fractal noise, a CPU particle system with an instanced soft-quad renderer
and normal or additive blending, render targets and blend modes, a bloom pass and a rate-based flash limiter, a
crossfade scene, a frame-delta clock that never jumps after the background, frame pacing that follows Low Power Mode
and the thermal state, a cached still frame, precision probes, snapshots with migration, experience storage with small
values, one-shot procedural tones and accessibility preferences. It has no continuous sound player, no luminance cap
for an arbitrary scene, no tone mapping, no hide-and-restore controls mode, no static fallback frame and no CPU value
noise.

## Decisions

- **D1 Scope:** audit only. The one app is the shell.
- **D2 Matrix scope:** the five brainstorm capabilities (procedural shaders, noise functions, particle systems,
  animation, blending and compositing) and the six version 0.1 features:
  - three procedural sky presets with aurora ribbons, stars and cloud layers;
  - colour, motion and intensity controls with sensible bounds;
  - scene transitions and saveable preferences;
  - a low-power static view and a reduced-flash mode;
  - an optional ambient loop with its own sound control;
  - a full-screen view that hides its controls and restores them by tap.

  Cross-cutting rows cover context loss, resize and orientation, quality tiers, accessibility, bounded resources,
  permissions (none), rendered versus wall-clock time and truthful claims.
- **D3 Availability rule:** clarification 2.
- **D4 Gap owners** (the manual's phases):

  | Gaps | Phase |
  |---|---|
  | The sky scene, presets, palettes and parameter bounds as pure versioned models; the ribbon, star and cloud shaders over `vc/`; the rendered clock; the reduced-motion stable frame | A21-P01 |
  | Scene selection and the controls with bounds; the luminance cap as pure math and a composite pass; hiding and restoring the controls | A21-P02 |
  | Multi-layer compositing and transitions under the cap; saved preferences; sound independent of the drawing lifecycle | A21-P03 |
  | The ambient loop player in VisualCoreAudio (upstream); the low-power static view, the reduced-flash mode and the static fallback frame; GPU targets released on theme changes | A21-P04 |
  | The ambient loop with its own control in the experience; long-run thermal and comfort device plan; low-power cadence without a time jump | A21-P05 |
  | Release | A21-P06 |
- **D5 Permissions:** none. The loop and any tone use the ambient session and need no microphone; nothing uses
  location.
- **D6 Sound:** synthesised, never a recording (manual risk 3 met by construction).
- **Alternatives considered:**
  - an experience-local looping player over the system audio engine (rejected: a speaker-output loop is generic, and
    experiences use VisualCore's audio products rather than the system audio engine directly);
  - a VisualCore luminance-cap pass now (rejected: one user; moved upstream only when a second experience needs it,
    per Principle II);
  - a bundled, licensed recording (rejected by the constitution: sound is code).
