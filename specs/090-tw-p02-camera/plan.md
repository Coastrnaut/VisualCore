# Implementation Plan: Tiny Worlds — Phase 02 Camera and scene renderer

**Branch**: `090-tw-p02-camera` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-MATERIALS (an optional per-vertex colour stream on `MeshRenderer`, pixel-identical without it) and G-PICKING
(`Ray3`, `RayHit3` and ray intersection with boxes, spheres and triangles in `VisualCoreMath`) upstream, and G-CAMERA in
Tiny Worlds: a camera policy that keeps the eye 0.5 m above the terrain around it, drag and pinch gestures sent as the
existing view actions, presenter-only easing replaced by direct moves under Reduce Motion, rate-limited spoken view
changes; plus terrain coloured by height, a ground pick on tap, and three detail levels declared as quality levels.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6, GLSL ES 3.0. **Dependencies**: `VisualCoreMath` (`Vec3`, `Vec4`, `OrbitCamera.ray`; new
`Ray3`), `VisualCoreScenes` (`Mesh`, `MeshError`, `Mesh.validate()`, `HeightField`), `VisualCoreRendering`
(`MeshRenderer`, `DepthMeshPass`, `ResourceRegistry`), `VisualCoreScenes` recognizers (`DragRecognizer`,
`PinchRecognizer`, `TapRecognizer`), `VisualCoreExperience` (`GestureAlternatives`, `ExperienceCore`).
**Storage**: unchanged (`WorldState` schema 1). **Testing**: host `swift test --package-path Packages/VisualCore
--filter RayIntersectionTests`; `VisualCoreRendering` package on sim-27.2 (`MeshRendererTests`, `DepthMeshPassTests`,
the new `MeshRendererColorTests`); Tiny Worlds suites on sim-27.2 with the core also on the host scratch package;
public API; app build and unit; runner iOS 27; package check; contract; script tests. **Performance**: level 0 ≤ 4,225
vertices per terrain; the colour stream adds 16 bytes per vertex; ground pick ≤ 2·64 + 40 height samples; clearance
check 9 samples per view change; no per-frame generation. **Constraints**: tests < 10 s; iOS 27 only; reference
regression and iOS 26 at X-A12; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (one renderer, host context) · II PASS (colour stream and ray intersection generic in VisualCore; camera policy,
colouring, levels and picking app-local) · II-a PASS (existing pixels and digests unchanged, API additive, reference at
X-A12) · III PASS (easing transient in the presenter; the state changes only by actions) · IV PASS (ray, colouring,
policy, levels and pick tested without GPU) · V PASS (schema 1 unchanged) · VI PASS (pixel tests on the simulator) ·
VII PASS (gesture alternatives, Reduce Motion, rate-limited speech) · VIII PASS · IX PASS (bounded samples and levels) ·
X PASS · XI–XIII PASS. A12 rules: deterministic, bounded, visuals as code — PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreMath/RayIntersection.swift; Tests/VisualCoreMathTests/RayIntersectionTests.swift  new
Packages/VisualCoreRendering/Sources/VisualCoreRendering/MeshRenderer.swift (colour stream)                         modify
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/MeshRendererColorTests.swift                            new
Packages/VisualCore/README.md, docs/api/visualcore-public-api.txt                                                   modify
Packages/ExperiencesCreative/TinyWorlds/Core/{TerrainColoring,TerrainDetail,CameraPolicy,GroundPick}.swift          new
Packages/ExperiencesCreative/TinyWorlds/CoreTests/{TerrainColoringTests,TerrainDetailTests,CameraPolicyTests,
  GroundPickTests}.swift                                                                                            new
Packages/ExperiencesCreative/TinyWorlds/Experience/{WorldsGestures.swift (new), WorldsPresenter.swift,
  Adapter/WorldsCore.swift (qualityTiers 3, policy-clamped view), Adapter/WorldsManifest.swift}                     new/modify
Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/{WorldsGestureTests (new), WorldsRenderTests,
  WorldsCoreTests}.swift; TinyWorlds/scenario-manifest.json (regenerated)                                           new/modify
Catalog/registrations.json (quality_tiers level-0…2, capabilities); docs/apps/tiny-worlds/visualcore-contract.json
  (G-MATERIALS, G-PICKING, G-CAMERA closed by A12-P02)                                                              modify
```

**Dependency direction** unchanged: TinyWorldsExperience → TinyWorldsCore → VisualCoreScenes, VisualCoreSimulation,
VisualCoreMath; nothing in VisualCore depends on the experience.

**Lifecycle**: `WorldsCore` applies `view.orbit`/`view.zoom`/`view.reset` and then the camera policy (pitch raised
until the clearance holds), so the saved view is always valid; the presenter eases its drawn camera towards the
state's view over 0.35 s (direct under Reduce Motion), builds renderers for the host's current quality level (level
change → rebuild of the terrain renderer only) with colour streams, rebuilds after a context recreation and releases
in teardown; taps resolve on the CPU against the level-0 height field and are spoken; nothing on the GPU is read
back. **Migration**: none. **Rollback**: revert the commits (VisualCore additions are additive; the shader change is
neutral without a stream).

## Parallel work

Agent A: `RayIntersection.swift` and tests. Agent B: `MeshRenderer` colour stream and `MeshRendererColorTests`. Agent C:
Core files and tests. Agent D (after A–C): experience changes and tests. Lead: README, API baseline, registration,
manifest regeneration, contract, runs, commits.
