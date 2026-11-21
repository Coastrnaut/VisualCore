# Data model: R02-G05-03

| Entity | Fields | Rules |
|---|---|---|
| `ColorfallCanyonsSceneSnapshot` | columns, rows, heights, grounds, springs (cell, colour, valve, supply left), basins (cell, shares, fill, capacity, protected), masses per cell, downhill per cell, stage, failure, tick, tick limit, actions left, levelNumber, time | immutable; built from the adapter; finite values |
| `ColorfallCanyonsPalette` | night #05070F, sandstone #8C5A3C, rock #3B302C, pearl #E8E4DA, cyan #19E3F0, coral #FF6F59, yellow #FFD23F; `fluid(masses)` = mass-weighted mix | linear colours in 0 … 1 |
| `ColorfallCanyonsPattern` | cyan stripes, coral dots, yellow chevrons | one per colour |
| `ColorfallCanyonsTier` | level-0: subdivision 4, 3 flow bands, 2 glow shells; level-1: 2, 2, 1; level-2: 1, 1, 0 | richest first; logged with reason on change |
| `ColorfallCanyonsExperienceCore` | level number, play | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Controls | `canyon.carve [0 … 119]`, `canyon.valve [0 … 2]`, `time.step [1 … 600]`, `play.undo`, `play.redo`, `level.next` | kernel refusals pass through with their codes |
| Candidate registration | id `r02-g05.colorfall-canyons`, tiers, palette, capabilities, content facts (100 levels, digest 68eec7b5…f019), scenario manifest | `available: false` until X-R02-G05 |
