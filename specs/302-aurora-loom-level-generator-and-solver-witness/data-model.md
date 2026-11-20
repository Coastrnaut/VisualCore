# Data model: R02-G01-02

| Entity | Fields | Rules |
|---|---|---|
| `AuroraLoomManifestEntry` | number 1 … 100, seed `UInt64`, band 1 … 5, budget 8 … 19 | copied from round2.md's R02-G01 table; numbers 1 … 100 in order, 20 per band |
| `AuroraLoomBandProfile` | band, omega, tolerance, shortest `ClosedRange<Int>` | the five profiles of research R4 |
| `AuroraLoomSolveMethod` | `descent`, `grid` | research R2 |
| `AuroraLoomSolution` | shortest, moves `[AuroraLoomMove]`, setting `AuroraLoomSteps`, work, winningSettings `[Int]` (per ribbon), method | moves ordered by ribbon, wave before phase; setting wins; moves.count == shortest |
| `AuroraLoomDifficulty` | shortest, work, winningSettings (sum), tolerance, omega | `puzzleDifficulty` for R02-F24 |
| `AuroraLoomGenerated` | entry, level, solution, difficulty, skipped 0 … 63 | level id `aurora-loom-NNN`, allowance = budget, tutorial for 1 … 3 |
| `AuroraLoomCounterexample` | setting, mismatch `AuroraLoomMismatch` | |mismatch.residual| > tolerance |
| `AuroraLoomWitness` | schema 1, number, level (stored form), actions `[AuroraLoomMove]`, fingerprints `[String]` (after begin/tutorial, then after each action), terminal `AuroraLoomMismatch`, counterexample, difficulty, method, skipped | decode refuses newer schema (`newerSchema`), damage (`malformed`) and a witness that does not replay to a win with the same fingerprints (`witness(reason)`) |

State: a witness is produced from an `AuroraLoomGenerated`; replaying it on a new `AuroraLoomPlay` ends in stage `won`
with `spent == actions.count ≤ allowance`.
