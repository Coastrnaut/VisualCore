# Implementation Plan: R02-F23 — Puzzle contract, seed generation and solver certification

**Branch**: `223-puzzle-contract-seed-generation-and-solver-certification` (spec directory only; work on `main`) |
**Date**: 2026-11-20 | **Spec**: [spec.md](spec.md)

## Summary

In VisualCoreSimulation, beside the unchanged R02-F16 solvers and `SolverCertificate`: a `PuzzleRules` protocol; an
immutable `PuzzleLevel` with a `StableHash` identity of its canonical JSON (schema 1, edited forms refused);
`PuzzleUniqueness`, `FairnessBudget`, `PuzzleVerdict` and `PuzzleCertificate`; `PuzzleValidator.certify` (replay,
length bounds, bounded breadth-first search for branching, shortest length and uniqueness); `PuzzleGenerator.generate`
(derived seeds per attempt, the first certified candidate, a `PuzzleGeneration` report). Failures are `PuzzleError` with
`r2-f23.*` codes. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`SeededRandom`, `SeedDerivation`),
VisualCoreMath (`StableHash`). No new module, dependency, GPU, GLSL or Objective-C++ code.
**Seeds**: fixtures use `SeededRandom` seeded 2_023; two small test puzzles (3 × 3 lights-out and a sliding row) are
written in the tests.
**Testing**: `swift test --package-path Packages/VisualCore`; VisualCoreRendering on sim-27.2 and sim-26.5 and
ExperiencesCreative on sim-27.2 as regression; reference regression in two chunks; script tests (run alone); isolated
timing run.
**Performance**: certification explores at most the node budget once; generation at most attempts × that. Test puzzles
have at most 512 states.
**Constraints**: additive; existing types unchanged; every verdict reproducible.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering change. |
| II App-neutral API · II-a reference | PASS — generic contract; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — none. |
| IV Host-testable | PASS — pure, host-tested. |
| IX Bounded input | PASS — solution length, budgets, attempts and search nodes refused or bounded by code. |
| X Licensing and provenance | PASS — breadth-first search, path counting and content hashing are textbook; test puzzles are original or public-domain mechanics. |
| XI Stable identity | PASS — content-derived level identity; schema 1; newer and edited forms refused. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleError.swift      new  PuzzleError (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleRules.swift      new  PuzzleRules, PuzzleUniqueness, FairnessBudget, PuzzleVerdict, PuzzleCertificate (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleLevel.swift      new  PuzzleLevel, identity, stored form (agent A)
Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleValidator.swift  new  PuzzleValidator.certify (agent B)
Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleGenerator.swift  new  PuzzleGenerator, PuzzleGeneration (agent C)
Packages/VisualCore/Tests/VisualCoreSimulationTests/PuzzleFixtures.swift (lead), PuzzleLevelTests.swift (A),
  PuzzleValidatorTests.swift (B), PuzzleGeneratorTests.swift (C)   new
docs/architecture/puzzle-contract.md (new), docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none of existing data. **Rollback**: revert the commits (additive files only).

## Parallel work

Lead writes the error, the value types and the test puzzles; agents A, B and C write the level, the validator and the
generator in parallel against the contract (C's tests wait for B's file). Lead: docs, API baseline, runs, commits.
