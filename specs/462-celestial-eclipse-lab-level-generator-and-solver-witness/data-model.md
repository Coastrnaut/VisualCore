# Data model: R02-G17-02

| Entity | Fields | Rules |
|---|---|---|
| `CelestialEclipseLabManifestEntry` | number 1 … 100, planned seed, band 1 … 5, budget 8 … 19, emphasis | 100 entries in manifest order, 20 per band |
| `CelestialEclipseLabBandProfile` | bodies, targets, horizon, moved, plan range | band 1 (3, 1 … 2, 24 … 32, 2, 1 … 2), 2 (3 … 4, 2 … 3, 28 … 36, 3, 2 … 3), 3 (4 … 5, 2 … 3, 32 … 40, 4, 3 … 4), 4 (5 … 6, 3 … 4, 36 … 44, 4, 3 … 4), 5 (6, 3 … 4, 40 … 48, 5, 4 … 5) |
| `CelestialEclipseLabPlan` | actions (phase changes in body order), settings at each smaller depth, work | the first winning setting at the smallest depth; size = actions.count (the `run` is not counted) |
| `CelestialEclipseLabDifficulty` | witness length, bodies, movable, targets, events, settings searched, work | |
| `CelestialEclipseLabGenerated` | entry, level, plan, difficulty, skipped | skipped = the accepted candidate's index |
| `CelestialEclipseLabWitness` | schema 1, number, level (stored form), actions (+ `run`), state digests, fingerprints, terminal timeline, counterexample, difficulty, skipped | sorted-key JSON; re-checked on decode by replay |
