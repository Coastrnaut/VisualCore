# Data model: R02-G03-02

| Entity | Fields | Rules |
|---|---|---|
| `WaveKnotKeeperManifestEntry` | number 1 … 100, seed (UInt64), band 1 … 5, budget 8 … 19 | copied from round2.md |
| `WaveKnotKeeperBandProfile` | band, points, gates, scramble, shortest range | bands 1 … 5: 6/7/8/9/10 points; 0/0/1/1/2 gates of side 3; scramble 1/2/2/3/4; shortest 1, 1–2, 1–2, 2, 2–3 |
| `WaveKnotKeeperSolution` | shortest, moves, final rope, work, crossing counterexample (rope, move) | moves replay from the start through legal ropes to a win |
| `WaveKnotKeeperDifficulty` | shortest, points, gates, crossings, work | crossings = target crossings |
| `WaveKnotKeeperGenerated` | entry, level, solution, difficulty, skipped | skipped 0 … 63 |
| `WaveKnotKeeperWitness` | schema 1, number, level, moves, fingerprints, terminal {crossings, writhe, tension}, nearMiss {move, crossings, writhe, degenerate}, crossing {points, move}, difficulty, skipped | sorted-key JSON; byte-exact |
| Catalog | 100 generated levels in manifest order, digest | progression rule holds |
