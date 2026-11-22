# Implementation Plan: R02-G08-01 — Faceted Forge: playable rule kernel

**Branch**: `371-faceted-forge-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-22 |
**Spec**: [spec.md](spec.md)

## Summary

Add Faceted Forge's pure rule kernel, `FacetedForgeCore`, to `Packages/ExperiencesRound02` on the pattern of Amethyst
Escape's (feature 361): an exact fraction type of checked 64-bit integers; the 13 named plane directions; a convex piece
given by its bounding half-spaces with its exact corners, ordered faces, edges and signed-tetrahedra volume; an
immutable, fingerprinted level (crystal half-spaces, cut budget, sliver limit, target of share and face count); the cut
of clarification Q2 with the degenerate refusal; the cut-wise evaluation (sliver, win, budget); the play state machine
with records, full undo, redo and replay; and the rules as an R02-F23 `PuzzleRules`. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in this
feature (the shader interfaces come in R02-G08-03); no new package; one new target pair.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains `FacetedForgeCore` (path `FacetedForge/Core`), its tests
(`FacetedForge/CoreTests`) and the product.
**Numbers**: directions with components in {−1, 0, 1}, depths −24 … 24, crystal inside −6 … 6; a corner solves three
such planes (Cramer's rule, determinant at most 4 in size), so numerators and denominators stay far below 2^31; every
operation is checked and an overflow refuses the action. No floating point in the rules.
**Seeds**: fixtures use `SeededRandom(seed: 2_371)`; neighbouring-input checks seed 2_376.
**Testing**: `swift test --package-path Packages/ExperiencesRound02 --filter FacetedForge`; regression as for 361.
**Performance**: a piece has at most 14 + 12 = 26 planes; its corners come from at most C(26, 3) = 2,600 triples,
each checked against 26 planes; a cut is well under a millisecond; a 500-trace test stays under 10 s.
**Constraints**: additive; reason codes `r02-g08.*`; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided.
**CI**: the existing `swift test` step of ExperiencesRound02 covers the new targets; no workflow change.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests. |
| V Implementation Before Devices | PASS — no device work. |
| IX Bounded Untrusted Input | PASS — bounded ranges; stored levels re-checked on decode; checked arithmetic. |
| X Licensing and Provenance | PASS — the project's own archived design; original code. |
| XI One App and Stable Experience Identity | PASS — experience R02-G08; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                  edit  + FacetedForgeCore (lead)
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeError.swift      new   (lead)
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeFraction.swift   new   checked exact fractions (lead)
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgePiece.swift      new   directions, planes, corners, faces, volume (lead)
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeLevel.swift      new   level, target, names, stored form (lead)
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgePlay.swift       new   cut, stages, records, undo, redo, replay (agent B)
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeRules.swift      new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeFixtures.swift new  seeded levels with a known solution (lead)
Packages/ExperiencesRound02/FacetedForge/CoreTests/{FacetedForgeFractionTests, FacetedForgeLevelTests (lead),
  FacetedForgePieceTests (A), FacetedForgePlayTests (B), FacetedForgeRulesTests (C), FacetedForgeInvariantTests (D)}.swift
docs/architecture/faceted-forge.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, fraction, piece, level and fixtures first; then agents A (piece tests with an independent
reference: corners by brute force over all plane triples and volume by the divergence theorem over faces), B (play), C
(rules) and D (invariants) in parallel in isolated package copies; the lead retests every agent result and records
checks after every agent has reported.
