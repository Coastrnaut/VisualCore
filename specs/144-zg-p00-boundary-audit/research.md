# Research: A20-P00 (feature 144)

## Facts (verified in code, 2026-11-17)

The facts of the clarification session hold. VisualCore provides touch input with stable ids and timestamps, uniform
resampling of pointer paths with a cap, gesture recognizers with an arbiter, persistent and ping-pong render targets in
half float with an 8-bit fallback, field passes, a GLSL noise and SDF library, 2D transforms with hit testing by depth,
procedural meshes with a lit mesh renderer, a cached still frame, snapshots with migration, experience storage with a
quota, a one-shot sound player, haptics and announcements. It has no coalesced touch samples, no stroke smoothing, no
brush-stamp pass, no GLSL lighting helper, no shadows, no undo stack, no named-document store over experience storage
and no selection helper.

## Decisions

- **D1 Scope:** audit only. The one app is the shell.
- **D2 Matrix scope:** the five brainstorm capabilities (touch interaction, procedural textures, feedback shaders,
  animation, save and restore state) and the six version 0.1 features:
  - one tray with sand relief, two rake styles and a stone palette;
  - continuous multi-sample touch strokes and a brush preview;
  - stone placement, rotation, deletion and layer-aware selection;
  - undo and redo for strokes and placements;
  - named gardens saved and loaded with a lightweight stroke history;
  - the low-stimulation mode with sound and animation off by default.

  Cross-cutting rows cover context loss, resize and orientation, quality tiers, accessibility and gesture
  alternatives, bounded resources, permissions (none) and truthful claims.
- **D3 Availability rule:** clarification 2.
- **D4 Gap owners** (the manual's phases):

  | Gaps | Phase |
  |---|---|
  | The garden document, strokes, stones and the command log with caps and validation; stroke resampling and rake footprints as pure math; the undo/redo command semantics and fixtures | A20-P01 |
  | The sand height target with the experience's stamp pass, relief lighting, the replay from checkpoints, the brush preview and the touch path | A20-P02 |
  | Stones as procedural shapes with soft shadows, placement, rotation, deletion and layer-aware selection, orientation-independent positions | A20-P03 |
  | Named gardens in the experience's storage, accessibility (descriptions, gesture alternatives, Dynamic Type) and a still of the garden | A20-P04 |
  | Responsiveness and idle-power device tests; the low-stimulation and reduced-motion behaviour; coalesced touches assessed | A20-P05 |
  | Release | A20-P06 |
- **D5 Permissions:** none. Sound is an ambient one-shot player, off by default, and needs no microphone.
- **D6 Undo:** command replay with checkpoints (manual risk 1), never texture snapshots.
- **Alternatives considered:**
  - a VisualCore brush-stamp pass and undo stack now (rejected: one user; moved upstream only when a second experience
    needs them, per Principle II);
  - CPU stroke meshes instead of a height target (rejected for the relief: a height target gives lighting and
    overlapping grooves directly; kept as the fallback if half float is missing and 8-bit banding shows);
  - coalesced touches in VisualCore now (rejected for 0.1: resampling already closes gaps; measured on devices in
    A20-P05).
