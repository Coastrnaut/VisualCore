# Data model: R02-G18-03

| Entity | Fields | Rules |
|---|---|---|
| `ApsidesWorkshopSceneSnapshot` | orbit (size, eccentricity, direction steps), positions (current orbit, sky units), ghost positions (starting orbit), orbiter (position at the shown tick), shares, periapsis and apoapsis sector and distance, planets, targets with bands, readings, deviations and met flags, failure, shown tick, period, stage, actionsLeft, budget, levelNumber, time | immutable; built from the adapter |
| `ApsidesWorkshopPalette` | midnight #0A0B1F, midnightTop #1A1438, speck #D8E4FF, wedge #2A2350, targetWedge #6B2346, compass #3A3F6B, ghost #5B6390, glacial #E8F1FF, deepRose #C2456E, planet #8C93B8, hazard #C2456E, star #FFF4D6, met #C2456E, unmet #E8F1FF, actionsLit #C2456E, actionsUnlit #262A4E, broken #E0533A, glow #F4F8FF | linear colours in 0 … 1 |
| `ApsidesWorkshopTier` | level-0: spheres 24 × 16, 4 refinement points per tick, 2 glow shells; level-1: 16 × 12, 2 points, 1 shell; level-2: flat 20-sided discs, chords only, no glow | richest first; logged with reason on change |
| `ApsidesWorkshopExperienceCore` | level number, play, shown tick (0 at opening) | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Mesh streams | backdrop, wedges, compass (spokes, rim, notches, brackets), ghost loop, orbit loop, apsis markers, planets (spheres or discs, hazard rings), star, orbiter, gauges (tracks, bands, marks), bars: normal, uv = (material code, local coordinate); glow: colour in the normal slot | rebuilt when the orbit, the shown tick, the stage or the tier change |
| Controls | `orbit.periapsis [k, d]`, `orbit.size [a]`, `orbit.play`, `play.undo`, `play.redo`, `level.next`, `clock.show [tick]` | kernel refusals pass through with their codes; show does not touch the kernel |
| Candidate registration | id `r02-g18.apsides-workshop`, tiers, palette, capabilities, content facts (100 levels, the pinned digest), scenario manifest | `available: false` until X-R02-G18 |
