# Research: Phase 7

- **R1 Engine on the VisualCore host** — Decision: `ProjectMScene.setup` creates `ProjectMEngine(glLoader: vcEGLLoadProc,
  userData: nil)` with the host context current (EGL current on the main thread, the bridge's thread rule), sets the
  viewport from `context.pixelWidth/Height`, loads the preset; `render` feeds PCM then calls
  `renderFrameToFramebuffer(context.framebuffer)`; `teardown` releases the engine (context still current); a new
  context generation calls `setup` again (host contract), so the engine is recreated and the preset reloaded.
  Rationale: identical engine calls to the reference `ANGLERenderer` (current-rendering-pipeline.md §4–§6).
- **R2 GL state handoff** — Decision: `GLState.resetForVisualCore(framebuffer:viewport:)` in VisualCoreRendering:
  bind VAO 0, program 0, ARRAY/ELEMENT buffers 0, disable BLEND/DEPTH_TEST/CULL_FACE/SCISSOR_TEST/STENCIL_TEST,
  color mask all true, ACTIVE_TEXTURE 0 with texture 0, UNPACK_ALIGNMENT 4, bind framebuffer and viewport. Called by
  any scene after a foreign renderer. Alternatives: save/restore every state (expensive, needs glGet on every
  frame) — rejected; resetting VisualCore's assumptions is enough because VisualCore sets everything else itself.
- **R3 Baseline A/B** — Decision: in one test, create two engines on the same context, both with the same preset
  and the same synthesized PCM per frame; path A renders into a harness-owned offscreen RenderTarget (the reference
  sequence: engine → framebuffer), path B renders via the VisualCore `ProjectMScene` into the host framebuffer,
  frames interleaved A,B per step so wall-clock time differs by microseconds. Compare after N frames with
  `ImageDiff` (mean abs diff, % pixels within 8). The engine animates on wall-clock time internally, so exact
  equality is not expected; the SC-F702 tolerance absorbs microsecond timing differences. If the tolerance fails,
  the measured numbers are recorded and the cause analysed — never loosened silently.
- **R4 Synthetic signal** — Decision: 44.1 kHz stereo, 220 Hz sine with slow sweep + 2 Hz beat pulses, generated
  deterministically by frame index; chunks of `min(735, ProjectMEngine.maxSamplesPerFrame)` frames per video frame.
- **R5 Linkage and LGPL** — The harness links `ProjectMBridge` (static target) whose engine is the dynamic
  `ProjectM.xcframework`, exactly as the reference app; harness is a tester tool, not distributed (contract FR-F109).
- **R6 Retained ProjectM-specific integration** (FR-F710): preset library/indexing/warm-up (`PresetLibrary`,
  `ANGLERenderer.prewarm`), purchase/StoreKit, audio capture (`AudioCore`, `CaptureKit`), `CFlashLimiter` (VisualCore
  has its own model + pass), the reference's EGL renderer itself (kept so the shipping app is unchanged). Reasons
  recorded in the migration log.
