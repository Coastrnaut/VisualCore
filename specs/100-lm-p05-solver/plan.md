# Implementation Plan: Light Maze — Phase 05 Content solvability and release QA

**Branch**: `100-lm-p05-solver` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-SOLVER with no VisualCore and no experience-runtime change: in LightMazeCore a pure `Solver` (orientation sets
by increasing turns, lexicographic within, traced with `BeamTracer`, limit 16 turnable tiles) and `ContentQA` (five
named checks per level); core tests over all 20 levels and built fixtures; an experience test that the drawn beam
equals the tracer's segments for 60 boards; a committed content QA table `docs/apps/light-maze/content-qa.md`
checked against the catalog by a test (as `content-licenses.md` is). Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Contract: [contracts/solver.md](contracts/solver.md).

## Technical Context

**Language**: Swift 6. **Dependencies** (verified in the clarification session): LightMazeCore's `Board`
(`applying(_:)`, `turnableIndices`, `orientations`, `problem`), `BeamTracer.trace(_:)` / `Beam.isSolved`,
`LevelCatalog.bundled` / `Level` (`solution`, `startOrientations`, `turnableCount`), `LicenseAudit.problems(_:)`; the
experience's `MazePresenter.scene(_:)` (tests only). **Storage**: none; state schema unchanged. **Testing**:
ExperiencesCreative on sim-27.2; app build and unit; runner iOS 27; packages; contract; script tests.
**Performance**: the catalog needs at most 2⁸ = 256 traces per level; the 16-tile limit bounds a search at 65,536
traces, run once in a test on a small board (well under 10 s on a phone-class simulator; measured, not asserted on
wall clock). **Constraints**: tests < 10 s; iOS 27 only; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS · II PASS (no upstream change; G-SOLVER is app-local per the contract) · II-a N/A · III PASS · IV PASS (search
and QA tested without GPU) · V PASS (no schema change) · VI PASS · VII PASS (no UI change) · VIII PASS (no data, no
network) · IX PASS (bounded search, refused above the limit) · X PASS · XI–XIII PASS. A13 rules: deterministic rules
(fixed search order), offline — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/LightMaze/Core/Solver.swift                                                   new
Packages/ExperiencesCreative/LightMaze/Core/ContentQA.swift                                                new
Packages/ExperiencesCreative/LightMaze/CoreTests/{SolverTests,ContentQATests}.swift                       new
Packages/ExperiencesCreative/LightMaze/ExperienceTests/MazeBeamFixtureTests.swift                         new
docs/apps/light-maze/content-qa.md (generated table: level, fewest turns, recorded turns, result)           new
docs/apps/light-maze/README.md (link to content-qa.md)                                                      modify
docs/apps/light-maze/visualcore-contract.json (G-SOLVER closed by A13-P05; rows M11, M20)                   modify
```

**Dependency direction**: unchanged (LightMazeCore → VisualCoreMath only; the beam fixture test reads the experience's
scene). **Lifecycle**: none at run time; the search and QA run in tests and when regenerating `content-qa.md`
(`UPDATE_CONTENT_QA=1` with `TEST_RUNNER_UPDATE_CONTENT_QA=1`, as the manifest and licenses do). **Migration**: none.
**Rollback**: revert the commits; nothing persisted changes.

## Parallel work

Agent A: `Solver.swift` + `SolverTests.swift`. Agent B (after A's API is fixed in this plan): `ContentQA.swift` +
`ContentQATests.swift` + `content-qa.md` generation test. Agent C: `MazeBeamFixtureTests.swift`. Lead: docs, contract,
runs, commits.
