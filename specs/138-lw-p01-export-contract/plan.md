# Implementation Plan: Living Wallpapers — Phase 01 Platform API and export contract verification

**Branch**: `138-lw-p01-export-contract` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds Living Wallpapers' pure core and closes three gaps:
- **G-MODEL:** the project document, export plans and results.
- **G-TEMPLATES:** nine device templates with provenance and the size fallback.
- **G-VIDEO:** the no-go decision record with a guarding source scan.

A regression fixture proves the manual's rule: the written file's dimensions and colour profile equal the template's.
It encodes through the existing sRGB still encoder and reads the file back. Nothing is drawn on screen, no experience
is registered, and VisualCore and ProjectM are unchanged.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/core.md](contracts/core.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6 (strict concurrency), Foundation and ImageIO in the core; POSIX shell for the scan.
- **Dependencies:**
  - `LivingWallpapersCore` → `VisualCoreScenes` (`ExportGeometry`, `ExportAspect`, `ExportSize`) and
    `VisualCoreExperience`;
  - `LivingWallpapersCoreTests` → the core, `VisualCoreScenes` and `VisualCoreRendering` (`StillImage`,
    `StillImageEncoder`; CPU only).
- **Storage:** none in this phase. The project file is pure `Data` in and out.
- **Testing:** `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme
  ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LivingWallpapersCoreTests`.
- **Performance:** each test is under 10 s. The fixture encodes nine portrait and nine landscape pictures of one solid
  colour, with the largest file 2064×2752.
- **Constraints:**
  - no GL call, UIKit or SwiftUI in the core;
  - no VisualCore change, so no API baseline update and no reference regression in this phase;
  - iOS 27 only.

  No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: no renderer, no GL call; context ownership stays in the host |
| II | PASS: reuses `ExportGeometry`, `ExportAspect`, `StillImage`, `StillImageEncoder`; the experience-only rules stay app-local |
| II-a | PASS: no VisualCore change, regression not required |
| IV | PASS: pure, versioned models tested without a GPU |
| VI | PASS: evidence by run-check |
| VIII | PASS: no permission, no network |
| XIII | PASS: scenes and presets written here; template sizes with provenance |

A19 rules (constitution 2.15.0): PASS.
- platform truth: no wallpaper call, and video is no-go with a guarding scan;
- bounded: sizes refused before allocation, with a fallback;
- truthful claims: sizes and profile are read back from the file.

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                                  modify  two targets
Packages/ExperiencesCreative/LivingWallpapers/Core/SceneCatalog.swift                       new     scenes, parameters, presets
Packages/ExperiencesCreative/LivingWallpapers/Core/CanvasTemplates.swift                    new     templates, guides, provenance
Packages/ExperiencesCreative/LivingWallpapers/Core/WallpaperProject.swift                   new     project, envelope, refusals
Packages/ExperiencesCreative/LivingWallpapers/Core/ExportPlanner.swift                      new     format, plan, fit and fallback
Packages/ExperiencesCreative/LivingWallpapers/Core/ImageColorPipeline.swift                 new     profile and read-back inspection, result
Packages/ExperiencesCreative/LivingWallpapers/CoreTests/{SceneCatalogTests,TemplateTests,ProjectTests,PlannerTests,ExportFixtureTests}.swift   new
docs/apps/living-wallpapers/video-decision.md                                               new     G-VIDEO record
docs/apps/living-wallpapers/licenses.md                                                     new     scenes, presets, template provenance
specs/138-lw-p01-export-contract/scan-platform-claims.sh                                    new     no video, wallpaper calls or words
docs/apps/living-wallpapers/visualcore-contract.json                                        modify  G-MODEL, G-TEMPLATES, G-VIDEO closed
scripts/test_scripts.py                                                                     modify  only if a dependency rule needs the new core named
```

- **Dependency direction:** core → VisualCore products, never the reverse. The experience target (A19-P02) will
  depend on the core.
- **Lifecycle:** none in this phase; the core holds values only.
- **Migration:** project schema 1, the first version. **Rollback:** revert the commits; no stored data exists yet.

## Parallel work

- **Agent C:** `SceneCatalog`, `CanvasTemplates` and their tests.
- **Agent P:** `WallpaperProject`, `ExportPlanner`, `ImageColorPipeline` and their tests.
- **Agent D:** `video-decision.md` and `licenses.md`.
- **Lead:** Package.swift, the scan, the contract, the runs and the commits.
