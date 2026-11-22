# Implementation Plan: R02-G07-01 — Amethyst Escape: playable rule kernel

**Branch**: `361-amethyst-escape-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-22 |
**Spec**: [spec.md](spec.md)

## Summary

Add Amethyst Escape's pure rule kernel, `AmethystEscapeCore`, to `Packages/ExperiencesRound02` on the pattern of Chrono
Constellator's (feature 351): an immutable, fingerprinted level (sector count, nested shells with outer apertures,
radial walls and blocked wedges, the pearl's start, the move budget, the single exit gap), the crystal state (shell
offsets and the pearl's pocket) with exact rotation and the deterministic advance transition of clarification Q2, the
move-wise evaluation (exit, wedge, budget), the play state machine with records, full undo, redo and replay, and the
rules as an R02-F23 `PuzzleRules`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in this
feature (the shader interfaces come in R02-G07-03); no new package; one new target pair.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains `AmethystEscapeCore` (path `AmethystEscape/Core`), its
tests (`AmethystEscape/CoreTests`) and the product.
**Numbers**: at most 5 shells × 12 sectors = 60 pockets, offsets 0 … 11 and 60 moves; all integer, no floating point in
the rules.
**Seeds**: fixtures use `SeededRandom(seed: 2_361)`; neighbouring-input checks seed 2_366.
**Testing**: `swift test --package-path Packages/ExperiencesRound02 --filter AmethystEscape`; regression as for 351.
**Performance**: a rotation is one modular addition; an advance is at most two set look-ups; a 60-move run is under
200 operations.
**Constraints**: additive; reason codes `r02-g07.*`; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided.
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
| XI One App and Stable Experience Identity | PASS — experience R02-G07; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                         edit  + AmethystEscapeCore (lead)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeError.swift         new   (lead)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeLevel.swift         new   shells, level, names, stored form (lead)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeCrystal.swift       new   offsets, pearl, rotate, advance, verdict (lead)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapePlay.swift          new   stages, actions, records, undo, redo, fingerprints, replay (agent B)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeRules.swift         new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeFixtures.swift new   seeded levels with a known solution (lead)
Packages/ExperiencesRound02/AmethystEscape/CoreTests/{AmethystEscapeLevelTests (lead), AmethystEscapeCrystalTests (A),
  AmethystEscapePlayTests (B), AmethystEscapeRulesTests (C), AmethystEscapeInvariantTests (D)}.swift   new
docs/architecture/amethyst-escape.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, level, crystal and fixtures first; then agents A (crystal tests with an independent pocket-graph
reference), B (play), C (rules) and D (invariants) in parallel in isolated package copies; the lead retests every agent
result and records checks after every agent has reported.
