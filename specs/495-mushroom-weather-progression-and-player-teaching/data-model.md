# Data model: R02-G20-05

| Entity | Fields | Rules |
|---|---|---|
| `MushroomWeatherHintPlan` | actions (pod, vent and moonlight actions) | the first is the hint; the witness's remaining actions while on its way, else a shortest completion within min(actions left, 2); empty when the current arrangement already wins; nil when none fits the actions left or 1,500 arrangements were judged |
| `MushroomWeatherHint` | level 1 … 3, kind (pod, vent, moonlight, run, stuck), action, text | won: none; failed: undo or retry; never changes the state |
| `MushroomWeatherFailureExplanation` | failure, text | names the dried colony and its cycle, the mold cell and its cycle, or the unstable colony with its final run and the cycles required |
| `MushroomWeatherTutorialStep` | place, balance, recover, done | advances after an accepted placement, after a second accepted action or the level's end, and at the level's end; levels 1 … 3 |
| `MushroomWeatherProgress` | best actions spent and stars per level, frontier | level 1 open; a campaign win opens the next |
| `MushroomWeatherMode` | campaign, practice, daily(level) | daily = (days since 2026-01-01 × 17) mod 100 + 1; practice budget 24 |
| Snapshot schema 2 | level, mode, progress, records, tutorial | migration from schema 1 |
