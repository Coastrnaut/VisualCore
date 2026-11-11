# Implementation Plan: Fluid Art Playground — Phase 04 Interaction and capture UX

**Branch**: `022-fap-p04-palettes-capture` (spec directory only; work stays on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Ledger gate**: A02-P04

## Summary

This phase adds three palettes (Ink, Smoke, Glowing dye) as display modes over the existing dye field. Glow comes from
VisualCore's `EffectScene` bloom graph, with the flash limiter under Reduce Flashing, and is bypassed for Ink and Smoke.
Pinch-to-resize uses VisualCore's `PinchRecognizer` and `PointerTracker`, with a Brush size slider as the control
alternative. Still capture reuses A01's offscreen path (`RenderHost.renderOffscreen`, `ExportGeometry`,
`StillImageEncoder`) with the scene paused. The only VisualCore addition is a `FieldPass` run observer, which powers
the "every pass writes elsewhere" fixture.

## Technical Context

**Language/Version**: Swift 6.4.2, GLSL ES 3.00.

**Primary Dependencies** (verified in code):
- VisualCoreEffects: `EffectScene(content:graph:)`, `bypassEffects`, `reduceFlashing`, and the `bloom` pass with its
  parameters threshold, intensity, radius and hdr.
- VisualCoreScenes: `PinchRecognizer` (`scale`, `state`), `PointerTracker`, `ExportGeometry`.
- VisualCoreRendering: `RenderHost.renderOffscreen(width:height:time:)`, `maxRenderSize`, `StillImageEncoder.pngData`,
  `FieldPass`.
- VisualCoreUI: `SystemAccessibilityObserver` (Reduce Flashing), `AccessibleColors`.
- SwiftUI `ShareLink`.

**Storage**: a temporary PNG file per capture, with the previous one deleted.

**Testing**: host Core tests; app unit and UI tests on iOS 27.2 and 26.5 with the guard; the VisualCoreRendering
package tests on both runtimes; the ProjectM regression; an A01 build check.

**Constraints**: offline; exactly one usage description (Photos add-only); no EGL in the app; capture never steps the
simulation.

**Scale/Scope**:
- VisualCore: 1 observer API.
- App Core: `FluidPalette` (3 palettes) plus a palette field on the configuration and queue.
- App: the display shader modes, the EffectScene wrap, pinch handling, the Brush size slider and palette picker, and
  capture.
- About 7 new test classes.

## Constitution Check

| Principle / rule | Compliance | Status |
|---|---|---|
| I. Proven renderer | The glow is VisualCore's EffectScene; capture is `renderOffscreen` on the same context. | PASS |
| II. Reuse first | Effects, pinch, export and accessibility come from VisualCore. The run observer is generic and goes to VisualCore with docs and baseline. Palettes are app content. | PASS |
| II-a. Reference | The ProjectM regression runs after the observer is added. | PASS (planned) |
| III. GPU lifecycle | EffectScene owns its targets; the scene is unchanged; capture targets are released by VisualCore. | PASS |
| VII. Accessible UI | Picker and slider with values; the canvas description names the palette; Reduce Flashing is honored. | PASS |
| VIII. Privacy | One disclosed add-only Photos reason via the system share sheet; nothing stored beyond a temporary file. | PASS |
| A02 Every gesture has a control alternative | Pinch has the Brush size slider. | PASS |

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreRendering/FieldPass.swift           # EDIT Run + runObserver
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/FieldPassTests.swift   # EDIT observer test
Apps/FluidArtPlayground/FluidArtPlaygroundCore/Sources/FluidArtPlaygroundCore/
├── FluidPalette.swift         # NEW ink / smoke / glow definitions, display mode, splat colors
├── FluidConfiguration.swift   # EDIT paletteID (default glow)
├── SplatQueue.swift           # EDIT colors from the configuration's palette
└── FluidCanvasDescription.swift # EDIT names the palette
Apps/FluidArtPlayground/App/
├── FluidShaders.swift         # EDIT display with uMode, uBackground
├── FluidFieldsScene.swift     # EDIT display uniforms from the palette
├── PlaygroundView.swift       # EDIT EffectScene wrap, pinch, capture button, Reduce Flashing
├── AdjustPanel.swift          # EDIT palette picker, Brush size slider
└── CaptureModel.swift         # NEW offscreen capture → PNG → share
Apps/FluidArtPlayground/Tests/Unit/PaletteRenderTests.swift, PinchTests.swift, CaptureTests.swift, PassIsolationTests.swift
Apps/FluidArtPlayground/Tests/UI/PaletteCaptureUITests.swift
project.yml                    # EDIT NSPhotoLibraryAddUsageDescription; VisualCoreEffects dependency
```

## Frame and capture contract

- Each frame, the EffectScene renders the fluid scene into its target, then the bloom (if Glowing dye, unbypassed),
  then presents.
- Capture: `scene.paused = true` → `host.renderOffscreen(width:height:time:)` → `scene.paused = previous` → PNG.

## Migration and rollback

- The configuration gains `paletteID` (version 1; nothing is stored).
- The `FieldPass` observer is additive; it is nil by default.
- Rollback: revert the feature-022 commits.

## Complexity Tracking

None.
