# Research: R02-G13-02

- **R1 Missing symbol pairs are always in the plan.** Decision: the solver starts from the fixed links plus every
  missing symbol pair. Rationale: a listen loses `missing` while any symbol pair is unlinked, so every winning plan
  contains them; only the extra actions need searching.
- **R2 Extra actions: helper links and nudges, without waste.** Decision: options are helper links (unlinked pairs in
  pair order) and nudges (star order, −1 then +1); a set never repeats a helper link, never holds opposite nudges on one
  star and never unlinks. Rationale: opposite nudges cancel and the player starts with no removable links, so such sets
  are never minimal; the remaining sets are exactly the candidates for a minimum. Alternatives: every play action
  (larger search, same minimum; used only by the independent brute force).
- **R3 Increasing size, fixed order.** Decision: e = 0, 1, 2, … extra actions as multisets in option order; the first
  winning set is the plan. Rationale: the first size with a win is the minimum, and every smaller set tried is the
  minimality proof; deterministic.
- **R4 Constructive generator; ranges measured first.** Decision: a spanning-tree symbol (plus one cycle from band 3),
  near-equal rates (base + 0 or 1), drawn starting phases, missing pairs by band; let the solver measure the true
  minimum; ranges 1 … 2, 2 … 3, 3 … 4, 4 … 5, 5 … 6. Rationale: equal-ish rates make coherence reachable within the
  clamp, and starting phases make nudges matter; the prototype reached its band's range in 17 … 48 of 60 candidates with
  at most 6,657 listens of work (lesson of R02-G10-02: simulate a generator's filters before writing them down).
- **R5 Witness = links, nudges, then listen.** Decision: the plan's links in pair order, its nudges in star order, then
  one listen; the budget check needs actions ≤ budget − 1. Rationale: a listen on the last action still wins; the
  final link set is within the limits, so every prefix is too.
- **R6 State digest.** Decision: 16 hex characters of the SHA-256 of the links and phases after each action, in a
  canonical text. Rationale: compact, detects any change in the rules.
- **R7 Counterexample.** Decision: the size one below the plan and the number of sets of that size tried, none winning.
  Rationale: a concrete, re-checkable proof of minimality.
