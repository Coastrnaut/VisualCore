# Implementation Plan: R02-F18 — Procedural terrain mesh and skydome

**Branch**: `218-procedural-terrain-mesh-and-skydome` (spec directory only; work on `main`) | **Date**: 2026-11-19 |
**Spec**: [spec.md](spec.md)

## Summary

In VisualCoreScenes: `TerrainSettings` and `TerrainLOD` choose `TerrainPiece`s (P × P pieces of C × C base cells, levels
by distance, neighbours within one level, a vertex budget) and build each piece's mesh from `HeightField` sampling with
crack-free edges; `ErosionMask` derives steepness, D8 flow and wear from a `HeightField` as a `FieldGrid`; `SkyParameters`
and `SkyModel` give the analytic sky colour. In VisualCoreRendering: the include `vc/sky.glsl` (`vc_sky`, the same
expression) and `SkyRenderer`, a full-screen far-plane pass that restores the state it changes. Settings are `Codable`
(schema 1). Failures are `TerrainError` and `SkyError` with `r2-f18.*` codes. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 through the existing ANGLE path. **Primary dependencies**: VisualCoreScenes
(`HeightField`, `MeshBuilder`, `Mesh`), VisualCoreSimulation (`FieldGrid`, `SeededRandom`), VisualCoreMath (`Vec3`,
`Mat4`), VisualCoreRendering (`RenderHost`, `FullScreenShaderScene`, `ShaderBundle`, `ResourceRegistry`). No new module,
dependency or Objective-C++ code.
**Seeds**: fixtures use `SeededRandom` seeded 2_018; heights from `GradientNoise2D` seeded 2_018.
**Testing**: `swift test --package-path Packages/VisualCore` (terrain, masks, sky reference, settings);
VisualCoreRendering on sim-27.2 and sim-26.5 (`SkyShaderTests`, `SkyRendererTests`, `ShaderBundleTests` with the new
include); ExperiencesCreative on sim-27.2; reference regression in two chunks; script tests; isolated timing run.
**Performance**: bounded by arithmetic — selection O(P² · L) per pass; piece meshes within the vertex budget; masks
O(N log N) for N grid points (sorted visit); the sky is a few dozen arithmetic operations per pixel in one pass.
**Constraints**: additive; `HeightField`, `GradientNoise2D`, the mesh renderer and TinyWorlds unchanged; no image.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — the sky is GLSL ES on the existing ANGLE path through `RenderHost`. |
| II App-neutral API · II-a reference | PASS — generic terrain and sky; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — `SkyRenderer` releases its program; tests read `ResourceRegistry.stats.leaked == 0`. |
| IV Host-testable | PASS — terrain, masks and the sky reference are pure and host-tested; GPU parity on simulators. |
| IX Bounded input | PASS — sizes, levels, budgets and sky parameters bounded and refused by code. |
| X Licensing and provenance | PASS — chunked LOD with edge stitching, D8 flow and an analytic gradient sky are textbook; original code; no image. |
| XI Stable identity | PASS — schema 1 stored settings; newer refused. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/TerrainError.swift      new  TerrainError (lead)
Packages/VisualCore/Sources/VisualCoreScenes/TerrainSettings.swift   new  TerrainSettings, Codable schema 1 (lead)
Packages/VisualCore/Sources/VisualCoreScenes/TerrainLOD.swift        new  TerrainPiece, TerrainLOD.select, TerrainLOD.mesh (agent A)
Packages/VisualCore/Sources/VisualCoreScenes/ErosionMask.swift       new  ErosionMask.masks(of:) (agent B)
Packages/VisualCore/Sources/VisualCoreScenes/SkyParameters.swift     new  SkyError, SkyParameters, Codable schema 1 (lead)
Packages/VisualCore/Sources/VisualCoreScenes/SkyModel.swift          new  SkyModel.colour(direction:sun:parameters:) (agent C)
Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/sky.glsl      new  vc_sky (agent C)
Packages/VisualCoreRendering/Sources/VisualCoreRendering/SkyRenderer.swift     new  SkyRenderer (agent C)
Packages/VisualCore/Tests/VisualCoreScenesTests/TerrainSettingsTests.swift (lead), TerrainLODTests.swift (A),
  ErosionMaskTests.swift (B), SkyModelTests.swift (C)   new
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/SkyShaderTests.swift, SkyRendererTests.swift (C)   new
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/ShaderBundleTests.swift   edit: add vc/sky.glsl (lead)
docs/architecture/terrain-and-sky.md (new), docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none of existing data. **Rollback**: revert the commits (additive files and one list entry).

## Parallel work

Lead first writes the four shared files and their test. Then agents A (terrain), B (masks) and C (sky reference, include,
renderer) in parallel, each writing only its own files against contracts/api.md. Lead: the include list, docs, API
baseline, runs, commits.
