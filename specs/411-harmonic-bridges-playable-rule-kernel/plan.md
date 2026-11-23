# Implementation Plan: R02-G12-01 — Harmonic Bridges: playable rule kernel

**Branch**: `411-harmonic-bridges-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-23 |
**Spec**: [spec.md](spec.md)

## Summary

Add Harmonic Bridges' pure rule kernel, `HarmonicBridgesCore`, to `Packages/ExperiencesRound02` on the pattern of Echo
Cartographer's (feature 401): 2 … 8 islands with drawing positions, a start and a goal; 1 … 12 strings joining distinct
island pairs, each with a length 1 … 6, a peg 1 … 12 and a locked flag; a crossing window of 1 … 4 steps, each sounding
1 … 3 distinct tones (frequency 1 … 72, strength 1 … 3); the exact resonance rule (tone F resonates mode n = F · L / p
when that is a whole number in 1 … 5); the swing table q(n, k) = 4 sin²(nπk/6) ∈ {0, 1, 3, 4} and the averaged swing
E(k) = Σ w · q(n, k) at the five interior samples; a string is a bridge in a step when every E(k) reaches the threshold
1 … 12; the bridge graph per step and the start's breadth-first reachable set; the actions `tune` and `test` (pluck as
a query) with their refusals; the action-wise evaluation (a test wins over every step or fails naming the first broken
step and string; a spent budget fails); the truth metric (every swing, bridge and reachable set per step); an immutable,
fingerprinted level; the play state machine with records, full undo, redo (undo from failed returns to playing; a won
level is final) and replay; and the rules as an R02-F23 `PuzzleRules`. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in
this feature (the shader interfaces come in R02-G12-03); no new package; one new target pair. **Package**:
`Packages/ExperiencesRound02/Package.swift` gains `HarmonicBridgesCore` (path `HarmonicBridges/Core`), its tests
(`HarmonicBridges/CoreTests`) and the product. **Numbers**: F · L ≤ 72 · 6 = 432; E(k) ≤ 3 tones · 3 · 4 = 36: plain
`Int` arithmetic is exact; the swing table is a fixed integer table, never computed with floating point. **Seeds**:
fixtures use `SeededRandom(seed: 2_411)`; neighbouring-input checks seed 2_416. **Testing**:
`swift test --package-path Packages/ExperiencesRound02 --filter HarmonicBridges`; regression as for 401.
**Performance**: a test evaluates at most 4 steps × 12 strings × 3 tones × 5 samples and a breadth-first search over 8
islands; a 500-trace test stays under 10 s. **Constraints**: additive; reason codes `r02-g12.*`; denylisted names
(ProjectM, PresetLibrary, MilkDrop …) avoided. **CI**: the `round02-host-tests` job's `swift test` covers the new targets;
no workflow change.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests. |
| V Implementation Before Devices | PASS — no device work. |
| IX Bounded Untrusted Input | PASS — bounded ranges; stored levels re-checked on decode. |
| X Licensing and Provenance | PASS — the project's own archived design; original code. |
| XI One App and Stable Experience Identity | PASS — experience R02-G12; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                               edit  + HarmonicBridgesCore (lead)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesError.swift             new   (lead)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesResonance.swift         new   swing table, resonance, swing, bridges, graph, reachability (lead)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesLevel.swift             new   islands, strings, steps, names, stored form (lead)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesPlay.swift              new   actions, stages, records, undo, redo, replay (agent B)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesRules.swift             new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesFixtures.swift     new   seeded levels with known actions (lead)
Packages/ExperiencesRound02/HarmonicBridges/CoreTests/{HarmonicBridgesLevelTests (lead), HarmonicBridgesResonanceTests (A),
  HarmonicBridgesPlayTests (B), HarmonicBridgesRulesTests (C), HarmonicBridgesInvariantTests (D)}.swift
docs/architecture/harmonic-bridges.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, resonance, level and fixtures first; then agents A (resonance tests with an independent
reference: the swing recomputed from the sine law with rational arithmetic on exact quarter values, resonance by
enumerating every mode n in 1 … 5 and comparing n · p with F · L, reachability by repeated relaxation instead of a
queue — over seeded levels), B (play), C (rules) and D (invariants) in parallel in isolated package copies; the lead
retests every agent result and records checks after every agent has reported.
