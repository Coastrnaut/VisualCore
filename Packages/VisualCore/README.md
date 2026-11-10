# VisualCore (pure modules)

Host-testable Swift modules with no GPU and no UIKit. They run on macOS for `swift test` and on
iOS 26+ inside apps. The package map and dependency rules R1–R5 are in
[`specs/002-architecture-contracts/contracts/package-map.md`](../../specs/002-architecture-contracts/contracts/package-map.md).

| Product | Purpose |
|---|---|
| VisualCoreMath | vectors, matrices, quaternions, cameras, easing |
| VisualCoreSimulation | fixed-step clock, seeded RNG, timelines, particle pool, NaN guard |
| VisualCoreScenes | input mapping, pointer tracking, mesh generators |
| VisualCoreShaderSource | shader library, includes, line maps, diagnostics parsing |
| VisualCoreEffectsGraph | effect DAG model, validation, quotas, flash-limiter model |
| VisualCoreDiagnostics | render lifecycle state machine, frame statistics, reports |
| VisualCoreAudioDSP | lock-free ring, FFT, bands, RMS, onsets |
| VisualCorePersistence | versioned documents, atomic writes, migrations |
| VisualCoreTestSupport | fake clock and fixtures (test targets only, rule R5) |

Imports allowed (R2): Foundation-level system modules (`Foundation`, `Dispatch`, `os`, `simd`,
`Accelerate`, `Synchronization`) and other modules of this package.

```bash
swift test --package-path Packages/VisualCore
python3 scripts/check_dependencies.py
```

Version 0.1.0 (semantic versioning; 0.x until the F09 stabilization gate).
