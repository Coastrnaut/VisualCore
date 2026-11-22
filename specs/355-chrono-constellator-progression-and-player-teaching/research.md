# Research: R02-G06-05

- **R1 Hint plan.** Decision: run when the current timeline wins; rewind when a change is needed after tick 0; remove the
  first hold when holds exist at tick 0; otherwise the certified solver on the level with the current phases as its
  defaults, accepted when the edits in use afterwards fit the budget and the timeline wins. Rationale: the solver's
  lower-bound proof gives the smallest phase-only change set and runs in milliseconds; holds are never needed by a
  certified solution. Alternatives: a breadth-first search over phases and holds (exponential in stars).
- **R2 Failure explanation.** Decision: replay the timeline to the failing tick (closed-form positions) and name the
  colliding pair and cell, or every star off target at the tick limit. Rationale: the kernel's failure already names the
  pair and cell; positions at any tick are exact.
- **R3 Stars.** Decision: edits in use at the win against the certified smallest edit count (3: ≤ smallest, 2: ≤ +2,
  else 1). Rationale: as features 335 and 345; edits in use, not presses, reward a clean timeline.
- **R4 Daily multiplier 59.** Decision: (days since 2026-01-01 × 59) mod 100 + 1. Rationale: coprime with 100 (a
  permutation over 100 days) and distinct from the other round-two games' multipliers.
- **R5 Schema 2.** Decision: `{level, records, progress, mode, tutorial}` with a migration from 1. Rationale: the
  established round-two pattern; progress and mode are part of the digest, the tutorial step is not.
