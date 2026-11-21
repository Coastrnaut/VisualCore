# Data model: R02-G02-05

| Entity | Fields | Rules |
|---|---|---|
| `LissajousLabyrinthHint` | level 1 … 3, dial, raise?, value?, remaining shortest, `withinActions` | level 2 adds the direction, level 3 the value; `withinActions` false → "No solution fits in the actions left; undo or retry" |
| `LissajousLabyrinthFailureExplanation` | verdict (contact obstacle/tick or missed checkpoint), text | equals the kernel's failure; p = ⌊100 · tick / 4,096⌋ |
| `LissajousLabyrinthTutorialStep` | `turn(dial)`, `checkpoints`, `hints`, `done` | turn → checkpoints on an accepted dial action, → hints on the next accepted action or a hint, → done on a win; dismiss → done; undo never moves it back; shown only on levels 1 … 3 in campaign mode, once per opening |
| `LissajousLabyrinthMode` | campaign, practice, daily(level) | practice: allowance 64, no stars, no unlocks; daily: campaign rules, no unlocks |
| `LissajousLabyrinthProgress` | solved: [level: (bestActions, stars)], frontier | level 1 open; a campaign win opens the next; a better result replaces a worse one |
| Snapshot schema 2 | level, records, progress, mode, tutorial | migration from schema 1: empty progress, campaign, tutorial first step on levels 1 … 3 |
