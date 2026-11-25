# Research: R02-G17-05

- **R1 Hints from the current phases.** Decision: a solver entry point `plan(_:from:)` searches from the play's current
  phases within min(actions left, 5) changes; the first change is the hint. Rationale: the certifying search already
  proves minimality from the opening; starting it from any phases gives a shortest completion, so exact hints win
  within the budget. Alternatives: replaying the witness (rejected: useless once the player diverges).
- **R2 Three levels.** Decision: the planet, then the way and distance (the shorter way around its orbit), then the
  exact phase. Rationale: the same escalation as features 445 and 455, adapted to a phase.
- **R3 Failure text from the run's failure.** Decision: the kernel's failure (unwanted, window, horizon) carries the
  planets and ticks; the explanation names them, numbers targets from 1 and offers undo or retry. Rationale: the
  failure happens on the clock, not on an action, so the text names the eclipse, not a move.
- **R4 Stars by actions spent.** Decision: 3 stars at most the witness's change count, 2 at most that + 2, else 1, over
  every accepted phase change including undone ones. Rationale: the same rule as feature 455; the run costs nothing.
- **R5 Daily multiplier 29.** Decision: (days since 2026-01-01 × 29) mod 100 + 1. Rationale: 29 is coprime with 100, so
  the daily level cycles through all 100 levels, and no other round-two game uses it.
- **R6 Schema 2.** Decision: `{level, mode, progress, records, tutorial}` with a migration from schema 1. Rationale: the
  same shape as feature 455, so the shared snapshot migrations apply unchanged.
