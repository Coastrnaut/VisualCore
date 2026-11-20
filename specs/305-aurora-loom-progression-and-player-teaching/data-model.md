# Data model: R02-G01-05

| Entity | Fields | Rules |
|---|---|---|
| `AuroraLoomHint` | level 1 … 3, ribbon, control?, step?, remaining shortest, `withinMoves` | level 2 adds control, level 3 adds step |
| `AuroraLoomFailureExplanation` | ribbon, gate, tick, residual, text | equals the kernel's failure |
| `AuroraLoomTutorialStep` | `wave(ribbon)`, `phase(ribbon)`, `harmony`, `done` | advances on a wave move, a phase move, a win; dismiss → done |
| `AuroraLoomMode` | campaign, practice, daily(level) | practice: allowance 64, no stars, no unlocks |
| `AuroraLoomProgress` | solved: [level: (bestMoves, stars)], open frontier | level 1 open; winning in campaign opens the next |
| Snapshot schema 2 | level, records, progress, mode, tutorial | migration from schema 1 |
