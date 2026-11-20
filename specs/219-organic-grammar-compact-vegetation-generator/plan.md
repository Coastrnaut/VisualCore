# Implementation Plan: R02-F19 — Organic grammar & compact vegetation generator

**Branch**: `219-organic-grammar-compact-vegetation-generator` (spec directory only; work on `main`) | **Date**:
2026-11-20 | **Spec**: [spec.md](spec.md)

## Summary

In VisualCoreScenes: `PlantGrammar` (start word, weighted rules, turtle settings, seed; `Codable` schema 1) and
`LSystem.derive` (seeded rewriting); `PlantTurtle.interpret` turns a word into a `PlantSkeleton` of `PlantBranch`es and
`PlantMarker`s; `PetalShape`, `CapShape` and `StemShape` build part meshes; `PlantMesh.build` draws branches with
`CurveMeshes.tube` and places parts at markers, merged with `CurveMeshes.merged`; `PlantScatter.scatter` places
`PlantInstance`s with a minimum spacing, ready for `MeshInstance`. Failures are `PlantError` with `r2-f19.*` codes.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (`MeshBuilder`, `Mesh`, `MeshBudget`,
`CurveSamples`, `CurveMeshes`), VisualCoreSimulation (`SeededRandom`), VisualCoreMath (`Vec3`, `Mat4`). No new module,
dependency, GPU, GLSL or Objective-C++ code (plants draw through the existing mesh and instanced renderers).
**Seeds**: fixtures use `SeededRandom` seeded 2_019 (the test target reaches it through a fileprivate generator or the
public API, as in feature 218).
**Testing**: `swift test --package-path Packages/VisualCore`; ExperiencesCreative on sim-27.2 and VisualCoreRendering on
sim-27.2 and sim-26.5 as regression; reference regression in two chunks; script tests; isolated timing run.
**Performance**: bounded by arithmetic — words ≤ 1,048,576 symbols, branches ≤ 65,536, meshes within `MeshBudget`,
scatter ≤ 30 · maxCount candidates with a grid check of O(1) each.
**Constraints**: additive; existing types and experiences unchanged; no image.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering change. |
| II App-neutral API · II-a reference | PASS — generic grammar and shapes; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — none. |
| IV Host-testable | PASS — pure, host-tested. |
| IX Bounded input | PASS — generations, word, rule, branch, shape and scatter limits refused by code. |
| X Licensing and provenance | PASS — L-systems and turtle conventions (Prusinkiewicz and Lindenmayer 1990) and dart-throwing are published methods; original code; no image. |
| XI Stable identity | PASS — schema 1 stored grammar; newer refused. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/PlantError.swift     new  PlantError (lead)
Packages/VisualCore/Sources/VisualCoreScenes/PlantGrammar.swift   new  PlantRule, PlantGrammar, Codable schema 1 (lead)
Packages/VisualCore/Sources/VisualCoreScenes/PlantTurtle.swift    new  LSystem.derive, PlantBranch, PlantMarker, PlantSkeleton, PlantTurtle (agent A)
Packages/VisualCore/Sources/VisualCoreScenes/PlantShapes.swift    new  PetalShape, CapShape, StemShape (agent B)
Packages/VisualCore/Sources/VisualCoreScenes/PlantScatter.swift   new  PlantInstance, PlantScatter (agent C)
Packages/VisualCore/Sources/VisualCoreScenes/PlantMesh.swift      new  PlantMesh.build (lead, after A and B)
Packages/VisualCore/Tests/VisualCoreScenesTests/PlantGrammarTests.swift (lead), PlantTurtleTests.swift (A),
  PlantShapesTests.swift (B), PlantScatterTests.swift (C), PlantMeshTests.swift (lead)   new
docs/architecture/vegetation.md (new), docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none of existing data. **Rollback**: revert the commits (additive files only).

## Parallel work

Lead first writes the two shared files and their test; agents A, B and C then write their own files in parallel; the
lead writes `PlantMesh` once A and B are in, then docs, API baseline, runs and commits.
