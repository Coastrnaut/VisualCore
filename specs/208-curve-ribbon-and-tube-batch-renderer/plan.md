# Implementation Plan: R02-F08 — Curve, ribbon and tube batch renderer

**Branch**: `208-curve-ribbon-and-tube-batch-renderer` (spec directory only; work on `main`) | **Date**: 2026-11-19 |
**Spec**: [spec.md](spec.md)

## Summary

Pure curve geometry beside the one mesh in VisualCoreScenes: Bézier chains and centripetal Catmull-Rom splines,
adaptive sampling with arc length, public parallel-transport frames robust to cusps and reversals, ribbons and a tube
overload with world-unit texture coordinates continuous across seams, and mesh merging drawn by the existing
`MeshRenderer` in one call. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (Mesh, MeshBuilder, MeshBudget, MeshError,
validation), VisualCoreMath (Vec3); VisualCoreRendering `MeshRenderer` for the one GPU test. No new dependency.
**Testing**: `swift test --package-path Packages/VisualCore`; one runtime test in VisualCoreRendering on sim-27.2 and
sim-26.5; ExperiencesCreative on sim-27.2 (experiences that use `Mesh.tube`); reference regression in two chunks.
**Performance goals**: bounded by arithmetic: at most 65,536 samples per curve and the mesh budget per mesh; each test
< 10 s. **Constraints**: additive; existing `Mesh.tube` and `CameraRail` outputs unchanged.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — existing `MeshRenderer` draws merged meshes. |
| II App-neutral API · II-a reference | PASS — generic geometry; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — pure value types; one GPU test uses the existing renderer lifecycle. |
| IV Host-testable | PASS — everything but the draw is host-tested. |
| IX Bounded input | PASS — sample and mesh budgets; finite, positive tolerances and widths. |
| XIII Code-only visuals | PASS. |

Post-design re-check: PASS (VisualCoreScenes → VisualCoreMath unchanged).

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/
  CurveSplines.swift     new   ParametricCurve, CubicBezierChain, CatmullRomSpline
  CurveSampler.swift     new   CurveSamples, CurveSampler.sample(_:tolerance:budget:)
  CurveFrames.swift      new   CurveFrame, CurveFrames.parallelTransport(_:initialNormal:)
  CurveMeshes.swift      new   Mesh.ribbon(_:width:repeatLength:budget:), Mesh.tube(samples:…), Mesh.merged(_:budget:), RibbonWidth
  MeshShapes.swift       unchanged
Packages/VisualCore/Tests/VisualCoreScenesTests/
  CurveSplineTests.swift, CurveSamplerTests.swift, CurveFrameTests.swift, CurveMeshTests.swift   new
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/CurveBatchRuntimeTests.swift        new
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/architecture/determinism.md (curves),
docs/catalog/shared-feature-map.json (as built)                                              modify (lead)
```

**Migration**: none. **Rollback**: revert the commits.

## Parallel work

Agent A: CurveSplines and CurveSampler with their tests. Agent B (after A's API names): CurveFrames and CurveMeshes
with their tests. Lead: runtime test, docs, API baseline, runs, commits.
