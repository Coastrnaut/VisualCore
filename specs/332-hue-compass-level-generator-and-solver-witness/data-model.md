# Data model: R02-G04-02

| Entity | Fields | Rules |
|---|---|---|
| `HueCompassManifestEntry` | number 1 … 100, seed, band 1 … 5, budget 8 … 19 | copied from round2.md |
| `HueCompassBandProfile` | bearing tolerance, band tolerance, clear share (percent), smallest range | per band, constants |
| `HueCompassSolution` | probes (bearings, ascending), smallest (0 … 2), work, best single bearing, largest class after it | first settling set in lexicographic order |
| `HueCompassAmbiguity` | probes (0 … 1 bearings), two targets | consistent with the same clues; no one selection accepts both |
| `HueCompassDifficulty` | smallest, largest class after the best single probe, bearing and band tolerance, clear share, work | from level and solver |
| `HueCompassGenerated` | entry, level, solution, difficulty, skipped (0 … 63) | |
| `HueCompassWitness` | schema 1, number, level (stored form), actions, clues, candidate counts, fingerprints, near miss, ambiguity, difficulty, skipped | sorted keys; replays on decode |
