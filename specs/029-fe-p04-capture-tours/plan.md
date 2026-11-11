# Implementation Plan: Fractal Explorer — Phase 04 High-resolution capture and tours

**Branch**: `029-fe-p04-capture-tours` (spec directory only; work stays on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Ledger gate**: A03-P04

## Summary

The iteration cap with a relative cost estimate (MVP), high-resolution still capture limited by the device and by
precision, curated tours with log-scale flights, and the float-spacing regression fixture. The parts are:
- **VisualCore** (owner reuse rule, Principle II):
  - `VisualCoreDiagnostics.RenderCostEstimate` (G-COST);
  - `VisualCoreMath.FramingFlight` and `TourTimeline` (G-TOUR), on `PlaneFraming` and `ease`;
  - `VisualCoreRendering.StillCapture` (G-CAPTURE), generalized from A02's `CaptureModel`: `renderOffscreen` →
    `StillImageEncoder.pngData` → a file in a `TemporaryFolder`, previous file removed, errors as messages.
- **App domain** (`FractalExplorerCore`): `FractalTours` (three tours of stops and captions), `CaptureSizing`
  (precision-limited long edge), `CapControl` (log slider mapping, ÷2/×2).
- **App UI**: cap slider and buttons with the cost line; Capture and ShareLink; Tours sheet and tour player with
  caption and Stop.

## Technical Context

**Language/Version**: Swift 6.4.2.

**Primary Dependencies** (each checked in code):
- `RenderHost.renderOffscreen(width:height:time:)`, `RenderHost.maxRenderSize`, `StillImage`, `StillImageEncoder.pngData`,
  `OffscreenRenderError` (VisualCoreRendering);
- `ExportGeometry(maxEdge:)`, `ExportAspect(id:title:width:height:)`, `ExportSize` (VisualCoreScenes);
- `TemporaryFolder(name:)`, `makeFileURL(prefix:extension:)`, `removeAll()` (VisualCorePersistence);
- `PlaneFraming`, `PlaneViewport`, `PrecisionAdvisor`, `ease(_:_:_:)`, `EasingCurve`, `EasingMode` (VisualCoreMath);
- SwiftUI `Slider`, `ShareLink`, `sheet`; `UIAccessibility` Reduce Motion via VisualCoreUI `SystemAccessibility`.

**Storage**: `tmp/Captures` (TemporaryFolder; emptied at launch). Nothing persistent.

**Testing**:
- host `swift test` for VisualCore (`RenderCostEstimateTests`, `FramingFlightTests`, `TourTimelineTests`,
  `PrecisionSpacingTests` — the float-spacing fixture next to the advisor) and FractalExplorerCore
  (`FractalToursTests`, `CaptureSizingTests`, `CapControlTests`);
- VisualCoreRendering package tests (`StillCaptureTests`) on iOS 27.2 and 26.5;
- app unit tests (`CostAndCapTests`, `CaptureTests` including the CPU agreement, `TourPlayerTests`) and UI tests
  (`CaptureTourUITests`, audit) on both runtimes with the guard;
- ProjectM regression and A01/A02 builds after the VisualCore additions.

**Target Platform**: iOS/iPadOS 26.0+.

**Performance Goals**: none timed (cost is relative by definition); a capture is one offscreen render.

**Constraints**: the capture runs on the host's own context (no second context); animation frozen during capture; the
tour player advances from the display's frame clock (no timers on the GL thread).

## Constitution Check

| Principle / rule | Compliance | Status |
|---|---|---|
| I. Proven renderer only | Capture uses `renderOffscreen` on the one host. | PASS |
| II. Reuse first | Cost, flight/timeline and still capture are generic VisualCore types; tours and sizing rules stay app content. | PASS |
| II-a. Preserve reference | ProjectM regression and A01/A02 builds after the additions. | PASS (planned) |
| III. GPU lifecycle | No new GL resources; offscreen targets are the host's. | PASS |
| IV. Host-testable, test first | Cost, flight, timeline, spacing fixture, tours, sizing, cap mapping host-tested first. | PASS |
| V/VI. Evidence | Simulator and host only; simulator render limits are context. | PASS |
| VII. Accessible UI | Labelled slider and buttons, caption announced, Reduce Motion honoured, audit. | PASS |
| VIII. Privacy | Share sheet only; Photos add-only usage text; temporary files removed. | PASS |
| IX. Bounded input | Cap 50…10,000; capture ≤ device limit, 8192, 64 Mpx and the precision limit. | PASS |
| A03 truthful precision | Capture never claims detail beyond precision; tour stops checked. | PASS |

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreDiagnostics/RenderCostEstimate.swift          # NEW G-COST
Packages/VisualCore/Tests/VisualCoreDiagnosticsTests/RenderCostEstimateTests.swift  # NEW
Packages/VisualCore/Sources/VisualCoreMath/FramingFlight.swift                      # NEW G-TOUR (FramingFlight, TourTimeline)
Packages/VisualCore/Tests/VisualCoreMathTests/{FramingFlightTests,TourTimelineTests,PrecisionSpacingTests}.swift  # NEW
Packages/VisualCoreRendering/Package.swift                                         # EDIT + VisualCorePersistence (pure)
Packages/VisualCoreRendering/Sources/VisualCoreRendering/StillCapture.swift        # NEW G-CAPTURE
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/StillCaptureTests.swift  # NEW
Packages/VisualCore/README.md, docs/api/visualcore-public-api.txt, specs/002-architecture-contracts/contracts/package-map.md  # EDIT
Apps/FractalExplorer/FractalExplorerCore/Sources/FractalExplorerCore/{FractalTours,CaptureSizing,CapControl}.swift  # NEW
Apps/FractalExplorer/FractalExplorerCore/Tests/FractalExplorerCoreTests/{FractalToursTests,CaptureSizingTests,CapControlTests}.swift  # NEW
Apps/FractalExplorer/App/ExplorerView.swift      # EDIT cap control, cost line, capture button, tours button, tour player hook
Apps/FractalExplorer/App/ToursView.swift         # NEW tour list sheet
Apps/FractalExplorer/App/TourPlayer.swift        # NEW drives FramingFlight/TourTimeline from frame time
Apps/FractalExplorer/App/FractalExplorerApp.swift  # EDIT empty the capture folder at launch
Apps/FractalExplorer/Tests/Unit/{CostAndCapTests,CaptureTests,TourPlayerTests}.swift   # NEW
Apps/FractalExplorer/Tests/UI/CaptureTourUITests.swift, AccessibilityAuditUITests.swift  # NEW / EDIT
project.yml   # EDIT NSPhotoLibraryAddUsageDescription; app links VisualCoreDiagnostics
docs/apps/fractal-explorer/*  docs/testing/simulator-test-lessons.md   # EDIT
```

Dependency direction: VisualCoreRendering → VisualCorePersistence (pure, allowed by the package map's "pure modules"
rule); app → FractalExplorerCore → VisualCoreMath/Persistence; app → VisualCore modules.

## Lifecycle contracts

- `StillCapture` is `@MainActor`, owned by the explorer model. `capture(host:size:prefix:)` renders, encodes and
  writes; the previous file is removed first. `removeFile()` on leaving; the app calls
  `StillCapture.folder(named: "Captures").removeAll()` at launch.
- During capture the model sets the scene's animate flag off and restores it afterwards (clock frozen).
- `TourPlayer` holds a `TourTimeline` and a start time; the explorer's `TimelineView(.animation)` (or the host's frame
  callback through the scene) calls `tick(now:)`, which applies the framing through the model's `apply` (precision
  clamp applies) and sets the caption. Any canvas touch, Stop, leaving, or mode change stops it.

## Migration and rollback

- **Migration**: none (no stored data). A02 keeps its `CaptureModel`; adopting `StillCapture` is a recorded follow-up.
- **Rollback**: revert the feature-029 commits; all VisualCore additions are additive (the new Rendering → Persistence
  edge is removed with them).

## Complexity Tracking

None.
