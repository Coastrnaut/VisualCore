# Research: R02-G04-05

- **R1 Hints from the consistent set.** Decision: the hint reasons only from the clues the player has seen (the targets
  still consistent with them), never from the hidden target. Rationale: a hint must teach the deduction and cannot leak
  the answer; when the consistent set settles, the selection it names is correct for every remaining target.
- **R2 Probe choice.** Decision: the first settling bearing, else the bearing with the smallest largest class.
  Rationale: the same tie rules as the solver, so hints and certificates agree; the greedy fallback always narrows the
  set because the certified levels settle within two probes.
- **R3 Stars by units spent.** Decision: 3 stars at most the certified smallest + 1 units, 2 within one more. Rationale:
  units (probes and the selection) are the game's resource; turns are free.
- **R4 Daily × 47.** Decision: (days since 2026-01-01 × 47) mod 100 + 1. Rationale: coprime with 100, so 100 days visit
  every level once, and distinct from the other round-two games' multipliers.
