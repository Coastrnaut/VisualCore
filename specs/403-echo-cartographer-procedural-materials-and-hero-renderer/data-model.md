# Data model: R02-G11-03

| Entity | Fields | Rules |
|---|---|---|
| `EchoCartographerSceneSnapshot` | width, height, knowledge (per cell), entry, markers, located (beacon cells), lastEcho, stage, failure, energy, budget, levelNumber, time | immutable; built from the adapter; holds no unknown wall and no unlocated beacon |
| `EchoCartographerPalette` | ground #05070A, floor #3A4A46, wallFace #12302A, wallEdge #3DF5C4, flare #B8FFF0, pulse #5FF7FF, entry #CFE3DD, marker #E8F1EE, pillar #5FF7FF, glow #9FFFF7, gaugeLit #3DF5C4, gaugeUnlit #1E2A2A | linear colours in 0 … 1 |
| `EchoCartographerTier` | level-0: rings, flare trails, 2 glow shells; level-1: rings, no trails, 1 shell; level-2: none | richest first; logged with reason on change |
| `EchoCartographerExperienceCore` | level number, play | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Mesh streams | ground, tiles, entry, markers, rays, rings, blocks (faces and edges), pillars, gauge: normal, uv = (material code, local coordinate); glow: colour in the normal slot, uv = (glow, 0) | rings and flares move by uniforms |
| Controls | `cell.pulse [x, y]`, `cell.claim [x, y]`, `cell.mark [x, y]`, `play.undo`, `play.redo`, `level.next`; cursor (column −/+, row −/+) | kernel refusals pass through with their codes; the cursor does not touch the kernel |
| Candidate registration | id `r02-g11.echo-cartographer`, tiers, palette, capabilities, content facts (100 levels, digest a32a593b…dca9), scenario manifest | `available: false` until X-R02-G11 |
