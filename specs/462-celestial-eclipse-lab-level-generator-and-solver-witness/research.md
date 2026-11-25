# Research: R02-G17-02

- **R1 Search by phase changes.** Decision: the solver searches phase settings by the number of movable bodies whose
  phase differs from the start, depth 1, 2, …. Rationale: a later phase change of the same body overrides an earlier
  one, so the settings reachable with at most d actions are exactly those differing on at most d movable bodies; the
  first win at the smallest depth is a minimal plan and exhausting every smaller depth proves nothing shorter wins.
- **R2 Pair-interval table.** Decision: for every pair of bodies and every pair of their phases, the pair's eclipse
  intervals over the horizon are computed once per level with the kernel's exact overlap and visibility rules; a
  setting's timeline is the merge of its pairs' lists, walked by the kernel's judge. Rationale: "overlap interval
  enumeration" in the catalog; the prototype judged 20 band-5 entries in 7.0 s on a debug build against 27 s with the
  whole-sky timeline, and agreed with the kernel on every win (a precondition in the prototype).
- **R3 Fixed order.** Decision: subsets of movable bodies in lexicographic order, then new phases in lexicographic order,
  skipping each starting phase. Rationale: deterministic; the plan found is the same on every build.
- **R4 Constructive generator; ranges measured first.** Decision: draw bodies on integer ellipse orbits in depth layers,
  draw winning phases, take the first target-count events of their timeline as the target with windows of 0 … 2 ticks
  either side, then move some movable bodies away; plan ranges 1 … 2, 2 … 3, 3 … 4, 3 … 4, 4 … 5. Rationale: building
  from a winning setting guarantees a win exists; on the real manifest the prototype certified every entry within
  candidate index 4 and the band means rose (1.65, 2.15, 3.25, 3.40, 4.40) — the lesson of R02-G10-02: simulate a
  generator's filters before writing them down.
- **R5 Integer orbits.** Decision: positions from a fixed table of round(1000·cos), round(1000·sin) for periods 4 … 8,
  scaled by the semi-axes and rounded half away from zero; layers 4·rank − 12 with a tilt of −1 … 1 keep every pair
  depth-ordered. Rationale: no floating point in any rule, identical on every platform.
- **R6 Neighbour rule.** Decision: skip a candidate whose (front, back) target sequence equals the previous level's.
  Rationale: the manifest asks for a genuinely different puzzle from adjacent seeds; the prototype found one such
  repeat in 100 entries.
- **R7 State digest.** Decision: 16 hex characters of the SHA-256 of the phases and the actions spent after each action,
  in a canonical text. Rationale: compact, detects any change in the rules.
- **R8 Counterexample.** Decision: the depth one below the plan and the number of settings at that depth, none winning.
  Rationale: a concrete, re-checkable proof of minimality.
