# Implementation Plan: Fractal Explorer — Phase 01 Complex-plane math and fixtures

**Branch**: `026-fe-p01-complex-math` (spec directory only; work stays on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Ledger gate**: A03-P01

## Summary

This phase delivers the first working slice: the Mandelbrot and Julia modes with accessible explanations, computed
by a GPU-free escape-time reference and shown as a bounded CPU preview. The parts are:
- **VisualCore**: a generic `PlaneViewport` (VisualCoreMath). It closes G-VIEWPORT.
- **App**: a domain package `FractalExplorerCore` with the escape math, state and explanations (G-FRACTAL), and an
  explorer screen.
- **Phase 02**: GPU shaders replace the preview, which then becomes their comparison fixture.

## Technical Context

**Language/Version**: Swift 6.4.2.

**Primary Dependencies** (each checked in code):
- **VisualCoreMath**: `Vec2` and `Camera2D` (unchanged).
- **VisualCoreUI**: `AccessibleColors` (A02 home tint).
- **SwiftUI**: `Image(decorative:scale:)` from a `CGImage` built from RGBA bytes (CoreGraphics, public).

**Storage**: none.

**Testing**:
- host `swift test` for VisualCore (`PlaneViewportTests`) and FractalExplorerCore (`FractalMathTests`,
  `FractalStateTests`, the preview checks inside `FractalStateTests`);
- app unit and UI tests on iOS 27.2 and 26.5 with the guard;
- the accessibility audit at default size and XXXL;
- the ProjectM regression after the VisualCore addition.

**Target Platform**: iOS/iPadOS 26.0+.

**Performance Goals**: the preview stays within its fixed budget (160² samples × cap) off the main thread. No timing
claims.

**Constraints**:
- no EGL or GL in the app;
- Double-precision viewport;
- every input validated.

**Scale/Scope**: VisualCore gains 1 type. The app gains 1 package (4 sources), an `ExplorerView` and a model.
Around 8 test classes.

## Constitution Check

| Principle / rule | Compliance | Status |
|---|---|---|
| I. Proven renderer only | No rendering through GL in this phase; the preview is a CPU image. | PASS |
| II. Reuse first | `PlaneViewport` is generic, in VisualCoreMath, documented, and in the API baseline. Formulas are app-local per the A03 rule. | PASS |
| II-a. Preserve reference | ProjectM regression after the VisualCore addition. | PASS (planned) |
| III. GPU lifecycle | No GPU resources. | N/A |
| IV. Host-testable, test first | Viewport, math and state have host tests first. | PASS |
| V/VI. Evidence | Simulator and host only, with run-check. | PASS |
| VII. Accessible UI | A segmented mode picker, the explanation text, a spoken canvas description, and the audit. | PASS |
| VIII. Privacy | No permissions or networking. | PASS |
| IX. Bounded input | Cap 1…10,000, R ≥ 2, scale limits, finite checks. | PASS |
| A03 truthful precision | The CPU clamp is reported; no deep-zoom claim. | PASS |

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreMath/PlaneViewport.swift                 # NEW
Packages/VisualCore/Tests/VisualCoreMathTests/PlaneViewportTests.swift         # NEW
docs/api/visualcore-public-api.txt                                             # EDIT (--update)
Apps/FractalExplorer/FractalExplorerCore/Package.swift                         # NEW (depends on VisualCoreMath)
Apps/FractalExplorer/FractalExplorerCore/Sources/FractalExplorerCore/
├── FractalMath.swift          # escape iteration, smooth value, EscapeResult
├── FractalState.swift         # mode, viewport, seed, cap, radius (validated), defaults, spoken description
├── FractalExplanations.swift  # mode texts
└── FractalPreview.swift              # deterministic bounded RGBA preview of a state
Apps/FractalExplorer/FractalExplorerCore/Tests/FractalExplorerCoreTests/*.swift  # NEW
Apps/FractalExplorer/App/FractalExplorerApp.swift   # EDIT home link to the explorer
Apps/FractalExplorer/App/ExplorerView.swift         # NEW mode picker, explanation, preview image, model
Apps/FractalExplorer/Tests/Unit/ExplorerModelTests.swift   # NEW
Apps/FractalExplorer/Tests/UI/ExplorerUITests.swift, AccessibilityAuditUITests.swift   # NEW
project.yml   # EDIT packages: FractalExplorerCore; FAP-style targets: app links Core, VisualCoreMath, VisualCoreUI; unit-test target
docs/apps/fractal-explorer/visualcore-contract.{json,md}, regression-baseline.md   # EDIT
```

Dependency direction:
- app → FractalExplorerCore → VisualCoreMath;
- app → VisualCoreUI.

## Lifecycle contracts

- `ExplorerModel` (`@MainActor @Observable`) holds the `FractalState`. On any change it starts a detached preview
  task with a new request identifier and assigns the result only if the identifier is still current.
- There is no render host. Phase 02 adds the GPU view and keeps this model.

## Migration and rollback

- **Migration**: none (nothing persisted). The shell's home text and link are extended.
- **Rollback**: revert the feature-026 commits. `PlaneViewport` is additive.

## Complexity Tracking

None.
