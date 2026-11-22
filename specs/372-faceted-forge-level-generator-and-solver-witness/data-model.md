# Data model: R02-G08-02

| Entity | Fields | Rules |
|---|---|---|
| `FacetedForgeManifestEntry` | number 1 … 100, seed (UInt64 from the archived hex), band 1 … 5, budget 8 … 19 | 100 entries, 20 per band, manifest order |
| `FacetedForgeBandProfile` | crystal shape, cuts (range), directions | band 1 cube, 2 … 3 cuts, axes and face diagonals; 2 box, 3 … 4; 3 truncated cube, 4 … 5, all 13; 4 octahedron, 5 … 6; 5 doubly truncated cube, 6 … 7 |
| `FacetedForgeSolution` | smallest, actions, work (cut evaluations) | smallest = target pieces − 1; the actions win on the last |
| `FacetedForgeDifficulty` | smallest, directions (distinct), diagonals, crystal faces, pieces, work | pieces = smallest + 1 |
| `FacetedForgeGenerated` | entry, level, solution, difficulty, skipped | level id `faceted-forge-NNN`; tutorial on 1 … 3; difficulty = band; sliver 1/64 |
| `FacetedForgeCounterexample` | actions, outcome (`open` not won yet, `sliver`, `budget`), cut | the near miss (witness minus its last cut) |
| `FacetedForgeWitness` | schema 1, number, level, actions, digests (one per cut), fingerprints (after begin and each cut), smallest, lower bound (pieces needed), near miss, difficulty, skipped | JSON with sorted keys; decode refuses newer, damaged and non-replaying files |
