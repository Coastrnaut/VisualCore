# Implementation Plan: Fractal Explorer — Phase 02 Fractal shaders and precision probe

**Branch**: `027-fe-p02-shaders-precision` (spec directory only; work stays on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Ledger gate**: A03-P02

## Summary

The explorer switches from the CPU preview to a GPU picture. It runs through VisualCore's `FullScreenShaderScene`,
inside an app `FractalScene` that drives a `SceneClock` for palette animation. The work, by area:

- **Gestures**: pinch and drag go through VisualCore's tracker and recognizers into `PlaneViewport`. Zoom and Reset
  controls are the alternative.
- **Palettes**: VisualCore `Palette.builtIns`.
- **G-PRECISION**, closed in two parts:
  - `RenderCapabilities` gains the fragment `highp` and `mediump` precision (VisualCoreRendering);
  - a pure `PrecisionAdvisor` goes into VisualCoreMath.
- **Precision UI**: the app clamps zoom and shows and announces the limit.
- **Agreement check**: a GPU–CPU class fixture proves the shader.

## Technical Context

- **Language**: Swift 6.4.2, GLSL ES 3.00.
- **Dependencies**, each verified in code (see the spec clarifications):
  - VisualCoreRendering: `FullScreenShaderScene`, `RenderHost` (`pointerHandler`, `renderOffscreen`,
    `capabilities`) and `ShaderBundle`;
  - VisualCoreScenes: `PointerTracker`, `PinchRecognizer` and `DragRecognizer`;
  - VisualCoreSimulation: `SceneClock`;
  - VisualCoreParameters: `Palette`;
  - VisualCoreMath: `PlaneViewport`;
  - VisualCoreUI: `RenderSurface`, `AccessibleColors` and `SystemAccessibilityObserver`.
- **Testing**:
  - host: `PrecisionAdvisorTests` and the Core tests;
  - VisualCoreRendering package tests on both runtimes (capabilities precision);
  - app unit tests: GPU agreement, gestures, precision clamp and palette;
  - UI tests and the audit;
  - the ProjectM regression.
- **Constraints**: no EGL in the app; float32 uniforms; a bounded loop (10,000 iterations, early break at the cap).

## Constitution Check

| Principle | Status |
|---|---|
| I. Proven renderer | PASS: `FullScreenShaderScene` runs on `RenderHost`. |
| II. Reuse | PASS: the shader scene, recognizers, palettes, clock and viewport are reused. G-PRECISION is generic and lives in VisualCore. The fractal shader and `FractalScene` are app content. |
| II-a. Reference | PASS (planned): the regression runs after the `RenderCapabilities` change. |
| III. Lifecycle | PASS: `FractalScene` forwards setup, resize and teardown. The state lives in the model and survives context loss. |
| IV. Host-testable | PASS: the advisor and the gesture mapping have host or unit tests first. |
| VII. Accessibility | PASS: controls stand in for gestures; announcements; the spoken description includes the precision state. |
| VIII. Privacy | PASS: none. |
| IX. Bounded input | PASS: clamped uniforms, the cap and the zoom limit. |
| A03 truthful precision | PASS: limit enforced and shown; simulator values are context only. |

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreRendering/RenderCapabilities.swift      # EDIT ShaderPrecision, fragmentHighp/Mediump
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/RenderCapabilitiesPrecisionTests.swift  # NEW
Packages/VisualCore/Sources/VisualCoreMath/PrecisionAdvisor.swift                       # NEW
Packages/VisualCore/Tests/VisualCoreMathTests/PrecisionAdvisorTests.swift              # NEW
Apps/FractalExplorer/App/FractalShaders.swift      # NEW fragment source
Apps/FractalExplorer/App/FractalScene.swift        # NEW wrapper: clock, uniforms, palette, fallback flag
Apps/FractalExplorer/App/ExplorerView.swift        # EDIT host + RenderSurface, gestures, controls, palette UI, precision banner
Apps/FractalExplorer/Tests/Unit/{GPUAgreementTests,GestureTests,PrecisionClampTests,PaletteTests}.swift  # NEW
Apps/FractalExplorer/Tests/UI/ExplorerUITests.swift, AccessibilityAuditUITests.swift    # EDIT
project.yml   # EDIT app links VisualCoreRendering, VisualCoreScenes, VisualCoreSimulation, VisualCoreParameters
docs/apps/fractal-explorer/visualcore-contract.{json,md}, regression-baseline.md       # EDIT
```

## Lifecycle contracts

- `ExplorerModel` owns one `RenderHost(scene: FractalScene)` and destroys it in `close()` (on disappear).
- The model forwards `pointerHandler` events to the gesture mapping. The mapping updates `state.viewport` (clamped by
  the precision limit) and the scene's snapshot.
- `FractalScene.render`, on each frame:
  1. advances the clock by `frame.delta` when animation is on;
  2. sets `inner.fixedTime = clock.time`;
  3. sets the parameters and the palette;
  4. calls `inner.render`.
- On a shader failure (`inner.errorMessage`), the model shows the CPU preview with a notice.

## Migration and rollback

- **Migration**: `RenderCapabilities` gains optional fields, so stored reports still decode. The app replaces the
  preview image with the GPU surface.
- **Rollback**: revert the feature-027 commits.

## Complexity Tracking

None.
