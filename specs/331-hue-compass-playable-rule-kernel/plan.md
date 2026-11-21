# Implementation Plan: R02-G04-01 — Hue Compass: playable rule kernel

**Branch**: `331-hue-compass-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-21 |
**Spec**: [spec.md](spec.md)

## Summary

Add Hue Compass's pure rule kernel, `HueCompassCore`, to `Packages/ExperiencesRound02` on the pattern of Wave Knot
Keeper's (feature 321): an immutable, fingerprinted level (offset, 96 fog densities, target bearing, tolerances,
allowance), the exact wheel (96 integer boundary vectors, sector test by cross products, hue bands, circular distances,
clues), the play state machine with records, turn-only undo and redo and replay, and the rules as an R02-F23
`PuzzleRules`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in
this feature (the shader interfaces come in R02-G04-03); no new package; one new target pair.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains `HueCompassCore` (path `HueCompass/Core`), its tests
(`HueCompass/CoreTests`) and the product.
**Numbers**: boundary vectors have components |c| ≤ 65 536; directions tested are |x|, |y| ≤ 2^20, so every cross
product stays below 2^38 and fits a 64-bit integer; no floating point in the rules (the tests compare against `atan2`
only as an independent reference away from boundaries).
**Seeds**: fixtures use `SeededRandom(seed: 2_331)`; neighbouring-input checks seed 2_336.
**Testing**: `swift test --package-path Packages/ExperiencesRound02 --filter HueCompass`; regression as for 321.
**Performance**: a clue sums at most 47 densities; trivial.
**Constraints**: additive; reason codes `r02-g04.*`; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided.
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
| XI One App and Stable Experience Identity | PASS — experience R02-G04; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                   edit  + HueCompassCore (lead)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassError.swift           new   (lead)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassWheel.swift           new   boundary table, sector, band, distances, clue (lead)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassLevel.swift           new   level, stored form (lead)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassPlay.swift            new   stages, actions, records, undo, redo, fingerprints, replay (agent B)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassRules.swift           new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassFixtures.swift   new   seeded levels with a known solution (lead)
Packages/ExperiencesRound02/HueCompass/CoreTests/{HueCompassLevelTests (lead), HueCompassWheelTests (A), HueCompassPlayTests (B),
  HueCompassRulesTests (C), HueCompassInvariantTests (D)}.swift             new
docs/architecture/hue-compass.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none. **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, wheel, level and fixtures first; then agents A (wheel tests), B (play), C (rules) and D
(invariants) in parallel in isolated package copies; the lead retests every agent result and records checks after every
agent has reported.
