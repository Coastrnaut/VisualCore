# Research: A12-P01 (feature 089)

Facts verified on 2026-11-15 (clarification session): `VisualCoreScenes` depends on `VisualCoreMath` and
`VisualCoreSimulation`; `Mesh`, `MeshBudget`, `MeshError`, `Mesh.digest` (SHA-256 of little-endian IEEE-754 bits);
`SeededRandom`, `SplitMix64`; `OrbitCamera`, `OrbitBounds`; `MeshRenderer` (one colour, one light direction, ambient,
fog) and `DepthMeshPass`; no noise or height field in any framework product (contract G-TERRAIN).

## D1 — Gradient noise (VisualCoreScenes)

- **Decision**: `GradientNoise2D(seed: UInt64)` with `value(x:y:) -> Double` in −1…1: lattice cell (floor), corner hash
  h = mix(seed ^ (i · 0x9E3779B97F4A7C15) ^ (j · 0xC2B2AE3D27D4EB4F)) with the SplitMix64 finalizer (wrapping
  arithmetic on `UInt64` from `Int64` bit patterns), gradient = one of 8 directions (±1, 0), (0, ±1), (±1, ±1)·(1/√2
  as the literal 0.7071067811865476), dot with the offset, quintic fade, bilinear blend, scaled by √2 (literal) and
  clamped. `FractalNoise2D` (octaves 1…8, frequency > 0, lacunarity 1…4, gain 0…1, finite) sums octaves with seeds
  seed + octave index and divides by the amplitude sum; `init?` refuses invalid settings.
- **Rationale**: only +, −, × and floor on binary64: bit-identical across arm64 devices and simulators; integer hashing
  avoids permutation tables.
- **Alternatives**: value noise (blockier), simplex (patent-free now but more code, skew constants), GPU noise
  (`vc/noise.glsl`; rejected: CPU authority and digests).

## D2 — Height field (VisualCoreScenes)

- **Decision**: `HeightField(columns:rows:cellSize:origin:height:)` (throws `MeshError.invalidInput` for counts outside
  1…512, non-positive or non-finite cell size or non-finite heights) stores (columns + 1)(rows + 1) heights row-major
  (row = z index) and (columns + 3)(rows + 3) samples including one ring beyond for normals; `height(atX:z:)` bilinear,
  clamped to the grid; `normal(column:row:)` = normalise(h(i−1) − h(i+1), 2c, h(j−1) − h(j+1)); `mesh(budget:)` builds
  positions (x, h, z), the field normals, uv = (i/columns, j/rows) and indices (two triangles per cell, CCW seen from
  +y) after checking the budget (`.budget`). The tile seam test builds two fields sharing an edge from one function.
- **Rationale**: normals from the function, not from triangles, are what makes adjacent pieces agree.
- **Alternatives**: `MeshShapes.surface` (area-weighted triangle normals differ at piece edges); storing only the grid
  (normals at the edge need neighbours).

## D3 — Preset terrains (app-local)

- **Decision**: the clarified recipes (island, asteroid garden, miniature city; 12 × 12 m; heights within −1…1.6 m),
  shaping as pure functions of (x, z) and the seed (craters and mounds placed by `SeededRandom(seed)` before the field
  is sampled); each world yields up to three parts — terrain, and a sea plane (island, city) or none (asteroid garden,
  drawn over the void colour) — each with a palette colour. Digest fixtures for seeds 1, 2, 3 are generated once and
  committed in `TerrainFixtureTests` (and in the manifest fixtures).

## D4 — View, actions and state

- **Decision**: the clarified actions; the view is (yaw, pitch, distance) clamped to pitch 10°…75° and distance
  10…30 m (an `OrbitBounds` plus the app-local lower pitch); the camera target is the world centre at height 0.3 m.
  `WorldState` schema 1 as sorted-key JSON; the digest covers preset, seed, view and generator state; the terrain digest
  is a separate pure function of preset and seed.

## D5 — Manifest fixtures

- **Decision**: nine standard scenarios plus fixtures `fixture-<preset>-<seed>` for the three presets × seeds 1, 2, 3,
  each asserting the terrain digest; plus refusal scenarios for an out-of-range preset and a fractional zoom.
