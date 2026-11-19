# Contract: colour boundaries (G-COLOR)

- Every target holds sRGB-encoded values; the source and the result are `.rgba8`; the intermediates are
  `FloatRenderSupport.detect(in:).storageFormat(forceFallback: renderer.forceStandardPrecision)`.
- grade, blur, vignette: `vec3 c = vc_srgbDecode(texture(u_source, uv).rgb)` … `color.rgb = vc_srgbEncode(result)`;
  alpha passes unchanged. distort and posterize unchanged.
- grade (linear): `y = c·2^exposure; y = (y − 0.18)·contrast + 0.18; L = 0.2126 r + 0.7152 g + 0.0722 b;
  y = L + (y − L)·saturation`.
- `EffectReference` mirrors this with the CPU transfer functions and the storage precision of the path.
- Tests: identity chain over a 256-value ramp within 1/255 on both paths; mid-grey (118) with exposure +1 matches the
  CPU linear reference within 2/255; blur radius 2 across a black/white edge gives 188 ± 3 in the edge's middle column;
  every effect on the test picture matches `EffectReference` within 2/255 (distort 4/255) on both paths.
