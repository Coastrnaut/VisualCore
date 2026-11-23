# Data model: R02-G10-05

| Entity | Fields | Rules |
|---|---|---|
| `BackwardsAuroraPlan` | actions | the first is the hint; nil when no continuation within the reversals left |
| `BackwardsAuroraHint` | level 1 … 3, kind (reverse, stuck), action, text | won: none; failed: undo or retry; never changes the state |
| `BackwardsAuroraFailureExplanation` | failure, reversal, text | tear names the reversal, samples, seam, bend and B; budget names spent, checkpoints matched and worst bend against L |
| `BackwardsAuroraTutorialStep` | mark, reverse, finish, done | advances after an accepted reversal or at the level's end; levels 1 … 3 |
| `BackwardsAuroraProgress` | best reversals made and stars per level, frontier | level 1 open; a campaign win opens the next |
| `BackwardsAuroraMode` | campaign, practice, daily(level) | daily = (days since 2026-01-01 × 73) mod 100 + 1; practice budget 40 |
| Snapshot schema 2 | level, records, progress, mode, tutorial | migration from schema 1 |
