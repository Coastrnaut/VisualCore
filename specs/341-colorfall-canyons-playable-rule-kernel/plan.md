# Implementation Plan: R02-G05-01 — Colorfall Canyons: playable rule kernel

**Branch**: `341-colorfall-canyons-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-21 |
**Spec**: [spec.md](spec.md)

## Summary

Add Colorfall Canyons's pure rule kernel, `ColorfallCanyonsCore`, to `Packages/ExperiencesRound02` on the pattern of Hue
Compass's (feature 331): an immutable, fingerprinted level (terrain of heights and cell kinds, springs, basins, flow
rate, action budget, tick limit), the exact flow step (downhill routing, synchronous integer moves, largest-remainder
colour sharing, springs, drains, conservation totals) and the end-of-tick evaluation (contamination, overflow, win,
time), the play state machine with records, full undo and redo and replay, and the rules as an R02-F23 `PuzzleRules`.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in
this feature (the shader interfaces come in R02-G05-03); no new package; one new target pair.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains `ColorfallCanyonsCore` (path `ColorfallCanyons/Core`),
its tests (`ColorfallCanyons/CoreTests`) and the product.
**Numbers**: at most 120 cells, 3 springs of supply ≤ 999, so every mass is ≤ 2,997 and every product r · mass ≤ 8 ·
2,997 fits easily in `Int`; no floating point in the rules.
**Seeds**: fixtures use `SeededRandom(seed: 2_341)`; neighbouring-input checks seed 2_346.
**Testing**: `swift test --package-path Packages/ExperiencesRound02 --filter ColorfallCanyons`; regression as for 331.
**Performance**: one tick visits ≤ 120 cells; a 3,600-tick run is ≤ 432,000 cell visits, well under a second.
**Constraints**: additive; reason codes `r02-g05.*`; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided.
**CI**: the existing `swift test` step of ExperiencesRound02 covers the new targets; no workflow change.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests. |
| V Implementation Before Devices | PASS — no device work. |
| IX Bounded Untrusted Input | PASS — bounded ranges; stored levels re-checked on decode. |
| X Licensing and Provenance | PASS — the project's own archived design; original code. |
| XI One App and Stable Experience Identity | PASS — experience R02-G05; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                         edit  + ColorfallCanyonsCore (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsError.swift     new   (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsLevel.swift     new   cells, springs, basins, level, stored form (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsFlow.swift      new   fluid state, routing, tick, sharing, evaluation (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsPlay.swift      new   stages, actions, records, undo, redo, fingerprints, replay (agent B)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsRules.swift     new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsFixtures.swift  new  seeded levels with a known solution (lead)
Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/{ColorfallCanyonsLevelTests (lead), ColorfallCanyonsFlowTests (A),
  ColorfallCanyonsPlayTests (B), ColorfallCanyonsRulesTests (C), ColorfallCanyonsInvariantTests (D)}.swift   new
docs/architecture/colorfall-canyons.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, level, flow and fixtures first; then agents A (flow tests with an independent brute-force
reference), B (play), C (rules) and D (invariants) in parallel in isolated package copies; the lead retests every agent
result and records checks after every agent has reported.
