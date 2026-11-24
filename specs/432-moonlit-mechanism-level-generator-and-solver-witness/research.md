# Research: R02-G14-02

- **R1 Actions commute; a plan is a vector.** Decision: a plan is (t, h, r₁ … rₙ₋₁): net handle turns, net lamp steps
  and each gear's net re-seat; its length is the L1 norm. Rationale: a turn adds each gear's direction, a re-seat adds
  one to one gear and a lamp step adds one to the height, so order never changes the final set-up, and a lamp path that
  moves one way stays within the range whenever its end does; searching vectors is exactly searching plans.
- **R2 Alignment pruning (the gear-ratio constraint).** Decision: a vector that leaves any mesh misaligned is skipped
  without a run. Rationale: a turn moves meshing gears by +t and −t, so alignments depend only on the re-seats, and a
  misaligned machine jams on any run; the pruned vectors are exactly those that cannot win.
- **R3 Increasing norm, fixed order.** Decision: norms c = 0, 1, 2, …, coordinates from −left to +left in the order t,
  h, r₁, …, the last coordinate +left before −left; the first winning vector is the plan. Rationale: the first norm with
  a win is the minimum, and every smaller vector tried is the minimality proof; deterministic.
- **R4 Constructive generator; ranges measured first.** Decision: a solution set-up whose key-frame casts are the
  targets, alignments taken from the solution, forbidden cells outside every cast, then a scramble of random accepted
  actions; let the solver measure the true minimum; ranges 1 … 2, 2 … 3, 3 … 4, 4 … 5, 5 … 6. Rationale: building from
  a solution guarantees a winning set-up exists; the prototype reached its band's range in 14 … 42 of 60 candidates with
  at most 760 runs of work (lesson of R02-G10-02: simulate a generator's filters before writing them down).
- **R5 Witness = turns, re-seats, lamp steps, then run.** Decision: |t| turns of t's sign, then each gear's re-seats in
  gear order, then |h| lamp steps, then the run; the budget check needs actions ≤ budget − 1. Rationale: a run on the
  last action still wins; the monotone lamp path stays in range.
- **R6 State digest.** Decision: 16 hex characters of the SHA-256 of the phases and the lamp height after each action,
  in a canonical text. Rationale: compact, detects any change in the rules.
- **R7 Counterexample.** Decision: the norm one below the plan and the number of vectors of that norm tried, none
  winning. Rationale: a concrete, re-checkable proof of minimality.
