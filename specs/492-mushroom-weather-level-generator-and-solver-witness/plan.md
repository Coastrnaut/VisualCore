# Implementation Plan: R02-G20-02 — Mushroom Weather: level generator and solver witness

**Branch**: `492-mushroom-weather-level-generator-and-solver-witness` (spec directory only; work on `main`) |
**Date**: 2026-11-26 | **Spec**: [spec.md](spec.md)

## Summary

Extend `MushroomWeatherCore` with the content pipeline, on the pattern of Microscopic Aurora's (feature 482), after two
additive kernel changes: the level's budget range widens to 1 … 24, and a level may list 2 … 8 pod sites (a placement
elsewhere is refused by the play and is not a move of the puzzle contract; a level without sites is unchanged in its
stored form, fingerprint and play). Then: the 100-entry `MushroomWeatherManifest` from the archived design (number,
seed, band, budget, control emphasis); band profiles (rows, columns, blocked cells, vents, pod slots, colonies, sites,
plan length, margin); a constructive generator per manifest entry (a floor, colonies, vents and sites next to the
colonies, a winning choice of pods, vent toggles and a moonlight change, each colony's band from the winning run
widened by a margin, sensitive floors below the run's minimum, no starting pod); a depth search solver over
arrangements by their distance from the start (pod count + vents toggled + a moonlight change), the last depth ordered
by the band loss of each arrangement's parent, counting arrangements judged against a bound of 1,500 and storing the
counts at every smaller depth as the minimality proof; difficulty metrics with the nearest miss; witness files with
per-action state digests, the terminal report (ledger totals, colony runs) and the counterexample; the catalog digest,
the neighbour rule and the progression rule. Research: [research.md](research.md). Data: [data-model.md](data-model.md).
API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`SeededRandom`, `SeedDerivation`,
`PuzzleCatalog`, `ProgressionRule`, `PuzzleDifficulty`) and VisualCoreMath (`StableHash`), already linked by
`MushroomWeatherCore`. **Numbers**: catalog levels have 6 … 9 by 6 … 10 cells, runs of 30 … 40 cycles, 2 … 5 colonies,
1 … 3 vents, 2 … 4 pod slots, 4 … 6 sites and plans of 2 … 5 actions; at most 1 + 12 + 63 + 192 + 378 = 1,144
arrangements up to a band-5 plan depth; arrangements judged bounded at 1,500 per candidate (the prototype needed at most
1,128); all weather rules are the kernel's integer rules (feature 491). **Seeds**: manifest seeds through
`SeedDerivation`; test fixtures seed 2_492. **Testing**: `swift test --package-path Packages/ExperiencesRound02 --filter
MushroomWeather`; catalog certification in 20 groups of 5 levels, each under 10 s on a debug host build (the prototype
built the whole catalog in 21.2 s, at most 1.14 s for one level and 3.53 s for a group; measured locally, not asserted on
CI); generated levels cached per process. **CI**: no workflow change; the new tests run in round-two host chunk 3f and
the `round02-host-tests` job. **Constraints**: additive; reason codes `r02-g20.*`; no clock in any rule.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-Neutral Public API | PASS — game code in the experience package; VisualCore unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests and byte-for-byte witnesses. |
| V Implementation Before Devices | PASS — no device work. |
| VI Evidence Over Assertion | PASS — every level carries a replayable witness; minimality is re-checked independently on samples. |
| IX Bounded Untrusted Input | PASS — witness files re-checked on decode; work bounded; sites range-checked. |
| X Licensing and Provenance | PASS — manifest copied from the project's own archived design; levels generated. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherError.swift       edit  + generation(Int), witness(String) (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherLevel.swift       edit  budgets 1 … 24, optional sites (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherPlay.swift        edit  "not a site" refusal (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherPuzzle.swift      edit  pods on sites only (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherManifest.swift    new   entries (100), provenance (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSolver.swift      new   depth search, loss order, work (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherDifficulty.swift  new   (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherGenerator.swift   new   band profiles, candidates, catalog, digest (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherWitness.swift     new   digests, terminal report, counterexample (agent B)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherSitesTests.swift      new  kernel extension (lead)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherSolverTests.swift     new  incl. independent BFS (agent A)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherWitnessTests.swift    new (agent B)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherGeneratorTests.swift  new (agent C)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherCatalogTests.swift    new  digest, progression, neighbours, witnesses (lead)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherLevelTests.swift      edit  budget bound 25 (lead)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherInvariantTests.swift  edit  budget bound 25 (lead)
docs/games/mushroom-weather/levels/001.witness.json … 100.witness.json   new  generated by the catalog test (lead)
docs/architecture/mushroom-weather.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: none (witness schema 1 is new; the level's stored form gains an optional field, omitted when absent, so
every existing stored level and fingerprint is unchanged). **Rollback**: revert the commits.

## Parallel work

The lead writes the kernel extension, the error cases, the manifest, the solver, the difficulty and the generator
(starting from the measured prototype); agents A (solver tests with an independent breadth-first search over the
puzzle's moves and no loss order), B (witness and its tests) and C (generator tests) then work in parallel against the
contract in isolated copies; the lead writes the catalog tests and the witness files, retests every agent result and
records checks only after every agent has reported.
