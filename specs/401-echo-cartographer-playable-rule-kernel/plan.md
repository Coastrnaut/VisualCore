# Implementation Plan: R02-G11-01 — Echo Cartographer: playable rule kernel

**Branch**: `401-echo-cartographer-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-23 |
**Spec**: [spec.md](spec.md)

## Summary

Add Echo Cartographer's pure rule kernel, `EchoCartographerCore`, to `Packages/ExperiencesRound02` on the pattern of
Backwards Aurora's (feature 391): the chamber as a W × H grid of open and wall cells (W, H 5 … 16) with its entry and
1 … 4 hidden beacons; the player's knowledge of each cell (unknown, open, wall); the pulse from a known-open cell with
its four rays (north, east, south, west) that reveal open cells and the struck wall, their travel distances, and the
beacons' echoes as breadth-first path lengths through open cells, sorted and unlabelled, each with a delay of
24 × distance ticks; the claim with its tolerance (the larger of the column and row differences, 0 … 2), the nearest
unlocated beacon rule and the miss cost; free markers (at most 8); energy; the truth metric (each located beacon's
localization error and their total); an immutable, fingerprinted level (width, height, walls, entry, beacons,
tolerance, energy, miss cost, tutorial, seed, id); the actions `pulse`, `claim`, `mark` with their refusals; the
action-wise evaluation (win, then energy); the play state machine with records, full undo, redo (undo from failed
returns to playing; a won level is final) and replay; and the rules as an R02-F23 `PuzzleRules`. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in
this feature (the shader interfaces come in R02-G11-03); no new package; one new target pair. **Package**:
`Packages/ExperiencesRound02/Package.swift` gains `EchoCartographerCore` (path `EchoCartographer/Core`), its tests
(`EchoCartographer/CoreTests`) and the product. **Numbers**: at most 16 × 16 = 256 cells, so every distance is at most
255 and every delay at most 24 · 255 = 6 120 ticks: plain `Int` arithmetic is exact. No floating point in the rules.
**Seeds**: fixtures use `SeededRandom(seed: 2_401)`; neighbouring-input checks seed 2_406. **Testing**:
`swift test --package-path Packages/ExperiencesRound02 --filter EchoCartographer`; regression as for 391.
**Performance**: a pulse walks at most 4 × 15 ray cells and one breadth-first search over at most 256 cells; a
500-trace test stays under 10 s. **Constraints**: additive; reason codes `r02-g11.*`; denylisted names (ProjectM,
PresetLibrary, MilkDrop …) avoided. **CI**: the existing `swift test` step of ExperiencesRound02 covers the new
targets; no workflow change.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests. |
| V Implementation Before Devices | PASS — no device work. |
| IX Bounded Untrusted Input | PASS — bounded ranges; stored levels re-checked on decode. |
| X Licensing and Provenance | PASS — the project's own archived design; original code. |
| XI One App and Stable Experience Identity | PASS — experience R02-G11; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                              edit  + EchoCartographerCore (lead)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerError.swift          new   (lead)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerChamber.swift        new   grid, cells, rays, path lengths, echo report (lead)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerLevel.swift          new   level, names, stored form (lead)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerPlay.swift           new   actions, knowledge, stages, records, undo, redo, replay (agent B)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerRules.swift          new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerFixtures.swift  new   seeded levels with known actions (lead)
Packages/ExperiencesRound02/EchoCartographer/CoreTests/{EchoCartographerLevelTests (lead), EchoCartographerChamberTests (A),
  EchoCartographerPlayTests (B), EchoCartographerRulesTests (C), EchoCartographerInvariantTests (D)}.swift
docs/architecture/echo-cartographer.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, chamber, level and fixtures first; then agents A (chamber tests with an independent reference:
rays and path lengths recomputed by a separate formulation — rays by explicit coordinate stepping, path lengths by
repeated relaxation instead of a queue — over seeded chambers), B (play), C (rules) and D (invariants) in parallel in
isolated package copies; the lead retests every agent result and records checks after every agent has reported.
