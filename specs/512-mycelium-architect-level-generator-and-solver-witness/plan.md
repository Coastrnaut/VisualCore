# Implementation Plan: R02-G22-02 — Mycelium Architect: level generator and solver witness

**Branch**: `512-mycelium-architect-level-generator-and-solver-witness` (spec directory only; work on `main`) |
**Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

## Summary

Extend Mycelium Architect's Core (feature 511) with its content pipeline on the pattern of feature 502: optional
placement sites in the kernel (2 … 12 empty cells; placements elsewhere refused "not a site"; absent sites keep feature
511's stored form and fingerprint); the 100-entry manifest; a seeded generator drawing, per candidate, the board, the
features, the parameters, the sites and a winning plan of the band's length p (1, 2, 3, 3, 4), taking terminals from
the winning growth and setting budget and limit from its weight; a breadth-first solver over arrangements by action
count with a loss order, reachability checks and a counted work bound of 20 000; difficulty metrics; witness files
with per-action digests, the terminal growth report and the counterexample; the catalog digest and progression.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`, `PuzzleCatalog`,
`ProgressionRule`, `SeedDerivation`, `SeededRandom`) and VisualCoreMath (`StableHash`), as feature 511. **Storage**: the
witness files `docs/games/mycelium-architect/levels/NNN.witness.json`, written only with
`MYCELIUM_ARCHITECT_WRITE_WITNESSES=1`. **Numbers**: integers only. **Testing**: `swift test --package-path
Packages/ExperiencesRound02 --filter MyceliumArchitect`. **Performance**: a growth run is at most a few thousand integer
steps on boards up to 16 × 16; the solver judges at most 20 000 arrangements per candidate (band 5: 6 sites with two kinds each and up to 8 seed directions give at most 20 changes from any
arrangement, so within plan length 4 at most 1 + 20 + 190 + 1 140 + 4 845 = 6 196 distinct arrangements; below the bound);
the measured catalog (research R4) takes 8.9 s with a candidate bound of 1 024 and its slowest group of five 2.2 s;
certification is split into 20 groups of 5 levels, each measured under 10 s locally (never asserted on CI); generated
levels are cached per process. **Constraints**: additive changes only; reason codes `r02-g22.*` (new `generation`,
`witness`); the new sources sit in `Core/Content/` so feature 511's source scans keep their file lists. **Scale/Scope**:
5 new sources, 5 new test files, 100 witness files. **CI**: no change (half b already holds `MyceliumArchitect`).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven Renderer Only | PASS — no rendering. |
| II App-Neutral Public API | PASS — content stays in the experience package; R02-F24's catalog and progression are consumed, not copied. |
| II-a Preserve the Reference and Prove It | PASS — reference regression in two chunks. |
| III GPU Lifecycle | PASS — not applicable. |
| IV Host-Testable Domain Logic, Test-First | PASS — deterministic, seeded, counted work, independent brute-force check. |
| V Implementation Before Devices | PASS — no device work. |
| VI Evidence Over Assertion | PASS — run-check records; witnesses checked byte for byte. |
| VII Native, Accessible UI | PASS — no UI; levels named in words by the kernel. |
| VIII Public Apple APIs, Privacy | PASS — Foundation only. |
| IX Bounded Untrusted Input | PASS — witness schema 1, refused when damaged, edited or newer. |
| X Licensing and Provenance | PASS — the project's own manifest. |
| XI One App | PASS — experience R02-G22 only. |
| XII One Purchase, No Advertising | PASS — free tier. |
| XIII Code-Driven Visuals | PASS — no art. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectError.swift        edit  + generation(Int), witness(String) (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectLevel.swift        edit  optional sites, refusals, stored form (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectPlay.swift         edit  "not a site" in changed (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectPuzzle.swift       edit  placements on sites only (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Content/MyceliumArchitectManifest.swift    new  100 entries (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Content/MyceliumArchitectDifficulty.swift  new  plan, difficulty (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Content/MyceliumArchitectSolver.swift      new  breadth-first search, loss, work (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Content/MyceliumArchitectGenerator.swift   new  profiles, candidates, catalog, digest (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Content/MyceliumArchitectWitness.swift     new  digests, terminal report, counterexample (agent B)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectSitesTests.swift     new  kernel extension (lead)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectSolverTests.swift    new  incl. independent enumeration (agent A)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectGeneratorTests.swift new (agent C)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectWitnessTests.swift   new (agent B)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectCatalogTests.swift   new  digest, progression, neighbours, witnesses, content and novelty boundaries (lead)
docs/games/mycelium-architect/levels/001.witness.json … 100.witness.json                      new
docs/architecture/mycelium-architect.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md, README.md  edit (lead)
```

**Migration**: the stored level gains an optional `sites`, omitted when absent; witness schema 1 is new. **Rollback**:
revert the feature's commits.

## Implementation order

1. Baselines after R02-G22-01 is recorded. 2. Kernel extension with `MyceliumArchitectSitesTests` (a literal
fingerprint of a hand level recorded before the edit stays equal). 3. Manifest, difficulty, solver and generator, then
one measured catalog build in an isolated copy, results in research R4 (profile changes written back to spec, research,
data model and this plan in the same commit). 4. Witness (agent B). 5. Catalog tests and the 100 witness files.
6. Docs, chunks, chain, reference, script tests. 7. Converge.

## Parallel work

Lead: kernel extension, manifest, difficulty, solver, generator, catalog (shared files). Agents A (solver tests with the
independent enumeration), B (witness and its tests) and C (generator tests) in isolated copies after step 3.

## Complexity Tracking

None.
