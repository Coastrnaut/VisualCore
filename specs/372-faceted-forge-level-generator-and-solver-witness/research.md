# Research: R02-G08-02

- **R1 The lower bound is the piece count.** Decision: a target of P pieces needs at least P − 1 cuts, because every
  accepted cut adds exactly one piece; a winning sequence of P − 1 cuts is therefore certified smallest. Rationale: an
  exact, cheap proof instead of an exhaustive search over all shorter sequences. Alternatives: breadth-first search over
  all cut sequences (branching in the hundreds per level of depth; infeasible).
- **R2 Depth-first search with partition pruning.** Decision: the solver re-finds a sequence from the crystal alone in
  the rules' fixed order, keeping only cuts whose pieces can still be partitioned into the remaining target (subset sums
  of exact shares; a piece given one entry has its face count). Rationale: exact shares make wrong cuts fail fast; the
  stored witness is the solver's, not the generator's. Alternatives: storing the generator's cuts (no independent proof).
- **R3 Work counted, not timed.** Decision: count cut evaluations; bound 20,000 per level; a candidate over the bound is
  skipped. Rationale: deterministic on every machine; about 2.6 s of debug cutting at worst.
- **R4 Generated, not authored, targets.** Decision: a candidate's target is what a seeded sequence of c cuts produces,
  so a solution always exists; filters keep shares at least 1/32 and bands 3 … 5 use a body diagonal. Rationale: solvable
  by construction, varied by seed, harder by band.
- **R5 Ranges widened for the manifest.** Decision: budget 1 … 20 and target faces 4 … 34. Rationale: the manifest's
  budgets are 8 … 19; widening keeps every earlier level valid.
