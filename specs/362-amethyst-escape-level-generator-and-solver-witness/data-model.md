# Data model: R02-G07-02

| Entity | Fields | Rules |
|---|---|---|
| `AmethystEscapeManifestEntry` | number 1 … 80, seed (UInt64 from the archived hex), band 1 … 5, budget 6 … 21 | 80 entries, 16 per band, manifest order |
| `AmethystEscapeBandProfile` | sectors, shells, smallest (range) | 6×2 (3 … 4), 6×3 (5 … 6), 8×3 (7 … 8), 8×4 (9 … 10), 10×4 (11 … 12) |
| `AmethystEscapeSolution` | smallest, actions, depths (states first reached at each depth 0 … smallest − 1), work (states expanded) | the actions escape on the last; no shorter escape exists |
| `AmethystEscapeDifficulty` | smallest, turns, advances, shells, sectors, explored | turns + advances = smallest |
| `AmethystEscapeGenerated` | entry, level, solution, difficulty, skipped | level id `amethyst-escape-NNN`; tutorial on 1 … 3; difficulty = band |
| `AmethystEscapeCounterexample` | actions, outcome (`stuck`, `wedge(shell, sector)`, `budget`, `open`), move | the unedited run and the near miss |
| `AmethystEscapeWitness` | schema 1, number, level, actions, digests (one per move), fingerprints (after begin and each action), smallest, depths, unedited, near miss, difficulty, skipped | JSON with sorted keys; decode refuses newer, damaged and non-replaying files |
