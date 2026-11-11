# Implementation Plan: Generative Art Studio — Phase 04 Offscreen still export

**Branch**: `015-gas-p04-still-export` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md) | **Gate**: A01-P04

## Summary

Gap G-EXPORT (matrix row M09) is closed in VisualCore, following constitution Principle II:

- **VisualCoreScenes** (pure, host-testable) gets `ExportGeometry`, `ExportAspect` and `ExportSize`: long-edge and
  aspect math, even rounding, and the cap to a maximum edge and a pixel count.
- **VisualCoreRendering** gets the following:
  - `RenderCapabilities.maxRenderbufferSize`;
  - `RenderHost.maxRenderSize`;
  - `RenderHost.renderOffscreen(width:height:time:)`, which renders the host's current scene into a
    registry render target on the same EGL context and returns a `StillImage` (top-down RGBA);
  - `StillImageEncoder.pngData(_:)`, which encodes an opaque PNG tagged sRGB through CoreGraphics and ImageIO;
  - the error type `OffscreenRenderError`.

The app adds:
- an `ExportOptions` model in Core;
- `ExportSheet`, with size, aspect, crop preview, "Opaque · sRGB", progress and a share button;
- `ExportRunner`, which pauses playback, sets the particles points-to-pixels factor, renders, encodes, writes the
  temporary file and restores state;
- `NSPhotoLibraryAddUsageDescription`.

## Technical Context

**Language/Version**: Swift 6.4.2

**Primary Dependencies**:
- VisualCoreRendering: ANGLE GLES through the existing host, plus CoreGraphics and ImageIO, which are public Apple
  frameworks available to the UIKit/GPU package (rule R3).
- VisualCoreScenes: pure, Foundation-free logic.

**Storage**: the exported file is written to `FileManager.default.temporaryDirectory/Exports/<name>-<w>x<h>.png` and
removed when the sheet closes. Nothing is persisted.

**Testing**:
- host `swift test` for `ExportGeometry` (all 12 combinations, caps, even rounding) and for `ExportOptions` in Core;
- VisualCoreRendering simulator package tests:
  - size, top-down orientation (a quadrant fixture), opaque output;
  - PNG decode giving the same size, sRGB color space, no alpha and the same pixels;
  - restore after export (the live frame is unchanged);
  - over-budget failure leaves 0 leaks;
  - an over-limit size is refused before any GPU work;
  - `maxRenderSize` is at least 4096 on the simulators;
- app hosted tests (`ExportRenderTests`): 12 combinations give the exact dimensions; 4 families are deterministic;
  4 families downscaled match the on-screen render (mean ≤ 6/255); a forced failure leaves the live scene rendering
  with 0 leaks; particle proportions hold;
- UI test (`ExportUITests`): open Export, change size and aspect, check the dimension label and crop preview, export,
  see the share control, close the sheet; both runtimes;
- ProjectM regression (7 steps), API baseline, documented API, contract check.

**Target Platform**: iOS/iPadOS 26.0+

**Performance Goals**: none claimed. Device timing is campaign II, and the spec makes no duration claim.

