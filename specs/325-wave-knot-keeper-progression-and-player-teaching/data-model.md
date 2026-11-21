# Data model: R02-G03-05

| Entity | Fields | Rules |
|---|---|---|
| `WaveKnotKeeperHint` | level 1 … 3, point, axis, direction?, remaining shortest, `withinMoves` | level 2 adds the axis, level 3 the direction; none when no solution within 3 moves or the moves left |
| `WaveKnotKeeperFailureExplanation` | summary (crossings, writhe, degenerate), target, text | equals the kernel's summary at failure |
| `WaveKnotKeeperTutorialStep` | `move(point)`, `signature`, `hints`, `done` | move → signature on an accepted move; signature → hints on the next accepted move or a hint; hints → done on a win; dismiss → done |
| `WaveKnotKeeperProgress` | solved [level: (bestMoves, stars)], frontier | stars 3 / 2 (≤ shortest + 2) / 1; campaign win opens the next |
| `WaveKnotKeeperMode` | campaign, practice, daily(level) | practice allowance 64, no stars; daily does not open levels |
| Snapshot | schema 2 `{level, records, progress, mode, tutorial}` | migration 1 → 2 |
