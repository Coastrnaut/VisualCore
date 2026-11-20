# Research: R02-F20

- **R1 Exact equivalence by construction.** Decision: the grid only narrows the candidates; distances, the radius test,
  the sort and the limit are the same expressions as `NeighbourSearch`. Rationale: candidates within the scanned cells
  include every agent within the radius, so the lists are equal, not merely similar.
- **R2 Hashed integer cells.** Decision: a dictionary keyed by the integer cell, agents appended in index order.
  Rationale: no bounds needed, agents outside any area still found; order inside a cell does not matter because results
  are re-sorted. Cell indices are clamped to ±2^40 (no integer overflow for far agents; any agent within r of a clamped
  agent lies in a clamped or nearby cell inside the window), and a window wider than the number of occupied cells falls
  back to scanning every occupied cell, so a huge radius costs at most one pass.
- **R3 Exact rotation for a uniform field.** Decision: the Lorentz force q v × B with B along z only turns the velocity, so
  it is applied as an exact rotation by −q B h each step instead of an Euler increment. Rationale: speed is preserved to
  rounding and a whole-step period closes the orbit; Euler would spiral outward.
- **R4 Softened poles.** Decision: Plummer-style softening (|r|² + ε²)^{3/2}. Rationale: finite at the pole with a closed
  bound 2 |s q| / (3√3 ε²) at |r| = ε / √2.
- **R5 Reflecting and wrapping edges.** Decision: reflect the overshoot and flip the velocity component (walled), or take
  the position modulo the bounds (wrapping); a reflection that would still land outside (a step longer than the box)
  is clamped to the bound. Rationale: every agent provably stays inside.
- **R7 JSON needs finite values.** Decision: `Swarm` refuses non-finite agents and invalid steering parameters, and
  `decode` re-runs the initialisers so a stored form that breaks a rule is `.malformed`. Rationale: `JSONEncoder` cannot
  write NaN or infinity, and a step from valid values stays finite (forces and speed capped).
- **R6 Bilinear splatting with folded edges.** Decision: weights to the four neighbouring cell centres, indices clamped to
  the grid. Rationale: each agent contributes exactly 1, so the total is the in-area count.
