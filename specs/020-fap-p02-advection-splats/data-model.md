# Data Model: Fluid Art Playground — Phase 02

## PointerVelocityTracker (VisualCoreScenes)

- `init(spacing: Double, maxSamplesPerUpdate: Int = 16, smoothing: Double = 0.5)`:
  - spacing > 0, otherwise 1;
  - cap 1…256;
  - smoothing 0 < α ≤ 1, otherwise 0.5.
- `Sample { id: Int, position: Vec2 (view points, top-left origin), velocity: Vec2 (points/s), timestamp: Double,
  phase: PointerPhase }`.
- `mutating handle(_ e: PointerEvent) -> [Sample]`.
- Counters: `ignoredPointers`, `rejectedSamples`, `cappedUpdates`. `activeCount`.
- Limit: `PointerTracker.maxPointers` (10).

## FieldGrid additions (VisualCoreSimulation)

- `sampleBilinear(cellX: Float, cellY: Float, channel: Int) -> Float`: the coordinate is in cell units with centers
  at `i + 0.5`. It computes `p = coord − 0.5`, `i0 = floor(p)`, `t = p − i0`, with indices clamped to the edge and
  `lerp(a, b, t) = a + (b − a)·t` in x then y.
- `sampleBilinear(cellX:cellY:) -> [Float]` (all channels).

## FluidConfiguration additions (app Core, still version 1)

| Field | Default | Bounds |
|---|---|---|
| brushRadius | 0.04 | 0.005…0.25 (fraction of the shorter edge; non-finite → default) |
| forceScale | 1.0 | 0…4 (non-finite → default) |
| maxSplatsPerFrame | 16 | 1…64 |

## Splat (app Core)

- `position: SIMD2<Float>`: normalized 0…1, origin bottom-left (GL), clamped.
- `radius: Float`: a fraction of the shorter edge, 0.005…0.25.
- `force: SIMD2<Float>`: cells per second, magnitude ≤ 10,000; scaled down if larger.
- `color: SIMD4<Float>`: each 0…1.
- `timestamp: Double`.
- `init?(…)` returns nil for any non-finite input. Clamping is reported via `wasClamped`.
- `apply(to velocity: inout FieldGrid, dye: inout FieldGrid, precision:, velocityEncoding:)` is the CPU reference
  (the Gaussian of research R3).

## SplatQueue (app Core)

- `init(configuration:, gridSize:)`.
- `add(_ samples: [PointerVelocityTracker.Sample], viewSize: SIMD2<Double>)`:
  - converts each sample to a splat: y is flipped and normalized;
  - force = velocity (points/s) × (grid cells / view points per axis) × forceScale;
  - color = palette by pointer order (the first finger seen gets index 0, the next index 1, …, wrapping at 6).
- `addSplash()`: burst *k* (research R6). `splashCount`.
- `drain(max:) -> [Splat]` (research R5).
- `pending`, `dropped`, `totalQueued`.

## Advection (app Core)

- `step(velocity: inout FieldGrid, dye: inout FieldGrid, dt:, velocityDissipation:, dyeDissipation:, precision:,
  velocityEncoding:)`:
  1. new velocity = sample(velocity.old at cell − dt·v.old) × factorV;
  2. new dye = sample(dye.old at cell − dt·v.new) × factorD;
  3. both are rounded to `precision`.

  Velocity is decoded and encoded via `velocityEncoding` when the storage is 8-bit.

## Relationships

`PointerEvent` → tracker → `Sample` → `SplatQueue` → `Splat` → (GPU splat pass | `Splat.apply` CPU) → `Advection`
(GPU advect pass | CPU) → display.
