# Implementation Plan: Molecular Explorer — Phase 02 Camera/atom/bond renderer

**Branch**: `111-me-p02-renderer` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Build G-RENDER, G-CAMERA and G-DISPLAY with no VisualCore change: in the core a pure molecule scene (atom items and
bond halves for a display mode), camera settings with steps, limits and a framed orbit camera, and state schema 2
(molecule, mode, camera) with a migration from schema 1; in the experience the presenter draws the scene with one unit
sphere and one unit stick renderer, new actions and native controls for the mode and the camera, a legend and the mode
in the canvas description, and two new manifest fixtures. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Contract: [contracts/renderer.md](contracts/renderer.md).

## Technical Context

**Language**: Swift 6. **Dependencies** (verified in the clarification session): `VisualCoreMath` (`Vec3`, `Mat4`,
`Quat`, `OrbitCamera`) — now also a dependency of the core, which stays pure; `VisualCoreScenes` (`Mesh.uvSphere`,
`Mesh.tube`); `VisualCoreRendering` (`MeshRenderer`, `DepthMeshPass.Item(renderer:model:color:)`);
`VisualCoreExperience` (`MigrationChain`) and `VisualCoreExperienceHost`. **Storage**: the session state (schema 2).
**Testing**: core and experience tests in ExperiencesCreative on sim-27.2; app build and unit; runner iOS 27;
packages; contract; documented API; script tests. **Performance**: at most 74 draw items for the library, budget 1,500;
two meshes. **Constraints**: tests < 10 s; iOS 27 only; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (one renderer, the host's) · II PASS (sphere, tube, mesh renderer, depth pass, orbit camera reused; instanced
lit meshes assessed and not needed) · II-a N/A (no VisualCore change) · III PASS (geometry in code) · IV PASS (scene,
camera and state tested without GPU; drawing reads the state only) · V PASS (schema 2 with a migration from 1) · VI
PASS · VII PASS (native controls with values; mode spoken; legend states display radii) · VIII PASS · IX PASS (draw
budget, camera limits) · X PASS · XI–XIII PASS. A15 rules: truthful claims (display radii labelled), bounded,
GPU-free rules, context loss rebuilds from state — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/MolecularExplorer/Core/{DisplayMode,MoleculeScene,CameraSettings}.swift           new
Packages/ExperiencesCreative/MolecularExplorer/Core/MoleculeState.swift (schema 2)                             modify
Packages/ExperiencesCreative/MolecularExplorer/CoreTests/{MoleculeSceneTests,CameraSettingsTests,
  MoleculeStateSchema2Tests}.swift                                                                              new
Packages/ExperiencesCreative/MolecularExplorer/Experience/{Adapter/MoleculeCore.swift (actions, migration),
  Adapter/MoleculeManifest.swift (fixtures), MoleculePresenter.swift (scene drawing), MoleculeControls.swift}  modify
Packages/ExperiencesCreative/MolecularExplorer/ExperienceTests/{MoleculeSceneRenderTests,
  MoleculeCameraTests}.swift; existing experience tests updated                                                new/modify
Packages/ExperiencesCreative/Package.swift (core depends on VisualCoreMath); scenario-manifest.json (regenerated);
  docs/apps/molecular-explorer/visualcore-contract.json (G-RENDER, G-CAMERA, G-DISPLAY closed)                   modify
```

**Dependency direction**: Experience → Core → VisualCoreMath and Foundation; the experience → scenes, rendering, host,
UI; nothing in VisualCore depends on the experience.

**Lifecycle**: actions change the state at their step; choosing a molecule resets the camera, keeps the mode. The
presenter builds the scene from the state on each draw (pure, cheap), owns the two renderers (made together when the
context is current, rebuilt after a recreation, released together), and never writes the state. **Migration**: schema
1 → 2 (default mode and camera) through the adapter's `MigrationChain`. **Rollback**: revert the commits; schema-2
snapshots then fail to restore and the experience opens with water (refused newer state).

## Parallel work

Agent A: core files and core tests (contracts/renderer.md). Agent B: experience changes and tests after A. Lead:
Package.swift, manifest regeneration and pins, contract, runs, commits.
