# Research: A09-P02 Fish movement and visual prototype

Facts verified in code on 2026-11-14 (clarification session): no steering, neighbour or flocking type exists in any
VisualCore product (`VisualCoreSimulation` holds particles, field grids, clocks, timelines and `SeededRandom`);
`VisualCoreMath.Vec2` provides the vector operations needed; `DecorPlacement` holds `kindId` and `position`; the
bundled catalog has no decor; `AquariumSimulation.advance` is the Phase 01 bounded wander with clamp and reflection.

## D1 — Steering model

- **Decision**: classic weighted steering per agent: separation (sum of away-vectors weighted by 1 − d/r over all
  neighbours within the separation radius; a coincident neighbour pushes along +x for the lower index and −x for the
  higher, deterministic), alignment (mean neighbour velocity of the same group minus own velocity), cohesion (mean
  neighbour position of the same group minus own position), boundary avoidance (inward push rising linearly from 0 at
  `margin` to 1 at the bound, per axis). Each term is capped to `maxForce` after weighting; the sum is capped to
  `maxForce`. Non-finite inputs give zero force.
- **Rationale**: well-understood, bounded, deterministic and cheap; caps prevent erratic motion (manual risk 3).
- **Alternatives**: potential fields on a `FieldGrid` (indirect, grid resolution artefacts); physics springs (unbounded
  energy).

## D2 — Neighbour search

- **Decision**: linear scan, keep the `limit` nearest within `radius`, order by (distance, index), exclude self.
- **Rationale**: ≤ 24 agents; O(n·k) per agent is trivially bounded; deterministic ordering.
- **Alternatives**: uniform grid / spatial hash (needed only for hundreds of agents; deferred until an experience needs
  it).

## D3 — Integration in the aquarium

- **Decision**: per step, compute every fish's force from the state at the start of the step (no order dependence),
  then: velocity += force × dt; a seeded wander turn of ±(turnRate × 0.35 × dt); speed clamped to
  0.5 × cruise…maxSpeed; boundary clamp and reflection exactly as Phase 01; heading follows velocity; `turn` =
  smoothed (0.2 per step) heading change / dt; animation phase as Phase 01. Species tuning: neighbour radius 2.5 units,
  separation radius 0.8 × (2 × length), limit 6, weights separation 2.0, alignment 1.0, cohesion 0.8, boundary 3.0,
  maxForce 2.0 units/s².
- **Rationale**: start-of-step snapshot makes the result independent of document order; the speed floor keeps fish
  moving; tuning values are tested against SC-A09-201/202 and may be adjusted in implementation (recorded).

## D4 — Decor and schema 2

- **Decision**: `DecorShape` rock/shell; `DecorKind` (id, name, shape, colour, size 0.3…2.0, author, license);
  bundled kinds `round-rock`, `flat-rock`, `spiral-shell`; Reef starter decor 3 pieces, Kelp 2 pieces. Rotation
  −π…π, scale 0.5…2.0. Custom `init(from:)` decodes missing fields with defaults; `migrated(catalog:)` adds starter decor
  to a schema-1 document with no decor and sets schema 2.
- **Alternatives**: separate decor document (more moving parts); keep schema 1 with optional fields (hides the version).

## D5 — Swim animation

- **Decision**: body outline points displaced laterally by `0.06 × length × sin(phase − 4 × u) × u` (u = 0 at the head
  to 1 at the tail), tail triangle displaced by `0.15 × length × sin(phase)`, the whole outline bent by
  `clamp(turn × 0.12, ±0.35)` × u² radians; Reduce Motion multiplies wave, swing and bend by 0.5. The Phase 01 angular
  tail swing (0.4 rad) is replaced.
- **Rationale**: frequency grows with speed through the phase (already speed-driven); amounts from clarification 5.

## D6 — Fixtures

- **Decision**: fixture-6 schooling (Reef, 1,800 steps = 30 s; the test checks cohesion and agreement); fixture-7
  save/load (Kelp, bright, 240 steps; the save-restore check compares species, decor transforms and lighting). Manifest
  digests derived as in A09-P01.
