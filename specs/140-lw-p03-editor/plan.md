# Implementation Plan: Living Wallpapers — Phase 03 Project and preset editing and crop interface

**Branch**: `140-lw-p03-editor` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds G-EDITOR, G-HELP and G-A11Y in three parts.

- **Editable colours:**
  - project schema 2 and snapshot schema 2, with a migration and registered schema-1 examples;
  - new controls `preset.color` and `preset.reset`.
- **Fallback, result and help:**
  - the fallback notice, with export at the offered size;
  - the verified result line;
  - the help page, guarded by a claims scan.
- **Accessibility:** labels with values, one announcement per export outcome, and a one-column layout at the largest
  text size.

No VisualCore change.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/editor.md](contracts/editor.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6 and SwiftUI. **Storage:** none new (the snapshot through the host).
- **Testing:**
  - `LivingWallpapersCoreTests` and `LivingWallpapersExperienceTests` on sim-27.2;
  - the app build and unit on the iOS 27.2 phone (the migration examples);
  - the runner on iOS 27;
  - the scans.
- **Constraints:** iOS 27 only; no VisualCore change, so no baseline update. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: no renderer change |
| II | PASS: reuses `AnnouncementPlanner` via `ExperienceFeedback`, `MigrationChain`, `SnapshotMigrationCheck` |
| IV | PASS: notice, result line, help and colours are pure core data, tested without the GPU |
| IX | PASS: labels, announcements and large text; audits wait for devices |
| A19 platform truth | PASS: help says the person sets the wallpaper; claims scan |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/LivingWallpapers/Core/{WallpaperProject,ExportNotice,ExportResultLine,WallpaperHelp}.swift         modify/new
Packages/ExperiencesCreative/LivingWallpapers/CoreTests/{ProjectTests,ExportNoticeTests,HelpTests}.swift      modify/new
Packages/ExperiencesCreative/LivingWallpapers/Experience/{Adapter/WallpaperCore,Adapter/AdapterSchemaExamples,
  WallpaperPresenter,WallpaperControls,HelpView}.swift                                                       modify/new
Packages/ExperiencesCreative/LivingWallpapers/ExperienceTests/{WallpaperCoreTests,ColourEditTests,
  SnapshotMigrationTests,EditorAccessibilityTests,NoticeAndResultTests}.swift                                modify/new
Packages/ExperiencesCreative/LivingWallpapers/Experience/Adapter/WallpaperManifest.swift (fixtures unchanged; rejection entries)  modify
Packages/ExperiencesCreative/LivingWallpapers/scenario-manifest.json                                         regenerated
Apps/VisualCore/App/ExperienceRegistry.swift (schema-1 example registered)                                    modify
specs/140-lw-p03-editor/scan-help-claims.sh                                                                   new
docs/apps/living-wallpapers/visualcore-contract.json (G-EDITOR, G-HELP, G-A11Y closed)                        modify
```

- **Dependency direction:** unchanged: the experience → the core → VisualCore.
- **Lifecycle:** a colour edit updates uniforms only; a scene or preset change clears the custom colours.
- **Migration:**
  - the project: schema 1 to 2, with `customColors` nil;
  - the snapshot: schema 1 to 2, with `custom` 0 and the preset's colours copied.
- **Rollback:** revert the commits. A schema-2 snapshot would then be refused as newer by A19-P02's code, which is the
  documented refusal.

## Parallel work

- **Agent K:** the core files and their tests.
- **Agent E:** the experience files and their tests.
- **Lead:** the registry, the manifest regeneration, the scan, the contract, the runs and the commits.
