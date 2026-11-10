# Data model: Phase 2

- **RenderLifecycle** (pure): `state`, `generation`, `history[RenderLifecycleEvent] (≤256)`, `rejectedTransitions`;
  `isAllowed(from:to:)` per `specs/002-architecture-contracts/contracts/render-lifecycle.md`.
- **FramePacing** (pure): input `thermal ∈ {nominal, fair, serious, critical}`, `lowPower: Bool`,
  `requestedMaxFPS: Int`; output `maxFPS` (≥30), `renderScale ∈ {1.0, 0.75}`, `frameRateRange(min 30, max, preferred)`.
- **RenderCapabilities**: `glVersion`, `glslVersion`, `renderer`, `vendor`, `extensions[String]`,
  `maxTextureSize`, `maxViewport (w,h)`, `eglVendor`.
- **FrameInfo**: `index: Int`, `time: Double`, `delta: Double (0…0.1)`, `targetTimestamp: Double`.
- **RenderContext**: `generation`, `pixelSize (w,h)`, `framebuffer: UInt32 (0 = window)`.
- **RenderHostError**: `unsupported(String)`, `allocation(String, Int32)`, `contextLost`, `scene(String)`.
