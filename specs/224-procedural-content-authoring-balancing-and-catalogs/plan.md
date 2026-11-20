# Implementation Plan: R02-F24 — Procedural content authoring, balancing and catalogs

**Branch**: `224-procedural-content-authoring-balancing-and-catalogs` (spec directory only; work on `main`) |
**Date**: 2026-11-20 | **Spec**: [spec.md](spec.md)

## Summary

In VisualCoreSimulation, on top of R02-F23: `PuzzleCatalogPlan` and `PuzzleCatalogStage`; `PuzzleDifficulty` and
`ProgressionRule`; `PuzzleCatalogBuilder` turning a plan into a `PuzzleCatalog` of `PuzzleCatalogEntry`s with a digest
(JSON schema 1); `PuzzleCatalogChecker` with `PuzzleCatalogReport` and `PuzzleCatalogIssue`; `TutorialContract`,
`TutorialContractStep`, `TutorialCondition`, `TutorialEvent` and `TutorialContractProgress` (JSON schema 1). Failures are
`ContentError` with `r2-f24.*` codes. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (R02-F23 contract, `SeedDerivation`),
VisualCoreMath (`StableHash`). No new module, dependency, script, GPU, GLSL or Objective-C++ code.
**Seeds**: fixtures use seed 2_024 and the R02-F23 test puzzles (`PuzzleFixtures.swift`).
**Testing**: `swift test --package-path Packages/VisualCore`; VisualCoreRendering on sim-27.2 and sim-26.5 and
ExperiencesCreative on sim-27.2 as regression; reference regression in two chunks; script tests (run alone); isolated
timing run.
**Performance**: a catalog of n levels costs at most n × attempts certifications; test catalogs hold at most 30 levels of
the 512-state lights-out puzzle.
**Constraints**: additive; existing types unchanged (names chosen to avoid Light Maze's `LevelCatalog`, Physics
Playground's tutorial types and the existing `CatalogError`s).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering change. |
| II App-neutral API · II-a reference | PASS — generic catalogs and tutorials; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — none. |
| IV Host-testable | PASS — pure, host-tested. |
| VII Native, accessible UI | PASS — tutorial text by key for localisation and VoiceOver in the consuming experiences. |
| IX Bounded input | PASS — stages, levels, attempts, steps, keys and counts refused or bounded by code. |
| X Licensing and provenance | PASS — original code; content comes from seeds and rules, no authored art. |
| XI Stable identity | PASS — content digest; schema 1; newer and edited forms refused. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/ContentError.swift          new  ContentError (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleCatalogPlan.swift     new  PuzzleCatalogPlan, PuzzleCatalogStage, PuzzleDifficulty, ProgressionRule (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleCatalog.swift         new  PuzzleCatalog, PuzzleCatalogEntry, PuzzleCatalogBuilder, stored form (agent A)
Packages/VisualCore/Sources/VisualCoreSimulation/PuzzleCatalogChecker.swift  new  PuzzleCatalogChecker, PuzzleCatalogReport, PuzzleCatalogIssue (agent B)
Packages/VisualCore/Sources/VisualCoreSimulation/TutorialContract.swift      new  TutorialContract, TutorialContractStep, TutorialCondition, TutorialEvent, TutorialContractProgress (agent C)
Packages/VisualCore/Tests/VisualCoreSimulationTests/ProgressionRuleTests.swift (lead), PuzzleCatalogTests.swift (A),
  PuzzleCatalogCheckerTests.swift (B), TutorialContractTests.swift (C)   new
docs/architecture/content-catalogs.md (new), docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none of existing data. **Rollback**: revert the commits (additive files only).

## Parallel work

Lead writes the error and plan types with their test; agents A, B and C write the catalog, the checker and the tutorial
in parallel against the contract (B builds catalogs by hand in its tests until A's builder exists). Lead: docs, API
baseline, runs, commits; checks recorded only after every agent has reported.
