# Implementation Plan: R02-G14-01 — Moonlit Mechanism: playable rule kernel

**Branch**: `431-moonlit-mechanism-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-24 |
**Spec**: [spec.md](spec.md)

## Summary

Add Moonlit Mechanism's pure rule kernel, `MoonlitMechanismCore`, to `Packages/ExperiencesRound02` on the pattern of
Acoustic Constellator's (feature 421): a train of 2 … 5 gears (gear 0 the driver, every other gear meshing with one
lower-index parent) with tooth counts 6 … 20, whole-tooth phases, blade patterns, depths and placements; the exact
handle turn (every gear by ±1 tooth in its direction, alternating with its distance from the driver), re-seats of one
gear and lamp steps; the mesh alignment (phaseₚ + phase_c) mod gcd(Tₚ, T_c) = a and its cyclic error; the shadow cast
on a W × H wall from each gear's slot table, shifted down by lamp height · depth; the key frames (handle-turn counts,
targets, required flags) with forbidden cells and a stray allowance; the run decision order (`jammed`, then per key
frame `forbidden`, `missing`, `stray`, else won) and the spent budget (`budget`); the truth metric (alignment errors
and per-key-frame overlap counts); an immutable, fingerprinted level; the play state machine with records, full undo,
redo (undo from failed returns to playing; a won level is final) and replay; and the rules as an R02-F23
`PuzzleRules`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in
this feature (the shader interfaces come in R02-G14-03); no new package; one new target pair. **Package**:
`Packages/ExperiencesRound02/Package.swift` gains `MoonlitMechanismCore` (path `MoonlitMechanism/Core`), its tests
(`MoonlitMechanism/CoreTests`) and the product. **Numbers**: phases below 20, handle turns of a key frame at most a few
hundred, cells below 24 · 16 = 384: plain `Int` arithmetic is exact; cell sets are sorted arrays of cell numbers.
**Seeds**: fixtures use `SeededRandom(seed: 2_431)`; neighbouring-input checks seed 2_436. **Testing**: `swift test
--package-path Packages/ExperiencesRound02 --filter MoonlitMechanism`. **Performance**: a run casts at most 6 key frames
× 5 gears × 20 blades × 64 offsets; a 500-trace test stays under 10 s. **Constraints**: additive; reason codes
`r02-g14.*`; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided. **CI**: the `round02-host-tests` job's
`swift test` covers the new targets; no workflow change.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests. |
| V Implementation Before Devices | PASS — no device work. |
| IX Bounded Untrusted Input | PASS — bounded ranges; stored levels re-checked on decode. |
| X Licensing and Provenance | PASS — the project's own archived design; original code. |
| XI One App and Stable Experience Identity | PASS — experience R02-G14; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                          edit  + MoonlitMechanismCore (lead)
Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismError.swift      new   (lead)
Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismMechanics.swift  new   train, turn, alignment, cast, run (lead)
Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismLevel.swift      new   gears, key frames, names, stored form (lead)
Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismPlay.swift       new   actions, stages, records, undo, redo, replay (agent B)
Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismRules.swift      new   PuzzleRules conformance (agent C)
Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismFixtures.swift  new  seeded levels with known actions (lead)
Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/{MoonlitMechanismLevelTests (lead),
  MoonlitMechanismMechanicsTests (A), MoonlitMechanismPlayTests (B), MoonlitMechanismRulesTests (C),
  MoonlitMechanismInvariantTests (D)}.swift
docs/architecture/moonlit-mechanism.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, mechanics, level and fixtures first; then agents A (mechanics tests with an independent
reference: phases recomputed by walking the train from the driver one turn at a time, shadows rasterised by a separate
loop over blades and offsets into a W × H boolean grid, alignment by brute force over all re-seats, the run decision
by a direct transcription of clarification Q4 — over seeded levels), B (play), C (rules) and D (invariants) in
parallel in isolated package copies; the lead retests every agent result and records checks after every agent has
reported.
