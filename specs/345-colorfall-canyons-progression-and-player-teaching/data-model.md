# Data model: R02-G05-05

| Entity | Fields | Rules |
|---|---|---|
| `ColorfallCanyonsHint` | level 1 … 3, kind (carve, valve, run, stuck), cell, spring, ticks, plan size, text | read only; reset after any play change; none when won |
| `ColorfallCanyonsFailureExplanation` | failure (contamination, overflow, time), basin, colour, amount, limit, tick, text | only when the play failed |
| `ColorfallCanyonsTutorialStep` | steer, run, fill, done | levels 1 … 3; steer → run when an edit was accepted and the plan is empty; run → fill on an accepted step; fill → done when the level ends; dismissible |
| `ColorfallCanyonsProgress` | per level best actions and stars; frontier | stars 3/2/1 by smallest / smallest + 2; campaign wins open the next |
| `ColorfallCanyonsMode` | campaign, practice, daily(level) | practice budget 30, no stars, no unlocks; daily opens nothing |
| Snapshot | schema 2 `{level, records, progress, mode, tutorial}` | migration from schema 1 |
