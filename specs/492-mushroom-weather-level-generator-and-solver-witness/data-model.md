# Data model: R02-G20-02

| Entity | Fields | Rules |
|---|---|---|
| `MushroomWeatherLevel` (edit) | + sites (optional, 2 … 8 distinct floor cells without a colony, row-major); budget 1 … 24 | with sites, starting pods stand on sites; absent sites are omitted from the stored form |
| `MushroomWeatherManifestEntry` | number 1 … 100, planned seed, band 1 … 5, budget 8 … 19, emphasis | 100 entries in manifest order, 20 per band |
| `MushroomWeatherBandProfile` | rows, columns, blocked, vents, slots, colonies, sites, plan, margin | band 1 (6 … 7, 6 … 7, 2 … 5, 1, 2, 2, 4, 2, 4 … 6), 2 (6 … 8, 6 … 8, 3 … 6, 2, 2, 3, 4, 3, 3 … 5), 3 (7 … 8, 7 … 9, 3 … 7, 2, 3, 3, 5, 3, 2 … 4), 4 (7 … 9, 8 … 10, 4 … 8, 3, 3, 4, 6, 4, 1 … 3), 5 (8 … 9, 8 … 10, 4 … 8, 3, 4, 5, 6, 5, 1 … 2) |
| `MushroomWeatherPlan` | actions (placements in slot order, vent toggles, moonlight), arrangement (the winning one), arrangements at each smaller depth, nearest miss, work | the first winning arrangement at the smallest depth; size = actions.count (`run` not counted) |
| `MushroomWeatherDifficulty` | witness length, colonies, narrowest band, sites, vents, arrangements searched, work, nearest miss | from the level and the plan |
| `MushroomWeatherGenerated` | entry, level, plan, difficulty, skipped | skipped = the accepted candidate's index |
| `MushroomWeatherWitness` | schema 1, number, level (stored form), actions (+ `run`), state digests, fingerprints, terminal report (ledger totals, colony runs, cycles run), counterexample, difficulty, skipped | sorted-key JSON; re-checked on decode by replay |
