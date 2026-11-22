# Data model: R02-G08-03

| Entity | Fields | Rules |
|---|---|---|
| `FacetedForgeSceneSnapshot` | pieces (world-space corners, faces as corner index lists with a cut flag, centroid), crystal centroid and scale, chosen piece, direction, depth, preview polygon, stage, failure (with its piece), cuts, budget, levelNumber, time | immutable; built from the adapter; finite values; corners within the unit sphere |
| `FacetedForgePalette` | ground #07090F, ice #BFE6F5, highlight #F2FBFF, ruby #C8163C, amber #FFB347, lattice #FFE2A8, sliver #FF4D6D, spent #C8163C, unspent #3A4558 | linear colours in 0 … 1 |
| `FacetedForgeTier` | level-0: 3 bevel segments, 3 dispersion layers, 2 glow shells; level-1: 2, 2, 1; level-2: 1, 1, 0 | richest first; logged with reason on change |
| `FacetedForgeExperienceCore` | level number, play | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Mesh streams | ground, glass faces, cut faces, bevels, preview and marks: normal, uv = (material code, shade); glow: colour in the normal slot, uv = (glow, 0) | shimmer and opening move by uniforms; translucent glass drawn back to front |
| Controls | `piece.cut [0 … pieces − 1, 0 … 12, −24 … 24]`, `play.undo`, `play.redo`, `level.next`; preview pickers (piece, direction, depth − and +) | kernel refusals pass through with their codes; pickers do not touch the kernel |
| Candidate registration | id `r02-g08.faceted-forge`, tiers, palette, capabilities, content facts (100 levels, digest ceb59042…a924c), scenario manifest | `available: false` until X-R02-G08 |
