# Research: Phase 4

## R-F401 Separable Gaussian blur
- **Decision**: two passes (horizontal, vertical) inside the `blur` pass type, 9 taps per direction with
  linear-sampling offsets derived from the radius (σ = radius / 2), weights normalized to 1.
- **Rationale**: standard, bounded cost; radius clamped to 1–32.

## R-F402 Bloom
- **Decision**: bright-pass (luma > threshold, soft knee 0.1) at the pass scale → blur → additive
  composite with intensity onto the input. Uses rgba16f when `hdr` param is 1, else rgba8.

## R-F403 Flash limiter on the GPU
- **Decision**: per frame, render luma of the input into a 16×16 target; read it back on the CPU
  (256 pixels, cheap) and feed `FlashLimiterModel`, which returns the gain toward the adapted mean;
  the output pass multiplies color by that gain. Avoids an extra GPU reduction chain; matches the
  reference FlashLimiter idea (adapted luminance, bounded step) without copying its code.

## R-F404 Kahn ordering tie-break
- **Decision**: ready set ordered by declaration index (min-heap by index), giving a stable order.
