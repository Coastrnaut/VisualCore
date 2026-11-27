# Implementation Plan: R02-G20-01 — Mushroom Weather: playable rule kernel

**Branch**: `491-mushroom-weather-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-26 |
**Spec**: [spec.md](spec.md)

## Summary

Add Mushroom Weather's pure rule kernel, `MushroomWeatherCore`, to `Packages/ExperiencesRound02` on the pattern of
Microscopic Aurora's (feature 481): a forest floor of 6 … 12 rows by 6 … 14 columns with floor and blocked cells and a
closed boundary; integer humidity 0 … 10000 per floor cell; a run of T cycles (20 … 200), each three synchronous steps
— diffusion between orthogonally adjacent floor cells with antisymmetric flows (hₐ − h_b)·D/64 truncated toward zero
(D 1 … 12), evaporation ⌊h·rate·(4 + L)/4096⌋ by each cell's rate (vent cells open or closed) and the moonlight level
L 0 … 3, and release by up to six pods (r, or g once grown) — with an exact ledger (total after = total before +
released − evaporated) for every cycle; pod growth when a pod's humidity integral reaches G; colonies with a band and,
when sensitive, a survival floor; the judge (`dried`, `mold`, then `unstable` or won when every colony is in band for
each of the last K cycles) in that order; actions `place(slot, row, column)`, `remove(slot)`, `vent(index, open)` and
`moonlight(level)` (one action each) and `run` (ends the level); an immutable, fingerprinted level; the play state
machine with records, full undo, redo (undo from failed returns to playing before the run; a won level is final) and
replay; and the rules as an R02-F23 `PuzzleRules` over arrangements. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `SeededRandom`) and
VisualCoreMath (`StableHash`), as the existing round-two Cores use them (`MicroscopicAuroraCore` depends on both in
`Packages/ExperiencesRound02/Package.swift`). No GPU, UIKit, Objective-C++ or GLSL code in this feature; no new
package; one new target pair. **Package**: `Packages/ExperiencesRound02/Package.swift` gains `MushroomWeatherCore`
(path `MushroomWeather/Core`), its tests (`MushroomWeather/CoreTests`) and the product. **Numbers**: `Int64`
throughout; a cell holds at most 10000 + 200 · 80 units in a run (release only adds 80 a cycle to one cell, and mold
ends the run at the first cell above M ≤ 10000), so one cycle's products are below 26000 · 200 · 7 < 2^26; integrals
below 200 · 26000 < 2^23; totals below 168 · 26000 < 2^23. Nothing approaches 2^62; no platform floating point decides
anything; `Double` appears only in the words. **Seeds**: fixtures use `SeededRandom(seed: 2_491)`; neighbouring-input
checks seed 2_496. **Testing**: `swift test --package-path Packages/ExperiencesRound02 --filter MushroomWeather`.
**Performance**: one run is at most 200 cycles × 168 cells × 4 neighbours, about 135,000 integer steps; a 500-run test
stays under 10 s. **Constraints**: additive; reason codes `r02-g20.*`; denylisted names (ProjectM, PresetLibrary,
MilkDrop …) avoided. **CI**: the local round-two host chunk 3f (`EchoCartographer|ColorfallCanyons|StarlitCartouche|
ApsidesWorkshop`) gains `MushroomWeather`; the `round02-host-tests` job's `swift test` covers the new targets; no
workflow change. **Seed convention**: a level's seed is a `UInt64` stored in the level and its records; nothing in the
kernel draws random numbers.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests. |
| V Implementation Before Devices | PASS — no device work. |
| IX Bounded Untrusted Input | PASS — bounded ranges; stored levels re-checked on decode. |
| X Licensing and Provenance | PASS — the project's own archived design; original code. |
| XI One App and Stable Experience Identity | PASS — experience R02-G20; level fingerprints. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                              edit  + Core target (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherError.swift            new   (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherWeather.swift          new   cycle, ledger, judge (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherLevel.swift            new   level, words, stored form (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherPlay.swift             new   play, records, replay (B)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherPuzzle.swift           new   PuzzleRules (C)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherFixtures.swift    new   seeded levels (lead)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/{MushroomWeatherLevelTests (lead), …WeatherTests (A),
    …PlayTests (B), …PuzzleTests (C), …InvariantTests (D)}.swift
docs/architecture/mushroom-weather.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Migration**: none (schema 1 is new). **Rollback**: revert the commits; the other games' targets are untouched.

## Parallel work

Lead: package, error, weather, level and fixtures first; then agents A (weather tests with an independent reference: a
second, straightforward implementation of the cycle law, ledger, growth, colony runs and judge written from the
spec's clarifications, compared on 500 seeded runs), B (play), C (rules) and D (invariants) in parallel in isolated
package copies; agents compile but run no tests while the lead's runs are going; the lead retests every agent result
and records checks after every agent has reported.
