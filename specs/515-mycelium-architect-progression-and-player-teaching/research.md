# Research: R02-G22-05

- **R1 Hints from the current arrangement.** Decision: while the arrangement lies on the way from the start to the
  certified arrangement (for placed nutrients, placed blockers and seeds alike, start ∩ certified ⊆ current ⊆ start ∪
  certified) and the actions left cover the witness's remaining actions (those not yet done, in the witness's order,
  each accepted by the rules from the arrangement before it), the hint is the first of them; otherwise a bounded
  breadth-first search over the arrangements reachable within min(actions left, 2) legal moves of
  `MyceliumArchitectPuzzle.moves(in:)` (nutrient, blocker, clear, seed, unseed in the fixed cell and direction order),
  one action before two, each reached arrangement judged once, at most 2,000 judged; the first action of the first
  winning sequence is the hint. Rationale: witnesses reach 4 actions, more than a two-action search sees, so the witness
  rule carries exact hints from a level's start to a win by certification with no search; a minimal plan touches each
  cell or direction at most once, so "on the way" is a set test; a report depends only on the arrangement, so judging
  arrangements is exact; 2,000 exceeds the largest two-action space (at most 6 sites: 34 + 34² = 1,190).
  Alternatives: re-running the certifying solver from the current arrangement (rejected: 20,000-arrangement bound,
  slower and not needed); a search as deep as the witness (rejected: up to 34⁴ arrangements).
- **R2 Three levels.** Decision: the kind of change (nutrient, blocker, clear, seed, unseed), then where (the board
  quadrant of a cell: a column below W / 2 is left, a row below H / 2 upper; a direction's side: top, bottom, east,
  west), then the exact action with the level's words for the cell or the compass name. Rationale: the same escalation
  as feature 505, adapted to placements on cells and seeds by direction.
- **R3 Failure text from the play's failure.** Decision: the level's own `failureDescription` (toxic, starved,
  unreached, overweight with tip, terminal, cell, pulse, weight and bound; numbers grouped), first letter capitalised,
  then ". Undo the last action or retry the level." Rationale: the kernel's words already name every value; one source
  of truth for the words.
- **R4 Stars by actions spent.** Decision: 3 stars at most the certified action count, 2 at most that + 2, else 1, over
  every accepted nutrient, blocker, clear, seed and unseed record including undone ones. Rationale: the same rule as
  feature 505; the run costs nothing.
- **R5 Daily multiplier 11.** Decision: (days since 2026-01-01 × 11) mod 100 + 1. Rationale: 11 is coprime with 100,
  so 100 consecutive days visit all 100 levels, and no other round-two game uses it (the others use 13 … 97).
- **R6 Schema 2 and digest v2.** Decision: `{level, mode, progress, records, tutorial}` with a migration from schema 1;
  digest domain `"r02-g22.mycelium-architect.v2"` over level, play fingerprint, progress and mode. Rationale: the same
  shape as feature 505, so the shared snapshot migrations apply unchanged; the tutorial step is snapshotted but not
  digested.
- **R7 `level.next` without wrap.** Decision: moves to the next open level in campaign mode, refused `r02-g22.locked`
  when none. Rationale: with progression a wrap from 100 to 1 would bypass the frontier rule; the existing wrap test is
  updated in place (spec clarification on changed tests).
