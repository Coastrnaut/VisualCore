# Research: R02-G19-05

- **R1 Hints from the current wells.** Decision: a bounded search from the play's current wells over the sets of wells
  reachable within min(actions left, 2) placements or removals, one action before two, the certified plan's next
  placement first while the current wells are a subset of the certified wells, then removals by slot and placements by
  slot, site, strength and sense; at most 1,200 sets judged; the first action of the found sequence is the hint.
  Rationale: a report depends only on the set of wells, so judging sets is exact; trying the certified placement first
  makes exact hints from a level's start replay the certified plan (which wins within the budget by certification) at
  one set judged per hint, and the bounded fallback serves players who diverge. Alternatives: re-running the certifying
  solver (rejected: it only starts from a level without wells); replaying the witness alone (rejected: useless once the
  player diverges); an unbounded search over three edits (rejected: up to ~10,000 swims).
- **R2 Three levels.** Decision: the site (or the well to take away), then the sense, then the exact well (slot, site,
  strength, sense). Rationale: the same escalation as features 465 and 475, adapted to a well's three choices.
- **R3 Failure text from the play's failure.** Decision: the kernel's failure (exit, coherence, coverage,
  connectedness) carries the swimmer, tick, group, counts or cell; the explanation names them, numbers swimmers from 1,
  names cells by row and column and offers undo or retry. Rationale: the failure happens during the swim, not on an
  action.
- **R4 Stars by actions spent.** Decision: 3 stars at most the certified placement count, 2 at most that + 2, else 1,
  over every accepted placement and removal including undone ones. Rationale: the same rule as feature 475; the play
  costs nothing.
- **R5 Daily multiplier 19.** Decision: (days since 2026-01-01 × 19) mod 100 + 1. Rationale: 19 is coprime with 100,
  so the daily level cycles through all 100 levels, and no other round-two game uses it (the others use 23 … 97).
- **R6 Schema 2.** Decision: `{level, mode, progress, records, tutorial}` with a migration from schema 1. Rationale: the
  same shape as features 465 and 475, so the shared snapshot migrations apply unchanged.
