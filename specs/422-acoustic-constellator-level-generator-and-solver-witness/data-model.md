# Data model: R02-G13-02

| Entity | Fields | Rules |
|---|---|---|
| `AcousticConstellatorManifestEntry` | number 1 … 100, planned seed, band 1 … 5, budget 8 … 19 | 100 entries in manifest order, 20 per band |
| `AcousticConstellatorBandProfile` | stars, missing, window, plan range | band 1: 3 … 4, 1 … 2, 24, 1 … 2; band 2: 4 … 5, 1 … 2, 24, 2 … 3; band 3: 5 … 6, 2 … 3, 32, 3 … 4; band 4: 6 … 7, 2 … 3, 40, 4 … 5; band 5: 7 … 8, 3 … 4, 48, 5 … 6; a cycle from band 3 |
| `AcousticConstellatorPlan` | links (missing and helper together, in pair order), nudges (one entry per ±1 step, in (star, step) order), smaller sets tried, work | the first winning set of the smallest size; size = links + nudges |
| `AcousticConstellatorDifficulty` | witness actions, stars, symbol pairs, cycles, fixed links, rate spread, window, hold, threshold, smaller sets, work | |
| `AcousticConstellatorGenerated` | entry, level, plan, difficulty, skipped | skipped = the accepted candidate's index; a candidate whose symbol has a star of degree 5 or more is refused by the level rules (the degree limit is capped at 4) and skipped like any uncertified one |
| `AcousticConstellatorWitness` | schema 1, number, level (stored form), actions, state digests, fingerprints, counterexample, difficulty, skipped | sorted-key JSON; re-checked on decode by replay |
