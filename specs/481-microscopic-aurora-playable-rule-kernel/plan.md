# Implementation Plan: R02-G19-01 — Microscopic Aurora: playable rule kernel

**Branch**: `481-microscopic-aurora-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-26 |
**Spec**: [spec.md](spec.md)

## Summary

Add Microscopic Aurora's pure rule kernel, `MicroscopicAuroraCore`, to `Packages/ExperiencesRound02` on the pattern of
Apsides Workshop's (feature 471): a dish of 24 × 24 cells (256 dish units each) with a round enclosure of radius R
6 … 11 cells about (3072, 3072), the rim inside; a swarm of 4 … 16 swimmers with integer positions and velocities; a
swim of T ticks (120 … 480), each a synchronous step of separation (within σ), alignment and cohesion (within ρ) with
weights 0 … 8 and the divisors 64, 16 and 256, plus the curl acceleration sense·s·4096·(−dy, dx)/(dx² + dy² + 65536) of
up to three wells, every division truncating toward zero, the acceleration clamped to ±a_max and the velocity to
±v_max per axis, then p ← p + v; coincident swimmers separated along ±x by index; trail density per cell over ticks
1 … T, lit at the threshold; coverage of the stencil in tenths of a percent rounded down; connectedness as exactly one
four-neighbour group of lit stencil cells; coherence as the largest group of swimmers linked within κ; the judge
(`exit`, `coherence`, `coverage`, `connectedness`, or won) in that order; actions `place(slot, row, column, strength,
sense)` and `remove(slot)` (one action each) and `play` (ends the level); an immutable, fingerprinted level; the play
state machine with records, full undo, redo (undo from failed returns to playing before the play; a won level is final)
and replay; and the rules as an R02-F23 `PuzzleRules` over well placements. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them (audited 2026-11-26 in
`Packages/ExperiencesRound02/Package.swift`, where `ApsidesWorkshopCore` depends on both). No GPU, UIKit,
Objective-C++ or GLSL code in this feature; no new package; one new target pair. **Package**:
`Packages/ExperiencesRound02/Package.swift` gains `MicroscopicAuroraCore` (path `MicroscopicAurora/Core`), its tests
(`MicroscopicAurora/CoreTests`) and the product. **Numbers**: `Int64` throughout; positions 0 … 6143 (a swimmer leaves
the dish only by leaving the enclosure first, which ends the swim); velocities within ±48; the curl numerator
4 · 4096 · 6144 ≈ 2^27 over a denominator ≥ 65,536; squared distances ≤ 2 · 6144² < 2^27; densities ≤ 16 · 480. Nothing
approaches 2^62; no platform floating point decides anything; `Double` appears only in the words. **Seeds**: fixtures
use `SeededRandom(seed: 2_481)`; neighbouring-input checks seed 2_486. **Testing**: `swift test --package-path
Packages/ExperiencesRound02 --filter MicroscopicAurora`. **Performance**: one swim is at most 480 ticks × 16² pair
tests for the swarm and 16² for coherence, about 250,000 integer pair tests; a 500-swim test stays under 10 s.
**Constraints**: additive; reason codes `r02-g19.*`; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided.
**CI**: the round-two host chunk 3e (`FacetedForge|NocturneGarden|BackwardsAurora`) gains `MicroscopicAurora`; the
`round02-host-tests` job's `swift test` covers the new targets; no workflow change. **Seed convention**: a level's seed
is a `UInt64` stored in the level and its records; nothing in the kernel draws random numbers.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests. |
| V Implementation Before Devices | PASS — no device work. |
| IX Bounded Untrusted Input | PASS — bounded ranges; stored levels re-checked on decode. |
| X Licensing and Provenance | PASS — the project's own archived design; original code. |
| XI One App and Stable Experience Identity | PASS — experience R02-G19; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                               edit  + Core target (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraError.swift         new   (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSwim.swift          new   swarm step, trails, judge (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraLevel.swift         new   level, words, stored form (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraPlay.swift          new   play, records, replay (B)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraPuzzle.swift        new   PuzzleRules (C)
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraFixtures.swift new   seeded levels (lead)
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/{MicroscopicAuroraLevelTests (lead), …SwimTests (A),
    …PlayTests (B), …PuzzleTests (C), …InvariantTests (D)}.swift
docs/architecture/microscopic-aurora.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, swim, level and fixtures first; then agents A (swim tests with an independent reference: a
second, straightforward implementation of the tick law, trails, coverage, groups and coherence written from the spec's
clarifications, compared on 500 seeded swims), B (play), C (rules) and D (invariants) in parallel in isolated package
copies; agents compile but run no tests while the lead's runs are going; the lead retests every agent result and
records checks after every agent has reported.
