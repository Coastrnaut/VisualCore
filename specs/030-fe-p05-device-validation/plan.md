# Implementation Plan: Fractal Explorer — Phase 05 Device precision and performance validation

**Branch**: `030-fe-p05-device-validation` (spec directory only; work stays on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Ledger gate**: A03-P05

## Summary

Make the device precision and performance measurements automation-ready, rehearse them on simulators, prove the
bookmark reproduction fixture, and write the device-campaign plan. The parts are:
- **VisualCore** (G-AUTOMODE): `AutomationRunner.appModes` (name → handler receiving the host and the report),
  `AutomationReport.measurements` / `details` (optional), `AutomationView(appModes:)`; built-in names win.
- **App domain** (`FractalExplorerCore`): `PrecisionLadder` — the ladder plan (zooms from the Seahorse point, ×4 per
  step, ≤ 24 steps) and the pure verdict (reliable steps ≥ 99%, clamp at or before the breakdown).
- **App automation** (`#if DEBUG || VISUALCORE_AUTOMATION`): `AppAutomation` with the explorer model hosted by
  `AutomationView` and app modes `precision` and `tour`; the app root routes automation launches to it.
- **Fixture**: `BookmarkReproductionTests` (identical pictures on the same canvas; ≥ 99% classes on another shape).
- **Docs**: `docs/apps/fractal-explorer/device-campaign.md`; contract and baseline.

## Technical Context

**Language/Version**: Swift 6.4.2.

**Primary Dependencies** (each checked in code):
- `AutomationRunner(host:bundleID:outputDirectory:terminate:)`, `run(mode:frames:)`, `postRunCheck`, `checkNote`,
  `requestedMode/requestedFrames/requestedSeed`, `knownModes`; `AutomationReport` (Codable; `frames`, `frameTimeMs`,
  `result`, `message`); `FrameTimeStats(samples:)`; `AutomationView(mode:bundleID:makeScene:configure:outputDirectory:
  postRunCheck:checkNote:terminate:)`.
- `RenderHost.renderOneFrame(present:)`, `renderOffscreen(width:height:time:)`, `maxRenderSize`, `capabilities`
  (`fragmentHighp`, `fragmentMediump`, `fragmentMantissaBits`).
- App: `ExplorerModel` (`scene`, `apply`, `startTour`, `tourTick`, `captureStill`-style sizing), `FractalTours`,
  `StillCapture`, `PrecisionAdvisor`, `PlaneFraming`, `BookmarkLibrary`.
- Scripts: `scripts/run_automation_sim.py` (simulator rehearsal), `scripts/check_release_symbols.py` (Release check).

**Storage**: reports in the app's Documents (automation builds only); temporary captures removed.

**Testing**:
- VisualCoreAutomation package tests (`AutomationRunnerTests` + app-mode cases) on 27.2 and 26.5;
- host `swift test` for FractalExplorerCore (`PrecisionLadderTests`);
- app unit tests (`AutomationModeTests` running both app modes against an injected output folder and recorder,
  `BookmarkReproductionTests`) on both runtimes;
- simulator rehearsal of 5 modes on both runtimes; Release build symbol check (absent) and measurement build (present);
- ProjectM regression and A01/A02 builds after the VisualCore change.

**Target Platform**: iOS/iPadOS 26.0+.

**Performance Goals**: none claimed; frame times are recorded for the device campaign.

**Constraints**: automation code only under `DEBUG || VISUALCORE_AUTOMATION`; triggered only by the launch environment;
no device actions.

## Constitution Check

| Principle / rule | Compliance | Status |
|---|---|---|
| I. Proven renderer only | All renders through the one `AutomationView` host. | PASS |
| II. Reuse first | App modes are a generic VisualCoreAutomation feature; the ladder plan and tours are app content. | PASS |
| II-a. Preserve reference | ProjectM regression and A01/A02 builds after the change; A02 automation unchanged. | PASS (planned) |
| III. GPU lifecycle | No new GL resources; captures through StillCapture. | PASS |
| IV. Host-testable, test first | Ladder verdict and report decoding host/package-tested first. | PASS |
| V/VI. Evidence | Simulator runs are rehearsal; device rows "pending device campaign". | PASS |
| VII. Accessible UI | No user UI change. | N/A |
| VIII. Privacy | Reports contain device model and OS only (no identifiers); automation absent from Release. | PASS |
| IX. Bounded input | Frames clamped 1…10,000; ladder ≤ 24 steps; capture ≤ device limit. | PASS |
| A03 truthful precision | The verdict fails if a "reliable" step draws wrongly or the clamp is late. | PASS |

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreAutomation/AutomationRunner.swift   # EDIT appModes, allModes
Packages/VisualCoreRendering/Sources/VisualCoreAutomation/AutomationReport.swift   # EDIT measurements, details
Packages/VisualCoreRendering/Sources/VisualCoreAutomation/AutomationView.swift     # EDIT appModes parameter
Packages/VisualCoreRendering/Tests/VisualCoreAutomationTests/AutomationRunnerTests.swift  # EDIT app-mode tests
Apps/FractalExplorer/FractalExplorerCore/Sources/FractalExplorerCore/PrecisionLadder.swift  # NEW
Apps/FractalExplorer/FractalExplorerCore/Tests/FractalExplorerCoreTests/PrecisionLadderTests.swift  # NEW
Apps/FractalExplorer/App/AppAutomation.swift          # NEW (#if DEBUG || VISUALCORE_AUTOMATION)
Apps/FractalExplorer/App/FractalExplorerApp.swift     # EDIT route automation launches
Apps/FractalExplorer/Tests/Unit/{AutomationModeTests,BookmarkReproductionTests}.swift   # NEW
project.yml                                            # EDIT app links VisualCoreAutomation (Debug/measurement)
docs/apps/fractal-explorer/device-campaign.md          # NEW
docs/apps/fractal-explorer/{visualcore-contract.json,.md,regression-baseline.md}, docs/testing/simulator-test-lessons.md  # EDIT
```

## Lifecycle contracts

- `AutomationView` creates the one host for `model.scene` and the runner with the app modes; the explorer model is
  created unhosted (`close()`-free: it never makes its own host in automation — `ExplorerModel(hosted: false)`).
- The precision handler: sets the model state per ladder step, renders offscreen 64 × 64, compares with the CPU
  reference, fills measurements/details, sets the verdict.
- The tour handler: for each tour, steps tour time at 1/60 s, sets the framing, calls `renderOneFrame(present: true)`
  and times it; at each stop's first held step captures a 1024 px still and compares 64 points; removes the file.

## Migration and rollback

- **Migration**: report schema stays 1 with two optional fields; older reports decode. A02 unchanged.
- **Rollback**: revert the feature-030 commits.

## Complexity Tracking

None.
