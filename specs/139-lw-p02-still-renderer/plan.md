# Implementation Plan: Living Wallpapers — Phase 02 Offscreen still renderer

**Branch**: `139-lw-p02-still-renderer` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase adds two VisualCore pieces, the drawn scenes and the experience:
- **G-ENCODE (`VisualCoreRendering`):** JPEG and HEIC beside PNG, all tagged sRGB, with an availability query.
- **G-STILLTIME (`VisualCoreExperienceHost`):** the session's still at a chosen time, through a timed environment
  renderer.
- **G-SCENES:** the four curated scenes as fragment shaders.
- **The experience:** the crop frame and guides as a native canvas overlay; the export attempt with cancellation and
  cleanup; the adapter, manifest and controls. It is registered as a candidate.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contracts:
[contracts/still.md](contracts/still.md), [contracts/experience.md](contracts/experience.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, GLSL ES 3.0 (inline fragment sources over `vc/`), SwiftUI for the controls and the overlay.
- **Testing:**
  - VisualCore rendering (`--only-testing VisualCoreRenderingTests`) and the host (`VisualCoreExperienceHostTests`)
    on sim-27.2;
  - `LivingWallpapersCoreTests` and `LivingWallpapersExperienceTests` on sim-27.2;
  - the public and documented API checks;
  - the app build and unit on the iOS 27.2 phone;
  - the runner `verify_experiences.py --only a19.living-wallpapers --runtime 27`.
- **Constraints:**
  - no GL call in the experience (the vcgl isolation check);
  - export is synchronous on the main actor through `renderOffscreen`;
  - iOS 27 only; iOS 26 and the reference regression at X-A19.

  No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: offscreen on the host's own context; no second renderer |
| II | PASS: the encoder and the timed still are generic (every exporter can use them), so they go into VisualCore; scenes, frame and export stay app-local |
| II-a | PASS: additive API with tests and baseline; reference regression at X-A19 (owner ruling of 2026-11-14) |
| IV | PASS: the crop geometry is pure, in the core |
| VIII | PASS: no permission; files only in a temporary folder this phase |
| IX | PASS: native overlay with an accessibility label; Reduce Motion stills the preview |

A19 rules (constitution 2.15.0): PASS.

Post-design: PASS.

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreRendering/StillImage.swift                     modify  StillImageFormat, data(_:format:quality:), isAvailable(_:)
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/StillFormatTests.swift            new
Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ExperienceStill.swift           modify  renderStill(width:height:time:), init(timed:), callAsFunction(width:height:time:)
Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ExperienceHostView.swift        modify  installs the timed renderer
Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/StillTimeTests.swift         new
Packages/VisualCoreRendering/README.md, docs/api/visualcore-public-api.txt                    modify
Packages/ExperiencesCreative/LivingWallpapers/Core/{CropFrame,ExportPlanner}.swift            new/modify  crop geometry; jpeg and heic formats
Packages/ExperiencesCreative/LivingWallpapers/CoreTests/CropFrameTests.swift                  new
Packages/ExperiencesCreative/LivingWallpapers/Experience/{Adapter/WallpaperCore.swift,Adapter/WallpaperManifest.swift,
  SceneShaders.swift,WallpaperPresenter.swift,CropOverlay.swift,WallpaperControls.swift,StillExport.swift,
  LivingWallpapersExperience.swift}                                                           new
Packages/ExperiencesCreative/LivingWallpapers/ExperienceTests/{WallpaperTestSupport,WallpaperCoreTests,SceneRenderTests,
  CropOverlayTests,StillExportTests,WallpaperManifestTests}.swift                             new
Packages/ExperiencesCreative/LivingWallpapers/scenario-manifest.json                          generated
Packages/ExperiencesCreative/Package.swift (targets and product)                              modify
Catalog/registrations.json (a19 candidate), catalog and fixtures (build_catalog.py)           modify
Apps/VisualCore/App/ExperienceRegistry.swift (candidate); project.yml (product)               modify
docs/apps/living-wallpapers/visualcore-contract.json (G-ENCODE, G-STILLTIME, G-SCENES closed) modify
```

- **Dependency direction:** the experience → the core → VisualCore products. VisualCore never depends on the
  experience.
- **Lifecycle:**
  - `setup` makes the current scene's program;
  - `draw` sets the uniforms and draws once;
  - a scene change rebuilds the program;
  - `teardown` releases it;
  - the export runs on the main actor between frames.
- **Migration:** none (snapshot schema 1, project schema 1). **Rollback:** revert the commits; the A19-P01 core
  remains.

## Parallel work

- **Agent V:** the VisualCore encoder and the timed still with their tests.
- **Agent E:** the experience (adapter, shaders, presenter, overlay, controls, export) and its tests.
- **Agent K:** the core's `CropFrame` and the formats, with tests.
- **Lead:** Package.swift, the registry, registrations, project.yml, the manifest generation, the API baseline, the
  README, the contract, the runs and the commits.
