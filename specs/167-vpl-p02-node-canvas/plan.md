# Implementation Plan: Visual Programming Lab — Phase 02 Node canvas and connections

**Branch**: `167-vpl-p02-node-canvas` (spec directory only; work on `main`) | **Date**: 2026-11-18 | **Spec**: [spec.md](spec.md)

## Summary

This phase brings Visual Programming Lab into the one app as a candidate and closes G-CANVAS:
- **Core additions (pure):** `GraphEditor` (edits with refusals, using `GraphChecker`), `CanvasLayout` (boxes, ports,
  44-point targets, wire curves, hit testing), `CanvasView` (a `PlaneViewport` with y flipped, bounded zoom and pan)
  and `EditMessages` (one sentence per refusal and status).
- **Experience:** `LabCore` (snapshot schema 1, actions and rules), `LabPresenter` (grid scene, touch mapping, view
  state), `CanvasOverlay` (native nodes, ports and wires), `LabControls` (add menu, remove, list form, status,
  feedback) and `VisualProgrammingLabExperience.make(id:storage:)`.
- **Registration:** a candidate with a scenario manifest.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/experience.md](contracts/experience.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI, GLSL ES 3.00 (the grid shader, as text).
- **Dependencies:**
  - the core adds `VisualCoreMath` (`PlaneViewport`, `Vec2`);
  - the experience → `VisualProgrammingLabCore`, `VisualCoreParameters`, `VisualCoreExperience`,
    `VisualCorePersistence`, `VisualCoreMath`, `VisualCoreScenes` (`PointerEvent`), `VisualCoreRendering`
    (`FullScreenShaderScene`, `ShaderBundle`), `VisualCoreExperienceHost` (`ExperiencePresenter`, `ExperienceShell`)
    and `VisualCoreUI`.
  Only APIs verified at A23-P00, A23-P01 and this phase's clarification are used.
- **Testing:**
  - `VisualProgrammingLabCoreTests` and `VisualProgrammingLabExperienceTests` on sim-27.2;
  - the app build and unit tests;
  - the runner on iOS 27.
- **Constraints:**
  - no GL call outside VisualCore's scenes;
  - the canvas draws at 30 frames per second at one tier;
  - each test runs in under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: the grid is a VisualCore full-screen scene inside the presenter's calls; no GL call of the experience |
| II | PASS: reuses `PlaneViewport`, `FullScreenShaderScene`, `ExperiencePresenter`, the A23-P01 core; nothing copied |
| III | PASS: main-actor presenter; actions only through the engine |
| IV | PASS: editor, layout, view and messages tested without the GPU |
| IX | PASS: native overlay and controls with spoken labels; a list form for every canvas edit; 44-point targets |
| XI | PASS: a candidate, not available; one app target |
| A23 (2.19.0) | PASS: pure graph truth; validation before any GPU work; caps; accessible list form; offline |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                          modify  core + VisualCoreMath; VisualProgrammingLabExperience(+Tests), product
Packages/ExperiencesCreative/VisualProgrammingLab/Core/{GraphEditor,CanvasLayout,CanvasView,EditMessages}.swift   new
Packages/ExperiencesCreative/VisualProgrammingLab/CoreTests/{EditorTests,CanvasLayoutTests,CanvasViewTests,EditMessagesTests}.swift new
Packages/ExperiencesCreative/VisualProgrammingLab/Experience/Adapter/{LabCore,LabManifest}.swift                  new
Packages/ExperiencesCreative/VisualProgrammingLab/Experience/{GridScene,LabPresenter,CanvasOverlay,LabControls,VisualProgrammingLabExperience}.swift new
Packages/ExperiencesCreative/VisualProgrammingLab/ExperienceTests/{LabTestSupport,LabCoreTests,TouchTests,CanvasDrawTests,
  RebuildTests,LabManifestTests}.swift                                              new
Packages/ExperiencesCreative/VisualProgrammingLab/scenario-manifest.json            new
Catalog/registrations.json; Apps/VisualCore/App/ExperienceRegistry.swift; project.yml   modify  candidate a23
Apps/VisualCore/Tests/Unit/AppModelTests.swift (synthetic id a24.graphics-benchmark-lab); RealCatalogTests; scripts/test_scripts.py
docs/apps/visual-programming-lab/visualcore-contract.json (G-CANVAS closed)         modify
```

- **Dependency direction:** app → experience → core → VisualCore.
- **Lifecycle:**
  - the presenter builds the grid scene in `setup` and sets its `zoom` and `pan` at each `draw`;
  - `resize` passes the new size to the scene and to `CanvasView.resized(to:)`;
  - `teardown` tears the scene down; a context rebuild sets it up again from the same view state;
  - touches are mapped in `pointer` and dropped in `cancelPointers`.
- **Migration:** snapshot schema 1. **Rollback:** revert the commits.

## Parallel work

- **Agent E:** `GraphEditor`, `EditMessages` and their tests (core).
- **Agent L:** `CanvasLayout`, `CanvasView` and their tests (core).
- **Agent X:** the experience adapter, presenter, grid scene, overlay, controls, factory, manifest and the experience
  tests, against [contracts/experience.md](contracts/experience.md) and the core declarations of
  [data-model.md](data-model.md).
- **Lead:** Package.swift, registration (catalog, registry, project.yml, app and script tests), the contract, runs,
  commits.
