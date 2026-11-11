# Data model: Phase 7

- **ProjectMScene** (harness): `presetPath`, `engine: ProjectMEngine?`, `engineGeneration` (host generation it was created on), `enginesCreated`, `frames`, `lastError`, `signal: SyntheticSignal`, `useStateReset: Bool`.
- **SyntheticSignal**: `sampleRate` 44,100, `frame` index; `next(frames:) -> [Float]` interleaved stereo, deterministic.
- **EngineFramebufferPath** (path A): `engine`, `target: RenderTarget` (offscreen), `render()`, `pixels`.
- **ImageDiff**: inputs two RGBA8 buffers of equal size; outputs `meanAbsDiff` (0–255), `fractionWithin(8)`, `passes(tolerance)` per SC-F702.
- **MigrationBatch** (doc row): id (2a, 2), VisualCore implementation, reason, before evidence, after evidence, behavior change, retained parts.
