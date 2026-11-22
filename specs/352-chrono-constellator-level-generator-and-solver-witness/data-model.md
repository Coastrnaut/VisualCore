# Data model: R02-G06-02

| Entity | Fields | Rules |
|---|---|---|
| `ChronoConstellatorManifestEntry` | number 1 … 100, seed, band 1 … 5, budget 8 … 19 | copied from the archived design |
| `ChronoConstellatorBandProfile` | columns, rows, stars, smallest range, blocked minimum | bands 1 … 5 (research R3) |
| `ChronoConstellatorSolution` | lower bound m*, phases (the witness timeline's phases), window T, windows considered, windows blocked, work | nil when m* = 0 or every window is blocked |
| `ChronoConstellatorDifficulty` | smallest, win tick, stars, loop lengths, windows, blocked | |
| `ChronoConstellatorGenerated` | entry, level, solution, difficulty, skipped | skipped ≤ 511 |
| `ChronoConstellatorWitness` | schema 1, number, level, actions, win tick, digests (16 hex per tick), fingerprints, lower bound, window, windows, blocked, unedited and near-miss counterexamples, difficulty, skipped | refuses newer, damaged, non-replaying; decode re-solves |
| `ChronoConstellatorCounterexample` | actions, reason (`collision` or `time`), tick | the outcome is a failure |
