# Data model: R02-G21-05

| Entity | Fields | Rules |
|---|---|---|
| `BinaryGardensHintPlan` | actions (ring, phase, luminosity and tilt actions) | the first is the hint; the witness's remaining actions while on its way, else a shortest winning completion within min(actions left, 2); empty when the current arrangement already wins; nil when none fits the actions left or 2,000 arrangements would be exceeded |
| `BinaryGardensHint` | level 1 … 3, kind (ring, phase, luminosity, tilt, run, stuck, retry), action, text | won, loading, tutorial, paused: none; failed: retry text; never changes the state; resets to level 1 after any change of the play |
| `BinaryGardensFailureExplanation` | failure, text | frozen or scorched world and tick (E = 0 wording), unstable world with its window and the ticks required (w = 0 wording), wilted or bleached world with its total and bloom band; followed by "Undo the last action or retry the level." |
| `BinaryGardensTutorialStep` | adjust, balance, recover, done | levels 1 … 3; adjust → balance after an accepted arrangement action; balance → recover after a second one or the level's end; any → done at the level's end; dismiss → done; undo, redo, clock.show never move it back |
| `BinaryGardensProgress` | best actions spent and stars per level, frontier 1 … 100 | level 1 open; a campaign win opens the next; a better result replaces a worse, never the reverse; stars 1 … 3, actions ≥ 1 |
| `BinaryGardensMode` | campaign, practice, daily(level) | daily = (days since 2026-01-01 × 13) mod 100 + 1, years 1 … 9999, impossible dates refused `r02-g21.date`; practice budget 24, no stars, opens nothing |
| Snapshot schema 2 | level, mode, progress, records, tutorial (sorted keys) | migration from schema 1; damaged or out-of-range payloads throw the restore refusal; digest v2 over level, play fingerprint, progress, mode |
