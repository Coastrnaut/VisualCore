# Research: R02-G05-05

- **R1 Hints as a plan from the current state.** Decision: the hint searches edit sets applied now (size 0 … min(actions
  left, 3)) from the current fluid, heights and valves, in the solver's order and with its routing-key deduplication and
  reachability pruning, and runs each to the verdict; the first winning set is the plan, and its first edit (or "run"
  when it is empty) is the exact hint. Rationale: the same search as the certificates, so a hint followed from the start
  reproduces a smallest solution, and applying the plan's first edit leaves the rest of the plan winning (no tick passes
  between edits), so following exact hints from any state that can still win wins. Alternatives: replaying the certified
  witness (useless once the player deviates); a greedy one-step score (can lead into dead ends).
- **R2 Search from a fluid state.** Decision: generalize the solver's flat-array simulation to start from a given fluid
  (masses, valves, supplies, tick) instead of the level's start; the result is re-run through the kernel. Rationale: the
  kernel's tick stays the reference; the fast copy only speeds the search, exactly as in R02-G05-02.
- **R3 Sample size for hint properties.** Decision: SC-R02G0505-002's seeded reachable states are 200 (split so each test
  stays under 10 s), plus the 100 certified starts followed to a win. Rationale: a hint search costs up to about 0.5 s on
  the debug host (R02-G05-02 measured the same search at 3 … 15 s per 20 levels), so 2,000 states would take minutes;
  the spec is corrected accordingly.
- **R4 Stars by actions spent.** Decision: 3 stars at most the certified smallest edit count, 2 within two more, else 1.
  Rationale: carves and valve toggles are the game's resource; steps are free.
- **R5 Daily × 53.** Decision: (days since 2026-01-01 × 53) mod 100 + 1. Rationale: coprime with 100, so 100 days visit
  every level once, and distinct from the other round-two games' multipliers (37, 41, 43, 47).
- **R6 Failure text from the failing tick.** Decision: the explanation recomputes the verdict's details from the failed
  play's fluid (the first contaminated or overflowing basin in basin order, or for time the first basin not filled).
  Rationale: the kernel already decides the verdict in that order; the text names exactly what decided it.
