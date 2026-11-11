# Data model: Phase 7

- **ProjectMScene** (harness): `presetPath`, `engine: ProjectMEngine?` (`hasEngine`), `engineGeneration` (host generation it was created on), `enginesCreated`, `frames`, `lastError`, `signal: SyntheticSignal`, `loader` (injectable), `viewports` (every viewport given to the engine, never zero), pending preset request; GL state is always handed back with `GLState` after each engine frame.
- **SyntheticSignal**: `sampleRate` 44,100, `frame` index; `next(frames:) -> [Float]` interleaved stereo, deterministic.
- **EngineFramebufferPath** (path A, a `RenderScene`): `engine`, `target: RenderTarget` (offscreen), `captureNextFrame`, `captured` (read back inside its own frame while its context is current).
- **ImageDiff.Result**: `meanAbs` (0–255), `within8` (fraction), `passes` (strict mean ≤ 2 and ≥ 99%), `passes(noiseFloorWithin8:)` (SC-F702 amended: mean ≤ 2 and within8 ≥ max(0.95, floor − 0.01)).
- **MigrationBatch** (doc row): id (2a, 2), VisualCore implementation, reason, before evidence, after evidence, behavior change, retained parts.
