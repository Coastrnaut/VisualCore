# Data Model: A21-P01 (feature 152)

- **SkyScene** (schema 1, kind `a21.sky-scene`, ≤ 4,096 bytes): `preset` (catalog id), `palette` (2…4 opaque sRGB
  colours), `ribbons` 1…4, `turbulence` 0…1, `cloudiness` 0…1, `stars` 0…400, `speed` 0…2. Refusal codes: `damaged`,
  `newer-version`, `too-large`, `not-finite`, `out-of-range`, `unknown-preset`, `palette-size`. Setters clamp; a
  non-finite setter value is ignored.
- **SkyPresets:** `polar-night`, `violet-veil`, `dawn-haze`; each version 1, attribution "written for VisualCore".
- **SkyClock:** a `SceneClock` of period 600 s; `advance(by:)` uses the frame delta (≤ 0.25 s); held when
  `reducedMotion` or speed 0; `phase = time / 600` in 0…1.
- **SkyShader:** source `aurora-sky.frag` (`#include "vc/noise.glsl"`), uniforms `u_phase`, `u_ribbons`,
  `u_turbulence`, `u_cloudiness`, `u_stars`, `u_octaves`, the palette; levels: 0 → 5 octaves, 1 → 3.
- **SkyReference:** per-pixel colour at a resolution, phase and level, from the same formulas.
- **Tolerances:** mean absolute channel difference ≤ 2/255, largest ≤ 8/255; luminance (Rec. 709, sRGB-decoded)
  ≤ 0.75 per pixel and ≥ 0.02 mean; off-screen size 64 × 48.
