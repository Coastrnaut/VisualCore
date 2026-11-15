# Data Model: A12-P03

- **PlacedProp**: kind 0…3, x and z within ±5.5 m, y = terrain height, rotation −π…π, scale 1.
- **WorldLight**: azimuth 0…360°, elevation 10…85°, ambient 0.1…0.6.
- **WorldState** (schema 2): presetIndex, seed, view, generator state, props (≤ 24), selection (−1 or index), light.
- **WorldDocument** (file schema 2): name, state; ≤ 64 KB; `world-<slot>.json`, slots 0…3.
- **Thumbnail**: 160 × 120 PNG, ≤ 64 KB, `world-<slot>.png`.
