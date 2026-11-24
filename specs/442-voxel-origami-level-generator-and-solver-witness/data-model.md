# Data model: R02-G15-02

| Entity | Fields | Rules |
|---|---|---|
| `VoxelOrigamiManifestEntry` | number 1 … 100, planned seed, band 1 … 5, budget 8 … 19, emphasis | 100 entries in manifest order, 20 per band |
| `VoxelOrigamiBandProfile` | cubes, scramble, plan range | band 1: 5 … 6, 2 … 4, 1 … 2; band 2: 6 … 7, 4 … 6, 2 … 3; band 3: 7 … 8, 6 … 9, 3 … 4; band 4: 8 … 9, 8 … 12, 4 … 5; band 5: 9 … 10, 10 … 14, 5 … 6 |
| `VoxelOrigamiPlan` | turns (the actions in order), states at each smaller depth, work | the first matching state's path at the smallest depth; size = turns.count |
| `VoxelOrigamiDifficulty` | witness turns, cubes, turnable hinges at the start, orientations, states searched, work | |
| `VoxelOrigamiGenerated` | entry, level, plan, difficulty, skipped | skipped = the accepted candidate's index |
| `VoxelOrigamiWitness` | schema 1, number, level (stored form), actions, state digests, fingerprints, counterexample, difficulty, skipped | sorted-key JSON; re-checked on decode by replay |
