# ADR-0002 — VisualCore render host re-uses the audited ANGLE/EGL sequence

**Date:** 2026-11-10 · **Status:** accepted · **Gate:** F01 (constrains F02)

## Context

F00 found the only proven renderer in `External/projectm-ios/Packages/ANGLERendering`:
`ANGLERenderer` + the `CANGLE` C shim over the prebuilt `libEGL`/`libGLESv2` XCFrameworks (ANGLE pin
`29d1823`, Metal backend only). `ANGLERenderer` hard-wires `ProjectMEngine`, `Preset`, the PCM reader
and the preset prewarmer, and the submodule is read-only (Constitution II).

## Decision

1. VisualCore links the **same** prebuilt XCFrameworks via SwiftPM binary targets that point into
   `External/projectm-ios/Build/ANGLEFrameworks` (no copy, no rebuild, no second renderer).
2. `VisualCoreRendering.RenderHost` re-implements the audited sequence verbatim in behavior:
   `eglGetPlatformDisplay(EGL_PLATFORM_ANGLE_ANGLE, [TYPE, METAL])`, RGBA8 ES3 window|pbuffer config,
   ES 3.0 context, 1×1 pbuffer placeholder, `eglCreateWindowSurface` on a BGRA8 `CAMetalLayer`,
   recreation on drawable-size change, `CADisplayLink` on the main run loop, `eglSwapBuffers`,
   teardown order placeholder-current → resources → unbind → surfaces → context.
3. The C shim is written fresh (`CVisualCoreEGL`) with the EGL constants from the pinned ANGLE
   headers, mirroring `CANGLE.h`; provenance noted in the header (MIT, owner's project). GL entry
   points come from a generated table filled by `eglGetProcAddress` (`scripts/generate_vcgl.py`).
4. Additions beyond the reference: explicit lifecycle state machine, context generations, forced
   recreation, capability report, resource registry. The ProjectM reference harness (F07) uses this
   host to drive the unmodified engine, proving the seam.

## Consequences

Behavioral parity is verified by simulator pixel tests and, later, device rows; any divergence from
the reference sequence needs a new ADR. If the prebuilt frameworks are missing, the fix is the
reference's own `scripts/build_angle_xcframework.py`, never a new build system.
