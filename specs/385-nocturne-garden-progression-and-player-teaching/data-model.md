# Data model: R02-G09-05

| Entity | Fields | Rules |
|---|---|---|
| `NocturneGardenPlan` | actions (the first is the hint) | nil when no continuation within the moves and supply left |
| `NocturneGardenHint` | level 1 … 3, kind (move, stuck), action, text | won: none; failed: stuck "Undo the last move or retry the level." |
| `NocturneGardenFailureExplanation` | failure (leak(move) or budget), move, text | text names the move and cells, or the moves and match |
| `NocturneGardenTutorialStep` | plant, shape, finish, done | advances after an accepted move, a second accepted move, the end |
| `NocturneGardenProgress` | best moves made and stars per level, frontier | stars 3 ≤ smallest, 2 ≤ smallest + 2, else 1; better replaces worse |
| `NocturneGardenMode` | campaign, practice, daily(level) | practice budget 40, no stars or unlocks; daily does not unlock |
| Snapshot schema 2 | level, records, progress, mode, tutorial | migration from 1: level 1 and the restored level open, campaign, tutorial step 1 on tutorial levels |
