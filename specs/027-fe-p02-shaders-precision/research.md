# Research: Fractal Explorer — Phase 02

## R1. Precision query

- **Decision**: call `glGetShaderPrecisionFormat(GL_FRAGMENT_SHADER, GL_HIGH_FLOAT | GL_MEDIUM_FLOAT)` in
  `RenderCapabilities.query`, and store the results as optional `ShaderPrecision` values.
- **Rationale**: it is the standard GLES 3.0 query, and ANGLE implements it.
- **Alternatives**: a probe render that measures resolution empirically. This is more robust, but more complex;
  it is kept for the Phase 05 device validation.

## R2. Advisor thresholds

- **Decision**: margin = pixelStep / ulp(max(|m|, pixelStep)) in units of 2^−bits; *near* below 16, *beyond* below 1.
- **Rationale**:
  - below 1 ulp per pixel, neighboring pixels map to the same float, which gives blocky garbage;
  - 16 steps leaves room for the iteration's error growth before visible banding.

## R3. Shader structure

- **Decision**: a single fragment with a branch on `u_mode`, a loop bounded at 10,000 with a break at `u_cap`, and a
  smooth value computed as on the CPU. Color comes from the palette stops along `fract(smooth · 0.05 + u_time ·
  u_rate)`; the interior is black.
- **Rationale**: one program keeps mode switches cheap. The bounded loop satisfies GLSL ES 3.00.

## R4. GPU–CPU agreement

- **Decision**: `renderOffscreen(64, 64)` of the default views, with the scene paused. A pixel counts as interior when
  it is black (all channels ≤ 1). Compare its class with `FractalMath` at the pixel centers, and excuse disagreements
  that have a CPU-boundary neighbor.
- **Rationale**: float32 rounding moves only boundary pixels.
