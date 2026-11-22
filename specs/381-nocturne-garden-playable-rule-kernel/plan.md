# Implementation Plan: R02-G09-01 — Nocturne Garden: playable rule kernel

**Branch**: `381-nocturne-garden-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-22 |
**Spec**: [spec.md](spec.md)

## Summary

Add Nocturne Garden's pure rule kernel, `NocturneGardenCore`, to `Packages/ExperiencesRound02` on the pattern of
Faceted Forge's (feature 371): the six named bloom kinds as fixed lattice polygons; a bloom (kind, anchor cell, size)
whose outline is scaled and stretched by the sun factor e/2 about its foot; the exact cell test of clarification Q2
(doubled integer coordinates, winding number, boundary counted inside); the shadow mask as the union of all blooms'
cells in the bed; the match |M ∩ T| / |M ∪ T| compared with the required fraction by cross multiplication, the leak
|M ∩ F| and the boundary deviation (grid Hausdorff over boundary cells, the truth metric); an immutable, fingerprinted
level (bed, target and forbidden cells, supply, ranges, budget, required match, leak allowance, opening sun); the five
actions with their refusals; the action-wise evaluation (leak, win, budget); the play state machine with records, full
undo, redo and replay; and the rules as an R02-F23 `PuzzleRules`. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in this
feature (the shader interfaces come in R02-G09-03); no new package; one new target pair.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains `NocturneGardenCore` (path `NocturneGarden/Core`), its
tests (`NocturneGarden/CoreTests`) and the product.
**Numbers**: bed at most 32 × 24 cells; outlines at most 3 × 6 cells at size 1, scaled by at most 3 and stretched by at
most 2, so every doubled coordinate stays below 2^10 and every cross product below 2^22: plain `Int` arithmetic is
exact. No floating point in the rules.
**Seeds**: fixtures use `SeededRandom(seed: 2_381)`; neighbouring-input checks seed 2_386.
**Testing**: `swift test --package-path Packages/ExperiencesRound02 --filter NocturneGarden`; regression as for 371.
**Performance**: a mask is at most 768 cells; a bloom's shadow tests at most the cells of its bounding box (at most
9 × 36); an action recomputes the union from scratch (at most a few dozen blooms) well under a millisecond; a 500-trace
test stays under 10 s.
**Constraints**: additive; reason codes `r02-g09.*`; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided.
**CI**: the existing `swift test` step of ExperiencesRound02 covers the new targets; no workflow change.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests. |
| V Implementation Before Devices | PASS — no device work. |
| IX Bounded Untrusted Input | PASS — bounded ranges; stored levels re-checked on decode. |
| X Licensing and Provenance | PASS — the project's own archived design; original code and original bloom outlines. |
| XI One App and Stable Experience Identity | PASS — experience R02-G09; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                      edit  + NocturneGardenCore (lead)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenError.swift      new   (lead)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenBloom.swift      new   kinds, outlines, cast polygon, cells (lead)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenMask.swift       new   mask, match, leak, boundary deviation (lead)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenLevel.swift      new   level, names, stored form (lead)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenPlay.swift       new   actions, stages, records, undo, redo, replay (agent B)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenRules.swift      new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenFixtures.swift new  seeded levels with a known arrangement (lead)
Packages/ExperiencesRound02/NocturneGarden/CoreTests/{NocturneGardenLevelTests (lead), NocturneGardenBloomTests (A),
  NocturneGardenPlayTests (B), NocturneGardenRulesTests (C), NocturneGardenInvariantTests (D)}.swift
docs/architecture/nocturne-garden.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, bloom, mask, level and fixtures first; then agents A (bloom and mask tests with an independent
reference: cell tests by a separate even-odd ray-casting on rational coordinates and the deviation by brute force over
cell pairs), B (play), C (rules) and D (invariants) in parallel in isolated package copies; the lead retests every agent
result and records checks after every agent has reported.
