# Implementation Plan: R02-G02-01 — Lissajous Labyrinth: playable rule kernel

**Branch**: `311-lissajous-labyrinth-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-20 |
**Spec**: [spec.md](spec.md)

## Summary

Add the pure target `LissajousLabyrinthCore` to `Packages/ExperiencesRound02` (created by R02-G01-01) with its tests: an
integer sine table (`LissajousLabyrinthSine`), immutable levels with balls for checkpoints and obstacles and a fingerprint
(`LissajousLabyrinthLevel`, JSON schema 1), the exact lap evaluation with segment contact tests and an explained verdict
(`LissajousLabyrinthLap`), the play state machine with validated, recorded actions, undo, redo and exact win and failure
(`LissajousLabyrinthPlay`), and the R02-F23 `PuzzleRules` conformance (`LissajousLabyrinthRules`). Refusals are
`LissajousLabyrinthError` with `r02-g02.*` codes. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`),
VisualCoreMath (`StableHash`). No GPU, GLSL, Objective-C++ or UIKit code (the renderer is R02-G02-03).
**Package**: edit `Packages/ExperiencesRound02/Package.swift` (product and target `LissajousLabyrinthCore` at
`LissajousLabyrinth/Core`, tests `LissajousLabyrinthCoreTests` at `LissajousLabyrinth/CoreTests`). No XcodeGen or app target
change; the app links the experience at its gate X-R02-G02. The CI step `swift test --package-path
Packages/ExperiencesRound02` already covers the new targets.
**Seeds**: fixtures use `SeededRandom(seed: 2_311)`.
**Testing**: `swift test --package-path Packages/ExperiencesRound02`; regression as R02-G01-01: VisualCore host tests,
VisualCoreRendering on sim-27.2 and sim-26.5, ExperiencesCreative on sim-27.2, the reference regression in two chunks,
script tests (alone).
**Performance**: one verdict is 4,096 samples plus 4,096 segments × ≤ 8 obstacles, about 40,000 integer steps; exact
segment tests stay within Int64 (coordinates |·| ≤ 4,096, centres ≤ 5,000, products ≤ 6 × 10¹⁶).
**Constraints**: additive; Aurora Loom and every other package unchanged; every value an exact integer; no network, no art.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering in this feature. |
| II App-neutral API | PASS — game code lives in the experience package; VisualCore API unchanged. |
| IV Host-testable | PASS — pure Core with host tests. |
| V Implementation before devices | PASS — no device work. |
| IX Bounded input | PASS — level fields, dials, allowance and records refused or bounded by code. |
| X Licensing and provenance | PASS — original rules and code from the archived design; the sine table is computed, not copied. |
| XI One app and stable identity | PASS — experience R02-G02 (`r02-g02.lissajous-labyrinth`), no app target; level fingerprints. |
| XII One purchase, no advertising | PASS — free tier; no store code. |
| XIII Code-driven visuals | PASS — nothing drawn here. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                  edit  + LissajousLabyrinthCore (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthError.swift          new   (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSine.swift           new   4,096-entry table, pinned (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthLevel.swift          new   Ball, Dials, Level, stored form (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthLap.swift            new   tracer, segment contact, verdict (lead; the level's start check needs it)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthPlay.swift           new   stages, actions, records, undo, redo, fingerprints (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthRules.swift          new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthFixtures.swift  new   seeded levels with a known safe setting (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/{LissajousLabyrinthLevelTests (lead), LissajousLabyrinthLapTests (A),
  LissajousLabyrinthPlayTests (B), LissajousLabyrinthRulesTests (C), LissajousLabyrinthInvariantTests (D)}.swift            new
docs/architecture/lissajous-labyrinth.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none. **Rollback**: revert the commits; Aurora Loom's targets are untouched.

## Parallel work

Lead writes the package entry, error, sine table, level, lap evaluation, fixtures and the level test; agents A (lap tests
with an independent reference), B (play and its tests), C (rules and its tests) and D (the eight invariant tests) then work
in parallel against the contract. Lead: docs, runs, commits; checks recorded only after every agent has reported.
