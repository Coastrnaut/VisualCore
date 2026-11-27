# Data model: R02-G20-01

| Entity | Fields | Rules |
|---|---|---|
| `MushroomWeatherCell` | row, column (Int) | inside the grid; row-major order |
| `MushroomWeatherVent` | cell, open rate, closed rate (0 … 200) | on a floor cell; 0 … 6 per level |
| `MushroomWeatherColony` | cell, low, high, survival floor (nil unless sensitive) | 0 ≤ floor ≤ low ≤ high ≤ M; on a floor cell; 1 … 6 |
| `MushroomWeatherPodRules` | slots P 1 … 6, release r 1 … 40, grown release g r … 80, growth threshold G 100 … 200000 | integers |
| `MushroomWeatherArrangement` | pods (P slots, cell or nil), vents open (Bool per vent), moonlight L 0 … 3 | pods on free floor cells, never two on one cell |
| `MushroomWeatherLevel` | id, seed, difficulty 1 … 5, rows 6 … 12, columns 6 … 14, blocked cells, starting humidity (0 … M per floor cell), diffusion D 1 … 12, evaporation rate per cell (0 … 200), vents, pod rules, colonies, mold bound M 1000 … 10000, run length T 20 … 200, required cycles K 5 … T, starting arrangement, budget 1 … 12, tutorial, fingerprint | sensitive colonies start at or above their floor; no cell starts above M; the starting arrangement does not win; schema 1; sorted-key JSON |
| `MushroomWeatherLedger` | cycle, before, released, evaporated, after | after = before + released − evaporated |
| `MushroomWeatherReport` | cycles run, final humidity, ledger by cycle, growth cycle per pod, per colony: final run, longest run, first cycle out of band; failure; outcome | exact; never decides by itself |
| `MushroomWeatherAction` | place(slot, cell), remove(slot), vent(index, open), moonlight(level), run | arrangement actions spend 1 action; run spends none and ends the level |
| `MushroomWeatherFailure` | dried(colony, cycle), mold(cell, cycle), unstable(colony, run) | codes `dried`, `mold`, `unstable` |
| `MushroomWeatherPlay` | stage, arrangement, actions spent, report, failure, records, undo/redo stacks | records carry previous and next fingerprints |
| `MushroomWeatherRecord` | schema, level seed, index, kind (place, remove, vent, moonlight, run, undo, redo, begin, dismissTutorial, pause, resume), action, previous and next fingerprints | appended for every accepted action and event |
| `MushroomWeatherPuzzle.Position` | arrangement, actions spent | moves: every legal arrangement action; goal: the predicted run wins |
