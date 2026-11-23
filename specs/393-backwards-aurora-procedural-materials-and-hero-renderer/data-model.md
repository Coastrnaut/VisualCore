# Data model: R02-G10-03

| Entity | Fields | Rules |
|---|---|---|
| `BackwardsAuroraSceneSnapshot` | samples, target, checkpoints, matched, bendLimit, kinks (positions with \|b\| > L, sorted), tear (seam or nil), section (start, end), stage, failure, spent, budget, levelNumber, time | immutable; built from the adapter; positions within the wave |
| `BackwardsAuroraPalette` | ground #070B1F, ribbon #1FC8D6, ribbonHighlight #9FF4FA, glow #6FE8F0, ghost #C9B8F0, ring #DCD3FA, matched #F4F0FF, kink #FF8A7A, tear #FF3B30, band #2A3570, spent #1FC8D6, unspent #2B3352 | linear colours in 0 … 1 |
| `BackwardsAuroraTier` | level-0: 3 trailing layers, 2 pulses, 2 glow shells; level-1: 2, 1, 1; level-2: 1, 0, 0 | richest first; logged with reason on change |
| `BackwardsAuroraExperienceCore` | level number, play | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Mesh streams | ground, ribbon and trailing layers, ghost, ticks, rings, discs, crosses, band, gauge: normal, uv = (material code, shade or position along the timeline); glow: colour in the normal slot, uv = (glow, 0) | pulses and shimmer move by uniforms |
| Controls | `wave.reverse [start, end]`, `play.undo`, `play.redo`, `level.next`; section pickers (start −/+, end −/+) | kernel refusals pass through with their codes; pickers do not touch the kernel |
| Candidate registration | id `r02-g10.backwards-aurora`, tiers, palette, capabilities, content facts (100 levels, digest 6eb242e6…d06e), scenario manifest | `available: false` until X-R02-G10 |
