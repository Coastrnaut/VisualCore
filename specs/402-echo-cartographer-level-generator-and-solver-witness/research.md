# Research: R02-G11-02

- **R1 Inference over placements, not single beacons.** Decision: a placement is a whole set of beacon-count cells and
  it fits when each pulse's sorted echoes are reproduced exactly. Rationale: echoes are unlabelled, so beacons cannot be
  located one at a time; the multiset match is the exact condition. Alternatives: per-beacon candidate sets (unsound
  with two or more beacons at the same distance).
- **R2 Pruned enumeration with a cap.** Decision: depth-first over the cells that fit every pulse singly, in cell-index
  order, pruning when a partial placement's distance counts exceed a pulse's echoes; counts stop at 1 000. Rationale:
  exact and fast for 1 … 4 beacons; the cap bounds early, uninformative turns; uniqueness needs only "exactly 1".
- **R3 Greedy pulse plan.** Decision: pulse the known-open cell whose echo leaves the fewest fitting placements (ties
  lowest index), up to 6 pulses. Rationale: deterministic, reproducible, and every pulse is from a cell the player could
  use at that turn; the plan is a witness, not a minimum, and the metric is named "witness pulses". Alternatives:
  iterative deepening for the smallest plan (work grows with the region to the power of the depth).
- **R4 Acceptance ranges measured first.** Decision: witness pulses 1 … 2, 2 … 3, 3 … 4, 4 … 5, 5 … 6 by band, with
  chamber sizes 6 … 7 up to 10 … 14, wall chance 1/5 or 1/4, beacons 1 up to 3 … 4 and tolerance 1 or 0. Rationale: a
  prototype over 60 candidates per band reached each range in at least 8 % of candidates (256 candidates make a failure
  vanishingly unlikely) with at most about 50 000 nodes of work; one-pulse-wide ranges keep the progression rule (a drop
  of at most 1 within a band, a jump of at most 2 between bands) and band means non-decreasing (lesson of R02-G10-02:
  simulate a generator's filters before writing them down).
- **R5 Witness = plan + claims on the beacons.** Decision: the claims go on each beacon's own cell in beacon order (hits
  at distance 0, free). Rationale: the win then follows from the proof alone; the energy check needs pulses ≤ energy −
  1 (a pulse that spends the last energy fails).
- **R6 Echo digest.** Decision: 16 hex characters of the SHA-256 of the emitter, the rays (direction, distance, wall)
  and the sorted echoes, in a canonical text. Rationale: compact, detects any change in the physics.
- **R7 Counterexample.** Decision: the first two placements, in enumeration order, that fit every pulse but the last.
  Rationale: a concrete proof that the last pulse was needed; always exists because the greedy plan stops at the first
  unique turn (with one pulse, the turn before has no pulse and every placement fits).
