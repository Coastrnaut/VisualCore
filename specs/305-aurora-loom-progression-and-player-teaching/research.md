# Research: R02-G01-05

- **R1 Hints from the solver.** Decision: add `AuroraLoomSolver.solve(_:from:)` (the existing per-ribbon descent and grid,
  starting from given steps) and derive hints from its solution. Rationale: the solver already proves the fewest changes
  per ribbon; solving from the current steps makes every hint optimal and honest. Alternatives: a precomputed hint table
  per level (wrong after the first deviation).
- **R2 Progress as state.** Decision: progress, mode and tutorial step live in the experience core, snapshotted (schema 2;
  the tutorial step is not digested, so undo restores the earlier digest) with a schema-1 migration. Rationale: the shared contract restores whole sessions; R02-G01-07 then
  only adds the disk store.
- **R3 Clock-free daily.** Decision: the presenter reads the local calendar date and sends it in `mode.daily`; the core maps
  it with a fixed formula. Rationale: the core stays deterministic and testable for every date.
- **R4 Practice allowance.** Decision: practice plays a copy of the level with the allowance raised to 64 (the kernel's
  maximum). Rationale: "unlimited" within the kernel's bounded input; undo already refunds moves.
- **R5 Stars.** Decision: 3 stars at the certified shortest, 2 within shortest + 2, else 1; hints do not reduce stars.
  Rationale: rewards insight without punishing learning (the design forbids coercion).
