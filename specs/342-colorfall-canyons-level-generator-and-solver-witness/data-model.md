# Data model: R02-G05-02

| Entity | Fields | Rules |
|---|---|---|
| `ColorfallCanyonsManifestEntry` | number 1 … 100, seed, band 1 … 5, budget 8 … 19 | copied from the archived design |
| `ColorfallCanyonsEdit` | carve(cell) or valve(spring) | a set is a multiset of carves plus each valve at most once |
| `ColorfallCanyonsSolution` | edits (smallest, solver order), smallest, work (distinct routings), smaller (sets of fewer edits simulated, all failing) | nil when none within depth 4 |
| `ColorfallCanyonsDifficulty` | smallest, work, win tick, springs, basins, protected basins, carvable cells | |
| `ColorfallCanyonsBandProfile` | columns, rows, springs, depressions, smallest range | bands 1 … 5 |
| `ColorfallCanyonsGenerated` | entry, level, planted edits, solution, difficulty, skipped | skipped ≤ 255 |
| `ColorfallCanyonsWitness` | schema 1, number, level, actions, win tick, digests, totals, fingerprints, unedited and near-miss counterexamples, smaller, difficulty, skipped | refuses newer, damaged, non-replaying |
| `ColorfallCanyonsCounterexample` | edits, reason, tick | the outcome is a failure |
