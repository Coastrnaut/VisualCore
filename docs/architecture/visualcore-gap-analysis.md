# VisualCore gap analysis (feature 001, T-F012)

Capabilities the 25-app suite needs that the reference does not provide, from
`current-rendering-pipeline.md` and `reusable-component-inventory.md`, mapped to the gate that closes each.

| Gap | Evidence in reference | Closing gate |
|---|---|---|
| App-neutral render host (no engine types) | `ANGLERenderer` owns `ProjectMEngine` | F02 |
| Explicit lifecycle state machine | Only pause/resume + surface rebuild | F02 |
| Context generations and forced recreation (U-F001) | No context recreation path | F02 |
| Capability report (GL version, extensions, limits) | Not exposed | F02 |
| Full GL ES 3.0 entry table for app code | Only a few helpers resolve procs (`CANGLE.c`) | F02/F03 |
| Resource registry, byte budgets, leak counters (U-F002, U-F003) | Implicit per-component ownership | F03 |
| Shader library with includes, line-mapped diagnostics, program cache | Engine-internal only | F03 |
| Multi-pass effect graph (DAG, quotas, pass-through on failure) | Single flash-limiter post pass | F04 |
| Input mapping, fixed-step simulation, seeded RNG, math, meshes, particles | None (visualizer only) | F05 |
| Showcase without ProjectM | None | F06 |
| Reference adapter through VisualCore host | N/A | F07 |
| Second consumer; app-neutral audio features (FFT/bands/onset) | Audio tied to visualizer types | F08 |
| Suite compliance, symbol isolation, privacy checks, automation runner per app | Single-app versions | F09 |
