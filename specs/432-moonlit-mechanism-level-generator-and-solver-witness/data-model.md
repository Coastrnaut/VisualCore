# Data model: R02-G14-02

| Entity | Fields | Rules |
|---|---|---|
| `MoonlitMechanismManifestEntry` | number 1 … 100, planned seed, band 1 … 5, budget 8 … 19 | 100 entries in manifest order, 20 per band |
| `MoonlitMechanismBandProfile` | gears, lamp heights, key frames, scramble, plan range | band 1: 2 … 3, 2 … 3, 2, 2 … 3, 1 … 2; band 2: 3, 3, 2 … 3, 3 … 4, 2 … 3; band 3: 3 … 4, 3 … 4, 3, 4 … 6, 3 … 4; band 4: 4, 4, 3 … 4, 5 … 7, 4 … 5; band 5: 4 … 5, 4 … 5, 4 … 5, 7 … 9, 5 … 6 |
| `MoonlitMechanismPlan` | turns t, lamp h, re-seats (one per gear, the driver's 0), smaller vectors tried, work | the first winning vector of the smallest norm; size = |t| + |h| + Σ|rᵢ| |
| `MoonlitMechanismDifficulty` | witness actions, gears, meshes, teeth, key frames, required key frames, target cells, forbidden cells, lamp heights, smaller vectors, work | |
| `MoonlitMechanismGenerated` | entry, level, plan, difficulty, skipped | skipped = the accepted candidate's index |
| `MoonlitMechanismWitness` | schema 1, number, level (stored form), actions, state digests, fingerprints, counterexample, difficulty, skipped | sorted-key JSON; re-checked on decode by replay |
