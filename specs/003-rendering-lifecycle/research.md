# Research: Phase 2 rendering lifecycle

## R-F201 EGL declarations without Khronos headers
- **Decision**: declare the needed EGL subset (types, ~40 constants, ~20 functions) in
  `CVisualCoreEGL.h` with the values from the pinned ANGLE `include/EGL/egl.h`/`eglext_angle.h`, as the
  reference `CANGLE.h` does. Add `EGL_VENDOR`, `EGL_CONTEXT_LOST` (0x300E) and `EGL_BAD_*` codes
  for diagnostics.
- **Rationale**: no copy of the Khronos headers; matches the proven reference approach (MIT, owner).

## R-F202 Test hosting on simulator
- **Decision**: package tests create a `UIWindow` and add the `RenderView` to it, call
  `layoutIfNeeded()`, then `renderOneFrame()` and `readPixels()`, exactly as the reference
  `ANGLERendererTests.makeLaidOut` does.
- **Rationale**: proven to pass 13/13 on both runtimes (Phase 0 baseline).

## R-F203 Gradient without shaders module
- **Decision**: the sample scene compiles a tiny ES 3.00 vertex/fragment program directly through
  `vcgl*` (minimal, local to `SampleScenes.swift`); the general shader service comes in F03.
- **Alternatives**: wait for F03 (rejected: F02 exit evidence needs a drawn scene, not just a clear).

## R-F204 Lost-context detection
- **Decision**: after `eglSwapBuffers`/`eglMakeCurrent` returns `EGL_FALSE`, read `eglGetError()`;
  `EGL_CONTEXT_LOST` triggers `recreateContext()`. Tested via a forced path because simulators cannot
  produce a real loss.

## R-F205 Background handling
- **Decision**: observe `UIApplication.didEnterBackgroundNotification` (suspend after `glFinish`) and
  `willEnterForegroundNotification` (resume unless app-paused).
