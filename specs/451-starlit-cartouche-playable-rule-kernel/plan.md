# Implementation Plan: R02-G16-01 — Starlit Cartouche: playable rule kernel

**Branch**: `451-starlit-cartouche-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-24 |
**Spec**: [spec.md](spec.md)

## Summary

Add Starlit Cartouche's pure rule kernel, `StarlitCartoucheCore`, to `Packages/ExperiencesRound02` on the pattern of
Voxel Origami's (feature 441): 4 … 12 stars, each on a periodic orbit of 1 … 4 lattice positions with a distinct glyph
point on a 5 × 5 grid; undirected corridors with travel times 1 … 3 beats, flyable when the two stars are within the
level's range r at the departure beat (squared distance ≤ r²); star time windows; hazard tubes (a corridor and a closed
beat interval); a leg `leg(j, w)` that waits w beats (0 … 8) and flies one corridor; the failures in their fixed order
(`window` at departure, `hazard`, `window` at arrival, `deadline`, `stroke`); the win (drawn corridors equal the
symbol's strokes and the ship at the beacon) and the spent budget (`budget`); the truth metric (missing and stray
strokes, glyph mismatch, hazard clearance); an immutable, fingerprinted level; the play state machine with records,
full undo, redo (undo from failed returns to playing before the failing leg; a won level is final) and replay; and the
rules as an R02-F23 `PuzzleRules`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in
this feature; no new package; one new target pair. **Package**: `Packages/ExperiencesRound02/Package.swift` gains
`StarlitCartoucheCore` (path `StarlitCartouche/Core`), its tests (`StarlitCartouche/CoreTests`) and the product.
**Numbers**: at most 12 stars, coordinates within ±8, squared distances at most 768, beats at most 64 + 3: plain `Int`
arithmetic is exact. **Seeds**: fixtures use `SeededRandom(seed: 2_451)`; neighbouring-input checks seed 2_456.
**Testing**: `swift test --package-path Packages/ExperiencesRound02 --filter StarlitCartouche`. **Performance**: a leg
checks at most 8 hazards; a 500-trace test stays under 10 s. **Constraints**: additive; reason codes `r02-g16.*`;
denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided. **CI**: the `round02-host-tests` job's `swift test`
covers the new targets; no workflow change.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests. |
| V Implementation Before Devices | PASS — no device work. |
| IX Bounded Untrusted Input | PASS — bounded ranges; stored levels re-checked on decode. |
| X Licensing and Provenance | PASS — the project's own archived design; original code. |
| XI One App and Stable Experience Identity | PASS — experience R02-G16; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                          edit  + StarlitCartoucheCore (lead)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheError.swift      new   (lead)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheChart.swift      new   stars, orbits, range, corridors, leg check, strokes, report (lead)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheLevel.swift      new   level, names, stored form (lead)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartouchePlay.swift       new   actions, stages, records, undo, redo, replay (agent B)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheRules.swift      new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheFixtures.swift  new  seeded levels with known legs (lead)
Packages/ExperiencesRound02/StarlitCartouche/CoreTests/{StarlitCartoucheLevelTests (lead), StarlitCartoucheChartTests (A),
  StarlitCartouchePlayTests (B), StarlitCartoucheRulesTests (C), StarlitCartoucheInvariantTests (D)}.swift
docs/architecture/starlit-cartouche.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, chart, level and fixtures first; then agents A (chart tests with an independent reference: star
positions, range, arrival beats, hazard meeting, windows, stroke sets and mismatch recomputed by direct enumeration of
every beat of each leg over seeded levels), B (play), C (rules) and D (invariants) in parallel in isolated package
copies; the lead retests every agent result and records checks after every agent has reported.
