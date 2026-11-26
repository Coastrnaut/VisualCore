# Implementation Plan: R02-G19-02 — Microscopic Aurora: level generator and solver witness

**Branch**: `482-microscopic-aurora-level-generator-and-solver-witness` (spec directory only; work on `main`) |
**Date**: 2026-11-26 | **Spec**: [spec.md](spec.md)

## Summary

Extend `MicroscopicAuroraCore` with the content pipeline, on the pattern of Apsides Workshop's (feature 472), after two
additive kernel changes: the level's budget range widens to 1 … 24, and a level may list 2 … 8 well sites (a placement
elsewhere is refused by the play and is not a move of the puzzle contract; a level without sites is unchanged in its
stored form, fingerprint and play). Then: the 100-entry `MicroscopicAuroraManifest` from the archived design (number,
seed, band, budget, control emphasis); band profiles (swarm size, swim length, sites, plan length, stencil size,
coverage); a constructive generator per manifest entry (a swarm, sites, winning wells on a partial shuffle of the
sites, the stencil as the largest lit group trimmed breadth-first, the coverage and coherence requirements, no starting
well); a depth search solver over sets of wells on distinct sites (depth 0, 1, 2 …, the last depth ordered by the shape
loss of each set's prefix), counting sets judged against a bound of 1,200 and storing the sets at every smaller depth as
the minimality proof; difficulty metrics with the nearest miss; witness files with per-action state digests, the
terminal report and the counterexample; the catalog digest, the neighbour rule and the progression rule. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`SeededRandom`, `SeedDerivation`,
`PuzzleCatalog`, `ProgressionRule`, `PuzzleDifficulty`) and VisualCoreMath (`StableHash`), already linked by
`MicroscopicAuroraCore` (audited 2026-11-26 in `Packages/ExperiencesRound02/Package.swift`). **Numbers**: catalog levels
have enclosure 11, swims of 120 … 160 ticks, 4 … 8 swimmers, 3 … 6 sites and plans of 1 or 2 wells; at most 1 + 48 +
960 = 1,009 sets for six sites; sets judged bounded at 1,200 per candidate (the prototype needed at most 830); all swim
rules are the kernel's integer rules (feature 481). **Seeds**: manifest seeds through `SeedDerivation`; test fixtures
seed 2_482. **Testing**: `swift test --package-path Packages/ExperiencesRound02 --filter MicroscopicAurora`; catalog
certification in 20 groups of 5 levels, each under 10 s on a debug host build (the prototype built the whole catalog in
20.7 s, at most 1.64 s for one level; measured locally, not asserted on CI); generated levels cached per process.
**CI**: no workflow change; the new tests run in round-two host chunk 3e and the `round02-host-tests` job.
**Constraints**: additive; reason codes `r02-g19.*`; no clock in any rule.

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
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraError.swift       edit  + generation(Int), witness(String) (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraLevel.swift       edit  budgets 1 … 24, optional sites (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraPlay.swift        edit  "not a site" refusal (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraPuzzle.swift      edit  moves on sites only (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraManifest.swift    new   entries (100), provenance (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSolver.swift      new   depth search, loss order, work (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraDifficulty.swift  new   (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraGenerator.swift   new   band profiles, candidates, catalog, digest (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraWitness.swift     new   digests, terminal report, counterexample (agent B)
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraSitesTests.swift      new  kernel extension (lead)
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraSolverTests.swift     new  incl. independent enumeration (agent A)
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraWitnessTests.swift    new (agent B)
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraGeneratorTests.swift  new (agent C)
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraCatalogTests.swift    new  digest, progression, neighbours, witnesses (lead)
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraLevelTests.swift      edit  budget bound 25 (lead)
docs/games/microscopic-aurora/levels/001.witness.json … 100.witness.json   new  generated by the catalog test (lead)
docs/architecture/microscopic-aurora.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: none (witness schema 1 is new; the level's stored form gains an optional field, omitted when absent, so
every existing stored level and fingerprint is unchanged). **Rollback**: revert the commits.

## Parallel work

The lead writes the kernel extension, the error cases, the manifest, the solver, the difficulty and the generator;
agents A (solver tests with an independent enumeration and no loss order), B (witness and its tests) and C (generator
tests) then work in parallel against the contract in isolated copies; the lead writes the catalog tests and the witness
files, retests every agent result and records checks only after every agent has reported.
