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
