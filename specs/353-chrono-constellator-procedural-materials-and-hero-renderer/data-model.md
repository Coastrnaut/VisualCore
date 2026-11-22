# Data model: R02-G06-03

| Entity | Fields | Rules |
|---|---|---|
| `ChronoConstellatorSceneSnapshot` | columns, rows, stars (loop, target, current cell, the cells of its last 24 ticks oldest first), phases, holds, stage, failure, tick, tick limit, edits left, levelNumber, time | immutable; built from the adapter; finite values |
| `ChronoConstellatorPalette` | field #0B0A24, grid #1C1A44, silver #C9CED8, star #F2F4FF, rose #FF5C8A, amber #FFB020 | linear colours in 0 … 1 |
| `ChronoConstellatorShape` (kernel) | ring, cross, diamond, triangle, square | star i has shape i; drawn on the node and inside its target |
| `ChronoConstellatorTier` | level-0: ribbon 24 ticks, 4 segments, 2 glow shells; level-1: 12, 2, 1; level-2: 6, 1, 0 | richest first; logged with reason on change |
| `ChronoConstellatorExperienceCore` | level number, play | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Mesh streams | field and tracks: normal up, uv = (material code, shade); stars, rings, ribbons and marks: colour in the normal slot, uv = (age in ticks, glow), the glow program computing alpha 1 − age/R | shimmer is the uniform `u_time`; back faces culled |
| Controls | `star.phase [0 … 4, 0 … 31]`, `star.hold [0 … 4, 1 … 1,200, 1 … 60]`, `star.release [0 … 4, 1 … 1,200]`, `time.step [1 … 1,200]`, `time.rewind`, `play.undo`, `play.redo`, `level.next` | kernel refusals pass through with their codes |
| Candidate registration | id `r02-g06.chrono-constellator`, tiers, palette, capabilities, content facts (100 levels, digest 6483b20e…6ffc), scenario manifest | `available: false` until X-R02-G06 |
