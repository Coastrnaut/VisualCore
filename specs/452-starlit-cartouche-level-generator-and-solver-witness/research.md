# Research: R02-G16-02

- **R1 Time-expanded breadth-first search.** Decision: the solver searches route states (star, beat, strokes drawn)
  level by level from the start. Rationale: the catalog names a time-expanded graph search; with the beat in the state,
  waits, orbits, windows and hazards are all exact, and breadth-first search finds a minimal leg count and, by
  exhausting every smaller depth, proves nothing shorter wins. The prototype needed at most 33 832 legs tried, so no
  heuristic is needed.
- **R2 Legs filtered by the kernel.** Decision: a leg reaches a state only when the chart accepts it (flyable, not
  refused) and finds no failure. Rationale: every plan the solver reports is one the play accepts; a stray stroke always
  fails, so states only ever hold subsets of the symbol.
- **R3 State merging and order.** Decision: states merged by star, beat and stroke mask; at each depth states expanded
  in the order reached, legs by corridor index then wait 0 … 8. Rationale: deterministic; the plan found is the same on
  every build.
- **R4 Constructive generator; ranges measured first.** Decision: fly a random route of band + 1 … band + 2 flyable
  legs, make its corridors the symbol, add decoys and hazards that miss it, then let the solver measure the true
  minimum; ranges 2 … 3, 3 … 4, 4 … 5, 5 … 6, 6 … 7 legs. Rationale: building from a route guarantees a win exists; the
  prototype reached its band's range in 98 … 110 of 120 candidates (the lesson of R02-G10-02: simulate a generator's
  filters before writing them down).
- **R5 Emphasis shapes the level.** Decision: `avoid hazard` → band + 2 hazards; `time launch` → tight windows on every
  visited star; the others → 0 … band hazards and tight windows on a third of the stars. Rationale: the manifest's
  emphases name what the player attends to; the prototype measured exactly this generator.
- **R6 State digest.** Decision: 16 hex characters of the SHA-256 of the ship's star, the beat and the drawn strokes
  after each action, in a canonical text. Rationale: compact, detects any change in the rules.
- **R7 Counterexample.** Decision: the depth one below the plan and the number of states reached at that depth, none
  winning. Rationale: a concrete, re-checkable proof of minimality.
- **R8 Budget bound.** Decision: widen the kernel's budget to 1 … 24. Rationale: the manifest's budgets reach 19; the
  wider bound keeps every level of feature 451 valid.
