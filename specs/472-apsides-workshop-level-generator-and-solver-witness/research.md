# Research: R02-G18-02

- **R1 Search by levers changed.** Decision: the solver searches orbits by the number of levers (the periapsis knob, the
  size) that differ from the start, depth 1 then 2. Rationale: a later tuning of the same lever overrides an earlier
  one, so the orbits reachable with at most d tunings are exactly those differing in at most d levers; the first win at
  the smallest depth is a minimal plan and exhausting every smaller depth proves nothing shorter wins. With two levers a
  plan has at most two tunings.
- **R2 Apsis pruning.** Decision: an orbit failing an apsis target (its sector or distance from the orbit's steps alone)
  is judged not winning without computing its positions; every other orbit gets the kernel's full report. Rationale: the
  apsis checks are part of the judge and need no Kepler inversion, so pruning changes only the work, never the outcome;
  the prototype needed 3 346 full reports for the whole catalog.
- **R3 Fixed order.** Decision: depth 1 lists knob settings (eccentricity, then direction) then sizes; depth 2 lists
  size outermost, then eccentricity, then direction; the start's own settings are skipped. Rationale: deterministic; the
  plan found is the same on every build.
- **R4 Constructive generator; ranges measured first.** Decision: draw a valid winning orbit, make targets from its
  shares and apsides with bands of band-dependent half-widths, place planets beside its path, then move one or both
  levers away; plan ranges 1, 1, 1 … 2, 2, 2. Rationale: building from a winning orbit guarantees a win exists; on the
  real manifest the prototype certified every entry within candidate index 8 and the band means did not fall (1.0, 1.0,
  1.1, 2.0, 2.0) — the lesson of R02-G10-02: simulate a generator's filters before writing them down.
- **R5 Valid witness order.** Decision: two tunings go size first when the winning eccentricity is not lower than the
  start's, the knob first otherwise. Rationale: the orbit in between keeps the lower eccentricity with either size, so
  both validity inequalities hold; the play refuses an invalid orbit, so the witness must never pass through one (the
  lesson of feature 471's fixtures).
- **R6 Neighbour rule.** Decision: skip a candidate whose targets equal the previous level's. Rationale: the manifest
  asks for a genuinely different puzzle from adjacent seeds.
- **R7 State digest.** Decision: 16 hex characters of the SHA-256 of the orbit and the actions spent after each action,
  in a canonical text. Rationale: compact, detects any change in the rules.
- **R8 Counterexample.** Decision: the depth one below the plan and the number of orbits at that depth, none winning.
  Rationale: a concrete, re-checkable proof of minimality.
