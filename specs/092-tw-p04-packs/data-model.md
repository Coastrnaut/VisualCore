# Data Model: A12-P04

- **WorldPack**: id ∈ {island, asteroid-garden, miniature-city}, name, presetIndex 0…2, seed, props (≤ 16; kind, x, z,
  turn degrees), light (azimuth, elevation, ambient), pitch range, distance range (within 10°…75°, 10…30 m), default
  view, author, license ∈ {"MIT"}.
- **Budgets**: ≤ 16 props, ≤ 30,000 vertices, ≤ 18 draws per pack.
- **WorldState**: unchanged (schema 2).
