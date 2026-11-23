# Data model: R02-G12-05

| Entity | Fields | Rules |
|---|---|---|
| `HarmonicBridgesHintPlan` | actions | the first is the hint; the minimal plan's tunings from the current pegs, then the test; nil when none fits the actions left or the work bound is exceeded |
| `HarmonicBridgesHint` | level 1 … 3, kind (tune, test, stuck), action, text | won: none; failed: undo or retry; never changes the state |
| `HarmonicBridgesFailureExplanation` | failure, action index, text | names the action (the test, or the tuning or test that spent the last move), the broken step and string, the steps that held of n |
| `HarmonicBridgesTutorialStep` | tune, bridge, test, done | advances after an accepted tuning, when the pegs bridge every step, or at the level's end; levels 1 … 3 |
| `HarmonicBridgesProgress` | best actions spent and stars per level, frontier | level 1 open; a campaign win opens the next |
| `HarmonicBridgesMode` | campaign, practice, daily(level) | daily = (days since 2026-01-01 × 83) mod 100 + 1; practice budget 60 |
| Snapshot schema 2 | level, mode, progress, records, tutorial | migration from schema 1 |
