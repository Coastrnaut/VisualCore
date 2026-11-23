# Research: R02-G12-02

- **R1 Patterns instead of pegs.** Decision: for every string, the bridge pattern (the set of window steps in which it
  is a bridge) at each of its 12 pegs; a plan chooses patterns, realised by the lowest peg giving them. Rationale: only
  the pattern decides reachability, so the search is over at most 2^4 patterns per string instead of 12 pegs.
- **R2 Maximal, non-contained options.** Decision: a retuned string's options are the maximal patterns among its other
  pegs not contained in its current pattern. Rationale: reachability is monotone in the bridges, so any winning plan
  stays winning when each retuned string takes a maximal pattern, and a contained pattern never helps; the minimum is
  therefore found among these options. Alternatives: every peg (12^k choices).
- **R3 Increasing size, lexicographic order.** Decision: k = 1 … 6, subsets of the useful strings in lexicographic index
  order, options in order; the first winning choice is the plan. Rationale: the first k with a win is the minimum, and
  every smaller choice tried is the minimality proof; deterministic.
- **R4 Constructive generator; ranges measured first.** Decision: build a start-to-goal path whose strings take a
  (length, peg) that is a bridge in every step, scramble k of their pegs, add decoys and let the solver measure the true
  minimum; ranges 1 … 2, 2 … 3, 3 … 4, 4 … 5, 5 … 6. Rationale: random tones rarely form bridges (a prototype of random
  generation left 49 … 59 of 60 candidates unsolvable); the constructive prototype reached its band's range in 37 … 60 of
  60 generated candidates with at most 237 choices of work (lesson of R02-G10-02: simulate a generator's filters before
  writing them down).
- **R5 Witness = tunings + test.** Decision: the plan's tunings in string order, then one test; the budget check needs
  tunings ≤ budget − 1. Rationale: a test on the last action still wins, and the tunings alone never spend the budget.
- **R6 Bridge digest.** Decision: 16 hex characters of the SHA-256 of the bridges per step after each tuning, in a
  canonical text. Rationale: compact, detects any change in the resonance rules.
- **R7 Counterexample.** Decision: the size one below the plan and the number of choices of that size tried, none
  winning; for a one-tuning plan, the starting pegs' break. Rationale: a concrete, re-checkable proof of minimality.
