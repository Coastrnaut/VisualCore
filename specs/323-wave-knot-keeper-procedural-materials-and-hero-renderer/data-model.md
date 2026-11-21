# Data model: R02-G03-03

| Entity | Fields | Rules |
|---|---|---|
| `WaveKnotKeeperSceneSnapshot` | points, gates, target, summary (crossings, writhe, degenerate), crossings (segment pair, over-strand segment, projected point), stage, selected point, time, levelNumber | immutable; built from the adapter; finite values |
| `WaveKnotKeeperPalette` | night #05070F, pearl #E8E4DA, sapphire #2F6FD8, ember #E0703A | linear colours in 0 … 1 |
| `WaveKnotKeeperTier` | level-0: 16 sides, 8 corner samples, 2 glow shells; level-1: 10, 4, 1; level-2: 6, 2, 0 | richest first; logged with reason on change |
| `WaveKnotKeeperExperienceCore` | level number, play | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Controls | `point.move [0…15, 0…5]`, `point.select [0…15]`, `play.undo`, `play.redo`, `level.next` | kernel refusals pass through with their codes |
| Candidate registration | id `r02-g03.wave-knot-keeper`, tiers, palette, capabilities, content facts (100 levels, digest 12c8ecb8…933f), scenario manifest | `available: false` until X-R02-G03 |
