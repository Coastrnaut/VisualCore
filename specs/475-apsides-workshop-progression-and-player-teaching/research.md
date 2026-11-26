# Research: R02-G18-05

- **R1 Hints from the current orbit.** Decision: a solver entry point `plan(_:from:)` searches from the play's current
  orbit within min(actions left, 2) tunings; the first tuning is the hint. Rationale: the certifying search already
  proves minimality from the opening; starting it from any orbit gives a shortest completion, so exact hints win within
  the budget. Alternatives: replaying the witness (rejected: useless once the player diverges).
- **R2 Three levels.** Decision: the lever (periapsis knob or size), then the way and distance (eccentricity steps and
  the shorter turn of the direction, or the size change), then the exact setting. Rationale: the same escalation as
  features 455 and 465, adapted to the two levers.
- **R3 Failure text from the play's failure.** Decision: the kernel's failure (contact, order, share, apsis sector,
  apsis distance) carries the planet or target, tick and reading; the explanation names them, numbers targets from 1
  and offers undo or retry. Rationale: the failure happens during the revolution, not on an action.
- **R4 Stars by actions spent.** Decision: 3 stars at most the witness's tuning count, 2 at most that + 2, else 1, over
  every accepted tuning including undone ones. Rationale: the same rule as feature 465; the play costs nothing.
- **R5 Daily multiplier 23.** Decision: (days since 2026-01-01 × 23) mod 100 + 1. Rationale: 23 is coprime with 100, so
  the daily level cycles through all 100 levels, and no other round-two game uses it.
- **R6 Schema 2.** Decision: `{level, mode, progress, records, tutorial}` with a migration from schema 1. Rationale: the
  same shape as feature 465, so the shared snapshot migrations apply unchanged.
