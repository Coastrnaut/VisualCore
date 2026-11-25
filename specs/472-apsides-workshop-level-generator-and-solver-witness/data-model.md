# Data model: R02-G18-02

| Entity | Fields | Rules |
|---|---|---|
| `ApsidesWorkshopManifestEntry` | number 1 … 100, planned seed, band 1 … 5, budget 8 … 19, emphasis | 100 entries in manifest order, 20 per band |
| `ApsidesWorkshopBandProfile` | periods, targets, apsis targets, sweep half-width, apsis half-width, planets, levers, plan range | band 1 ({24}, 1 … 2, 0, 60 … 90, 40 … 60, 0, 1, 1), 2 ({24, 32}, 2, 0 … 1, 45 … 70, 40 … 60, 0 … 1, 1, 1), 3 ({32}, 2 … 3, 1, 35 … 55, 25 … 45, 1, 1 … 2, 1 … 2), 4 ({32, 48}, 3, 1, 25 … 40, 20 … 35, 1 … 2, 2, 2), 5 ({48}, 3 … 4, 1 … 2, 18 … 30, 15 … 25, 2 … 3, 2, 2) |
| `ApsidesWorkshopPlan` | actions (tunings in a valid order), orbit (the winning one), orbits at each smaller depth, work | the first winning orbit at the smallest depth; size = actions.count (the `play` is not counted) |
| `ApsidesWorkshopDifficulty` | witness length, targets, apsis targets, planets, narrowest share band, narrowest distance range, orbits searched, work | 0 for a band or range the level does not have |
| `ApsidesWorkshopGenerated` | entry, level, plan, difficulty, skipped | skipped = the accepted candidate's index |
| `ApsidesWorkshopWitness` | schema 1, number, level (stored form), actions (+ `play`), state digests, fingerprints, terminal report, counterexample, difficulty, skipped | sorted-key JSON; re-checked on decode by replay |
