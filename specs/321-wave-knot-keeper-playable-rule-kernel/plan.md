# Implementation Plan: R02-G03-01 — Wave Knot Keeper: playable rule kernel

**Branch**: `321-wave-knot-keeper-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-20 |
**Spec**: [spec.md](spec.md)

## Summary

Add Wave Knot Keeper's pure rule kernel, `WaveKnotKeeperCore`, to `Packages/ExperiencesRound02` on the pattern of
Lissajous Labyrinth's (feature 311): an immutable, fingerprinted level (a closed integer rope, crossing gates, target,
tension bound, allowance), exact integer geometry (segment-triangle intersection for swept moves, projected crossings
with signs, degeneracy, tension), the play state machine with records, undo, redo and replay, and the rules as an R02-F23
`PuzzleRules`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`). No GPU, UIKit or Objective-C++ code; no new package; one new target pair.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains `WaveKnotKeeperCore` (path `WaveKnotKeeper/Core`), its
tests and the product.
**Numbers**: coordinates −16 … 16; orientation determinants of differences ≤ 32 fit easily in 64-bit integers; no floating
point in the rules.
**Seeds**: fixtures use `SeededRandom(seed: 2_321)`; neighbouring-input checks seed 2_326.
**Testing**: `swift test --package-path Packages/ExperiencesRound02`; regression as for 311.
**Performance**: a move tests 2 triangles against ≤ 16 segments; a summary tests ≤ 120 segment pairs; trivial.
**Constraints**: additive; reason codes `r02-g03.*`; denylisted names avoided.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests. |
| V Implementation Before Devices | PASS — no device work. |
| IX Bounded Untrusted Input | PASS — bounded points, coordinates, allowance; stored levels re-checked on decode. |
| X Licensing and Provenance | PASS — the project's own archived design; original code. |
| XI One App and Stable Experience Identity | PASS — experience R02-G03; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                   edit  + WaveKnotKeeperCore (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperError.swift                             new   (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperLevel.swift                             new   Point, Gate, Target, Level, stored form (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperGeometry.swift                          new   orientation, segment-triangle, projection, crossings, tension (agent A)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperPlay.swift                              new   stages, moves, records, undo, redo, fingerprints (agent B)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperRules.swift                             new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperFixtures.swift                     new   seeded levels with a known solution (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/{WaveKnotKeeperLevelTests (lead), WaveKnotKeeperGeometryTests (A), WaveKnotKeeperPlayTests (B),
  WaveKnotKeeperRulesTests (C), WaveKnotKeeperInvariantTests (D)}.swift      new
docs/architecture/wave-knot-keeper.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none. **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, level and fixtures first (the level's start check needs the geometry contract, so the lead writes
the geometry's signatures in contracts/api.md); then agents A (geometry), B (play), C (rules) and D (invariants) in
parallel; the lead retests every agent result and records checks after every agent has reported.
