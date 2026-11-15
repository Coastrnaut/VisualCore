# Data Model: A12-P01

- **GradientNoise2D / FractalNoise2D** (VisualCore): seed `UInt64`; octaves 1…8, frequency > 0, lacunarity 1…4, gain
  0…1; output −1…1.
- **HeightField** (VisualCore): columns, rows 1…512; cellSize > 0 (metres); origin (x, z); heights (columns + 1) ×
  (rows + 1) row-major, finite; sampler and normals; mesh within `MeshBudget`.
- **ContentRecord** (experience): id (unique), kind ∈ {preset, palette}, name, author, license ∈ {"MIT"}.
- **Palette**: id, three colours (sea or void, low land, high land) as RGBA 0…1.
- **WorldPreset**: id ∈ {island, asteroid-garden, miniature-city}, name, columns, rows, size 12 m, recipe settings,
  palette id.
- **WorldView**: yaw −π…π, pitch 10°…75°, distance 10…30 m.
- **WorldState** (snapshot schema 1): presetIndex 0…2, seed `UInt32`, view, generator state; sorted-key JSON; damaged
  or newer refused.
