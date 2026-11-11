# Research: A02-P00

Read-only audit of the tree at gate A01-P06 (2026-11-11), for a GPU fluid solver.

- **R1 Ping-pong framebuffers.** `ResourceRegistry.makeRenderTarget(width:height:format:label:)`,
  `acquireTarget`/`recycle` (pool) and `RenderTarget.bind`/`bindColor` exist, and `EffectRenderer` already manages
  intermediate targets. There is no reusable "field" type that swaps a read and a write target and forbids
  read/write on the same texture. Status: `requires adaptation`. Owner: VisualCoreRendering, a new `PingPongTarget`
  (a pair, swap, generation-safe, budget-accounted) in the phase that first renders the solver (Phase 02).
- **R2 Texture feedback.** VisualCoreEffects' `feedback` pass type keeps a history target across frames. Its runner
  (`FeedbackPass`) is internal; the public surface is the effect-graph description run by `EffectRenderer` and
  `EffectScene`, which is what the matrix cites. It is an effect
  over an image, not a simulation field. Status: `available` for display feedback (example: `EffectRendererTests`);
  simulation feedback uses R1.
- **R3 GPU simulation techniques.** Full-screen passes come from `FullScreenShaderScene` and the effect passes' vertex
  shader. There is no generic "run fragment program P with inputs A, B into target T with uniforms U" helper outside
  the effect graph. Status: `requires adaptation`. Owner: VisualCoreRendering `FieldPass` (a program, named sampler
  inputs and a target) in Phase 02. The solver's own shaders (advect, divergence, Jacobi, gradient subtract, splat)
  stay app-domain, and the CPU reference lives in the app's Core package (A02 rule).
- **R4 Advection and diffusion shaders.** No VisualCore shader. The fluid equations are app content by the A02 rule.
  The `vc/*.glsl` library supplies hashing, noise and color helpers. Status: `upstream gap` resolved as app-local
  (justified).
- **R5 Touch input as forces.** `RenderView+Touches` delivers `PointerEvent`s and `PointerTracker` gives positions,
  phases and multi-touch. Velocity per pointer and capped-rate resampling into splats are missing. Status:
  `requires adaptation`. Owner: VisualCoreScenes `PointerVelocityTracker` (pure, host-testable) in Phase 03, with the
  app's `SplatQueue` as consumer.
- **R6 Color blending and post-processing.** Palette (`VisualCoreParameters.Palette`), effect graph bloom, composite
  and color matrix (`EffectRenderer`, `EffectScene`). Status: `available` (examples: Showcase effects scene, A01
  palettes).
- **R7 Bounded quality and thermal downgrade (v0.1 feature 06).** `FramePacing` (renderScale from thermal state and
  Low Power Mode) exists in VisualCoreRendering. There is no generic quality-profile policy mapping tiers to grid
  scale and iterations. Status: `requires adaptation`. Owner: VisualCoreSimulation `QualityPolicy` (pure) in
  Phase 03, the manual's "pressure projection and quality control" phase (aligned with gap G-QUALITY at T-A02-006).
- **R8 Pause, reset, deterministic seeded test mode (feature 05).** `SceneClock` (pause, step via scrub) and
  `SeededRandom` exist. Status: `available` (examples: A01 `ClockedArtScene`, `SceneClockTests`). A fixed-step
  stepping helper exists in `VisualCoreSimulation` (fixed-step clock).
- **R9 Still capture (feature 05).** `RenderHost.renderOffscreen`, `StillImageEncoder` and `ExportGeometry` (A01-P04).
  Status: `available` (example: A01 `ExportRunner`).
- **R10 Float render targets.** `TextureFormat.rgba16f` exists, and `makeRenderTarget` throws `incompleteFramebuffer`
  when a format is not renderable. There is no capability query (`EXT_color_buffer_half_float` /
  `EXT_color_buffer_float`) and no fallback policy. Status: `requires adaptation`. Owner: VisualCoreRendering
  `RenderCapabilities.supportsHalfFloatRenderTargets` plus a probe, in Phase 02. The RGBA8 fallback with a documented
  precision loss is app policy.
