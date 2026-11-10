# Implementation Plan: Phase 2 — Rendering Lifecycle Extraction

**Branch**: `003-rendering-lifecycle` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

Implement `RenderHost`, `RenderView`, `RenderScene` and the lifecycle state machine. They
re-implement, app-neutrally, the audited `ANGLERenderer` sequence
(`docs/architecture/current-rendering-pipeline.md` §2–§7) over the existing ANGLE XCFrameworks,
with the generated GL table. A minimal clear+gradient scene proves rendering on iOS 27.2 and 26.5
simulators, and the reference baseline renderer tests rerun as regression.

## Technical Context

**Language/Version**: Swift 6.4.2 (Swift 6 mode), C11
**Primary Dependencies**: libEGL/libGLESv2 XCFrameworks (pin 29d1823); UIKit, QuartzCore (CAMetalLayer, CADisplayLink)
**Storage**: N/A
**Testing**: `swift test` (lifecycle model, pacing policy) on host; `scripts/xcodebuild_package.py … --action test` on `sim-27.2` and `sim-26.5` (pixel readback)
**Target Platform**: iOS 26.0+
**Project Type**: SwiftPM library packages
**Performance Goals**: functional only in this phase (no device claims)
**Constraints**: main-thread EGL; no dlsym; no ProjectM; read-only reference
**Scale/Scope**: ~6 Swift files + EGL shim + tests

## Extraction map (Phase 0 inventory → VisualCore)

| Reference source (citation in trace) | VisualCore destination | Kind |
|---|---|---|
| `CANGLE.h` EGL declarations/constants | `CVisualCoreEGL/include/CVisualCoreEGL.h` | re-declared from pinned ANGLE headers (compatibility shim) |
| `CANGLE.c` `PMANGLELoadProc` | `CVisualCoreEGL.c` `vcEGLLoadProc` → `vcglLoad` | shim |
| `ANGLERenderer.make()` display/config/context/placeholder | `RenderHost.init` + `EGLDisplayProvider` (process-wide display) | re-implemented |
| `layoutSurface()` | `RenderHost.layoutSurface()` | re-implemented + `surfaceInvalid` state |
| display link + `ANGLEDisplayLinkProxy` | `FrameScheduler` (weak proxy) | re-implemented |
| `QualityGovernor` table | `VisualCoreDiagnostics.FramePacing` (pure, host-tested) | re-implemented |
| `isolated deinit` teardown order | `RenderHost.destroy()` | re-implemented + leak check |
| `MetalLayerView` | `RenderView` | re-implemented |
| none | `RenderLifecycle` (pure), recreation, capabilities, scene protocol | new (gaps) |

## Migration order (reference harness, F07) and rollback

1. F02: VisualCore host + sample scene (this feature). 2. F03: resources/shaders. 3. F07: the
`ProjectMReference` harness wraps the unmodified `ProjectMEngine` in a `RenderScene` using
`vcEGLLoadProc`. **Rollback:** the reference renderer is never modified. It keeps working on its own
(the baseline reruns), and any VisualCore change reverts by commit.

## Constitution Check

I (same ANGLE path, eglGetProcAddress) PASS · II/II-a (no ProjectM, reference untouched, regression rerun) PASS ·
III (state machine, generations, main-thread) PASS · IV (lifecycle + pacing pure and host-tested) PASS ·
V (simulator only) PASS · VI (run-check evidence) PASS · VII–X n/a in this phase. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreDiagnostics/RenderLifecycle.swift     # state machine (pure)
Packages/VisualCore/Sources/VisualCoreDiagnostics/FramePacing.swift         # thermal/power → cap/scale (pure)
Packages/VisualCore/Tests/VisualCoreDiagnosticsTests/*.swift
Packages/VisualCoreRendering/Sources/CVisualCoreEGL/include/CVisualCoreEGL.h  # EGL subset + vcEGLLoadProc
Packages/VisualCoreRendering/Sources/CVisualCoreEGL/CVisualCoreEGL.c
Packages/VisualCoreRendering/Sources/VisualCoreRendering/{RenderHost,RenderView,RenderScene,EGLDisplayProvider,FrameScheduler,RenderCapabilities,SampleScenes}.swift
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/RenderHostTests.swift
```

## Complexity Tracking

None.
