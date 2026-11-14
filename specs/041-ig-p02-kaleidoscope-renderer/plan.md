# Implementation Plan: Infinite Geometry — Phase 02 2D kaleidoscope renderer

**Branch**: `041-ig-p02-kaleidoscope-renderer` (spec directory only; work on `main`) | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Add VisualCore's 2D SDF helpers and a GLSL dihedral fold matching `PointGroup.fold` (G-SDF2D, with a GPU/CPU parity
test) and camera bounds for `Camera2D` and `OrbitCamera` (G-ORBITBOUNDS); draw the kaleidoscope with a full-screen
shader through `FullScreenShaderScene`; give the experience camera state and actions (pan, zoom, orbit, reset) mapped from
gestures with native button alternatives. Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6, GLSL ES 3.00 (shader library). **Dependencies**: existing packages. **Storage**: camera state joins
the Codable core snapshot (schema 1 → 2 with a migration step). **Testing**: host `swift test` (camera bounds);
VisualCoreRendering on sim-27.2/26.5 (fold parity, SDF signs); ExperiencesCreative on both runtimes (camera actions,
kaleidoscope symmetry probes, sessions); runner 9/9 on both; app unit; reference regression; public API.
**Constraints**: no wall-clock assertions on CI; tests < 10 s.

## Constitution Check

I PASS (existing GL path) · II PASS (helpers and bounds in VisualCore) · II-a PASS · III PASS (shader scene owned by the
presenter, created in setup, released in teardown, recompiled after context loss) · IV PASS (camera domain host-tested)
· V PASS · VI PASS (parity and probes) · VII PASS (button alternatives for every gesture) · VIII–XIII PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreMath/CameraBounds.swift                  new  ViewBounds2D, OrbitBounds; Camera2D/OrbitCamera pan, zoom, orbit, clamp
Packages/VisualCore/Tests/VisualCoreMathTests/CameraBoundsTests.swift          new
Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/sdf.glsl      modify  vc_sdCircle, vc_sdBox2, vc_sdSegment, vc_sdConvex, vc_foldDihedral
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/SymmetryParityTests.swift  new  GPU fold vs PointGroup.fold; SDF signs
Packages/ExperiencesCreative/InfiniteGeometry/Experience/KaleidoscopeShader.swift        new  fragment source using vc/sdf.glsl; parameter mapping from core state
Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryCore.swift      modify  camera state, actions camera.pan/zoom/orbit/reset, schema 2 migration
Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryPresenter.swift         modify  kaleidoscope via FullScreenShaderScene; camera applied to 2D and 3D; gestures; probes
Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryControls.swift          modify  camera buttons
Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/{GeometryCameraTests,KaleidoscopeRenderTests}.swift     new
Packages/ExperiencesCreative/InfiniteGeometry/scenario-manifest.json                     regenerate (controls grow)
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, Packages/VisualCoreRendering/README.md, Auto-Creator.md §13   modify
```

**Lifecycle**: the presenter owns one `FullScreenShaderScene` (setup/teardown/recreate) used only for the kaleidoscope.
**Migration**: snapshot schema 2 adds the camera; a schema-1 snapshot migrates with the preset's default camera.
**Rollback**: revert the commits.

## Parallel work

Agent A: CameraBounds + tests. Agent B: sdf.glsl additions + SymmetryParityTests. Agent C: experience changes + tests
(against A's API in contracts/api.md and B's GLSL names). Lead: docs, baseline, manifest regeneration, runs, commits.
