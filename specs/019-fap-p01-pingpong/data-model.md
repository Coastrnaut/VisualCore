# Data Model: Fluid Art Playground — Phase 01

## FluidConfiguration (app Core, `Codable`, `version = 1`)

| Field | Type | Default | Bounds (clamped, issue reported) |
|---|---|---|---|
| version | Int | 1 | must be 1; any other value is an issue and is reset |
| gridWidth | Int | 128 | 16…512; then ≤ the device's maximum render size (`clamped(maxEdge:)`) |
| gridHeight | Int | 128 | 16…512; then ≤ the device's maximum render size |
| dyeDissipation | Double | 1.0 | 0…10 per second; NaN → default |
| velocityDissipation | Double | 0.2 | 0…10 per second; NaN → default |
| viscosity | Double | 0.0 | 0…1 (stored and validated; used in Phase 03) |
| pressureIterations | Int | 20 | 1…80 (stored and validated; used in Phase 03) |
| velocityRange | Double | 4.0 | 0.5…64 cells per step (the `vmax` for RGBA8 velocity encoding) |
| seed | UInt64 | 1 | any value |

- `validated() -> (FluidConfiguration, [ConfigurationIssue])`.
- `ConfigurationIssue { field: String, requested: String, applied: String }`.
- Validation is idempotent: validating a validated configuration returns no issues.

## Dissipation (app Core)

- `factor(d, dt) = 1 / (1 + d·dt)`, where `d` and `dt` are already validated.
- `step(_ grid: inout FieldGrid, d:, dt:, precision:)` multiplies every value by the factor, then rounds it with
  `precision`.

## DyeSeed (app Core)

- `uniform(width:height:rgba:) -> FieldGrid` (4 channels).
- `pattern(width:height:seed:) -> FieldGrid` is deterministic for a given seed (`SeededRandom`). It produces soft
  blobs of palette colors with values in [0, 1].
- `zeroVelocity(width:height:) -> FieldGrid` (2 channels stored as RGBA: the RG components are the velocity and BA
  are 0).

## FluidCanvasDescription (app Core)

`text(configuration:storage:paused:) -> String` (spoken canvas value).

## FieldGrid (VisualCoreSimulation)

- `width`, `height` (≥ 1), `channels` (1…4), `values: [Float]`, row-major from the bottom row up (GL order). The
  count is `width·height·channels`.
- `init(width:height:channels:fill:)`; subscript `(x, y, c)`; `map`, `maxAbsDifference(_:)`; `isFinite`; `minValue`.
- `rounded(to: StoragePrecision)`.

## StoragePrecision (VisualCoreSimulation)

- `.float32`, `.float16`, `.float16TowardZero` (truncating half writes, found in T-A02-111), `.unorm8`.
- `round(_ x: Float) -> Float`.
- `step: Float`, the comparison tolerance: 1e-3 for float16 at values ≤ 1, 1.5/255 for unorm8, 1e-6 for float32.

## SignedRangeEncoding (VisualCoreSimulation)

- `init(range: Float)` with `range > 0`.
- `encode(v) = clamp(v / range·0.5 + 0.5, 0, 1)`; `decode(u) = (u − 0.5)·2·range`.

## TimeStepPolicy (VisualCoreSimulation)

- `minStep = 1/240`, `maxStep = 1/30` (configurable when `0 < min ≤ max`).
- `clamp(_ delta: Double) -> Double`: NaN, an infinite value or a value ≤ 0 → `minStep`; otherwise
  `min(max(delta, minStep), maxStep)`.
- Counts `clampedCount` (deltas above max) and `invalidCount`.

## VisualCoreRendering additions

- **FloatRenderSupport**:
  - fields `extensionReported`, `probeComplete`, `supported`;
  - `static func detect(in registry:) -> FloatRenderSupport` (cached per generation);
  - `storageFormat(forceFallback:) -> TextureFormat` (`.rgba16f` or `.rgba8`).
- **PingPongTarget**:
  - `read`, `write` (`RenderTarget`), `width`, `height`, `format`, `swapCount`, `bytes` (the sum of both targets);
  - `swap()`, `release()`;
  - `isValid` (not released, current generation).

  State: created → (swap)* → released, or stale after a context loss.
- **FieldPass**:
  - `inputs: [String]`, `program`, `label`;
  - `run(output:inputs:uniforms:) throws(FieldPassError)`;
  - `run(pair:input:extraInputs:uniforms:) throws(FieldPassError)`;
  - `release()`.
- **FieldPass.Output**: `.target(RenderTarget)`, `.framebuffer(name: UInt32, width: Int, height: Int)`.
- **FieldUniform**: `.float(Float)`, `.vec2(SIMD2<Float>)`, `.vec4(SIMD4<Float>)`, `.int(Int32)`.
- **FieldPassError**: `inputIsOutput(String)`, `missingInput(String)`, `unknownInput(String)`,
  `unknownUniform(String)`, `uniformTypeMismatch(String)`, `stale`, `compile(String)`.
- **RenderTarget additions**: `upload(rgbaFloats: [Float]) -> Bool`, `readFloatPixels() -> [Float]`.

## Relationships

- `FluidConfiguration` → (validated) → `FluidFieldsScene` sizes two `PingPongTarget`s (velocity, dye) in
  `FloatRenderSupport.storageFormat`.
- `DyeSeed` produces a `FieldGrid` → `upload(rgbaFloats:)`.
- `Dissipation.step` on a `FieldGrid` is the CPU reference compared with `readFloatPixels()` of `dye.read`.
