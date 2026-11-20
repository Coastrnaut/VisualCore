# Research: R02-F16

- **R1 Home.** Decision: VisualCoreSimulation. Rationale: pure, already holds the deterministic runner and seeded
  randomness; the R02-F05 precedent avoids a new module. Alternatives: a new VisualCorePuzzle module (more targets, app
  dependency audit and project changes for no gain).
- **R2 Integer costs.** Decision: `Int` costs 0 … 1,000,000. Rationale: exact equality across devices; totals stay below
  2⁶³. Alternatives: `Double` (ties and sums differ by rounding).
- **R3 Deterministic best-first.** Decision: a binary min-heap ordered by (g + h, h, node id), lazy deletion. Rationale:
  a total order makes the popped sequence, and so the route, unique. Breadth-first follows edge insertion order.
- **R4 Optimality certificate.** Decision: node potentials from a cheapest-first pass truncated at the route cost C,
  π(v) = min(dist(v), C) (unreached nodes C). Rationale: if every edge satisfies π(v) ≤ π(u) + c, any route's cost is at
  least π(goal) − π(start) = C, checkable in O(V + E). An overestimating estimate yields a costlier route, which the solver
  detects (π(goal) < C) and refuses with `certificate-rejected` ("estimate").
- **R5 Unreachability.** Decision: the reachable set R, closed under edges, containing the start and not the goal.
  Rationale: a closed set no route can leave is a complete proof.
- **R6 Time expansion.** Decision: breadth-first over (cell, t) in increasing t, states indexed t·n + cell, never building
  the layered graph explicitly. Rationale: memory n·T bits for visited; earliest arrival is the first goal state reached.
- **R7 Minimum cut.** Decision: Edmonds–Karp on unit capacities per directed edge; the cut is the edges from the residual
  reachable set to its complement; the flow decomposes into edge-disjoint routes. Rationale: max-flow = min-cut gives a
  certificate of two matching counts.
- **R8 Matching.** Decision: backtracking over pattern nodes in a fixed order (highest degree first, ties by id),
  candidates in increasing graph id, pruned by degree and adjacency to already-mapped nodes. Rationale: deterministic
  lexicographic enumeration in that order; bounded by an extension-step budget. Alternatives: VF2 state tables (more
  code, same worst case).
