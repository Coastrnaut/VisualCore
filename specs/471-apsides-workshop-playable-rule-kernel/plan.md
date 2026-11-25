# Implementation Plan: R02-G18-01 — Apsides Workshop: playable rule kernel

**Branch**: `471-apsides-workshop-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-25 |
**Spec**: [spec.md](spec.md)

## Summary

Add Apsides Workshop's pure rule kernel, `ApsidesWorkshopCore`, to `Packages/ExperiencesRound02` on the pattern of
Celestial Eclipse Lab's (feature 461): a star at the origin of a sky of lattice units (256 sky units each); an orbit of
size a 8 … 48, eccentricity step k 0 … 15 (e = k/20) and periapsis direction step d 0 … 23 (15° each), valid when
a(20 − k) ≥ 60 and a(20 + k) ≤ 1280; a period of T ticks (even, 16 … 96); the orbiter's position at every tick from
Kepler's equation solved in deterministic integer fixed point (2^30 as one; integer sine, cosine and square root; at
most 8 Newton steps from E = M + e·sin M, stopping at a residual of 2^−24, then 48 bisection steps on [M − e, M + e]
when needed; every residual at most 2^−22), turned by 15d° and rounded to whole sky units; 8 sectors of 45° decided
exactly from signs and |x| against |y|; the swept share of each sector by one cross-product triangle per tick, in tenths
of a percent rounded down; apsis readings (sector ⌊d/3⌋ and ⌊(d + 12)/3⌋ mod 8, distances a(20 ∓ k) in twentieths);
exclusion planets with an exact strict segment-distance contact test; 1 … 6 ordered targets (sweeps and apsis
targets) with event ticks and the judge (`contact`, `order`, `share`, `apsis-sector`, `apsis-distance`, or won);
actions `periapsis(k, d)` and `size(a)` (one action each) and `play` (ends the level); an immutable, fingerprinted
level; the play state machine with records, full undo, redo (undo from failed returns to playing before the play; a won
level is final) and replay; and the rules as an R02-F23 `PuzzleRules` over orbits. Research: [research.md](research.md).
Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in
this feature; no new package; one new target pair. **Package**: `Packages/ExperiencesRound02/Package.swift` gains
`ApsidesWorkshopCore` (path `ApsidesWorkshop/Core`), its tests (`ApsidesWorkshop/CoreTests`) and the product.
**Numbers**: `Int64` fixed point with 2^30 as one; the mean anomaly is M = (twoPi · t) / T by truncating integer
division; the rotation factors for 15d° come from an exact quarter-turn table sin 15j° (j = 0 … 6, sin 0 = 0, sin 90° =
one, sin 45° = cos 45°) extended by symmetry, so a periapsis on a sector boundary lies exactly on it; sky positions
within ±64 × 256 = ±16,384 units; the size in sky units (≤ 12,288) is multiplied by a fixed-point factor (≤ 2^31) and
shifted to 2^16 as one before the rotation, so every product stays below 2^62; the contact test's products (squared
lengths ≤ 2^31, cross products squared ≤ 2^61) fit `Int64`; shares use `Int64` areas (≤ 2^31 per triangle × 96). No
platform floating point decides anything; `Double` appears only in tests' independent references and in the words.
**Seeds**: fixtures use `SeededRandom(seed: 2_471)`; neighbouring-input checks seed 2_476. **Testing**: `swift test
--package-path Packages/ExperiencesRound02 --filter ApsidesWorkshop`. **Performance**: an orbit is at most 96 Kepler
inversions of at most 56 steps; a 500-trace test stays under 10 s. **Constraints**: additive; reason codes `r02-g18.*`;
denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided. **CI**: the round-two host chunks of feature 457 gain
the new targets in chunk 3f (with the latest games); the `round02-host-tests` job's `swift test` covers them; no
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
| XI One App and Stable Experience Identity | PASS — experience R02-G18; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                              edit  + Core target (lead)
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopError.swift           new   (lead)
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopFixed.swift           new   fixed point, Kepler (lead)
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopOrbit.swift           new   orbit, sectors, judge (lead)
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopLevel.swift           new   level, words, stored form
(lead) Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopPlay.swift            new   play, records, replay
(B) Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopRules.swift           new   PuzzleRules (C)
Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopFixtures.swift   new   seeded levels (lead)
Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/{ApsidesWorkshopLevelTests (lead), …OrbitTests (A), …PlayTests
(B), …RulesTests (C), …InvariantTests (D)}.swift docs/architecture/apsides-workshop.md (new),
Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead) ```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, fixed point, orbit, level and fixtures first; then agents A (orbit tests with independent
references: positions against a `Double` Kepler solution within 2 sky units, every residual within 2^−22, and sectors,
shares, apsis readings, contact decisions and the judge recomputed by direct enumeration on the kernel's integer
positions over seeded orbits), B (play), C (rules) and D (invariants) in parallel in isolated package copies; agents
compile but run no tests while the lead's runs are going; the lead retests every agent result and records checks after
every agent has reported.
