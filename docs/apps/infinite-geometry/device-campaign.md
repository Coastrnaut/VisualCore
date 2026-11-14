# Infinite Geometry — device campaign plan

**Status: nothing measured on a device.** Every row below is pending. Feature 045 (A05-P06), FR-A05-622, task
T-A05-617 ({device}). Infinite Geometry (`a05.infinite-geometry`) is measured as a row of the one VisualCore app's
device campaign (Auto-Creator.md section 23), not as a separate app. Simulator results, including the quality and
stability suites of A05-P05 (`GeometryQualityTests`, `GeometryGPUStabilityTests`), are development signals only and
never device evidence.

## When and in which order

1. Not before the gate `ImplementationLock-100` is recorded: `python3 scripts/migration_ledger.py guard-device` must
   exit 0. No install, launch or test of the app on a physical device happens earlier.
2. The owner has provisioned signing, paired, trusted and unlocked the devices (owner steps; otherwise the row is
   `BLOCKED_OWNER_ACTION`).
3. Order: **D1** (iPhone 15), then **D2** (iPad Pro 13-inch M5), then **D3** (iPad A16). **D3 stays on iPadOS 26.5
   and is never updated**; if it reports another version, its campaign is blocked and the owner is told.
4. The runner of the campaign, `scripts/run_device_campaign.py`, is planned for UA-F13 (Auto-Creator.md 23.3) and does
   not exist yet. Hardware identifiers go only to untracked private files.

## What each device records for Infinite Geometry

| Measurement | What is recorded | Source in the code |
|---|---|---|
| Frame time per quality tier | Frame intervals of the drawn frames for every preset kind (kaleidoscope, square tiling, hexagonal tiling, 3D composition), with the level pinned to each of the four tiers (Full, High, Medium, Low; the 3D composition at 24, 16, 12 and 8 segments), first-run and warm runs separate | `PerformanceRecord.pacing`, `qualityLevel`, `qualityPinned` (VisualCoreDiagnostics, written by `ExperienceSession.makeRecord`); `GeometryCore.segments(forTier:)`, `GeometryPresenter.draw(_:tier:context:frame:)` |
| Settled quality tier | The tier the host's governor settles on in automatic mode and each change with its cause (thermal state, Low Power Mode) | `PerformanceRecord.qualityLevel`, `stepsDown`, `stepsUp`; `QualityGovernor`, `QualityPolicy` (VisualCoreDiagnostics); `ExperienceSession.applyLevelInForce` |
| Memory with the mesh cache full | Resident memory and the render resources of the session (`ResourceRegistry` counts) after every preset kind has been drawn at every tier (the presenter's `MeshCache` full), after saving and opening compositions, and after leaving the experience | `PerformanceRecord.memoryFootprintBytes`, `gpuBytes`, `gpuPeakBytes`, `memoryEvents`; `GeometryPresenter` (`MeshCache`, `shedCaches()`) |
| Thermal state over a short session | The thermal state and Low Power Mode over a short session on the 3D composition and the drawn detail they forced; the composition and its digest never change | `PerformanceRecord.thermal`, `lowPower`; `DeviceConditions` (VisualCoreDiagnostics) |
| Export time | Time from "Export picture" to the share control, at the export size of the device's canvas (long edge up to 2048 pixels), for every preset kind | `GeometryExport.png(still:canvas:maxEdge:)`, `GeometryControls` (`export()`) |
| Accessibility system audits | The system accessibility audits at the default and the largest accessibility text size, run with `VC_RUN_AUDITS=1` (`AppUITestSupport.swift`; deferred to the devices by owner ruling of 2026-11-13) | `Apps/VisualCore/Tests/UI/InfiniteGeometry/` |
| VoiceOver journeys | With VoiceOver on: open the experience and hear the canvas description, change preset and symmetry order, move the view with the buttons, save and reopen a composition, export and reach the share control | `GeometryPresenter.describe(_:)`; the labels and hints of `GeometryControls.swift` |
| Persistence and lifecycle | Saved compositions survive relaunch; the container inventory holds only `composition-<uuid>.json` files and the app's `state.json` in the experience's folder | [privacy-and-credits.md](privacy-and-credits.md) |

Each row is recorded pass, fail or `BLOCKED_OWNER_ACTION`; skipped is never success. No measured value of Infinite
Geometry's speed, timing, heat or memory appears in any document or store text until a device row records it.

## Links

- Release checklist: [release-checklist.md](release-checklist.md) (rows with status `pending-campaign-ii`).
- Known limitations: [known-limitations.md](../../release/known-limitations.md), section "Infinite Geometry".
- Build and owner steps: [build-and-archive.md](../../release/build-and-archive.md).
