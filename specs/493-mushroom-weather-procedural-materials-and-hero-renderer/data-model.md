# Data model: R02-G20-03

| Entity | Fields | Rules |
|---|---|---|
| `MushroomWeatherSceneSnapshot` | rows, columns, blocked cells, humidity fields by cycle (predicted run of the current arrangement), cycles run, shown cycle, mold bound, colonies (cell, band, floor, final run, longest run, in band at the shown cycle), required cycles, pods (cell, growth cycle), sites, vents (cell, open), moonlight, failure, stage, actionsLeft, budget, levelNumber, time | immutable; built from the adapter |
| `MushroomWeatherPalette` | midnight #050A1A, midnightTop #0E1A33, moon #E8EEF7, moss #12261C, log #2A2118, frond #1F4A33, mistLow #0B1E4A, mistHigh #3A6FD8, site #C9A15A, stalk #D8E6D0, cap #5FD3A0, capOut #3F6E5A, pod #F2A93B, droplet #FFC861, vent #6E8B7A, band #9FF5C8, marker #F2A93B, actionsLit #F2A93B, actionsUnlit #1A2A3A, broken #FF6B5E, glow #F7FFF9 | linear colours in 0 … 1 |
| `MushroomWeatherTier` | level-0: lathes of 16 segments, 12 droplets per pod, fronds, 8 motes, 2 glow shells; level-1: 10 segments, 6 droplets, fronds, 4 motes, 1 shell; level-2: flat caps and pods, no droplets, fronds, motes or glow | richest first; logged with reason on change |
| `MushroomWeatherExperienceCore` | level number, play, shown cycle (0 at opening) | digest = level number + play fingerprint (domain `r02-g20.mushroom-weather.v1`); snapshot schema 1 `{level, records}` |
| Mesh streams | backdrop, moon, floor, blocked, fronds, mist, sites, stalks, caps, pods, droplets, vents, gauges, bars: normal, uv = (material code, local coordinate); glow: colour in the normal slot | rebuilt when the arrangement, the shown cycle, the stage or the tier change |
| Controls | `pod.place [slot, row, column]`, `pod.remove [slot]`, `vent.set [index, open]`, `moon.set [level]`, `weather.run`, `play.undo`, `play.redo`, `level.next`, `clock.show [cycle]` | kernel refusals pass through with their codes; show does not touch the kernel |
| Candidate registration | id `r02-g20.mushroom-weather`, tiers, palette, capabilities, content facts (100 levels, the pinned digest), scenario manifest | `available: false` until X-R02-G20 |
