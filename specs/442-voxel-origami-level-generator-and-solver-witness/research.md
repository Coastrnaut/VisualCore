# Research: R02-G15-02

- **R1 Breadth-first search is the exact A-star.** Decision: the solver searches quarter-turn states level by level from
  the start (A-star with a zero heuristic). Rationale: turns do not commute here (a fold changes later hinges' axes and
  what a sweep may clip), so plans are paths, not vectors; breadth-first search finds a minimal path and, by exhausting
  every smaller depth, proves nothing shorter matches. An admissible non-zero heuristic would speed search but adds a
  proof obligation; the prototype needed at most 3 670 turns tried, so none is needed.
- **R2 The swept collision filter.** Decision: a move reaches a state only when the kernel's collision and exact sweep
  rule clear it; idle hinges are not moves. Rationale: the catalog's "swept AABB collision filter" is the kernel's own
  rule (feature 441), so every plan the solver reports is one the play accepts.
- **R3 State merging and order.** Decision: states merged by their quarter turns (the pose is a function of them); at
  each depth states expanded in the order reached, moves in hinge order, −1 then +1. Rationale: deterministic; the plan
  found is the same on every build.
- **R4 Constructive generator; ranges measured first.** Decision: a solution pose, a target taken from it, then a
  scramble of clear turns; let the solver measure the true minimum; ranges 1 … 2, 2 … 3, 3 … 4, 4 … 5, 5 … 6. Rationale:
  building from a solution guarantees a matching pose exists; the prototype reached its band's range in 9 … 73 of 120
  candidates (all three orientation groups), so 256 candidates certify every entry (the lesson of R02-G10-02: simulate a
  generator's filters before writing them down).
- **R5 Orientations by control emphasis.** Decision: `rotate assembly` → `any`, `lock shape` → `fixed`, the others →
  `upright`. Rationale: the manifest's emphases name what the player attends to; the prototype showed the three groups
  certify at similar rates.
- **R6 State digest.** Decision: 16 hex characters of the SHA-256 of the quarter turns after each action, in a canonical
  text. Rationale: compact, detects any change in the rules.
- **R7 Counterexample.** Decision: the depth one below the plan and the number of states reached at that depth, none
  matching. Rationale: a concrete, re-checkable proof of minimality.
