# Research: R02-G20-05

- **R1 Hints from the current arrangement.** Decision: while the current arrangement lies on the way to the certified
  witness's (pods a subset, toggled vents a subset, moonlight the start's or the witness's) and the actions left cover
  the witness's remaining actions, the hint is the witness's next remaining action; otherwise a bounded search over the
  arrangements reachable within min(actions left, 2) pod, vent or moonlight actions, one action before two, removals by
  slot, then moves and placements by slot and site, vents by index and moonlight levels ascending; at most 1,500
  arrangements judged; the first action of the found sequence is the hint. Rationale: witnesses reach 5 actions, more
  than a two-action search can see, so the witness rule carries exact hints from a level's start to a win within the
  budget by certification with no search at all, and the bounded fallback serves players who diverge; a report depends
  only on the arrangement, so judging arrangements is exact. Alternatives: re-running the certifying solver (rejected:
  it only starts from a level without pods); a search as deep as the witness (rejected: thousands of runs per hint).
- **R2 Three levels.** Decision: the kind of change (pod, vent, moonlight), then where (the site, the pod, the vent, or
  brighter or dimmer), then the exact action. Rationale: the same escalation as features 475 and 485, adapted to three
  kinds of control.
- **R3 Failure text from the play's failure.** Decision: the kernel's failure (dried, mold, unstable) carries the colony,
  cell, cycle or run; the explanation names them, numbers colonies from 1, names cells in the level's words and offers
  undo or retry. Rationale: the failure happens during the run, not on an action.
- **R4 Stars by actions spent.** Decision: 3 stars at most the certified action count, 2 at most that + 2, else 1, over
  every accepted pod, vent and moonlight record including undone ones. Rationale: the same rule as feature 485; the run
  costs nothing.
- **R5 Daily multiplier 17.** Decision: (days since 2026-01-01 × 17) mod 100 + 1. Rationale: 17 is coprime with 100,
  so the daily level cycles through all 100 levels, and no other round-two game uses it (the others use 19 … 97).
- **R6 Schema 2.** Decision: `{level, mode, progress, records, tutorial}` with a migration from schema 1. Rationale: the
  same shape as features 475 and 485, so the shared snapshot migrations apply unchanged.
