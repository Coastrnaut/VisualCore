# Implementation Plan: Interactive Anatomy — Phase 02 Region scene/selection renderer

**Branch**: `125-ia-p02-scene-selection` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds G-SCENE, G-PICK, G-CAMERA and G-BUDGETS with no VisualCore change, plus the layer toggles of the
manual's Phase 02 MVP. The work splits into the core and the experience.

**Core** (pure, GPU-free):
- the two quality levels with their budgets;
- schematic geometry for each of the 20 declared meshes, built from `MeshShapes` and `Mesh.uvSphere` and placed by a
  model matrix;
- the region scene (items, structure spheres, counts and the budget refusal);
- the picker (a ray against visible triangles);
- the camera (steps, limits, the opening view, framing);
- the view state (schema 1).

**Experience**, registered as a candidate:
- the adapter with ten actions and four rule refusals;
- a presenter that draws the visible items through one `DepthMeshPass`, with one `MeshRenderer` per mesh made and
  released together, and that turns a tap into `structure.select` or `structure.clear`;
- native controls: layer toggles, the structure list grouped by layer, camera steps and Reset view;
- the manifest with fixtures.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/scene.md](contracts/scene.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6.
- **Dependencies** (verified in the clarification session):
  - core: `VisualCoreMath` (`Vec3`, `Mat4`, `Quat`, `OrbitCamera`, `Ray3`, `RayHit3`) and `VisualCoreScenes` (`Mesh`,
    `MeshShapes`, `MeshBudget`, `Mesh.validate`, `Mesh.bounds`, `Mesh.digest`), both pure;
  - experience: `VisualCoreRendering` (`MeshRenderer`, `DepthMeshPass`), `VisualCoreExperience` (`ExperienceCore`,
    `MigrationChain`, `DigestBuilder`), `VisualCoreExperienceHost` (`ExperienceShell`, `ExperiencePresenter`) and
    `VisualCoreUI`.
- **Storage:** the session snapshot (state schema 1).
- **Testing:** core and experience tests in ExperiencesCreative on sim-27.2; app build and unit; runner on iOS 27;
  packages; contract; documented API; script tests.
- **Performance:** 20 draws; at most 60,000 triangles at level-0 and 20,000 at level-1. Picking tests at most every
  visible triangle once per tap, after a sphere prefilter.
- **Constraints:** tests under 10 s; iOS 27 only. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: one renderer, the host's; no context code in the experience |
| II | PASS: generators, ray tests, the depth pass, the mesh renderer and the orbit camera are reused; nothing is copied |
| II-a | N/A: no VisualCore change |
| III | PASS: geometry in code |
| IV | PASS: the scene, picker, camera and state are tested without a GPU; drawing reads the state only |
| V | PASS: state schema 1 with typed refusals |
| VI | PASS |
| VII | PASS: native list and toggles with labels and values; layer names in words |
| VIII | PASS |
| IX | PASS: budgets per level; camera limits |
| X–XIII | PASS |

A17 rules: educational not medical (no new text), visuals are code, the not-reviewed label stays in the content:
PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift: core + VisualCoreScenes; targets InteractiveAnatomyExperience(Tests);
  product InteractiveAnatomyExperience                                                                modify
Packages/ExperiencesCreative/InteractiveAnatomy/Core/{AnatomyQuality,AnatomyGeometry,AnatomyScene,AnatomyPicker,
  AnatomyCamera,AnatomyViewState}.swift                                                               new
Packages/ExperiencesCreative/InteractiveAnatomy/CoreTests/{SceneBuildTests,BudgetTests,PickerTests,
  CameraFramingTests,ViewStateTests}.swift                                                            new
Packages/ExperiencesCreative/InteractiveAnatomy/Experience/{Adapter/AnatomyCore.swift,Adapter/AnatomyManifest.swift,
  AnatomyPresenter.swift,AnatomyControls.swift,InteractiveAnatomyExperience.swift}                    new
Packages/ExperiencesCreative/InteractiveAnatomy/ExperienceTests/{AnatomyTestSupport,AnatomyCoreTests,
  AnatomySessionTests,AnatomyRenderTests,AnatomyTapTests,AnatomyManifestTests}.swift                  new
Packages/ExperiencesCreative/InteractiveAnatomy/scenario-manifest.json                                generated
Catalog/registrations.json and Packages/VisualCore/Tests/VisualCoreExperienceTests/Fixtures/Catalog/
  {registrations,experiences}.json; Catalog/experiences.json (build_catalog.py)                        modify
Apps/VisualCore/App/ExperienceRegistry.swift (candidate); project.yml (product); app and script tests
  listing registrations                                                                               modify
docs/apps/interactive-anatomy/visualcore-contract.json (G-SCENE, G-PICK, G-CAMERA, G-BUDGETS closed)  modify
```

**Dependency direction:** the experience → the core → VisualCoreMath, VisualCoreScenes and Foundation. The experience
also depends on rendering, the host and UI. Nothing in VisualCore depends on the experience.

**Lifecycle:**
- Actions change the view state at their step.
- The scene is built once per quality level from the bundled content and cached in the adapter; a level change selects
  the other cached scene.
- The presenter makes one `MeshRenderer` per mesh when the context is current. It rebuilds them all after a recreation
  (setup again) and releases them all together with the pass in teardown. It never writes the state.
- A tap goes through the presenter's `pointer` to the picker and sends an action.

**Migration:** none (schema 1 is the first). **Rollback:** revert the commits. The candidate registration goes with
them, and the pending core of A17-P01 remains.

## Parallel work

- **Agent A:** the core sources and core tests (contracts/scene.md).
- **Agent B, after A:** the experience sources and experience tests.
- **Lead:** Package.swift, registration, manifest generation, contract, runs, commits.
