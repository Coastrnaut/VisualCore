# Data model: R02-G14-05

| Entity | Fields | Rules |
|---|---|---|
| `MoonlitMechanismHintPlan` | actions | the first is the hint; the minimal plan's turns, re-seats in gear order, lamp steps, then the run, from the current phases and lamp height; nil when none fits the actions left or the work bound is exceeded |
| `MoonlitMechanismHint` | level 1 … 3, kind (turn, reseat, lamp, run, stuck), action, text | won: none; failed: undo or retry; never changes the state |
| `MoonlitMechanismFailureExplanation` | failure, action index, text | names the action and the jammed gear and parent, the key frame and forbidden cell, the key frame and missing or stray count, or the action that spent the budget |
| `MoonlitMechanismTutorialStep` | change, align, run, done | advances after an accepted turn, re-seat or lamp step, when the run report of the current set-up wins, or at the level's end; levels 1 … 3 |
| `MoonlitMechanismProgress` | best actions spent and stars per level, frontier | level 1 open; a campaign win opens the next |
| `MoonlitMechanismMode` | campaign, practice, daily(level) | daily = (days since 2026-01-01 × 97) mod 100 + 1; practice budget 40 |
| Snapshot schema 2 | level, mode, progress, records, tutorial | migration from schema 1 |
