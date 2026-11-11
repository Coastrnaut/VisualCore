# Research: Fractal Explorer Phase 00 (read-only audit)

This is a read-only audit of the tree at gate A02-P06 (2026-11-11), for a GPU escape-time fractal explorer. Each
finding gives a decision, its rationale and the alternatives considered.

- **R1 High-resolution fragment shaders.**
  - Available: `FullScreenShaderScene` (VisualCoreRendering) draws one fragment program over the target with
    validated uniforms. A01's raymarched family is the example consumer. `FieldPass` runs a fragment into a target.
  - Offscreen high-resolution rendering: `RenderHost.renderOffscreen(width:height:time:)`, capped by
    `maxRenderSize`.
  - **Decision**: available. The fractal escape-time shader is app content (A03 rule) with a CPU reference.
- **R2 Coordinate transforms.**
  - `Camera2D` (VisualCoreMath) handles pan, zoom and rotation in point space, but clamps zoom to 0.1…100.
  - `ViewMetrics` (VisualCoreScenes) maps points to pixels.
  - Fractal navigation needs a double-precision complex-plane viewport: center (re, im) and units per point, with
    an aspect-correct screen↔plane mapping, an anchored pinch that keeps the touched point fixed, and zoom far beyond
    100×.
  - **Decision**: requires adaptation. Add a generic `ComplexViewport` (or `PlaneViewport`) to VisualCoreMath in
    Phase 01, with host tests (anchored pinch, aspect change). It is reusable by any 2D-plane app (A16 Simulation
    Lab, A22 Shader Studio).
  - **Rejected**: widening `Camera2D`'s zoom range, which would change an existing contract used by A01.
- **R3 Precision management.**
  - The C table exposes `vcglGetShaderPrecisionFormat`, but no Swift API reports the fragment `highp` float range
    and precision bits. Shaders already declare `precision highp float`.
  - **Decision**: requires adaptation, in two parts, both in Phase 02 (the first GPU render):
    - a `RenderCapabilities` precision query in VisualCoreRendering;
    - a pure precision advisor in VisualCoreMath: given the mantissa bits and the viewport's units per pixel, it
      returns reliable, warn or clamp.
  - No double precision on the GPU is assumed. The app clamps zoom and shows the limit (A03 rule). Perturbation and
    emulated double are later ideas, not MVP.
- **R4 Parameter animation.**
  - `Tween` and `Timeline` (VisualCoreSimulation), `SceneClock` (play, pause, scrub, rate) and `EasingCurve`
    (VisualCoreMath) exist. A01's clocked scenes are the example consumer.
  - **Decision**: available for palette cycling and tour interpolation. Tours that interpolate between bookmarks
    need log-scale zoom interpolation, which is a small helper on the viewport (Phase 04).
- **R5 Color mapping and palette systems.**
  - `Palette` (VisualCoreParameters) has `sample(_:)` and `builtIns`. A01 uses them.
  - **Decision**: available. Smooth escape-count coloring is app content. If a palette texture or uniform array
    upload is needed for the shader, that is a small adaptation in Phase 02.
- **R6 Pinch/pan camera.** `PinchRecognizer`, `DragRecognizer` and `PointerTracker` (VisualCoreScenes) exist. A02's
  pinch-to-brush is the example consumer. **Decision**: available; the anchored mapping is part of R2.
- **R7 Bookmarks with precision mode.**
  - `DocumentStore` (VisualCorePersistence) gives versioned envelopes, atomic writes, migrations and per-file problem
    reports. A01's library is the example consumer.
  - **Decision**: available. The bookmark schema (view, parameters, precision status) is app content.
- **R8 Iteration cap with render-cost estimate.**
  - No VisualCore cost model exists. `QualityPolicy` (VisualCoreDiagnostics) handles thermal tiers.
  - **Decision**: requires adaptation, as a generic estimate: work ≈ pixels × iterations × samples, labelled as a
    relative estimate, not a time. It goes in VisualCoreDiagnostics in Phase 03, with `QualityPolicy` reused for
    interactive iteration reduction.
- **R9 Still capture and guided tours.**
  - Capture is available: `renderOffscreen`, `ExportGeometry`, `StillImageEncoder` and `TemporaryFolder`, with A01
    and A02 as consumers.
  - Tours: available through R4 plus bookmarks.
- **R10 Visible precision limits with graceful clamping.** This follows R3: the clamp and the warning UI are app
  content, and the advisor is VisualCore.
- **Regression baseline.** The same 7 steps as A01 and A02, at pin `d93edd1`.
