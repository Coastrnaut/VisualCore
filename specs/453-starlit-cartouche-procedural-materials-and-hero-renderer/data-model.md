# Data model: R02-G16-03

| Entity | Fields | Rules |
|---|---|---|
| `StarlitCartoucheSceneSnapshot` | stars (positions at the beat, glyph points, windows), corridors, hazards and active flags, legs (with departure and arrival positions), drawn strokes, symbol, ship star, beat, beacon, deadline, chosen destination, chosen wait, report, stage, failure, failedLeg (recomputed through the chart from the last record's action), actionsLeft, budget, levelNumber, time | immutable; built from the adapter |
| `StarlitCartouchePalette` | night #0A1240, nightTop #141E5C, speck #C9D2FF, pearl #F2EEE6, pearlShade #B8C0D8, corridor #3A4478, symbolDash #C9CCE0, trail #F5B83D, trailGlow #FFE3A0, ship #2F6BFF, shipGlow #8FB0FF, beacon #F2EEE6, chosen #2F6BFF, hazardActive #FF5A5F, hazardIdle #5A3A58, actionsLit #F5B83D, actionsUnlit #283058, beatTrack #8FB0FF, waitLit #2F6BFF, waitUnlit #283058, broken #FF6B4A, glow #FFF4E0 | linear colours in 0 … 1 |
| `StarlitCartoucheTier` | level-0: spheres 16 × 12, 3 trail ghosts, 2 glow shells; level-1: 12 × 8, 1 ghost, 1 shell; level-2: flat 12-sided discs, no ghosts, no glow | richest first; logged with reason on change |
| `StarlitCartoucheExperienceCore` | level number, play, chosen destination, chosen wait (reset at opening and after each leg to the other end of the lowest-index corridor from the ship's star, wait 0) | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| `StarlitCartoucheElement` | kind (corridor, hazard, trail, star, ship, beacon, gauge), index, world centre, camera distance | the paint order sorts by distance, farthest first, ties by kind then index (clarification Q1) |
| Mesh streams | backdrop, corridors, hazards, trails (and ghosts), stars (spheres or discs, rings, notches), ship, beacon and chosen rings, cartouche, bars, track, pips: normal, uv = (material code, local coordinate); glow: colour in the normal slot | rebuilt when the beat, the legs, the choice, the stage or the tier change |
| Controls | `route.fly [star, wait]`, `play.undo`, `play.redo`, `level.next`, `route.choose [star, wait]` | kernel refusals pass through with their codes; the choice does not touch the kernel |
| Candidate registration | id `r02-g16.starlit-cartouche`, tiers, palette, capabilities, content facts (100 levels, the pinned digest), scenario manifest | `available: false` until X-R02-G16 |
