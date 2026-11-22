# Implementation Plan: R02-G06-01 — Chrono Constellator: playable rule kernel

**Branch**: `351-chrono-constellator-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-21 |
**Spec**: [spec.md](spec.md)

## Summary

Add Chrono Constellator's pure rule kernel, `ChronoConstellatorCore`, to `Packages/ExperiencesRound02` on the pattern of
Colorfall Canyons's (feature 341): an immutable, fingerprinted level (grid, stars with loops, default phases and targets,
edit budget, tick limit), the timeline (start phases and holds, edits in use, its own fingerprint as the signed
snapshot), the closed-form star positions at any tick (clarification Q2) and the end-of-tick evaluation (collision, win,
time), the play state machine with records, full undo, redo, rewind and replay, and the rules as an R02-F23
`PuzzleRules`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in this
feature (the shader interfaces come in R02-G06-03); no new package; one new target pair.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains `ChronoConstellatorCore` (path `ChronoConstellator/Core`),
its tests (`ChronoConstellator/CoreTests`) and the product.
**Numbers**: at most 120 cells, 5 stars, loops of 32 cells, 1,200 ticks and 20 holds; every phase sum is below 2,500, so
`Int` arithmetic is exact; no floating point in the rules.
**Seeds**: fixtures use `SeededRandom(seed: 2_351)`; neighbouring-input checks seed 2_356.
**Testing**: `swift test --package-path Packages/ExperiencesRound02 --filter ChronoConstellator`; regression as for 341.
**Performance**: one tick is ≤ 5 position look-ups and ≤ 10 pair comparisons; a 1,200-tick run is ≤ 18,000 operations.
**Constraints**: additive; reason codes `r02-g06.*`; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided.
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
| XI One App and Stable Experience Identity | PASS — experience R02-G06; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                              edit  + ChronoConstellatorCore (lead)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorError.swift      new   (lead)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorLevel.swift      new   grid, stars, level, stored form (lead)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorTimeline.swift   new   phases, holds, edits in use, positions, evaluation (lead)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorPlay.swift       new   stages, actions, records, undo, redo, rewind, fingerprints, replay (agent B)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorRules.swift      new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorFixtures.swift  new  seeded levels with a known solution (lead)
Packages/ExperiencesRound02/ChronoConstellator/CoreTests/{ChronoConstellatorLevelTests (lead), ChronoConstellatorTimelineTests (A),
  ChronoConstellatorPlayTests (B), ChronoConstellatorRulesTests (C), ChronoConstellatorInvariantTests (D)}.swift   new
docs/architecture/chrono-constellator.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, level, timeline and fixtures first; then agents A (timeline tests with an independent step-by-step
reference), B (play), C (rules) and D (invariants) in parallel in isolated package copies; the lead retests every agent
result and records checks after every agent has reported.
