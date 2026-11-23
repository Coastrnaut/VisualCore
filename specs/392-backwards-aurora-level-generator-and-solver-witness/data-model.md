# Data model: R02-G10-02

| Entity | Fields | Rules |
|---|---|---|
| `BackwardsAuroraManifestEntry` | number 1 … 100, seed (UInt64 from the archived hex), band 1 … 5, budget 8 … 19 | 100 entries, 20 per band, manifest order |
| `BackwardsAuroraBandProfile` | lengths (wave), reversals (range), section lengths (range), checkpoints, breaking margin | band 1: 14 … 16, 2 … 3, 2 … 4, 2, none (B = 128); band 2: 18 … 22, 3 … 4, 2 … 5, 3, none; band 3: 22 … 26, 4 … 5, 2 … 6, 4, 48; band 4: 26 … 30, 5 … 6, 2 … 6, 5, 32; band 5: 30 … 32, 6 … 7, 2 … 6, 6, 16 (B = min(128, L + margin)) |
| `BackwardsAuroraBound` | badBends β, smallest = ⌈β / 4⌉ | β counts interior bends with \|b\| > L in the opening |
| `BackwardsAuroraSolution` | smallest, actions, work (reversals evaluated) | smallest = the bound; the actions win on the last |
| `BackwardsAuroraDifficulty` | smallest, length, checkpoints, reversedSamples, longestSection, badBends, bendLimit, breakingMargin, work | from the witness and the level |
| `BackwardsAuroraGenerated` | entry, level, solution, bound, difficulty, skipped | level id `backwards-aurora-NNN`; tutorial on 1 … 3; difficulty = band |
| `BackwardsAuroraCounterexample` | actions, badBends | the near miss (witness minus its last reversal): not won, badBends > 0 |
| `BackwardsAuroraWitness` | schema 1, number, level, actions, digests (one per action), fingerprints (after begin and each action), smallest, bound, near miss, difficulty, skipped | JSON with sorted keys; decode refuses newer, damaged and non-replaying files |

A candidate's k must lie in the band's range and its sections must be separated (each start at least 3 after the
previous end; first start ≥ 2; last end ≤ N − 3) with all 4 seam bends of each above L.
