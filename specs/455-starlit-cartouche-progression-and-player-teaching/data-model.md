# Data model: R02-G16-05

| Entity | Fields | Rules |
|---|---|---|
| `StarlitCartoucheHintPlan` | legs | the first is the hint; the minimal plan from the current star, beat and drawn strokes; nil when none fits the actions left or the work bound is exceeded |
| `StarlitCartoucheHint` | level 1 … 3, kind (leg, stuck), action, text | won: none; failed: undo or retry; never changes the state |
| `StarlitCartoucheFailureExplanation` | failure, action index, text | names the action, its destination and wait, and the star and window, hazard and beats, deadline, stray corridor, or the action that spent the budget |
| `StarlitCartoucheTutorialStep` | fly, symbol, recover, done | advances after an accepted leg, after a second accepted leg or the level's end, and at the level's end; levels 1 … 3 |
| `StarlitCartoucheProgress` | best actions spent and stars per level, frontier | level 1 open; a campaign win opens the next |
| `StarlitCartoucheMode` | campaign, practice, daily(level) | daily = (days since 2026-01-01 × 37) mod 100 + 1; practice budget 24 |
| Snapshot schema 2 | level, mode, progress, records, tutorial | migration from schema 1 |
