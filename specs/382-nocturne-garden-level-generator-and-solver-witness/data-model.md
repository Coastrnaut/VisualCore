# Data model: R02-G09-02

| Entity | Fields | Rules |
|---|---|---|
| `NocturneGardenManifestEntry` | number 1 … 100, seed (UInt64 from the archived hex), band 1 … 5, budget 8 … 19 | 100 entries, 20 per band, manifest order |
| `NocturneGardenBandProfile` | bed, sizes, elevations, blooms (range), ring, ring keep (fraction), required, leak allowance, decoy | band 1: 16 × 12, {2}, {2, 3}, 1 … 2, 1, 1/2, 4/5, 2, no; band 2: 20 × 14, {1, 2}, {2, 3}, 2 … 3, 1, 1/2, 17/20, 2, no; band 3: 24 × 16, {1, 2, 3}, {1 … 4}, 3 … 4, 2, 3/4, 9/10, 1, yes; band 4: 28 × 20, all, all, 4 … 5, 2, 3/4, 19/20, 1, yes; band 5: 32 × 24, all, all, 5 … 6, 2, 3/4, 1/1, 0, yes |
| `NocturneGardenSolution` | smallest, actions, work (plant evaluations) | smallest = the lower bound; the actions win on the last |
| `NocturneGardenBound` | elevation, needed, cover, sunMove | smallest = sunMove + ⌈needed / cover⌉ |
| `NocturneGardenDifficulty` | smallest, kinds, sizes, sunChange, targetCells, forbiddenCells, required, work | from the witness and the level |
| `NocturneGardenGenerated` | entry, level, solution, bound, difficulty, skipped | level id `nocturne-garden-NNN`; tutorial on 1 … 3; difficulty = band |
| `NocturneGardenCounterexample` | actions, shared, needed | the near miss (witness minus its last action): not won, shared < needed |
| `NocturneGardenWitness` | schema 1, number, level, actions, digests (one per action), fingerprints (after begin and each action), smallest, bound, near miss, difficulty, skipped | JSON with sorted keys; decode refuses newer, damaged and non-replaying files |
