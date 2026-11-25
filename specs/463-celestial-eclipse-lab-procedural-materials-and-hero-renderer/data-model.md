# Data model: R02-G17-03

| Entity | Fields | Rules |
|---|---|---|
| `CelestialEclipseLabSceneSnapshot` | bodies (orbit, radius, fixed), positions at the shown tick for the current phases, phases, eclipses under way at the shown tick (front, back, class), target with windows, predicted intervals, matched, failure, shown tick, horizon, chosen body, stage, actionsLeft, budget, levelNumber, time | immutable; built from the adapter |
| `CelestialEclipseLabPalette` | ink #0B1530, inkTop #16224A, speck #C9D2FF, disc #E9E1CF, discShade #7A829A, orbit #33406E, fixedFrame #8A93B0, chosen #F2C14E, corona #F2C14E, coronaGlow #FFE7A3, crescentShadow #050A18, ember #C8553D, window #E8E2D0, matched #F2C14E, unwanted #C8553D, faintEvent #5A6488, playhead #FFE7A3, actionsLit #F2C14E, actionsUnlit #24305A, broken #E0533A, glow #FFF1D0 | linear colours in 0 … 1 |
| `CelestialEclipseLabTier` | level-0: spheres 24 × 16, 2 glow shells; level-1: 16 × 12, 1 shell; level-2: flat 20-sided discs, no glow | richest first; logged with reason on change |
| `CelestialEclipseLabExperienceCore` | level number, play, chosen body (the lowest-numbered movable body at opening), shown tick (0 at opening) | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| `CelestialEclipseLabElement` | kind (ring, body, halo, gauge), index, world centre, camera distance | the paint order sorts by distance, farthest first, ties by kind then index |
| Mesh streams | backdrop, rings (notches, frames), bodies (spheres or discs, with up to 5 nearer circles for the mask), halos, chosen ring, timeline (strip, brackets, marks, playhead), bars: normal, uv = (material code, local coordinate); glow: colour in the normal slot | rebuilt when the phases, the shown tick, the choice, the stage or the tier change |
| Controls | `orbit.phase [body, offset]`, `clock.run`, `play.undo`, `play.redo`, `level.next`, `orbit.choose [body]`, `clock.show [tick]` | kernel refusals pass through with their codes; choose and show do not touch the kernel |
| Candidate registration | id `r02-g17.celestial-eclipse-lab`, tiers, palette, capabilities, content facts (100 levels, the pinned digest), scenario manifest | `available: false` until X-R02-G17 |
