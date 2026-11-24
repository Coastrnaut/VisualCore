# Data model: R02-G16-02

| Entity | Fields | Rules |
|---|---|---|
| `StarlitCartoucheManifestEntry` | number 1 … 100, planned seed, band 1 … 5, budget 8 … 19, emphasis | 100 entries in manifest order, 20 per band |
| `StarlitCartoucheBandProfile` | stars, route legs, decoys, plan range | band b: stars b + 4 … b + 5, route b + 1 … b + 2, decoys b + 1, plan range b + 1 … b + 2 |
| `StarlitCartouchePlan` | legs (the actions in order), states at each smaller depth, work | the first winning leg's path at the smallest depth; size = legs.count |
| `StarlitCartoucheDifficulty` | witness legs, stars, corridors, hazards, strokes, states searched, work | |
| `StarlitCartoucheGenerated` | entry, level, plan, difficulty, skipped | skipped = the accepted candidate's index |
| `StarlitCartoucheWitness` | schema 1, number, level (stored form), actions, state digests, fingerprints, counterexample, difficulty, skipped | sorted-key JSON; re-checked on decode by replay |
