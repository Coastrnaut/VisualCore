# Data model: R02-G19-05

| Entity | Fields | Rules |
|---|---|---|
| `MicroscopicAuroraHintPlan` | actions (placements and removals) | the first is the hint; a shortest completion from the current wells within min(actions left, 2); empty when the current wells already win; nil when none fits the actions left or 1,200 sets were judged |
| `MicroscopicAuroraHint` | level 1 … 3, kind (place, remove, play, stuck), action, text | won: none; failed: undo or retry; never changes the state |
| `MicroscopicAuroraFailureExplanation` | failure, text | names the swimmer that left and the tick, the split tick with the largest group and the need, the lit and needed counts, or the cut-off cell |
| `MicroscopicAuroraTutorialStep` | place, cover, recover, done | advances after an accepted placement, after a second accepted action or the level's end, and at the level's end; levels 1 … 3 |
| `MicroscopicAuroraProgress` | best actions spent and stars per level, frontier | level 1 open; a campaign win opens the next |
| `MicroscopicAuroraMode` | campaign, practice, daily(level) | daily = (days since 2026-01-01 × 19) mod 100 + 1; practice budget 24 |
| Snapshot schema 2 | level, mode, progress, records, tutorial | migration from schema 1 |
