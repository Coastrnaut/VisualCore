# Terrain levels of detail, erosion masks and the procedural sky

Feature 218 (R02-F18). Spec: [specs/218-procedural-terrain-mesh-and-skydome](../../specs/218-procedural-terrain-mesh-and-skydome/spec.md).

## The rule

A landscape larger than one mesh is drawn in pieces whose detail falls with distance, with no crack anywhere two pieces
meet; the ground is coloured by masks computed from its own heights; the sky is computed from the view and sun
directions, never from an image. The same inputs give the same pieces, masks and colours on every device.

## Terrain (VisualCoreScenes)

- `TerrainSettings`: P × P pieces (P 1 … 64) of C × C base cells (C a power of two, 4 … 128) of size s, L levels
  (level ℓ samples every 2^ℓ base cells), one level per distance D, and a vertex budget (default 262,144).
- `TerrainLOD.select` picks each piece's level from its horizontal distance d to the viewpoint,
  clamp(⌊log₂(d / D)⌋ + 1, 0, L − 1), refines until neighbours differ by at most one level, and when the total vertex count passes the budget it
  shrinks the distance per level in quarter-octave steps until it fits; a budget even the coarsest tiling exceeds is
  refused.
- `TerrainLOD.mesh(for:height:)` samples the piece through the existing `HeightField`. Every point is sampled and placed at its
  global grid index times the cell size, so a point shared by two pieces has bit-identical coordinates, and on an edge facing a coarser neighbour every odd
  point takes the mean height of its two even neighbours, which is the coarser piece's edge, so no crack can appear.

## Erosion masks (VisualCoreScenes)

`ErosionMask.masks(of:)` returns a three-channel `FieldGrid` on the grid points of a `HeightField`: steepness (the sine
of the slope angle), flow (the D8 flow accumulation of O'Callaghan and Mark, 1984, on a log scale, points visited from
highest to lowest with fixed tie rules) and wear (steepness × flow), each in 0 … 1 and bit-identical between runs on one platform (the flow scale uses the platform logarithm).

## Sky (VisualCoreScenes, VisualCoreRendering)

`SkyParameters` hold linear colours of zenith, horizon, ground, a dusk tint, a night scale and the sun, the sun's
angular radius and its glow. The colour of a view direction d under a sun s is a horizon-to-zenith gradient (ground
below the horizon), plus a dusk tint towards the sun near the horizon, scaled towards the night colour as the sun sets,
plus the sun disc and its glow above −r; `SkyModel.colour` (CPU) and `vc_sky` in `vc/sky.glsl` (GPU) compute the same
expression in the same order. `SkyRenderer` draws one far-plane triangle (depth test LEQUAL, no depth write) behind the
scene, finding d from the inverse view-projection, and restores the state it changes.

## Stored forms

`TerrainSettings` and `SkyParameters` are `Codable` as JSON schema 1 with sorted keys; a newer schema is refused and
damaged or out-of-range data is refused with its code.

## Failures

`TerrainError`: `r2-f18.terrain-size`, `r2-f18.piece-size`, `r2-f18.level-count`, `r2-f18.level-distance`,
`r2-f18.budget`, `r2-f18.viewpoint`, `r2-f18.newer-schema`, `r2-f18.malformed`. `SkyError`: `r2-f18.sky-parameter`,
`r2-f18.direction`, `r2-f18.newer-schema`, `r2-f18.malformed`. The experience that reports one adds its id, seed and tick.

## Limits

The sky is an artistic analytic model, not a physical atmosphere; no clouds. No image or texture is used anywhere.

## Sources

Chunked levels of detail with edge stitching, D8 flow accumulation and analytic gradient skies are textbook methods.
All code is original to VisualCore.
