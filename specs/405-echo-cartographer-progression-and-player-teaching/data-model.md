# Data model: R02-G11-05

| Entity | Fields | Rules |
|---|---|---|
| `EchoCartographerHintPlan` | actions | the first is the hint; pulses until one placement fits, then claims; nil when none within the energy left |
| `EchoCartographerHint` | level 1 … 3, kind (pulse, claim, stuck), action, text | won: none; failed: undo or retry; never changes the state |
| `EchoCartographerFailureExplanation` | failure, action index, text | names the action (pulse or missed claim and its cell), beacons located of n, pulses, missed claims |
| `EchoCartographerTutorialStep` | pulse, narrow, claim, done | advances after an accepted pulse, a located beacon or at the level's end; levels 1 … 3 |
| `EchoCartographerProgress` | best energy spent and stars per level, frontier | level 1 open; a campaign win opens the next |
| `EchoCartographerMode` | campaign, practice, daily(level) | daily = (days since 2026-01-01 × 79) mod 100 + 1; practice energy 60 |
| Snapshot schema 2 | level, records, progress, mode, tutorial | migration from schema 1 |
