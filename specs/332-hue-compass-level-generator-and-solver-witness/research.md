# Research: R02-G04-02

- **R1 — What "solvable" means for a deduction game.** Decision: a level is solvable when some set of probe bearings,
  spending fewer units than the allowance, partitions the possible targets into classes each accepted by one selection.
  Rationale: the source's "uniqueness tests" — the player wins by reasoning, never by luck; the witness proves it for the
  real target and the soundness check proves it for every target consistent with the clues. Alternatives: proving only
  the real target's play wins (rejected: a lucky guess would pass).
- **R2 — Non-adaptive sets, depth 2.** Decision: the solver searches probe sets (order does not matter for what the clues
  reveal), the empty set, then 96 singles, then 4,560 pairs. Rationale: a Python prototype (20 seeded levels per setting)
  showed one probe settles almost every level with tolerances (2, 1) or looser, and that tight tolerances (1, 0) on fog
  with 30 … 40 % clear bearings need two; three-probe sets (142,880 per level) would cost seconds per level on a debug host
  for little gain. Adaptive strategies cannot need more probes than the best non-adaptive set, so the smallest set is an
  honest upper bound the player can reach.
- **R3 — Band profiles.** Decision: tolerances (4, 2), (3, 1), (2, 1), (1, 0), (1, 0) and clear-fog shares 0, 10, 20, 30,
  40 % for bands 1 … 5, smallest probe ranges 1, 1, 1, 1 … 2, 2. Rationale: from the prototype, these keep every band
  generable within 64 candidates while difficulty grows through tighter tolerances (finer reading of the wheel), sparser
  fog (weaker depth cue) and finally a second probe.
- **R4 — Counterexamples.** Decision: the near miss is the selection one bearing beyond the bearing tolerance (always
  fails); the insufficient set is the empty set for one-probe levels and the first single bearing for two-probe levels,
  shown with two consistent targets no one selection accepts. Rationale: both always exist by the definition of the
  smallest count; a candidate without them is skipped.
