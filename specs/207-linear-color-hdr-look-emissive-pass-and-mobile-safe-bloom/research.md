# Research: R02-F07

- **R1 Downsampled bloom.** Decision: prefilter into a half/quarter-size target with 4 bilinear taps, separable 9-tap
  Gaussian there, one bilinear upsample in the composite. Rationale: 3 draws, a quarter or a sixteenth of the pixels;
  standard mobile practice. Alternative: dual-filter mip chain (rejected for this slice: more targets and draws).
- **R2 Soft knee.** Decision: quadratic knee (curve `(L − t + k)² / (4k)` between `t − k` and `t + k`, linear above).
  Rationale: continuous first derivative; no hard edge at the threshold.
- **R3 Tone maps.** Decision: none, Reinhard `x/(1+x)` per channel, Narkowicz ACES fit per channel, clamp 0…1.
  Rationale: cheap, monotonic, well known; code only.
- **R4 Unclamped decode.** Decision: the emissive programs carry their own decode that does not clamp above 1.
  Rationale: `vc_srgbDecode` clamps (audit); inputs are 8-bit so only intermediates exceed 1.
- **R5 Limiter in linear light.** Decision: opt-in `linear` parameter set by `EffectScene` only for graphs with an
  emissive pass. Rationale: no change to existing graphs.
- **R6 As built (T-R02F07-013, 2026-11-19).** The pass makes four draws, not three: prefilter into blur target A,
  horizontal blur into B, vertical blur back into A, composite into the output. The four prefilter taps sit ±0.25 blur
  texel from the centre (one input texel centre each at half size, an equal 2×2 average each at quarter size), each
  decoded before averaging. The blur is 9 taps one texel apart, σ = max(radius/2, 0.5), weights normalised, positions
  clamped to edge texel centres; the existing blur shader spaces taps differently and is not reused. Worst measured
  difference from the CPU reference on sim-27.2: 1.28/255 (filmic), within the 2/255 bound.
