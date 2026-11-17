# Implementation Plan: Digital Zen Garden — Phase 02 Sand and rake renderer

**Branch**: `146-zg-p02-sand-renderer` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase adds the Digital Zen Garden experience and closes three gaps:
- **G-SAND:** the drawn 480 × 360 height field, stamped on the CPU from the core's strokes, uploaded to one render
  target and rebuilt by replay; the transport of strokes to the core as small actions.
- **G-RELIEF:** the relief shader (normals from height, one light, grain, tone) inside the fitted 4:3 tray.
- **G-PREVIEW:** the rake outline drawn as a native overlay at the touch.

The experience is registered as a candidate with its scenarios; VisualCore and ProjectM are unchanged.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/experience.md](contracts/experience.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6 (strict concurrency), SwiftUI for controls and the overlay, GLSL ES 3.00 fragment source over
  `vc/` inside the experience; no GL call outside the host's scene protocol.
- **Dependencies:** `DigitalZenGardenExperience` → the core, `VisualCoreMath`, `VisualCoreScenes`,
  `VisualCoreSimulation`, `VisualCoreExperience`, `VisualCoreRendering`, `VisualCoreExperienceHost`, `VisualCoreUI` (as
  Ambient Clock's experience); its tests add `VisualCoreDiagnostics`.
- **Testing:** `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme
  ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalZenGardenCoreTests
  DigitalZenGardenExperienceTests`; the app build and unit tests; the runner on iOS 27.
- **Performance:** a full replay at 480 × 360 of 400 strokes of 512 points stamps at most 204,800 footprints of at most
  about 50 × 3 cells (bounded arithmetic, not a device claim); each test under 10 s.
- **Constraints:** iOS 27 only; iOS 26 and the reference regression at X-A20; no VisualCore change. No NEEDS
  CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: one render target and one full-screen scene through the host's context |
| II | PASS: reuses `FullScreenShaderScene`-style scene protocol, `ResourceRegistry.makeRenderTarget`, `RenderTarget.upload(rgbaFloats:)`, `readFloatPixels`, `FloatRenderSupport`, the GLSL library, `ExperienceShell`, the canvas overlay |
| IV | PASS: the field stays a CPU model rebuilt from the command log; drawing never changes the state |
| IX | PASS: native controls with spoken labels; patterns as native alternatives to raking |
| XIII | PASS: the shader is written here and added to `licenses.md` |

A20 rules (constitution 2.16.0): PASS: calm by default (no animation of its own), bounded field and caps, no permission.

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                                         modify  experience target, tests, product
Packages/ExperiencesCreative/DigitalZenGarden/Core/SandField.swift                                  modify  a size (default 160 × 120)
Packages/ExperiencesCreative/DigitalZenGarden/Experience/Adapter/GardenCore.swift                    new     ExperienceCore: controls, stroke in progress, snapshot
Packages/ExperiencesCreative/DigitalZenGarden/Experience/Adapter/GardenManifest.swift                new     scenarios and fixtures
Packages/ExperiencesCreative/DigitalZenGarden/Experience/SandScene.swift                             new     field upload, relief shader, tray fit
Packages/ExperiencesCreative/DigitalZenGarden/Experience/GardenPresenter.swift                       new     pointer to actions, preview state, rebuild
Packages/ExperiencesCreative/DigitalZenGarden/Experience/BrushPreview.swift                          new     the overlay
Packages/ExperiencesCreative/DigitalZenGarden/Experience/StrokePatterns.swift                        new     rows, circle, wave, spiral
Packages/ExperiencesCreative/DigitalZenGarden/Experience/GardenControls.swift                        new     native controls
Packages/ExperiencesCreative/DigitalZenGarden/Experience/DigitalZenGardenExperience.swift            new     factory
Packages/ExperiencesCreative/DigitalZenGarden/ExperienceTests/*.swift                               new
Packages/ExperiencesCreative/DigitalZenGarden/scenario-manifest.json                                 new     generated
Catalog/registrations.json; Apps/VisualCore/App/ExperienceRegistry.swift; project.yml                modify  candidate
Apps/VisualCore/Tests/Unit/AppModelTests.swift; scripts/test_scripts.py; RealCatalogTests             modify  candidate lists, synthetic id a21
docs/apps/digital-zen-garden/{visualcore-contract.json,licenses.md}                                  modify  G-SAND, G-RELIEF, G-PREVIEW closed; shader row
```

- **Dependency direction:** experience → core → VisualCore; the app registry → the experience product.
- **Lifecycle:** the scene's setup creates the target and program; resize and a context recreation rebuild by replay;
  teardown releases both; `cancelPointers` ends the stroke in progress without committing it and hides the preview.
- **Migration:** snapshot schema 1, the first version. **Rollback:** revert the commits.

## Parallel work

- **Agent E:** the experience (one writer: adapter, scene, presenter, overlay, patterns, controls, factory and tests).
- **Agent K:** the `SandField` size and its tests.
- **Lead:** Package.swift, registration, manifest generation, contract, runs, commits.
