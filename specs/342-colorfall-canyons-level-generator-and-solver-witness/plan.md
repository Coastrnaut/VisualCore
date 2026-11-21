# Implementation Plan: R02-G05-02 — Colorfall Canyons: level generator and solver witness

**Branch**: `342-colorfall-canyons-level-generator-and-solver-witness` (spec directory only; work on `main`) | **Date**:
2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Extend `ColorfallCanyonsCore` (R02-G05-01, feature 341) with the content pipeline of Colorfall Canyons: the 100-entry
manifest (`ColorfallCanyonsManifest`), the edit-set solver (`ColorfallCanyonsSolver`: the smallest multiset of carves and
set of valve toggles before the first tick that wins when time runs, depth bound 4, each distinct routing simulated once
with conservation asserted), difficulty metrics (`ColorfallCanyonsDifficulty`), the seeded generator
(`ColorfallCanyonsGenerator`: mesa terrain, springs, a planted path change per spring, basins at the planted pools with
targets from the planted run; candidates until one is proven within its band) and versioned witness files
(`ColorfallCanyonsWitness`, schema 1) under `docs/games/colorfall-canyons/levels/`. The catalog digest is R02-F24's
`PuzzleCatalog<ColorfallCanyonsRules>.digest(id:identities:)`, pinned. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: ColorfallCanyonsCore's own types (`ColorfallCanyonsLevel`,
`ColorfallCanyonsFluid`, `ColorfallCanyonsPlay`, `ColorfallCanyonsRules`); VisualCoreSimulation (`SeededRandom`,
`SeedDerivation.derive(_:index:)`, `PuzzleCatalog.digest(id:identities:)`, `ProgressionRule`); VisualCoreMath
(`StableHash`). No GPU, GLSL, Objective-C++ or UIKit code; no new package or target.
**Seeds**: level n uses its manifest seed; candidate k draws from `SeededRandom(seed: SeedDerivation.derive(seed, index:
k))`, k = 0 … 255. Brute-force cross-checks use seed 2_342.
**CPU reference**: every simulated run uses R02-G05-01's `ColorfallCanyonsFluid.tick` and asserts `isConserved()` each tick.
**Testing**: `swift test --package-path Packages/ExperiencesRound02` (CI step exists); regression as for 341.
**Performance**: the solver enumerates at most Σ_{k ≤ 4} C(m + k − 1, k) edit sets (m ≤ 51 moves) and simulates each
distinct routing once (the prototype's worst level: 6,540 runs of ≤ 120 ticks over ≤ 48 cells). Catalog tests are split
by band (and halves) so each stays under 10 s on a debug host build; CI timings measured, never asserted.
**Constraints**: additive to R02-G05-01's public API; budget = the manifest move budget (8 … 19); every value an exact
integer; no network, no art; witness files written only with `COLORFALL_CANYONS_WRITE_WITNESSES=1`.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering in this feature. |
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — pure Core with host tests; witness files checked byte for byte on the host. |
| V Implementation before devices | PASS — no device work. |
| IX Bounded input | PASS — candidates (256), search (depth 4) and witness decoding bounded. |
| X Licensing and provenance | PASS — the manifest is copied from the archived design (round2.md); generated content is original. |
| XI One app and stable identity | PASS — experience R02-G05; level and catalog fingerprints pinned. |
| XII One purchase, no advertising | PASS — free tier; no store code. |
| XIII Code-driven visuals | PASS — nothing drawn here. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsError.swift        edit  + generation(Int), witness(String) (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsManifest.swift     new   entries (100) (lead, generated from the planning index)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSolver.swift       new   routing key, edit sets, smallest set, counterexamples (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsDifficulty.swift   new   (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsGenerator.swift    new   band profiles, candidates, planted plan, basins, catalog digest (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsWitness.swift      new   actions, digests, totals, near miss, witness (agent B)
Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsSolverTests.swift     new  incl. independent brute force (agent A)
Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsWitnessTests.swift    new (agent B)
Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsGeneratorTests.swift  new (agent C)
Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsCatalogTests.swift    new  manifest, digest pin, progression, witnesses by band (lead)
docs/games/colorfall-canyons/levels/001.witness.json … 100.witness.json   new  generated by the catalog test (lead)
docs/architecture/colorfall-canyons.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: none (witness schema 1 is new). **Rollback**: revert the commits; R02-G05-01's types are unchanged.

## Parallel work

The lead writes the error cases, the manifest, the solver, the difficulty and the generator (they are coupled through
the planted plan and the solver's acceptance); agents A (solver tests with an independent brute force), B (witness and
its tests) and C (generator tests) then work in parallel against the contract; the lead writes the catalog tests and
the witness files, retests every agent result and records checks only after every agent has reported.
