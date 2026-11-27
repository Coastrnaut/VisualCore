# Research: R02-G21-05

- **R1 Hints from the current arrangement.** Decision: while every one of the seven controls holds its starting or its
  certified value and the actions left cover the witness's remaining actions (those whose control is not yet at its
  certified value, in the witness's order, each a legal move from the arrangement before it), the hint is the first of
  them; otherwise a bounded breadth-first search over the arrangements reachable within min(actions left, 2) legal moves
  of `BinaryGardensPuzzle.moves(in:)` (star 1 ring, phase, luminosity, star 2 ring, phase, luminosity, tilt; values
  ascending), one action before two, each reached arrangement judged once, at most 2,000 judged; the first action of the
  first winning sequence is the hint. Rationale: witnesses reach 4 actions, more than a two-action search sees, so the
  witness rule carries exact hints from a level's start to a win by certification with no search, and the fallback
  serves players who diverge; a minimal plan sets each control once, so "on the way" is a per-control test; a report
  depends only on the arrangement, so judging arrangements is exact; 2,000 exceeds the largest two-action space (650).
  Alternatives: re-running the certifying solver from the current arrangement (rejected: 5,000-arrangement bound, slower
  and not needed); a search as deep as the witness (rejected: up to 25⁴ arrangements).
- **R2 Three levels.** Decision: the kind of change (ring, phase, luminosity, tilt), then which star and which way
  (outward or inward, forward or back by (target − current) mod 48 in 1 … 24, brighter or dimmer, more or less tilt),
  then the exact action with units. Rationale: the same escalation as features 485 and 495, adapted to four kinds of
  control.
- **R3 Failure text from the play's failure.** Decision: the kernel's failure (frozen, scorched, unstable, wilted,
  bleached) carries the world, tick, window or integral; the explanation names them, numbers worlds from 1, names ticks
  in the level's words, groups numbers as the level does and offers undo or retry. Rationale: the failure is decided by
  the run, not by an action.
- **R4 Stars by actions spent.** Decision: 3 stars at most the certified action count, 2 at most that + 2, else 1, over
  every accepted ring, phase, luminosity and tilt record including undone ones. Rationale: the same rule as features
  485 and 495; the run costs nothing.
- **R5 Daily multiplier 13.** Decision: (days since 2026-01-01 × 13) mod 100 + 1. Rationale: 13 is coprime with 100,
  so 100 consecutive days visit all 100 levels, and no other round-two game uses it (the others use 17 … 97).
- **R6 Schema 2 and digest v2.** Decision: `{level, mode, progress, records, tutorial}` with a migration from schema 1;
  digest domain `"r02-g21.binary-gardens.v2"` over level, play fingerprint, progress and mode. Rationale: the same shape
  as features 485 and 495, so the shared snapshot migrations apply unchanged; the tutorial step is snapshotted but not
  digested (presentation of teaching, not game state).
- **R7 `level.next` without wrap.** Decision: moves to the next open level in campaign mode, refused `r02-g21.locked`
  when none. Rationale: with progression a wrap from 100 to 1 would bypass the frontier rule; the existing wrap test is
  updated in place (spec clarification on changed tests).
