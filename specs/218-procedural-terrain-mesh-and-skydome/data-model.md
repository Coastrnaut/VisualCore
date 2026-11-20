# Data model: R02-F18

| Entity | Fields | Rules |
|---|---|---|
| TerrainSettings | pieces P, pieceCells C, cellSize s, levels L, levelDistance D, vertexBudget | P 1 … 64; C power of two 4 … 128; s finite > 0; L 1 … log₂C; D finite > 0; budget 1 … 4,194,304 (default 262,144); JSON schema 1 |
| TerrainPiece | column, row, level, coarserNeighbours[4] (−z, +x, +z, −x), originX, originZ, cellSize, cells | cells = C / 2^level; vertexCount = (cells + 1)² |
| ErosionMask | FieldGrid of 3 channels: steepness, flow, wear | each 0 … 1, on the grid points of the HeightField |
| SkyParameters | zenith, horizon, ground, dusk, night, sunColour (linear RGB 0 … 1), sunRadius, glowStrength, glowExponent | sunRadius 0.001 … 0.2 rad; glowStrength 0 … 4; glowExponent 1 … 4,096; all finite; JSON schema 1 |
| TerrainError | terrainSize, pieceSize, levelCount, levelDistance, budget, viewpoint, newerSchema, malformed | `reasonCode` `r2-f18.*` |
| SkyError | skyParameter, direction, newerSchema, malformed | `reasonCode` `r2-f18.*` |

Sky defaults (linear RGB): zenith (0.18, 0.36, 0.75), horizon (0.70, 0.80, 0.92), ground (0.30, 0.27, 0.24), dusk
(0.90, 0.45, 0.20), night scale (0.05, 0.06, 0.12), sun colour (1.00, 0.95, 0.85), sun radius 0.0093 rad (about the
Sun's 0.53° disc), glow strength 0.5, glow exponent 64.
