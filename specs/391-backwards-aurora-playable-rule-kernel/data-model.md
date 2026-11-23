# Data model: R02-G10-01

| Entity | Fields | Rules |
|---|---|---|
| `BackwardsAuroraWave` | samples (N 12 … 32, each −64 … 64) | bends b(k) for k in 1 … N − 2; `reversed(start, end)`; seam positions {i − 1, i, j, j + 1} ∩ 1 … N − 2; worst bend; distance to a target (Σ\|s − t\|, Σ\|t\|) |
| `BackwardsAuroraLevel` | id, seed, difficulty 1 … 5, opening wave, target wave (same length and multiset), checkpoints (2 … 8 distinct sorted positions), bend limit L 1 … 64, breaking limit B L … 128, shortest section 2 … N, longest section shortest … N, budget 1 … 40, tutorial, fingerprint | schema 1; sorted-key JSON; the opening wave never already wins (checkpoints matched and smooth) |
| `BackwardsAuroraAction` | reverse(start, end) | start < end, both in 0 … N − 1, length end − start + 1 within shortest … longest; spends one reversal |
| `BackwardsAuroraPlay` | stage, wave, reversals spent, failure (`tear(move, seam)`: the reversal and the seam position; `budget`), records, undo/redo stacks | records carry previous and next fingerprints |
| `BackwardsAuroraRecord` | schema, level seed, move, kind (reverse, undo, redo), action, previous and next fingerprints | appended for every accepted action |
| `BackwardsAuroraRules.Position` | wave, spent, outcome (playing, won, failed) | moves: every valid, non-noop reversal in order of start, then end |
