# Implementation Plan: Infinite Geometry — Phase 05 Mesh, cache and quality regression

**Branch**: `044-ig-p05-mesh-cache-quality` (spec directory only; work on `main`) | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Add VisualCore's bounded least-recently-used `MeshCache` (VisualCoreScenes, G-MESHCACHE) and the tier-driven
`TessellationChoice` (VisualCoreDiagnostics, G-MESHLOD). Infinite Geometry declares a four-level quality profile, keeps
the tier outside its digest, and draws the solid through the cache at the tier's segment count while the core's
reference composition stays at full tessellation. A multi-aspect proportion test extends fixture 5. Research:
[research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: existing packages. **Storage**: none new (the tier is not persisted; the
snapshot schema stays 3). **Testing**: host `swift test` (cache, tessellation); ExperiencesCreative on sim-27.2/26.5
(tier monotonicity and digest equality, cache hits through the presenter, proportions at four aspects); runner on both;
app unit; public API; reference regression; script tests. **Constraints**: tests < 10 s; no wall-clock assertions on CI.

## Constitution Check

I PASS (no new renderer) · II PASS (cache and tessellation rule in VisualCore; the composition's segment use in the
experience) · II-a PASS · III PASS (CPU mesh cache owned by the presenter, GPU buffers unchanged in lifecycle) · IV PASS
(host-tested framework parts) · V PASS (no state change) · VI PASS (pixel and mapping proportion checks on both runtimes)
· VII PASS (no new control; the app's existing quality setting) · VIII–XIII PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/MeshCache.swift                         new  MeshCache (LRU, limits, counts), Mesh.byteSize
Packages/VisualCore/Tests/VisualCoreScenesTests/MeshCacheTests.swift                 new
Packages/VisualCore/Sources/VisualCoreDiagnostics/TessellationChoice.swift           new  segments(full:minimum:share:) and the budget-fitting variant
Packages/VisualCore/Tests/VisualCoreDiagnosticsTests/TessellationChoiceTests.swift   new
Packages/ExperiencesCreative/InfiniteGeometry/Core/Composition.swift                 modify  solid(segments:) parameter (default 24); signature for the cache
Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryCore.swift  modify  qualityTiers 4, qualityProfile, setQualityTier (not in digest/snapshot), tier segments
Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryPresenter.swift     modify  drawn solid from MeshCache at the tier's segments; counts exposed for tests
Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/{GeometryQualityTests,GeometryProportionTests}.swift  new
Packages/ExperiencesCreative/InfiniteGeometry/InfiniteGeometryCoreTests (existing core test target)  modify  solid(segments:) validation at 8/12/16/24
Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryManifest.swift  modify  fixture 5 doc (multi-aspect check named)
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, Auto-Creator.md §13   modify
```

**Dependency direction**: InfiniteGeometryExperience → VisualCoreScenes (MeshCache) and VisualCoreDiagnostics
(TessellationChoice, QualityProfile); VisualCore depends on nothing new.

**Lifecycle**: the presenter owns one `MeshCache` (CPU meshes) for its lifetime; GPU mesh renderers are still created for
the drawn mesh and released on teardown or when the drawn mesh changes; a context recreation keeps the CPU cache.

**Migration**: none (tier not persisted). **Rollback**: revert the commits.

## Parallel work

Agent A: MeshCache + tests. Agent B: TessellationChoice + tests. Agent C: experience changes + tests against
contracts/api.md. Lead: docs, baseline, manifest, runs, commits.
