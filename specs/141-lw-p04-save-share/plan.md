# Implementation Plan: Living Wallpapers — Phase 04 Save, share and permission paths

**Branch**: `141-lw-p04-save-share` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds G-SAVE, G-EXPORTJOB and G-HISTORY:
- **Share:** a `Transferable` export file handed to `ShareLink`. The registration declares `photo-library-add`, and a
  PhotoKit scan guards the code.
- **Export job:** progress and cancellation between steps, with the encode and verify off the main actor.
- **History:** a bounded export history, in the core and stored through `ExperienceStorage`.

The no-go decision for the short loop stays, and its scan is this phase's MVP evidence. No VisualCore change.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/save.md](contracts/save.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6 (strict concurrency, typed throws) and SwiftUI with CoreTransferable.
- **Storage:** `history.json` through `ExperienceStorage`.
- **Testing:**
  - core and experience tests on sim-27.2;
  - the app build and unit;
  - the release steps `app-release-build` and `app-usage-descriptions`;
  - the runner and the scans.
- **Constraints:** the render stays on the main actor (`RenderHost`). iOS 27 only. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: no renderer change |
| II | PASS: reuses `ShareLink`/`Transferable` (Simulation Lab's pattern), `ExperienceStorage`, `ClockSource`, `StillImageEncoder` |
| IV | PASS: the history is a pure, versioned model |
| VIII | PASS: add-only Photos string only, through the system sheet; no PhotoKit; no network |
| A19 platform truth | PASS: nothing is saved without the person's choice in the sheet |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/LivingWallpapers/Core/ExportHistory.swift                                     new
Packages/ExperiencesCreative/LivingWallpapers/CoreTests/ExportHistoryTests.swift                           new
Packages/ExperiencesCreative/LivingWallpapers/Experience/{ExportJob,WallpaperExportFile,HistoryStore}.swift new
Packages/ExperiencesCreative/LivingWallpapers/Experience/{WallpaperControls,WallpaperPresenter,EditorModel,
  LivingWallpapersExperience}.swift                                                                         modify
Packages/ExperiencesCreative/LivingWallpapers/ExperienceTests/{ExportJobTests,ShareFileTests,HistoryStoreTests}.swift  new
Catalog/registrations.json (a19 permissions ["photo-library-add"]); build_catalog.py                       modify
specs/141-lw-p04-save-share/scan-photos.sh                                                                  new
docs/apps/living-wallpapers/visualcore-contract.json (G-SAVE, G-EXPORTJOB, G-HISTORY closed)                modify
```

- **Dependency direction:** unchanged.
- **Lifecycle:**
  - the job holds no GPU object;
  - the history store reads once when the experience opens and writes after each written export;
  - the export file lives in the export folder until the next export or a discard.
- **Migration:** none; history schema 1 is the first, and the snapshot is unchanged (schema 2).
- **Rollback:** revert the commits; `history.json` is then an unused file in the experience's storage.

## Parallel work

- **Agent K:** `ExportHistory` and its tests.
- **Agent E:** the job, the share file, the history store, the controls and their tests.
- **Lead:** registration, scan, release steps, contract, runs and commits.
