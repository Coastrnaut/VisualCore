# Contract: VisualCore additions for A04-P03 (G-BLENDTRAIL)

| ID | Module | Contract | Verified by |
|---|---|---|---|
| C1 | VisualCoreSimulation | `TrailDecay.factor` frame-rate independent; `step8` reaches 0 in finite frames for s ≤ 0.98 | `TrailDecayTests` (host) |
| C2 | VisualCoreSimulation | `ParticleSystem.liveCount(source:)` counts live particles per emitter | `TrailDecayTests` / `ParticleSystemTests` |
| C3 | VisualCoreRendering | `ParticleBlend.normal` pixels identical to the pre-035 draw; `.additive` sums overlapping colors | `ParticleBlendTests` on sim-27.2 and sim-26.5 |
| C4 | VisualCoreRendering | `TrailLayer` fade matches `step8` within 1/255 per frame; 60 frames at 60 Hz vs 30 frames at 30 Hz agree within 6/255 (SC-A04-303) | `TrailLayerTests` |
| C5 | VisualCoreRendering | 20 resizes + 20 clears + recreation leave live textures equal to after first setup; `leaked` unchanged (SC-A04-304, fixture 3) | `TrailLayerTests` |
| C6 | VisualCoreRendering | with `brightnessCap` 0.6 every composited channel ≤ 153 (SC-A04-305) | `TrailLayerTests` |
| C7 | VisualCoreRendering | `ParticleLayerScene` without trails or cap draws the Phase 02 pixels; with trails uses one `TrailLayer` and releases it when off | `TrailLayerTests`, `ParticleLayerSceneTests` |

All public symbols have `///` docs and are in the API baseline; no ProjectM types appear.
