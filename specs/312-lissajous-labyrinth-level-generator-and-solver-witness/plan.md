# Implementation Plan: R02-G02-02 — Lissajous Labyrinth: level generator and solver witness

**Branch**: `312-lissajous-labyrinth-level-generator-and-solver-witness` (spec directory only; work on `main`) | **Date**:
2026-11-20 | **Spec**: [spec.md](spec.md)

## Summary

Extend `LissajousLabyrinthCore` (R02-G02-01, feature 311) with the content pipeline of Lissajous Labyrinth: the 100-entry
manifest (`LissajousLabyrinthManifest`), the solver (`LissajousLabyrinthSolver`: every one of the 14,080 legal settings
decided by a sound checkpoint-box prefilter plus the kernel's exact lap verdict, then a breadth-first search over legal
states for the shortest action list), difficulty metrics (`LissajousLabyrinthDifficulty`), the seeded generator
(`LissajousLabyrinthGenerator`) that draws candidates from each entry's planned seed until one is proven within its band,
and versioned witness files (`LissajousLabyrinthWitness`, schema 1) under `docs/games/lissajous-labyrinth/levels/`. The
catalog digest is R02-F24's `PuzzleCatalog<LissajousLabyrinthRules>.digest(id:identities:)`, pinned. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: LissajousLabyrinthCore's own types (`LissajousLabyrinthLevel`,
`LissajousLabyrinthLap`, `LissajousLabyrinthPlay`, `LissajousLabyrinthRules`, `LissajousLabyrinthSine`); VisualCoreSimulation
(`SeededRandom`, `SeedDerivation`, `PuzzleCatalog.digest`, `PuzzleDifficulty`, `ProgressionRule`); VisualCoreMath
(`StableHash`). No GPU, GLSL, Objective-C++ or UIKit code (the renderer is R02-G02-03); no new package or target.
**Seeds**: level n uses its manifest seed; candidate k draws from `SeededRandom(seed: SeedDerivation.derive(seed, index:
k))`, k = 0 … 63. Brute-force cross-checks use `SeededRandom(seed: 2_312)`.
**Testing**: `swift test --package-path Packages/ExperiencesRound02` (CI step exists); regression: VisualCore host tests,
VisualCoreRendering on sim-27.2 and sim-26.5, ExperiencesCreative on sim-27.2, the app unit tests, the reference
regression in two chunks, script tests (alone).
**Performance**: x depends only on (a, φ), y on b, z on ψ (c is the level's). Per checkpoint the prefilter builds 144 + 9
+ 16 axis bit sets of 4,096 ticks (64 words each) and ANDs three per setting: ≤ 14,080 × 6 × 3 × 64 ≈ 16 M word operations
per level. Survivors get an exact fast decision equal to the kernel's verdict (research R2b): obstacle contact is tested
exactly only on ticks whose segment's axis box meets the obstacle's box (bit sets per axis), and the in-order checkpoint
scan runs only over each checkpoint's box-hit ticks; the kernel's own verdict (about 1–2 ms per lap in debug) is used by
the tests as the independent judge. Breadth-first
search: 14,080 states × ≤ 46 moves. Target: a level's solve under 0.2 s on a debug host build; the catalog tests are split
by band (20 levels each) so each stays under 10 s; CI timings are measured, never asserted.
**Constraints**: additive to R02-G02-01's public API; levels' allowance = the manifest move budget (8 … 19); every value an
exact integer; no network, no art; witness files written only with `LISSAJOUS_LABYRINTH_WRITE_WITNESSES=1`.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering in this feature. |
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — pure Core with host tests; witness files checked byte for byte on the host. |
| V Implementation before devices | PASS — no device work. |
| IX Bounded input | PASS — candidates (64), settings (14,080), search states (14,080) and witness decoding bounded. |
| X Licensing and provenance | PASS — the manifest is copied from the archived design (round2.md) with its provenance; generated content is original. |
| XI One app and stable identity | PASS — experience R02-G02; level and catalog fingerprints pinned. |
| XII One purchase, no advertising | PASS — free tier; no store code. |
| XIII Code-driven visuals | PASS — nothing drawn here. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthError.swift       edit  + generation(Int), witness(String) (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthManifest.swift    new   entries (100) (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSolver.swift      new   prefilter, verdict table, BFS (agent A)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthDifficulty.swift  new   (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthGenerator.swift   new   band profiles, generator, catalog digest (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthWitness.swift     new   counterexamples, witness (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthSolverTests.swift     new (agent A)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthWitnessTests.swift    new (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthGeneratorTests.swift  new (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthCatalogTests.swift    new  manifest, digest pin, progression, witnesses by band (lead)
docs/games/lissajous-labyrinth/levels/001.witness.json … 100.witness.json                        new  generated by the catalog test (lead)
docs/architecture/lissajous-labyrinth.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: none (no stored data changes; witness schema 1 is new). **Rollback**: revert the commits; R02-G02-01's
types are unchanged, so nothing else depends on the new files.

## Parallel work

Lead first adds the error cases, the manifest, the solution and difficulty contract (contracts/api.md) and the difficulty
type; agents A (solver and its tests) and B (witness and its tests) then work in parallel against the contract; the lead
writes the generator, the catalog tests and the witness files once A's solver is in, retests every agent result and
records checks only after every agent has reported.