**Constraints**:
- main thread (the EGL context's owner);
- one host and one context;
- 256 MiB default budget: a 4096² RGBA8 target is 64 MiB;
- offline;
- only the Photos add-only usage string; no new permission request on launch.

**Scale/Scope**: 3 VisualCore types plus 1 host method and 1 property, 1 Core type, 2 app files, 1 Info.plist key,
3 test files.

## Constitution Check

| Principle | Status |
|---|---|
| I Renderer | PASS: same ANGLE context and host, no second renderer or EGL bridge; the offscreen pass uses a registry render target |
| II Maximize reuse | PASS: geometry, offscreen render, readback, PNG encoding and the max-size query are all in VisualCore; the app keeps only the UI and family-specific scaling |
| II-a Reference | PASS: ProjectM regression after the VisualCore change |
| III Lifecycle | PASS: the export runs on the main thread inside the host, restores the scene's size and releases the target on every path; leak counts are tested |
| IV Host-testable | PASS: geometry and options are pure and tested with `swift test` |
| V Simulator only | PASS |
| VI Evidence | PASS: `run-check` logs |
| VII Accessible UI | PASS: labelled pickers with values, Dynamic Type, progress announced |
| VIII Privacy | PASS: add-only usage string, file only in tmp, removed on close, nothing transmitted |
| IX Bounded input | PASS: sizes capped by device limits and a 64 MP cap; requests above them are refused before GPU work |
| X Licensing | PASS: no assets |
| A01 rules | PASS: no ProjectM link, offline |

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/ExportGeometry.swift          (+ Tests/VisualCoreScenesTests/ExportGeometryTests.swift)
Packages/VisualCoreRendering/Sources/VisualCoreRendering/RenderCapabilities.swift   # + maxRenderbufferSize
Packages/VisualCoreRendering/Sources/VisualCoreRendering/RenderHost.swift           # + maxRenderSize, renderOffscreen
Packages/VisualCoreRendering/Sources/VisualCoreRendering/StillImage.swift           # StillImage, StillImageEncoder, OffscreenRenderError
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/OffscreenExportTests.swift
Apps/GenerativeArtStudio/Core/Sources/GenerativeArtStudioCore/ExportOptions.swift  (+ Tests/…/ExportOptionsTests.swift)
Apps/GenerativeArtStudio/App/ExportSheet.swift            # sheet UI and ExportRunner
Apps/GenerativeArtStudio/App/SceneScreen.swift            # Export toolbar button; pause and restore hooks
Apps/GenerativeArtStudio/App/Info.plist (project.yml)     # NSPhotoLibraryAddUsageDescription
Apps/GenerativeArtStudio/Tests/Unit/ExportRenderTests.swift
Apps/GenerativeArtStudio/Tests/UI/ExportUITests.swift
docs/api/visualcore-public-api.txt                        # baseline update
docs/apps/generative-art-studio/visualcore-contract.{json,md}   # G-EXPORT closed, M09 available
Packages/*/README.md, docs/architecture/package-map.md, docs/release/known-limitations.md   # docs
```

**Dependency direction**:
- App → Core → VisualCoreScenes (geometry), VisualCoreParameters and VisualCorePersistence.
- App → VisualCoreRendering (host, still image, encoder).
- VisualCoreRendering → VisualCoreScenes and the existing modules. VisualCoreScenes stays pure.
- No ProjectM module anywhere.

**Lifecycle contract (`renderOffscreen`)**:
1. Requires the main thread, a host that is not destroyed, a live context, and the scene set up without failure.
   Otherwise it throws `.unavailable`.
2. Validates `1 ≤ w, h ≤ maxRenderSize` and `w × h ≤ 64 MP`; otherwise it throws `.invalidSize` before any GPU work.
3. Makes the context current. If `makeRenderTarget` fails, it throws `.resource`, including over budget and
   incomplete framebuffers.
4. Calls `scene.resize(redirected ctx)` and binds the target with the viewport `w×h`. It then calls
   `scene.render(redirected ctx, FrameInfo(index: frameIndex, time: time, delta: 0, …))`, which throws `.scene` on
   failure, and calls `readPixels`, which throws `.readback` if empty.
5. Always, through `defer`: release the target, rebind framebuffer 0, and call `scene.resize(live ctx)` when a surface
   exists. The live scene's `sceneFailed` flag is not changed, so the live scene keeps rendering.
6. Returns a `StillImage` flipped to top-down rows.

**App export flow**: `ExportRunner.export(options, name)`:
1. Pause the clock and remember the playing state.
2. Set the time to `clock.time`.
3. For particles, set `displayScale = h / onScreenPointHeight`.
4. Call `host.renderOffscreen`, then `pngData`, then write to tmp.
5. Restore `displayScale` and playback.
6. Publish `.ready(url)` or `.failed(message)`.

**Data migration**: none. Nothing is persisted, and the document format is unchanged.

**Rollback**: revert the phase commits. The new VisualCore API is additive, so no existing caller changes.

## Complexity Tracking

None.
