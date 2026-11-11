# Contract: VisualCore additions for A04-P02 (G-FIELDS, G-PQUALITY, layer scene)

| ID | Module | Contract | Verified by |
|---|---|---|---|
| C1 | VisualCoreSimulation | `ParticleForce.repulsor/.gravityWell/.wind/.vortex` with the formulas of research R2 | `ParticleForceFieldTests` |
| C2 | VisualCoreSimulation | `clamped()` maps non-finite → 0 and clamps to the published ranges; old cases unchanged for valid values | `ParticleForceFieldTests`, replay fixture, A01 core tests, `VisualCoreBaselines` |
| C3 | VisualCoreSimulation | `bound(speed:)` ≥ the magnitude of `acceleration(at:velocity:)` for every finite input, center included (SC-A04-201) | grid + center + 1e-12 tests |
| C4 | VisualCoreSimulation | 10,000 steps with particles born on a force center remove 0 non-finite particles (SC-A04-202) | `ParticleForceFieldTests` |
| C5 | VisualCoreSimulation | `liveLimit` ∈ 1…capacity; live ≤ liveLimit; dropped = demand − created (SC-A04-203) | `LiveLimitTests` |
| C6 | VisualCoreDiagnostics | `ParticleBudget.limit(requested:tier:)` per data model; never above requested | `ParticleBudgetTests` |
| C7 | VisualCoreDiagnostics | `DeviceConditions.current()` uses only `ProcessInfo` public API | `ParticleBudgetTests`, `check_compliance.py` |
| C8 | VisualCoreRendering | `ParticleLayerScene` (with `WorldRect`, `fit`, `worldPoint`, `viewPoint`) clears, aspect-fits the world rect (y up), draws with `ParticleRenderer`; centers lit, far pixels background in 3 fixed states (SC-A04-205); recreation redraws the same pixels | `ParticleLayerSceneTests` on sim-27.2 and sim-26.5 |

Every public symbol has `///` docs; `scripts/check_public_api.py --update` records the baseline. ProjectM types never
appear in these APIs.
