# Research: R02-G03-05

- **R1 Hints from the solver.** Decision: the certified breadth-first search started from the current rope (same moves,
  same order, same tie rule), depth at most 3. Rationale: hints are then never wrong and follow the certified tie rule; a
  deeper search would exceed the short-test budget (60^4 ropes), and "no short solution from here" with undo is honest.
- **R2 Progress as state.** Decision: as feature 315 — progress and mode in the digest, the tutorial step in the snapshot
  but not the digest, the revealed hint level in the presenter.
- **R3 Daily level.** Decision: (days since 2026-01-01 × 43) mod 100 + 1. Rationale: a permutation of the 100 levels,
  coprime with 100 and different from Aurora Loom's 37 and Lissajous Labyrinth's 41.
- **R4 Failure text.** Decision: from the kernel's summary (crossings, writhe, degenerate) against the target.
