# Data model: R02-G15-05

| Entity | Fields | Rules |
|---|---|---|
| `VoxelOrigamiHintPlan` | turns | the first is the hint; the minimal plan from the current turns; nil when none fits the actions left or the work bound is exceeded |
| `VoxelOrigamiHint` | level 1 … 3, kind (turn, stuck), action, text | won: none; failed: undo or retry; never changes the state |
| `VoxelOrigamiFailureExplanation` | failure, action index, text | names the action, the hinge and way, the moving and still cubes and the cell, or the action that spent the budget |
| `VoxelOrigamiTutorialStep` | turn, compare, recover, done | advances after an accepted turn, after a second accepted turn or the level's end, and at the level's end; levels 1 … 3 |
| `VoxelOrigamiProgress` | best actions spent and stars per level, frontier | level 1 open; a campaign win opens the next |
| `VoxelOrigamiMode` | campaign, practice, daily(level) | daily = (days since 2026-01-01 × 31) mod 100 + 1; practice budget 40 |
| Snapshot schema 2 | level, mode, progress, records, tutorial | migration from schema 1 |
