# Implementation Plan: R02-G15-01 — Voxel Origami: playable rule kernel

**Branch**: `441-voxel-origami-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-24 |
**Spec**: [spec.md](spec.md)

## Summary

Add Voxel Origami's pure rule kernel, `VoxelOrigamiCore`, to `Packages/ExperiencesRound02` on the pattern of Moonlit
Mechanism's (feature 431): a tree of 4 … 12 unit cubes (cube 0 the root at the origin, every other cube attached face
to face to a lower-index parent along one of six rest directions in the parent's frame), one hinge per non-root cube
with a quarter turn 0 … 3; poses computed from the root with the 24 integer rotation matrices of the cube
(x(i) = x(p) + O(p)·d(i), O(i) = O(p)·R(d(i), q(i))), so a turn of hinge i twists the cubes beyond i about the line
from its parent through i; the end-pose `collision` and the swept-band `sweep` decisions in integer squares; the
target matched up to translation and the level's allowed group (`fixed`, `upright`, `any`) through a canonical form
and its SHA-256 hash; the spent budget (`budget`); the truth metric (occupancy, canonical hash, covered count of the
best alignment); an immutable, fingerprinted level; the play state machine with records, full undo, redo (undo from
failed returns to playing before the failing turn; a won level is final) and replay; and the rules as an R02-F23
`PuzzleRules`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in
this feature (the shader interfaces come in R02-G15-03); no new package; one new target pair. **Package**:
`Packages/ExperiencesRound02/Package.swift` gains `VoxelOrigamiCore` (path `VoxelOrigami/Core`), its tests
(`VoxelOrigami/CoreTests`) and the product. **Numbers**: at most 12 cubes, coordinates within ±12, squared distances
below 600: plain `Int` arithmetic is exact; cell sets are sorted arrays of integer triples. **Seeds**: fixtures use
`SeededRandom(seed: 2_441)`; neighbouring-input checks seed 2_446. **Testing**: `swift test --package-path
Packages/ExperiencesRound02 --filter VoxelOrigami`. **Performance**: a turn checks at most 11 swinging × 11 still cubes;
the covered count tries at most 24 rotations × the translations that align one cell pair (≤ 144) × 12 cells; a
500-trace test stays under 10 s. **Constraints**: additive; reason codes `r02-g15.*`; denylisted names (ProjectM,
PresetLibrary, MilkDrop …) avoided. **CI**: the `round02-host-tests` job's `swift test` covers the new targets; no
workflow change.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests. |
| V Implementation Before Devices | PASS — no device work. |
| IX Bounded Untrusted Input | PASS — bounded ranges; stored levels re-checked on decode. |
| X Licensing and Provenance | PASS — the project's own archived design; original code. |
| XI One App and Stable Experience Identity | PASS — experience R02-G15; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                    edit  + VoxelOrigamiCore (lead)
Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiError.swift        new   (lead)
Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiLattice.swift      new   vectors, rotations, poses, turn, collision, sweep, canonical form (lead)
Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiLevel.swift        new   cubes, target, orientations, names, stored form (lead)
Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiPlay.swift         new   actions, stages, records, undo, redo, replay (agent B)
Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiRules.swift        new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiFixtures.swift  new  seeded levels with known actions (lead)
Packages/ExperiencesRound02/VoxelOrigami/CoreTests/{VoxelOrigamiLevelTests (lead), VoxelOrigamiLatticeTests (A),
  VoxelOrigamiPlayTests (B), VoxelOrigamiRulesTests (C), VoxelOrigamiInvariantTests (D)}.swift
docs/architecture/voxel-origami.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, lattice, level and fixtures first; then agents A (lattice tests with an independent reference:
poses recomputed by rotating each subtree's cell list directly about its hinge line one quarter turn at a time from
the rest pose, collision by a set intersection, the sweep by sampling the quarter arc at 1 000 fine steps with a
cube-overlap test and comparing with the exact band rule on the cases where sampling is unambiguous, canonical forms by
enumerating all rotations and translations — over seeded levels), B (play), C (rules) and D (invariants) in parallel in
isolated package copies; the lead retests every agent result and records checks after every agent has reported.
