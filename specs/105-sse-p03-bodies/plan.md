# Implementation Plan: Solar System Explorer — Phase 03 Camera and 3D body rendering

**Branch**: `105-sse-p03-bodies` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Build G-BODIES with no VisualCore change: in the core a seeded seam-free `SphereNoise`, a `SurfaceRecipe` per body
(per-vertex colours by unit direction, surface digest), Saturn's ring record (NSSDCA, public domain) with an audit, a
`ScaleMode` mapping (enhanced 4·√r with display radii; true-relative 2 units per AU for positions and radii) and
`SolarState` schema 3 (`scaleMode`); in the experience the presenter draws coloured spheres, a two-sided ring, a seeded
starfield and markers for sub-2-pixel bodies in the true-relative mode, eases its drawn camera through a pure
`FocusFlight` (30 frames, clearance push-out, Reduce Motion cut), builds model matrices camera-relative in double
precision, and the controls gain a scale-mode switch with its spoken label. Research: [research.md](research.md).
Data: [data-model.md](data-model.md). Contract: [contracts/bodies.md](contracts/bodies.md).

## Technical Context

**Language**: Swift 6. **Dependencies** (verified during clarification): `VisualCoreMath` (`Vec3`, `Mat4`,
`OrbitCamera` with public `near`/`far`, `StableHash`), `VisualCoreScenes` (`Mesh` with public `positions`, `normals`,
`uvs`, `indices`; `Mesh.uvSphere(segments:rings:radius:)`, `Mesh.revolution(profile:segments:)`, `Mesh.tube`),
`VisualCoreRendering` (`MeshRenderer(mesh:colors:registry:)` with per-vertex colours, back-face culling always on;
`DepthMeshPass`), `VisualCoreExperience`, `VisualCoreExperienceHost`, `VisualCoreUI`. **Storage**: none. **Testing**:
ExperiencesCreative on sim-27.2 (`SolarSystemExplorerCoreTests`, `SolarSystemExplorerExperienceTests`); app build and
unit; runner iOS 27; packages; contract; script tests. **Performance**: nine spheres of 48 × 24 segments (≈ 1,225
vertices each), one ring of 2 × 64 segments, one starfield mesh of 400 small tetrahedra, eight orbit tubes; surfaces
and meshes built once on the CPU. **Constraints**: tests < 10 s, no wall-clock asserts; iOS 27 only; reference
regression and iOS 26 at X-A14. No NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (one app; candidate) · II PASS (meshes, renderer, camera, hash reused) · II-a N/A (no VisualCore change; the 3D
noise stays app-local with one consumer, recorded in the contract) · III PASS (procedural surfaces, rings and stars;
no textures) · IV PASS (noise, recipes, ring audit, scale mapping, flight and precision tested without GPU) · V PASS
(state schema 3 with a tested migration from 2) · VI PASS · VII PASS (scale mode shown and spoken; enhanced mode
labelled not to scale; Reduce Motion cuts the flight; nothing flashes) · VIII PASS (no network, no data collection) ·
IX PASS (bounded meshes built once) · X PASS · XI–XIII PASS. A14 rules: provenance (ring radii audited), truthful
scale labelling, deterministic GPU-free rules (the flight is presentation only, the state is unchanged by it) — PASS.
Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/SolarSystemExplorer/Core/{SphereNoise,SurfaceRecipe,RingRecord,ScaleMode}.swift  new
Packages/ExperiencesCreative/SolarSystemExplorer/Core/{SolarState,SourceRecords,CitationAudit}.swift          modify
Packages/ExperiencesCreative/SolarSystemExplorer/CoreTests/{SphereNoiseTests,SurfaceRecipeTests,RingRecordTests,
  ScaleModeTests,SolarStateSchema3Tests}.swift; existing state and audit tests adjusted                       new/modify
Packages/ExperiencesCreative/SolarSystemExplorer/Experience/{FocusFlight,SceneMeshes}.swift                    new
Packages/ExperiencesCreative/SolarSystemExplorer/Experience/{OrbitLayout,SolarPresenter,SolarControls,
  SolarSystemExplorerExperience,Adapter/SolarCore,Adapter/SolarManifest}.swift                               modify
Packages/ExperiencesCreative/SolarSystemExplorer/ExperienceTests/{FocusFlightTests,PrecisionTests,
  SceneMeshesTests,SolarBodiesRenderTests}.swift; existing tests adjusted                                    new/modify
Packages/ExperiencesCreative/SolarSystemExplorer/scenario-manifest.json (regenerated, schema 3)              modify
docs/apps/solar-system-explorer/{data-sources.md (regenerated), visualcore-contract.json (G-BODIES closed; label
  placement moved to G-TOURS; rows M06, M07, M09, M13, M21, M23), visualcore-contract.md, README}            modify
```

**Dependency direction**: Core → VisualCoreMath and Foundation (already, A14-P02); Experience → Core, scenes,
rendering, host, UI; nothing in VisualCore depends on the experience.

**Lifecycle**: the core holds `SolarState` schema 3; `scale.mode` applies at its step. The presenter receives Reduce
Motion at make; it keeps its drawn view (`FocusFlight` progress) as presentation state, never in the core, so digests
do not depend on it. CPU meshes and colours (spheres, ring, stars, markers, orbit paths in both modes) are built once;
GPU renderers (bodies, ring, stars, markers, orbits — two orbit sets, one per mode) are created together and released
together (shared cached program, A14-P01 As built). Per frame: target and eye from the flight, positions minus target
in Double, then Float model matrices. **Migration**: schema 2 → 3 adds `scaleMode` 0; newer refused. **Rollback**:
revert the commits.

## Parallel work

Agent A: Core `SphereNoise`, `SurfaceRecipe` and tests. Agent B: Experience `FocusFlight`, precision helpers and
tests. Lead: `RingRecord`, sources and audit, `ScaleMode`, `SolarState` schema 3, `SolarCore`, manifest. Agent C
(after A, B and the lead's core): presenter, scene meshes, controls and render tests.

## Evidence

`python3 Tools/python/desktop_runbook.py run-check --stage A14-P03 --timeout 600 --name <n> -- <cmd>`: `sse-core-ios27`,
`sse-ios27`, `app-unit`, `verify-27`, `experience-packages`, `script-tests`, `contract`.
