# Data model: R02-G04-03

| Entity | Fields | Rules |
|---|---|---|
| `HueCompassSceneSnapshot` | bearing, offset, fog (96), bearing and band tolerances, clues, selection, stage, target (nil while playing), time, levelNumber | immutable; built from the adapter; finite values |
| `HueCompassPalette` | night #05070F, pearl #E8E4DA, sapphire #2F6FD8, ember #E0703A; `band(h)` = hue h/24, s 0.85, v 1.0 | linear colours in 0 … 1 |
| `HueCompassGlyph` | shape (h mod 4: dot, bar, triangle, ring), marks ⌊h/4⌋ + 1 | unique for each of the 24 bands |
| `HueCompassTier` | level-0: 12 facets, 3 fog layers, 2 glow shells; level-1: 8, 2, 1; level-2: 4, 1, 0 | richest first; logged with reason on change |
| `HueCompassExperienceCore` | level number, play | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Controls | `compass.turn [−48 … 48, not 0]`, `compass.probe`, `compass.select [0 … 95, 0 … 23]`, `play.undo`, `play.redo`, `level.next` | kernel refusals pass through with their codes |
| Candidate registration | id `r02-g04.hue-compass`, tiers, palette, capabilities, content facts (100 levels, digest fcb10a90…8b15), scenario manifest | `available: false` until X-R02-G04 |
