# Data model: R02-G02-02

| Entity | Fields | Rules |
|---|---|---|
| `LissajousLabyrinthManifestEntry` | number 1 … 100, seed (UInt64), band 1 … 5, budget 8 … 19 | copied from round2.md |
| `LissajousLabyrinthBandProfile` | band, checkpoints, checkpoint radius, obstacles, shortest range | bands 1 … 5: 2/3/4/5/6 checkpoints of radius 512/448/384/320/256; 2/3/4/6/8 obstacles; shortest 1–2, 2, 2–3, 3, 3–4 |
| `LissajousLabyrinthSolution` | shortest, actions, winning setting, winningSettings, work | actions replay from the start through legal states to a win |
| `LissajousLabyrinthDifficulty` | shortest, winningSettings, clearance, work | clearance > 0 (no sample inside an obstacle) |
| `LissajousLabyrinthGenerated` | entry, level, solution, difficulty, skipped | skipped 0 … 63 |
| `LissajousLabyrinthWitness` | schema 1, number, level, actions, fingerprints, visits, clearance, nearMiss, nonCoprime, difficulty, skipped | sorted-key JSON; byte-exact |
| Catalog | 100 generated levels in manifest order, digest | progression rule holds |
