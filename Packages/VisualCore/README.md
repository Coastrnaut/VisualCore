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
| VisualCoreAudioDSP | **placeholder, not built yet** — planned: lock-free ring, FFT, bands, RMS, onsets ([ADR-0006](../../docs/decisions/ADR-0006-unbuilt-readme-modules.md)) |
| VisualCorePersistence | **placeholder, not built yet** — planned: versioned documents, atomic writes, migrations (first app that persists documents) |
| VisualCoreTestSupport | **placeholder, not built yet** — planned: fake clock, fixtures, image baselines (test targets only, rule R5; ADR-0006) |

Imports allowed (R2): Foundation-level system modules (`Foundation`, `Dispatch`, `os`, `simd`,
`Accelerate`, `Synchronization`) and other modules of this package.

```bash
swift test --package-path Packages/VisualCore
python3 scripts/check_dependencies.py
```

Version 1.0.0-rc.1 (semantic versioning; release candidate from the F09 stabilization gate — see [release notes](../../docs/release/release-notes-1.0.0-rc.1.md)).

## Input, animation, scenes and particles (feature 006, gate F05)

Contract: [`specs/006-input-animation-scenes/contracts/interaction-api.md`](../../specs/006-input-animation-scenes/contracts/interaction-api.md).

**Coordinate spaces** (`VisualCoreScenes.ViewMetrics`, `VisualCoreMath.Camera2D`):

| Space | Origin | Axes | Units |
|---|---|---|---|
| view points | top-left | x right, y down | UIKit points |
| pixels | top-left | x right, y down | points × `scale` |
| NDC | center | x right, y up | −1…1 |
| camera | view center | x right, y up | points |
| world | `Camera2D.center` | x right, y up | points at zoom 1 (`zoom` 0.1…100) |

Conversions round-trip within 0.001 pt (SC-F501) and return nil for a zero-size view.
`worldToNDC(camera:)` is the matrix renderers use.

**Gestures** (`PointerTracker` + recognizers; feed the tracker first, then each recognizer; call `tick(now:)`
for time-based transitions). Defaults: tap ≤ 10 pt and ≤ 0.3 s; double-tap second tap within 0.3 s and 30 pt;
long-press ≥ 0.5 s within 10 pt; drag after 10 pt. Pinch and rotate run together; a second finger cancels an
active drag and fails a pending tap. At most 10 pointers; more are ignored and counted.

**Timing and determinism** (`VisualCoreSimulation`): `FixedStepClock` (1/120 s, ≤ 8 steps per frame, excess
time dropped and counted, 1e-9 s boundary tolerance, invalid deltas = 0). `SeededRandom` is xoshiro256** seeded
through SplitMix64; integer sequences are identical on every platform. Simulations driven by the clock and the
generator are bit-identical per platform and independent of the display rate (proven at 60 and 120 Hz); float
identity across CPU architectures is not promised.

**Animation**: `ease(_:_:_:)` (linear, quad, cubic, sine, expo, back, elastic, bounce × in/out/inOut; f(0)=0,
f(1)=1), `Tween` (repeat count or forever, autoreverse) and `Timeline` (play, pause, seek, reverse via negative
`rate`, completion events once per pass, `reduceMotion` jumps to end values and disables repeats).

**Scenes and particles**: `SceneNode` (TRS transform, z-order, visibility, primitive rect/circle/line/polygon
≤ 256 points, hit testing); `ParticleSystem` (capacity 10,000 default, ≤ 100,000; `Emitter`s with rate, burst, lifetime, speed, direction/spread,
size and color over life; `ParticleForce` gravity/drag/attractor; NaN removal, `checksum()`; `instances()` →
`ParticleInstance` for `ParticleRenderer`); 3D: `OrbitCamera` (pitch ±89°, `project`, `ray`), `Mesh.plane/cube/uvSphere`
(segments 3–256, rings 2–256, subdivisions ≤ 256).
