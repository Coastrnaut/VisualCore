# Data model: R02-G04-05

| Entity | Fields | Rules |
|---|---|---|
| `HueCompassHint` | level 1 … 3, kind (probe, select, guess), bearing, band, consistent count, text | read only; reset after any play change |
| `HueCompassFailureExplanation` | failure (selection, probes), target, band, bearing distance, band distance, tolerances, text | only when the play failed |
| `HueCompassTutorialStep` | aim, probe, select, done | levels 1 … 3; advances on an accepted turn, probe, end; dismissible |
| `HueCompassProgress` | per level best units and stars; frontier | stars 3/2/1 by smallest + 1 / + 2; campaign wins open the next |
| `HueCompassMode` | campaign, practice, daily(level) | practice allowance 24, no stars, no unlocks; daily opens nothing |
| Snapshot | schema 2 `{level, records, progress, mode, tutorial}` | migration from schema 1 |
