# Implementation Plan: Infinite Geometry — Phase 03 3D mesh and camera

**Branch**: `042-ig-p03-mesh-camera` (spec directory only; work on `main`) | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Add VisualCore's depth-correct mesh pass (G-MESHSCENE): a `DepthMeshPass` in VisualCoreRendering that owns a render
target with depth at the context's pixel size, draws a list of meshes through one orbit camera with depth test and write
on, and blits the colour to the context's framebuffer, rebuilding on resize and context recreation. Add orbit-camera pan
in view space, a target bound, a field-of-view clamp and the bounding-sphere distance rule (G-ORBITBOUNDS remainder) as
`OrbitViewBounds` in VisualCoreMath. The experience draws the 3D composition through the pass and gains target and field
of view in its camera state (snapshot schema 3), the `camera.fov` action, 3D pan and two-finger pan. Research:
[research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: existing packages only. **Storage**: target and field of view join the Codable
core snapshot (schema 2 → 3 with a migration step; schema 1 migrates through 2). **Testing**: host `swift test`
(orbit view bounds); VisualCoreRendering on sim-27.2/26.5 (occlusion in both orders, offscreen equality, context
recreation); ExperiencesCreative on both runtimes (camera actions and bounds, schema migration, 3D occlusion probes);
runner on both; app unit; reference regression; public API. **Constraints**: no wall-clock assertions on CI; tests
< 10 s; no second renderer.

## Constitution Check

I PASS (existing GL ES → ANGLE path; one more render target and a blit) · II PASS (pass and bounds in VisualCore, the
composition and its radius stay in the experience) · II-a PASS (no ProjectM) · III PASS (the presenter owns the pass,
created in setup, released in teardown, rebuilt on a new context generation; the host owns the context) · IV PASS
(camera domain host-tested) · V PASS (snapshot migration chain) · VI PASS (pixel probes on both runtimes) · VII PASS
(button alternatives for pan and field of view; no gesture-only action) · VIII–XIII PASS (no network, no assets, no ads,
documentation and baseline updated).

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreMath/OrbitViewBounds.swift                         new  OrbitViewBounds; OrbitCamera.right/up, panned, withFieldOfView, clamp
Packages/VisualCore/Tests/VisualCoreMathTests/OrbitViewBoundsTests.swift                 new
Packages/VisualCoreRendering/Sources/VisualCoreRendering/DepthMeshPass.swift             new  depth target, draw items, blit, rebuild, release
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/DepthMeshPassTests.swift     new  occlusion both orders, offscreen equality, context recreation, empty list
Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryCore.swift      modify  Orbit3D target/fov, camera.fov, 3D camera.pan, schema 3 migration, bounding radius
Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryPresenter.swift         modify  solid via DepthMeshPass; two-finger pan; camera fov/target applied
Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryControls.swift          modify  Wider/Narrower buttons; pan buttons also on the solid
Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryManifest.swift  modify  fixture 3 adds field-of-view and bounding-sphere steps
Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/{GeometryOrbitViewTests,SolidOcclusionTests}.swift  new
Packages/ExperiencesCreative/InfiniteGeometry/scenario-manifest.json                     regenerate
Apps/VisualCore/App/ExperienceRegistry.swift                                             modify  schema-2 example added to the migration examples
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, Packages/VisualCoreRendering/README.md, Auto-Creator.md §13   modify
```

**Dependency direction**: InfiniteGeometryExperience → VisualCoreRendering (DepthMeshPass, MeshRenderer) →
VisualCoreMath (OrbitCamera, OrbitViewBounds); nothing in VisualCore depends on the experience.

**Lifecycle**: `DepthMeshPass.draw` (re)creates its depth target when the context's pixel size or the registry
generation differs from the target's, so resize, offscreen export (redirected context) and context recreation all
rebuild; `release()` returns the target to the registry (teardown). An offscreen export draws into the export target
through the same blit, so captured stills are depth-correct.

**Migration**: snapshot schema 3 adds `target` (x, y, z) and `fovDegrees` to the 3D camera; schema 2 migrates with the
default target (origin) and 60°; schema 1 migrates through 2. A restored camera outside the bounds is refused.

**Rollback**: revert the commits; schema-3 snapshots written meanwhile would be refused by the Phase 02 build (no
migration backwards), which is acceptable before release (no shipped data).

## Parallel work

Agent A: OrbitViewBounds + tests. Agent B: DepthMeshPass + tests. Agent C: experience changes + tests against
contracts/api.md. Lead: docs, baseline, registry example, manifest regeneration, runs, commits.
