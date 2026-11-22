# Data model: R02-G07-03

| Entity | Fields | Rules |
|---|---|---|
| `AmethystEscapeSceneSnapshot` | sectors, shells (apertures, walls, blocked, offset), pearl pocket, exit gap, stage, failure, moves, budget, levelNumber, time | immutable; built from the adapter; finite values |
| `AmethystEscapePalette` | backdrop #0A0614, amethyst #8E4FD8, highlight #E3CCFF, platinum #D6DCE6, blocked #1E1426, pearl #F6F2FF, exit #B8F0FF, amber #FFB020 | linear colours in 0 … 1 |
| `AmethystEscapeTier` | level-0: 3 bevel segments, 3 highlight layers, 2 glow shells; level-1: 2, 2, 1; level-2: 1, 1, 0 | richest first; logged with reason on change |
| `AmethystEscapeExperienceCore` | level number, play | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Mesh streams | backdrop, wedges, fins and marks: normal, uv = (material code, shade); pearl and exit glow: colour in the normal slot, uv = (glow, 0) | highlights move by the uniform `u_time`; back faces culled except translucent facets |
| Controls | `shell.rotate [0 … shells − 1, −1 or +1]`, `pearl.advance`, `play.undo`, `play.redo`, `level.next` | kernel refusals pass through with their codes |
| Candidate registration | id `r02-g07.amethyst-escape`, tiers, palette, capabilities, content facts (100 levels, digest e65c4529…94e6), scenario manifest | `available: false` until X-R02-G07 |
