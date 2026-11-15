# Research: A10-P02 Neon Dodge complete mechanics

Facts verified in code on 2026-11-14 (clarification session): see spec Clarifications. Phase 01 constants:
first spawn at step 30, gap 40, fall 3…5 units/s, hazard 70 %.

## D1 — Wave director

- **Decision**: `WaveDirector.step(_ run: inout GameRun, random: inout SeededRandom) -> [SpawnRequest]` runs before
  spawning in `GameSimulation.advance`: if `waveStep == 600`, wave += 1, waveStep = 0, pattern chosen (wave 1 `rain`;
  later uniformly among the other three patterns via the generator), cursor reset; then the pattern's rule decides the
  spawns at this wave step (only for wave steps ≥ 30, every spawn gap; walls every 120 steps); waveStep += 1.
  Each spawn request carries lane, kind and content; positions, speeds and radii are drawn from the generator in a
  fixed order (as Phase 01) with the wave's difficulty.
- **Rationale**: one place decides spawns; deterministic; patterns stay data plus a small rule enum.
- **Alternatives**: precomputed spawn lists per wave (more state to save); free-form scripting (unbounded).

## D2 — Difficulty

- **Decision**: per clarification 3; pure function of the wave number; test monotonic and ceiling.

## D3 — Wall reachability

- **Decision**: proved by arithmetic in a test: worst lane distance 7.2 units at 9 units/s with 60 units/s²
  acceleration takes < 1 s; the row needs ≥ (16.5 − 1.9) / 5 s ≈ 2.9 s to reach the player's top. The free lane is
  never the previous wall's.

## D4 — Schema 2 and migration

- **Decision**: `GameRun` decodes schema 1 (missing wave fields) and `migrated()` sets the wave defaults; snapshot
  `MigrationChain(currentVersion: 2)` step 1 → 2 rewrites the payload's run; `schemaOneExample()` builds a schema-1
  payload after 120 steps of the replay. Restore validates the migrated run.

## D5 — Fixtures

- **Decision**: fixture-8 wave progression (1,900 steps: waves 1–4), fixture-9 wall gap (a seed whose wave 2 is
  `wall`, 800 steps), fixture-10 background/resume in wave 3 (1,300 steps, then the standard suspend; the session test
  proves no catch-up), fixture-11 migration (a schema-1 example restored, then 60 steps). Existing fixtures 1–7 are
  regenerated (their digests change with the waves).
