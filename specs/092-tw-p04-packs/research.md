# Research: A12-P04 (feature 092)

Facts verified on 2026-11-15 (clarification session): `WorldState` schema 2 fields; `WorldEditing` rules;
`CameraPolicy` global limits and terrain-only clearance; catalog and audit structure.

## D1 — Pack data
- **Decision**: `WorldPack` values in code (id, name, preset index, seed, ordered props with x, z and turn, light,
  pitch and distance ranges, default view, author, license), one per preset; `WorldPack.apply(to:)` builds the state by
  placing each prop through `WorldEditing.place` (so the rules and the drawn-surface height apply) and refuses the pack
  on the first refusal.
- **Rationale**: one rule path for user and pack placements; a broken pack can never load.
- **Alternatives**: JSON resources (more parsing, no gain for three packs); pre-computed y values (would bypass the rules).

## D2 — Per-preset limits and prop-aware clearance
- **Decision**: `CameraPolicy.limits(for preset:)` returns the pack's ranges; `clamp` uses them and the clearance takes
  the highest of the 9 terrain samples and each nearby prop's top (y + model height) within 1 m plus its picking
  radius; pitch raised in 1° steps to the preset's upper pitch.

## D3 — Budgets and fixtures
- **Decision**: count vertices (terrain + sea + Σ prop model vertices), props and draws (2 + props) per pack; commit the
  state digest after `world.pack` from the default state for each pack; a broken pack fixture (a prop moved under
  water) is refused with `a12.under-water`.
