# Data model: R02-G12-02

| Entity | Fields | Rules |
|---|---|---|
| `HarmonicBridgesManifestEntry` | number 1 … 100, planned seed, band 1 … 5, budget 8 … 19 | 100 entries in manifest order, 20 per band |
| `HarmonicBridgesBandProfile` | scrambled range, steps, tones per step, thresholds, decoys | band 1: 1 … 2, 1, 2, 1 … 3, 1 … 2; band 2: 2 … 3, 1 … 2, 2 … 3, 2 … 4, 2 … 3; band 3: 3 … 4, 2, 2 … 3, 2 … 5, 2 … 4; band 4: 4 … 5, 2 … 3, 2 … 3, 3 … 6, 3 … 4; band 5: 5 … 6, 3 … 4, 3, 3 … 6, 3 … 5 |
| `HarmonicBridgesPattern` | steps in which a string is a bridge | bit set over 1 … 4 steps |
| `HarmonicBridgesPlan` | tunings (string, peg) in string order, smaller choices tried, work | the first winning choice of the smallest size |
| `HarmonicBridgesDifficulty` | witness tunings, islands, strings, locked strings, steps, tones, threshold, smaller choices, work | |
| `HarmonicBridgesGenerated` | entry, level, plan, difficulty, skipped | |
| `HarmonicBridgesWitness` | schema 1, number, level (stored form), actions, bridge digests, fingerprints, counterexample, difficulty, skipped | sorted-key JSON; re-checked on decode by replay |
