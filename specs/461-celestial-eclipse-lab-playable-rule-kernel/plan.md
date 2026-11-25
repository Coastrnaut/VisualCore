# Implementation Plan: R02-G17-01 — Celestial Eclipse Lab: playable rule kernel

**Branch**: `461-celestial-eclipse-lab-playable-rule-kernel` (spec directory only; work on `main`) | **Date**:
2026-11-25 | **Spec**: [spec.md](spec.md)

## Summary

Add Celestial Eclipse Lab's pure rule kernel, `CelestialEclipseLabCore`, to `Packages/ExperiencesRound02` on the pattern
of Starlit Cartouche's (feature 451): 2 … 6 bodies, each on a periodic orbit of 4 … 24 lattice positions with a disc
radius 1 … 8, fixed or movable, kept in one front-to-back depth order for every pair; a phase per body (the starting
offset along its orbit); a horizon of 8 … 96 ticks; a target sequence of 1 … 6 eclipses (front, back, window); the
eclipse test in integers (squared projected distance below the squared sum of the radii), eclipse events (the first
tick of each run), visibility classes (partial, total, annular) and the timeline judge (`unwanted`, `window`,
`horizon`, or won); actions `phase(body, offset)` (one action each) and `run` (ends the level); an immutable,
fingerprinted level; the play state machine with records, full undo, redo (undo from failed returns to playing before
the run; a won level is final) and replay; and the rules as an R02-F23 `PuzzleRules` over phase vectors. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them. No GPU, UIKit, Objective-C++ or GLSL code in
this feature; no new package; one new target pair. **Package**: `Packages/ExperiencesRound02/Package.swift` gains
`CelestialEclipseLabCore` (path `CelestialEclipseLab/Core`), its tests (`CelestialEclipseLab/CoreTests`) and the
product. **Numbers**: coordinates within ±32, so squared distances are at most 2 × 64² = 8,192 and squared radius sums
at most 256; ticks at most 96 + 24: plain `Int` arithmetic is exact. **Seeds**: fixtures use `SeededRandom(seed:
2_461)`; neighbouring-input checks seed 2_466. **Testing**: `swift test --package-path Packages/ExperiencesRound02
--filter CelestialEclipseLab`. **Performance**: a timeline is at most 15 pairs × 96 ticks; a 500-trace test stays under
10 s. **Constraints**: additive; reason codes `r02-g17.*`; denylisted names (ProjectM, PresetLibrary, MilkDrop …)
avoided. **CI**: the round-two host chunks of feature 457 gain the new targets in chunk 3c (with the first games); the
`round02-host-tests` job's `swift test` covers them; no workflow change.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests. |
| V Implementation Before Devices | PASS — no device work. |
| IX Bounded Untrusted Input | PASS — bounded ranges; stored levels re-checked on decode. |
| X Licensing and Provenance | PASS — the project's own archived design; original code. |
| XI One App and Stable Experience Identity | PASS — experience R02-G17; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                 edit  + Core target (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabError.swift      new   (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSky.swift        new   bodies, eclipses, judge (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabLevel.swift      new   level, words, stored form (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabPlay.swift       new   play, records, replay (B)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabRules.swift      new   PuzzleRules (C)
Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabFixtures.swift  new  seeded levels (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/{CelestialEclipseLabLevelTests (lead), …SkyTests (A),
  …PlayTests (B), …RulesTests (C), …InvariantTests (D)}.swift
docs/architecture/celestial-eclipse-lab.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, sky, level and fixtures first; then agents A (sky tests with an independent reference: positions,
overlap decisions, events, intervals, classes and the judge recomputed by direct enumeration of every tick and pair
over seeded levels), B (play), C (rules) and D (invariants) in parallel in isolated package copies; agents compile but
run no tests while the lead's baselines or chain run; the lead retests every agent result and records checks after
every agent has reported.
