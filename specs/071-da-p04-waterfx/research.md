# Research: A09-P04 Lighting, particles and accessibility

Facts verified on 2026-11-14 (clarification session): `FullScreenShaderScene` (opaque full-screen fragment; `u_time`
from `fixedTime`; `u_resolution`; `u_<name>` parameters; `errorMessage` on failure, no throw), `ShaderBundle(files:)`
with `vc/noise`; the presenter's `ClearColorScene` and `PrimitiveRenderer`; `ScopeAnnouncer`'s pattern;
`validate(catalog:)` refusing unknown kinds; `lastRestoreRefusal`.

## D1 — Bubbles and motes from the step count

- **Decision**: `WaterEffects.bubbles(step:vents:reduceMotion:) -> [Vec2]`: bubble k of vent v was released at step
  `20k + phase(v)` (phase 0 and 10 for the two vents); its age `a = (step − release)/60` s; y = `1.0 + speed × a`, x =
  vent x + `wobble × sin(2π × 1.5 × a + k)`; alive while y < 9; the newest 24 per vent at most (48 total).
  `WaterEffects.motes(step:reduceMotion:) -> [Vec2]`: 24 positions from a fixed seeded table (SeededRandom seed 0x0A09),
  x wraps over 0…16 at 0.05 units/s (Reduce Motion 0.005), y sways ±0.15 at 0.1 Hz around its base inside 1.5…8.5.
- **Rationale**: no saved state, deterministic, holds with the step count, bounded by construction.
- **Alternatives**: `ParticleSystem` instances in the presenter (state outside the core, harder to hold on suspension).

## D2 — Depth layers

- **Decision**: `WaterEffects.layer(index:) = index % 3`; `scale(layer)` 0.75/0.875/1.0; `tint(layer)` 0.35/0.15/0;
  `tinted(color, water, amount)` linear mix. Presenter z: water/caustics 0, gravel 1, back plants 2, back fish 3, middle
  plants 4, decor 5, pellets 6, middle fish 7, front plants 8, front fish 9, bubbles and motes 10.

## D3 — Caustics

- **Decision**: `CausticsScene` wraps `FullScreenShaderScene` with an inline fragment: water colour above the gravel
  line (y < gravelTop in tank units mapped through the same centred scale), gravel colour below, plus
  `strength × pow(cell, 3)` where `cell` is a two-octave periodic value noise over tank x (period 16 units) and y; time
  `u_time` = step/60 × 0.4 (Reduce Motion: 0). Parameters `u_strength`, `u_scale`, `u_offset` (tank mapping), water and
  gravel colours as parameters. Fallback when `errorMessage != nil` after setup: the Phase 03 `ClearColorScene` and the
  gravel rectangle. A test seam (`fragmentOverride`) injects a broken source to prove the fallback.

## D4 — Wording and announcer

- **Decision**: `AquariumWording.description(document:catalog:paused:)` — "Digital Aquarium: <habitat>, <n> fish of
  <k> species (<count name>, …), <plants>, <decor>, <food>, lighting <level>, <swimming|paused>." (the Phase 03 text
  with the species counts added); `AquariumWording.change(from:to:) -> String?` gives the newest change sentence
  (priority: habitat, food dropped, decoration added, decoration removed, paused/swimming). `AquariumAnnouncer`:
  `announce(_:at:)`, `tick(at:)`, interval 3 s, VoiceOver gate, pending latest.

## D5 — Unknown content

- **Decision**: `UnknownContentTests` (catalog: missing species reference, unsupported fish/plant/decor shape, unknown
  decor in a habitat, vent outside the tank; document: unknown species/plant/decor refused by validation); session test
  restores a snapshot with an unknown species and an unknown decor kind (refused, Reef opens); render test draws a
  document with an unknown plant and decor kind (skipped, no throw). Fixture 11: Reef, 600 steps.
