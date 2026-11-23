# Implementation Plan: R02-G13-01 — Acoustic Constellator: playable rule kernel

**Branch**: `421-acoustic-constellator-playable-rule-kernel` (spec directory only; work on `main`) | **Date**:
2026-11-23 | **Spec**: [spec.md](spec.md)

## Summary

Add Acoustic Constellator's pure rule kernel, `AcousticConstellatorCore`, to `Packages/ExperiencesRound02` on the
pattern of Harmonic Bridges's (feature 411): 3 … 8 stars with natural rates and starting phases on a 12-step clock and
drawing positions; fixed links; a connected target symbol of star pairs; the exact tick (the whole-number coupling
table t(0 … 6) = 0, 1, 2, 2, 2, 1, 0, the pull summed over current links, the coupling step ⌊K · P / 4⌋ clamped to
−1 … 1, all stars moved at once modulo 12); snapping of links whose gap exceeds the snap limit; the exact order
parameter n²R² = A + B√3 and its exact comparison with the threshold; the actions `link`, `unlink`, `nudge` and
`listen` with their refusals; the action-wise evaluation (a listen fails `missing`, `disconnected` or `incoherent`, or
wins after the hold; a spent budget fails); the truth metric (a listen report of the current state and the
graph-isomorphism label with its match to the symbol); an immutable, fingerprinted level; the play state machine with
records, full undo, redo (undo from failed returns to playing; a won level is final) and replay; and the rules as an
R02-F23 `PuzzleRules`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in
this feature (the shader interfaces come in R02-G13-03); no new package; one new target pair. **Package**:
`Packages/ExperiencesRound02/Package.swift` gains `AcousticConstellatorCore` (path `AcousticConstellator/Core`), its
tests (`AcousticConstellator/CoreTests`) and the product. **Numbers**: |P| ≤ 4 links · 2 = 8, K · P ≤ 64; A and B are
at most n + 2·28 = 64 in magnitude and the comparison squares stay below 2¹⁶: plain `Int` arithmetic is exact; the
coupling and gap tables are fixed integer tables, never computed with floating point. **Label**: at most 8! = 40,320
orderings × 28 pairs per label, computed once per action. **Seeds**: fixtures use `SeededRandom(seed: 2_421)`;
neighbouring-input checks seed 2_426. **Testing**: `swift test --package-path Packages/ExperiencesRound02 --filter
AcousticConstellator`; regression as for 411. **Performance**: a listen runs at most 48 ticks × 8 stars × 4 links plus
a connectivity check per tick; a 500-trace test stays under 10 s. **Constraints**: additive; reason codes `r02-g13.*`;
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
| XI One App and Stable Experience Identity | PASS — experience R02-G13; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                      edit  + AcousticConstellatorCore (lead)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorError.swift          new   (lead)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorDynamics.swift       new   clock, coupling, tick, snap, order parameter, listen, label (lead)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorLevel.swift          new   stars, links, symbol, names, stored form (lead)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorPlay.swift           new   actions, stages, records, undo, redo, replay (agent B)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorRules.swift          new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorFixtures.swift  new   seeded levels with known actions (lead)
Packages/ExperiencesRound02/AcousticConstellator/CoreTests/{AcousticConstellatorLevelTests (lead),
  AcousticConstellatorDynamicsTests (A), AcousticConstellatorPlayTests (B), AcousticConstellatorRulesTests (C),
  AcousticConstellatorInvariantTests (D)}.swift
docs/architecture/acoustic-constellator.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, dynamics, level and fixtures first; then agents A (dynamics tests with an independent reference:
phases advanced with the coupling recomputed from 2·sin(πd/6) rounded at runtime, the order parameter checked against
|Σ e^{iπφ/6}|² in floating point with a margin and the exact comparison against rational bounds of √3, connectivity by
repeated relaxation, the label by brute force over permutations — over seeded levels), B (play), C (rules) and D
(invariants) in parallel in isolated package copies; the lead retests every agent result and records checks after
every agent has reported.
