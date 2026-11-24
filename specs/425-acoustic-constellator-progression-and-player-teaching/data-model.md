# Data model: R02-G13-05

| Entity | Fields | Rules |
|---|---|---|
| `AcousticConstellatorHintPlan` | actions | the first is the hint; the minimal plan's links (missing pairs, then helper links), its nudges, then the listen, from the current links and phases; nil when none fits the actions left or the work bound is exceeded |
| `AcousticConstellatorHint` | level 1 … 3, kind (linkSymbol, linkHelper, nudge, listen, stuck), action, text | won: none; failed: undo or retry; never changes the state |
| `AcousticConstellatorFailureExplanation` | failure, action index, text | names the action and the missing pair, the tick and snapped link, the longest run against the hold and window, or the move that spent the budget |
| `AcousticConstellatorTutorialStep` | link, complete, listen, done | advances after an accepted link, when no symbol pair is missing, or at the level's end; levels 1 … 3 |
| `AcousticConstellatorProgress` | best actions spent and stars per level, frontier | level 1 open; a campaign win opens the next |
| `AcousticConstellatorMode` | campaign, practice, daily(level) | daily = (days since 2026-01-01 × 89) mod 100 + 1; practice budget 40 |
| Snapshot schema 2 | level, mode, progress, records, tutorial | migration from schema 1 |
