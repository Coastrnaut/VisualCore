# Data model: R02-G17-05

| Entity | Fields | Rules |
|---|---|---|
| `CelestialEclipseLabHintPlan` | changes | the first is the hint; the minimal plan from the current phases; empty when the current phases already win; nil when none fits the actions left or the work bound is exceeded |
| `CelestialEclipseLabHint` | level 1 … 3, kind (change, run, stuck), action, text | won: none; failed: undo or retry; never changes the state |
| `CelestialEclipseLabFailureExplanation` | failure, text | names the unwanted eclipse's planets and tick and the target it came before, the target's tick and window, or the horizon and the target left |
| `CelestialEclipseLabTutorialStep` | phase, order, recover, done | advances after an accepted phase change, after a second accepted phase change or the level's end, and at the level's end; levels 1 … 3 |
| `CelestialEclipseLabProgress` | best actions spent and stars per level, frontier | level 1 open; a campaign win opens the next |
| `CelestialEclipseLabMode` | campaign, practice, daily(level) | daily = (days since 2026-01-01 × 29) mod 100 + 1; practice budget 24 |
| Snapshot schema 2 | level, mode, progress, records, tutorial | migration from schema 1 |
