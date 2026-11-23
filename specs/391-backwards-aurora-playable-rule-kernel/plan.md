# Implementation Plan: R02-G10-01 — Backwards Aurora: playable rule kernel

**Branch**: `391-backwards-aurora-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-22 |
**Spec**: [spec.md](spec.md)

## Summary

Add Backwards Aurora's pure rule kernel, `BackwardsAuroraCore`, to `Packages/ExperiencesRound02` on the pattern of
Nocturne Garden's (feature 381): the wave as N signed integer samples (N 12 … 32, heights −64 … 64); the bend
b(k) = s(k − 1) − 2·s(k) + s(k + 1) at every interior position; the reversal of a section [i, j] and its seam positions
(i − 1, i, j, j + 1 where they exist), the only bends a reversal can change; the checkpoint test (sample equals the
target's); the truth metric (distance Σ|s − t| / Σ|t| as an exact fraction and the worst bend); an immutable,
fingerprinted level (opening and target waves with the same multiset of heights, checkpoints, bend limit L, breaking
limit B, shortest and longest section, budget, tutorial, seed, id); the one action `reverse(start, end)` with its
refusals; the action-wise evaluation (tear, then win, then budget); the play state machine with records, full undo,
redo (undo from failed returns to playing; a won level is final) and replay; and the rules as an R02-F23
`PuzzleRules`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in
this feature (the shader interfaces come in R02-G10-03); no new package; one new target pair. **Package**:
`Packages/ExperiencesRound02/Package.swift` gains `BackwardsAuroraCore` (path `BackwardsAurora/Core`), its tests
(`BackwardsAurora/CoreTests`) and the product. **Numbers**: at most 32 samples of magnitude at most 64, so every bend
is at most 256 in magnitude and every distance sum at most 32 · 128 = 4 096: plain `Int` arithmetic is exact. No
floating point in the rules. **Seeds**: fixtures use `SeededRandom(seed: 2_391)`; neighbouring-input checks seed
2_396. **Testing**: `swift test --package-path Packages/ExperiencesRound02 --filter BackwardsAurora`; regression as
for 381. **Performance**: a reversal touches at most 32 samples and re-checks at most four seam bends; win checks at
most 30 bends and 8 checkpoints; a 500-trace test stays under 10 s. **Constraints**: additive; reason codes
`r02-g10.*`; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided. **CI**: the existing `swift test` step of
ExperiencesRound02 covers the new targets; no workflow change.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests. |
| V Implementation Before Devices | PASS — no device work. |
| IX Bounded Untrusted Input | PASS — bounded ranges; stored levels re-checked on decode. |
| X Licensing and Provenance | PASS — the project's own archived design; original code. |
| XI One App and Stable Experience Identity | PASS — experience R02-G10; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                         edit  + BackwardsAuroraCore (lead)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraError.swift       new   (lead)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraWave.swift        new   samples, bends, seams, reversal, distance (lead)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraLevel.swift       new   level, names, stored form (lead)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraPlay.swift        new   action, stages, records, undo, redo, replay (agent B)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraRules.swift       new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraFixtures.swift new  seeded levels with known reversals (lead)
Packages/ExperiencesRound02/BackwardsAurora/CoreTests/{BackwardsAuroraLevelTests (lead), BackwardsAuroraWaveTests (A),
  BackwardsAuroraPlayTests (B), BackwardsAuroraRulesTests (C), BackwardsAuroraInvariantTests (D)}.swift
docs/architecture/backwards-aurora.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, wave, level and fixtures first; then agents A (wave tests with an independent reference: bends,
reversal and distance recomputed from scratch over the whole wave by a separate formulation, and the seam claim checked
by comparing every bend before and after), B (play), C (rules) and D (invariants) in parallel in isolated package
copies; the lead retests every agent result and records checks after every agent has reported.
