# Data model: R02-G02-03

| Entity | Fields | Rules |
|---|---|---|
| `LissajousLabyrinthSceneSnapshot` | dials, level geometry, stage, verdict, visit ticks, time | immutable; read-only for the renderer |
| `LissajousLabyrinthTier` | index 0 … 2, stride 1/2/4, glow passes 2/1/0, trail 512/256/128 | richest first |
| `LissajousLabyrinthPalette` | night #070B1E, cobalt #2F5BD8, violet #8A4FE0, copper #D9824A | fixed |
| `LissajousLabyrinthExperienceCore` | level number, play, opening | digest: level + play fingerprint; schema 1 `{level, records}` |
| Registration | id, tiers, palette, capabilities, content facts, manifest | candidate, `available: false` |
