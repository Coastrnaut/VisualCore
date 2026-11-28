# Data model: R02-G22-05

| Entity | Fields | Rules |
|---|---|---|
| `MyceliumArchitectHintPlan` | actions (nutrient, blocker, clear, seed, unseed) | the first is the hint; the witness's remaining actions while on its way, else a shortest winning completion within min(actions left, 2); empty when the current arrangement already wins; nil when none fits the actions left or 2,000 arrangements would be exceeded |
| `MyceliumArchitectHint` | level 1 … 3, kind (nutrient, blocker, clear, seed, unseed, run, stuck, retry), action, text | won, loading, tutorial, paused: none; failed: retry text; never changes the state; resets to level 1 after any change of the play |
| `MyceliumArchitectFailureExplanation` | failure, text | the level's failure words (toxic, starved, unreached, overweight), first letter capitalised, followed by ". Undo the last action or retry the level." |
| `MyceliumArchitectTutorialStep` | place, grow, recover, done | levels 1 … 3; place → grow after an accepted arrangement action; grow → recover after a second one or the level's end; any → done at the level's end; dismiss → done; undo, redo, growth.show never move it back |
| `MyceliumArchitectProgress` | best actions spent and stars per level, frontier 1 … 100 | level 1 open (a fresh opening of level N opens 1 … N); a campaign win opens the next; a better result replaces a worse, never the reverse; stars 1 … 3, actions ≥ 1 |
| `MyceliumArchitectMode` | campaign, practice, daily(level) | daily = (days since 2026-01-01 × 11) mod 100 + 1, years 1 … 9999, impossible dates refused `r02-g22.date`; practice budget 24, no stars, opens nothing |
| Snapshot schema 2 | level, mode, progress, records, tutorial (sorted keys) | migration from schema 1; damaged or out-of-range payloads throw the restore refusal; digest v2 over level, play fingerprint, progress, mode |
