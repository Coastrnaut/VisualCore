# Research: Particle Universe Phase 00 (read-only audit)

A read-only audit of the tree at gate A03-P06 (2026-11-11) for a particle sandbox. Each finding gives a decision,
its rationale and the alternatives considered.

- **R1 GPU-oriented particle simulation.** `ParticleSystem` (VisualCoreSimulation) is a seeded, fixed-capacity CPU
  simulation (default 10,000, cap 100,000) with `checksum()` for determinism; A01's particles family is the consumer.
  OpenGL ES 3.0 through ANGLE offers no compute shaders, so GPU simulation would mean render-to-texture state.
  **Decision**: requires adaptation — keep the simulation on the CPU in VisualCore (bounded, testable, deterministic);
  GPU state is a later idea. **Rejected**: a Metal compute path (a second renderer, forbidden).
- **R2 Buffer management.** `DynamicVertexBuffer`, `ResourceRegistry` and `ParticleRenderer`'s per-frame instance
  upload exist. **Decision**: available.
- **R3 Instanced rendering.** `ParticleRenderer.draw(_:camera:metrics:)` draws instanced soft quads
  (`vcglDrawArraysInstanced`). **Decision**: available.
- **R4 Blending and trails.** Only premultiplied "over" blending; `PingPongTarget` and `FieldPass` (A02) can hold a
  decaying trail texture. **Decision**: requires adaptation — an additive blend option on `ParticleRenderer` and a
  generic trail-decay pass on `PingPongTarget` in VisualCoreRendering (Phase 03), with a reduced-flash cap.
- **R5 Interaction and simulation parameters.** `PointerTracker`, `PinchRecognizer`, `DragRecognizer`
  (VisualCoreScenes), `ParameterSchema`/`Palette` (VisualCoreParameters). **Decision**: available; touch-to-force
  mapping is app content on these.
- **R6 Emitter families with bounded counts (v0.1 F01).** One emitter kind (point + cone). **Decision**: requires
  adaptation — `Emitter` shapes (point, line, ring, burst) in VisualCoreSimulation (Phase 01).
- **R7 Attractors, repulsors, gravity/wind (F02).** `gravity`, `drag`, `attractor` exist; no repulsor-with-falloff,
  wind or singularity-safe softening. **Decision**: requires adaptation — new `ParticleForce` cases in
  VisualCoreSimulation (Phase 02), finite for any position (fixture 4).
- **R8 Size, lifetime, gradient, trail strength (F03).** Emitter start/end size and color exist (two stops).
  **Decision**: available for size/lifetime; multi-stop gradients via `Palette`; trail strength via R4.
- **R9 Pause/reseed/save (F05).** `ParticleSystem(seed:)`, `FixedStepClock`, `NamedLibrary`. **Decision**: available.
- **R10 Device-adaptive quality and reduced flash (F06).** `QualityPolicy`, `FramePacing`, `AccessibilityPreferences`
  (Reduce Flashing). **Decision**: requires adaptation — a particle-count tier mapping in VisualCoreDiagnostics
  (Phase 02) so counts drop before frame pacing degrades.
- **Regression baseline.** The same 7 steps as A01–A03, pin `d93edd1`.
