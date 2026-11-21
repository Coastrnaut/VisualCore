# Research: R02-G02-05

- **R1 Hints from the solver.** Decision: add `LissajousLabyrinthSolver.solve(_:from:winning:)`, the certified
  breadth-first search (same moves, same order, same tie rule) started from given dials, over a precomputed winning set;
  `solve(_:)` becomes `solve(level, from: level.start, winning: winningSettings(level))`, so the certified solutions are
  unchanged (the catalog test proves it). Hints are derived from the first action of the remaining solution. Rationale:
  every hint is optimal and honest. Alternatives: a precomputed hint table per level (wrong after the first deviation).
- **R2 Winning set once per level.** Decision: the adapter computes the opened level's winning settings when the level
  opens and keeps them as derived state (not digested, not snapshotted, recomputed on restore). Rationale: the winning set
  does not depend on the dials, so only the breadth-first search runs per hint.
- **R3 Progress as state.** Decision: progress, mode and tutorial step live in the experience core, snapshotted (schema 2;
  the tutorial step is not digested, so undo restores the earlier digest) with a schema-1 migration. Rationale: the shared
  contract restores whole sessions; R02-G02-07 then only adds the disk store.
- **R4 Clock-free daily.** Decision: the presenter reads the local calendar date and sends it in `mode.daily`; the core
  maps it with (days since 2026-01-01 × 41) mod 100 + 1. Rationale: deterministic and testable for every date; 41 is
  coprime with 100 and differs from Aurora Loom's 37.
- **R5 Practice allowance.** Decision: practice plays a copy of the level with the allowance raised to 64 (the kernel's
  maximum). Rationale: bounded input; undo already refunds actions.
- **R6 Stars.** Decision: 3 stars at the certified shortest, 2 within shortest + 2, else 1; hints do not reduce stars.
  Rationale: rewards insight without punishing learning.
- **R7 Hint level in the presenter.** Decision: the revealed hint level is presentation state, reset after any change of
  the play (as feature 305). Rationale: the core stays free of view state; undo is unaffected.
