# Data model: R02-G19-03

| Entity | Fields | Rules |
|---|---|---|
| `MicroscopicAuroraSceneSnapshot` | radius, positions and velocities by tick (predicted swim of the current wells), ticks swum, shown tick, density, lit cells (stencil and stray), stencil, sites, wells (3 slots), coverage and its requirement, smallest coherence and its requirement, swarm size, failure, stage, actionsLeft, budget, levelNumber, time | immutable; built from the adapter |
| `MicroscopicAuroraPalette` | abyss #04110F, abyssTop #0B2A26, field #0E2E2A, frond #2E6B5C, rim #6FB7A6, stencil #3E7F72, lit #7FE0C4, stray #2F6B5F, site #B58CE0, well #D2A8FF, ribbon #8FF0D6, swimmer #E9FFF8, met #B58CE0, unmet #E9FFF8, actionsLit #B58CE0, actionsUnlit #1E3A35, broken #FF6B5E, glow #F2FFFB | linear colours in 0 … 1 |
| `MicroscopicAuroraTier` | level-0: capsules of 12 segments, 64 ribbon ticks, fronds, 2 glow shells; level-1: 8 segments, 32 ticks, fronds, 1 shell; level-2: flat capsules, 16 ticks, no fronds, no glow | richest first; logged with reason on change |
| `MicroscopicAuroraExperienceCore` | level number, play, shown tick (0 at opening) | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Mesh streams | backdrop, field, fronds, rim, stencil, lit cells, sites, wells, ribbons, swimmers, gauges, bars: normal, uv = (material code, local coordinate); glow: colour in the normal slot | rebuilt when the wells, the shown tick, the stage or the tier change |
| Controls | `well.place [slot, row, column, strength, sense]`, `well.remove [slot]`, `swim.play`, `play.undo`, `play.redo`, `level.next`, `clock.show [tick]` | kernel refusals pass through with their codes; show does not touch the kernel |
| Candidate registration | id `r02-g19.microscopic-aurora`, tiers, palette, capabilities, content facts (100 levels, the pinned digest), scenario manifest | `available: false` until X-R02-G19 |
