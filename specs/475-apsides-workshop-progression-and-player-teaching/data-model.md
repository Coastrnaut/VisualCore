# Data model: R02-G18-05

| Entity | Fields | Rules |
|---|---|---|
| `ApsidesWorkshopHintPlan` | tunings | the first is the hint; the minimal plan from the current orbit; empty when the current orbit already wins; nil when none fits the actions left or the work bound is exceeded |
| `ApsidesWorkshopHint` | level 1 … 3, kind (tune, play, stuck), action, text | won: none; failed: undo or retry; never changes the state |
| `ApsidesWorkshopFailureExplanation` | failure, text | names the planet struck and the tick, the target out of order and its tick, the target's share and band, or the apsis target's sector or distance and its range |
| `ApsidesWorkshopTutorialStep` | knob, order, recover, done | advances after an accepted tuning, after a second accepted tuning or the level's end, and at the level's end; levels 1 … 3 |
| `ApsidesWorkshopProgress` | best actions spent and stars per level, frontier | level 1 open; a campaign win opens the next |
| `ApsidesWorkshopMode` | campaign, practice, daily(level) | daily = (days since 2026-01-01 × 23) mod 100 + 1; practice budget 24 |
| Snapshot schema 2 | level, mode, progress, records, tutorial | migration from schema 1 |
