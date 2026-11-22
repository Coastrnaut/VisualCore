# Research: R02-G07-05

- **R1 Hint plan.** Decision: the first action of the shortest escape from the current crystal that fits in the moves
  left, found by the solver's breadth-first search started at the current crystal. Rationale: the state space is small
  (offsets × pocket) and the solver already searches it in milliseconds; a shortest escape never wastes a move, so
  following hints wins within the budget whenever any escape does. Alternatives: replaying the certified solution
  (useless once the player has deviated).
- **R2 Failure explanation.** Decision: name the blocked wedge from the kernel's failure (`wedge(shell, sector)`) with
  the failing move, or the moves spent and the pearl's pocket for a budget failure. Rationale: the kernel's failure is
  exact; the text only names it in words.
- **R3 Stars.** Decision: moves at the win against the certified smallest move count (3: ≤ smallest, 2: ≤ +2, else 1).
  Rationale: as features 345 and 355.
- **R4 Daily multiplier 61.** Decision: (days since 2026-01-01 × 61) mod 100 + 1. Rationale: coprime with 100 (a
  permutation over 100 days) and distinct from the other round-two games' multipliers (37, 41, 43, 47, 53, 59).
- **R5 Schema 2.** Decision: `{level, records, progress, mode, tutorial}` with a migration from 1. Rationale: the
  established round-two pattern; progress and mode are part of the digest, the tutorial step is not.
