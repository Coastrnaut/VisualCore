# Implementation Plan: Oscilloscope Studio — Phase 02 Timebase/trigger waveform renderer

**Branch**: `062-os-p02-trace-xy` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-DECIMATION in `VisualCoreAudioDSP` (`MinMaxDecimator`: per-column min/max, identity when the window fits) and
G-TRACESTRIP across `VisualCoreScenes` (`Primitive.polyline([Vec2], width:)`, bounded to 8,192 finite points) and
`VisualCoreRendering` (`PrimitiveRenderer` draws it as one quad per non-zero segment in the same batch). In the
experience, replace the per-segment `.line` nodes of A08-P01 with one zig-zag polyline per channel built from the
decimated window, add the XY view (left × gain, right × gain, clamped, one polyline through the window's frames; mono
keeps the waveform view and marks XY unavailable), `ScopeState` schema 2 with `display`, the action `display.select`,
and manifest fixtures for the flat line, the missing crossing in both modes and XY. Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: as A08-P01 (`VisualCoreAudioDSP`, `VisualCoreScenes`, `VisualCoreRendering`,
`VisualCoreAudio`, `VisualCoreExperience`, `VisualCoreExperienceHost`, `VisualCoreUI`). **Storage**: experience snapshot
(`ScopeState` schema 2, migration from 1). **Testing**: host `swift test` (VisualCore: `MinMaxDecimatorTests`,
`SceneGraphTests` polyline cases); `VisualCoreRenderingTests/PrimitiveRendererTests` on sim-27.2 (polyline pixels equal
the segments; existing cases unchanged); ExperiencesCreative on sim-27.2 (core schema 2 and migration; adapter, manifest,
session, render); app build and unit; runner iOS 27; public API; script tests. **Performance**: reduction and polyline
build for 4,096 samples per channel measured on the host (no wall-clock assert on CI). **Constraints**: tests < 10 s;
iOS 27 only; reference regression at X-A08; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (one new primitive case drawn by the existing renderer; no context) · II PASS (decimation and polyline in
VisualCore, XY and copy in the experience) · II-a PASS (regression at X-A08) · III PASS (lifecycle unchanged from
A08-P01) · IV PASS (decimator and polyline host-tested) · V PASS (schema 2 with a schema-1 migration) · VI PASS
(renderer and scope frames on the simulator) · VII PASS (display picker with label and identifier; XY state spoken) ·
VIII PASS (no new data or permission) · IX PASS (8,192-point bound, non-finite points dropped, column count clamped) ·
X–XIII PASS. A08 rules: reuse first, truthful (no calibrated phase claims), bounded — PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreAudioDSP/MinMaxDecimator.swift                                   new
Packages/VisualCore/Tests/VisualCoreAudioDSPTests/MinMaxDecimatorTests.swift                           new
Packages/VisualCore/Sources/VisualCoreScenes/SceneGraph.swift (Primitive.polyline)                     modify
Packages/VisualCore/Tests/VisualCoreScenesTests/SceneGraphTests.swift (polyline cases)                 modify
Packages/VisualCoreRendering/Sources/VisualCoreRendering/PrimitiveRenderer.swift (polyline triangles)  modify
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/PrimitiveRendererTests.swift (polyline)    modify
Packages/ExperiencesCreative/OscilloscopeStudio/Core/{ScopeSettings,ScopeState}.swift (display, schema 2) modify
Packages/ExperiencesCreative/OscilloscopeStudio/Core/ScopeTrace.swift (waveform and XY point builders)  new
Packages/ExperiencesCreative/OscilloscopeStudio/CoreTests/{ScopeStateTests,ScopeTraceTests}.swift       modify/new
Packages/ExperiencesCreative/OscilloscopeStudio/Experience/{Adapter/ScopeCore,Adapter/ScopeManifest,ScopePresenter,
  ScopeControls}.swift, ExperienceTests/{ScopeCoreTests,ScopeManifestTests,ScopeSessionTests,ScopeRenderTests}.swift modify
Packages/ExperiencesCreative/OscilloscopeStudio/scenario-manifest.json                                  regenerate
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, Packages/VisualCoreRendering/README.md,
  docs/apps/oscilloscope-studio/visualcore-contract.json (G-DECIMATION, G-TRACESTRIP, G-XYMODE closed)  modify
```

**Dependency direction** unchanged from A08-P01 (experience → OscilloscopeStudioCore → VisualCoreAudioDSP;
experience → VisualCore host, scenes and rendering; nothing in VisualCore depends on the experience).

**Lifecycle**: as A08-P01; each drawn frame builds at most two polylines (waveform) or one (XY) from the window,
replacing the previous frame's nodes (no per-segment nodes). **Migration**: `ScopeState` schema 1 → 2 adds
`display = waveform` (registry example of schema 1 stored for the migration check). **Rollback**: revert the commits;
the polyline case is additive.

## Parallel work

Agent A: `MinMaxDecimator` + tests and `Primitive.polyline` + SceneGraph tests (VisualCore host). Agent B:
`PrimitiveRenderer` polyline + renderer tests (after A's primitive lands). Agent C: core schema 2, `ScopeTrace`, tests.
Agent D: presenter, controls, adapter, manifest and experience tests after A–C. Lead: README/API/contract, registry
schema-1 example, manifest regeneration, runs, commits.
