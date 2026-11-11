# Research: Fluid Art Playground — Phase 02

## R1 Exact bilinear sampling instead of hardware filtering

- **Decision**: advection fetches the 4 neighboring cells with `texelFetch` (indices clamped to the edge) and weights
  them in `highp` float32 as `a + (b − a)·t`, first along x and then along y. `FieldGrid.sampleBilinear` uses the
  same formula and order.
- **Rationale**: GPU hardware filtering uses reduced sub-texel weight precision (commonly 8 bits), so it cannot match
  a CPU reference to one storage step. With explicit arithmetic, the only differences are float32 contraction and
  the storage rounding (Phase 01: truncating half writes).
- **Alternatives**: hardware `LINEAR` (unmatchable); nearest sampling (blocky, wrong algorithm).
- **Cost**: 4 fetches per cell per advection pass, at 512² at most. This is acceptable now; it is measured in campaign
  II.

## R2 Velocity units and backtrace

- **Decision**: velocity is in cells per second; `src = fragCoord − Δt·v` (in cells; `gl_FragCoord.xy` gives cell
  centers `i + 0.5`). RGBA8 fallback encoding range = `velocityRange × 60` cells per second (spec clarification 1).
- **Rationale**: units are independent of the frame rate, and the Phase 01 meaning of `velocityRange` is kept.

## R3 Splat shape

- **Decision**: the Gaussian `exp(−d²/r²)`, with `d` in cells and `r = radius × min(W, H)`. Velocity gains the force;
  dye RGB gains the color, and alpha is unchanged. For 8-bit velocity the shader decodes, adds and re-encodes
  (clamped).
- **Rationale**: the standard artistic splat, deterministic and cheap. GPU `exp` versus CPU `exp` may differ by a few
  ulps, which is within the one-step tolerance.

## R4 Tracker (G-POINTERVEL) semantics

- **Decision**: `PointerVelocityTracker(spacing:maxSamplesPerUpdate:smoothing:)`.
  - **began**: emits 1 sample with velocity 0.
  - **moved**: emits `n = min(ceil(dist/spacing), cap)` samples along the segment (the last one at the new
    location). The raw velocity `Δp/Δt` is used when Δt ≥ 1 ms, otherwise the previous velocity. The smoothed
    velocity is `v += α(raw − v)` (α = 1 on the first move). The interpolated samples share the new velocity.
  - **ended**: emits 1 final sample, then forgets the pointer.
  - **cancelled**: forgets the pointer and emits nothing.
  - At most 10 pointers; non-finite input is rejected. Counters: `ignoredPointers`, `rejectedSamples`,
    `cappedUpdates`.
- **Rationale**: these are generic gesture-to-force semantics (A11, A20). Spacing is a parameter, so each app picks
  its brush.

## R5 Even capped drain

- **Decision**: `SplatQueue.drain(max:)`. If `pending ≤ max`, it returns everything in order. Otherwise it keeps
  indices `round(i·(n−1)/(max−1))` for `i` in `0..<max`, so both the first and the newest are kept in order, and
  `dropped += n − max`.
- **Rationale**: path coverage is preserved, the result is deterministic, and the newest touch is always applied.

## R6 Splash control

- **Decision**: burst *k* sits at the center with direction angle `k × 137.5°` (the golden angle, so successive
  bursts spread), force 600 cells per second, color `palette[k mod 6]` and the configured radius. VoiceOver announces
  "Splash added" through the accessibility notification. The button has the identifier `fap.splash` and is at least
  44 points tall.

## R7 Shader library for FieldPass

- **Decision**: `FieldPass.init(registry:fragment:inputs:label:library:)` with `library` defaulting to
  `ShaderBundle.visualCoreIncludes`, a new static: a `ShaderLibrary` holding `vc/*.glsl`. Passes can then
  `#include "vc/field.glsl"`.
- **Alternatives**: copying the sampler into app shaders (duplication, rejected by the reuse rule).

## R8 Advection fixtures

- **Decision**:
  - **Zero velocity**: `DyeSeed.pattern` on 8×8 and 16×16, d = 0, 120 steps; compared with the initial pattern
    rounded to storage.
  - **Uniform velocity**: velocity = (30, 0) cells per second at Δt = 1/60 (half a cell per step), 4 steps; GPU vs
    CPU per storage (half: the closer of the nearest and toward-zero references).
  - **Splat**: one splat at (0.3, 0.6), radius 0.2, force (100, −50), color (0.9, 0.2, 0.4); GPU vs CPU.
  - Tolerance: k storage steps after k steps (spec SC-A02-203).
