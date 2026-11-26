# Data model: R02-G19-02

| Entity | Fields | Rules |
|---|---|---|
| `MicroscopicAuroraLevel` (edit) | + sites (optional, 2 … 8 distinct usable cells, row-major); budget 1 … 24 | with sites, starting wells lie on sites; absent sites are omitted from the stored form |
| `MicroscopicAuroraManifestEntry` | number 1 … 100, planned seed, band 1 … 5, budget 8 … 19, emphasis | 100 entries in manifest order, 20 per band |
| `MicroscopicAuroraBandProfile` | swarm, lengths, sites, plan, stencil, coverage | band 1 (4 … 5, 120, 3, 1, 6 … 24, 600 … 800), 2 (5 … 6, 120 … 140, 4, 1, 10 … 32, 700 … 850), 3 (6 … 7, 140, 4, 2, 14 … 40, 750 … 900), 4 (7 … 8, 140 … 160, 5, 2, 18 … 50, 800 … 950), 5 (8, 160, 6, 2, 20 … 60, 850 … 1000) |
| `MicroscopicAuroraPlan` | actions (placements in slot order), wells (the winning set), sets at each smaller depth, nearest miss, work | the first winning set at the smallest depth; size = actions.count (the `play` is not counted) |
| `MicroscopicAuroraDifficulty` | witness length, stencil, coverage, swarm, sites, sets searched, work, nearest miss | from the level and the plan |
| `MicroscopicAuroraGenerated` | entry, level, plan, difficulty, skipped | skipped = the accepted candidate's index |
| `MicroscopicAuroraWitness` | schema 1, number, level (stored form), actions (+ `play`), state digests, fingerprints, terminal report, counterexample, difficulty, skipped | sorted-key JSON; re-checked on decode by replay |
