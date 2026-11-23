# Data model: R02-G11-02

| Entity | Fields | Rules |
|---|---|---|
| `EchoCartographerManifestEntry` | number 1 … 100, planned seed, band 1 … 5, energy 8 … 19 | 100 entries in manifest order, 20 per band |
| `EchoCartographerBandProfile` | sizes, wall chance (1 in 5 or 1 in 4), beacon counts, tolerance, miss cost, witness pulse range | band 1: 6 … 7, 1/5, 1, 1, 1, 1 … 2; band 2: 7 … 9, 1/5, 1 … 2, 1, 1, 2 … 3; band 3: 8 … 10, 1/4, 2, 1, 2, 3 … 4; band 4: 9 … 12, 1/4, 2 … 3, 0, 2, 4 … 5; band 5: 10 … 14, 1/4, 3 … 4, 0, 3, 5 … 6 |
| `EchoCartographerObservation` | emitter, sorted echoes | one per pulse heard |
| `EchoCartographerPlan` | pulses (cells), placements after each pulse (capped 1 000), counterexample placements (two), work | the last count is 1; each pulse from a cell known open at its turn |
| `EchoCartographerDifficulty` | witness pulses, width, height, region cells, beacons, tolerance, placements before the last pulse, work | |
| `EchoCartographerGenerated` | entry, level, plan, difficulty, skipped | |
| `EchoCartographerWitness` | schema 1, number, level (stored form), actions, echo digests, placements, fingerprints, counterexample, difficulty, skipped | sorted-key JSON; re-checked on decode by replay |
