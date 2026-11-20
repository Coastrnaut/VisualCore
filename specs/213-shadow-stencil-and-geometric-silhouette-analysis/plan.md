# Implementation Plan: R02-F13 — Shadow stencil and geometric silhouette analysis

**Branch**: `213-shadow-stencil-and-geometric-silhouette-analysis` (spec directory only; work on `main`) | **Date**:
2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

The CPU decides: `ShadowProjector` projects points, triangles, meshes and convex solids onto a `ProjectionPlane` from a
`ShadowLight` (point or directional), clipped to the slab where shadows are cast; `ConvexHull2D` gives a convex
solid's outline; `CoverageMask` rasterises polygons by cell centres (half-open edge rule) into packed bits with a digest
and a stored form; `MaskComparison` gives IoU. The GPU portrays: `PlanarShadowRenderer` draws the mesh flattened by
the same projection into a coverage target, then composites a constant darkness once per pixel. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00. **Primary dependencies**: VisualCoreMath (`Vec2`, `Vec3`, `Mat4`),
VisualCoreScenes (`ClipPlane`, `ConvexSolid`, `Mesh`), VisualCoreRendering (`ResourceRegistry`, `ShaderProgram`,
`makeRenderTarget`/`acquireTarget`, `FieldPass` or a full-screen draw, `RenderHost`). No new module or dependency; no
Objective-C++ bridge (existing `vcgl*` calls).
**Seeds**: fixtures use `SDFTestRandom` with seed 2_013; no randomness in the library.
**Testing**: `swift test --package-path Packages/VisualCore` (projection, hull, mask, IoU, stored form);
VisualCoreRendering on sim-27.2 and sim-26.5 (shadow drawing parity, single darkening, zero leaks); ExperiencesCreative
on sim-27.2; reference regression in two chunks; script tests.
**Performance**: bounded by arithmetic — rasterising is O(height × edges + covered cells), at most 2,048 × 2,048 cells
(4 M bits = 512 KiB); IoU is O(words); tests use ≤ 512 × 512; each test < 10 s and light enough not to slow the timed
R02-F05 budget test running beside it.
**Constraints**: additive; existing geometry, camera and renderer code unchanged.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — same context, registry and targets; no stencil or second path. |
| II App-neutral API · II-a reference | PASS — generic API; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — program and coverage target from the registry, rebuilt after a context rebuild, released. |
| IV Host-testable | PASS — every decision on the CPU; no readback for logic. |
| IX Bounded input | PASS — mask ≤ 2,048², triangles ≤ 1,048,576, finite inputs. |
| X Licensing and provenance | PASS — planar projection shadows (Blinn 1988) and Andrew's monotone chain (1979) cited. |
| XI Stable identity | PASS — mask stored form schema 1. |
| XIII Code-only visuals | PASS. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/ShadowError.swift          new  ShadowError + reasonCode
Packages/VisualCore/Sources/VisualCoreScenes/ShadowProjection.swift     new  ShadowLight, ProjectionPlane, ShadowProjector (points, triangles, mesh, solid, matrix)
Packages/VisualCore/Sources/VisualCoreScenes/ConvexHull2D.swift         new  ConvexHull2D.hull(_:), polygon area
Packages/VisualCore/Sources/VisualCoreScenes/CoverageMask.swift         new  CoverageMask (rasterise, count, area, digest, Codable), MaskComparison
Packages/VisualCore/Tests/VisualCoreScenesTests/ShadowProjectionTests.swift, ConvexHull2DTests.swift, CoverageMaskTests.swift   new
Packages/VisualCoreRendering/Sources/VisualCoreRendering/PlanarShadowRenderer.swift   new
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/PlanarShadowRendererTests.swift   new
docs/architecture/shadow-silhouettes.md (new), docs/api/visualcore-public-api.txt, both package READMEs, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none. **Rollback**: revert the commits.

## Parallel work

Agent A: ShadowError, ShadowProjection, ConvexHull2D and tests. Agent B (in parallel; uses only Vec2 polygons):
CoverageMask, MaskComparison and tests. Agent G (after A): PlanarShadowRenderer and its simulator tests. Lead: docs,
API baseline, runs, commits.
