# Grid, graph and route solvers

Feature 216 (R02-F16). Spec: [specs/216-grid-graph-and-route-solver-toolkit](../../specs/216-grid-graph-and-route-solver-toolkit/spec.md).

## The rule

Every answer comes with a proof that a small checker accepts without running the solver again. A puzzle a player is
given is solvable, or honestly marked impossible, because a certificate says so, and the same question gives the same
answer on every device (integer costs, fixed tie rules).

## Parts (VisualCoreSimulation)

- `RouteGraph`: nodes 0 ..< n (at most 1,048,576), directed edges (at most 4,194,304) with integer costs 0 … 1,000,000,
  kept per node in insertion order. `GridGraph` turns a grid of open and blocked cells (sides up to 4,096, at most
  1,048,576 cells) into one, with four or eight neighbours and no corner cutting, and gives never-overestimating
  estimates (Manhattan, Chebyshev).
- `RouteSearch.breadthFirst` (fewest steps, edges in insertion order) and `RouteSearch.bestFirst` (cheapest, popping the
  smallest (g + h, h, node id)) within a budget of expansions; running out is "gave up", never "unreachable".
- `TimeExpandedGraph.earliestArrival` over a `RouteSchedule` (which cells are open at each of up to 4,096 steps), with
  waiting allowed or forbidden.
- `MinimumCut.between` finds the fewest edges separating two nodes, with as many edge-disjoint routes.
- `SubgraphMatcher` finds placements of a pattern (at most 32 nodes) in an undirected graph and decides isomorphism
  within a budget of 10,000,000 extension steps.

## Certificates

`SolverCertificate` (JSON schema 1, sorted keys) and `CertificateChecker`:

| Answer | Certificate | What the checker confirms |
|---|---|---|
| A route | route and node potentials π | the route's edges and cost; π(start) = 0, π(v) ≤ π(u) + c on every edge, π(goal) = cost, so no route is cheaper |
| Unreachable | reachable node set | it holds the start, not the goal, and no edge leaves it |
| A timed route | timed states | every state open, every step a move or a permitted wait |
| Unreachable in time | reachable timed states | it holds the start state, no goal state, and no move or wait leaves it |
| A cut | cut edges and edge-disjoint routes | equal counts, disjoint valid routes, and the cut separates |
| A placement | the map | injective and every pattern edge lands on a graph edge |
| Nothing found | the count of an exhaustive search | recorded only; refused as not checkable |

Two claims are proved by tests against references rather than by a certificate: that a timed route is the earliest,
and an exhaustive "no placement".

## Failures

`RouteError` reason codes: `r2-f16.empty-graph`, `r2-f16.graph-limit`, `r2-f16.node-range`, `r2-f16.negative-cost`,
`r2-f16.blocked-endpoint`, `r2-f16.schedule-limit`, `r2-f16.pattern-limit`, `r2-f16.budget`,
`r2-f16.certificate-rejected` (with the failed rule), `r2-f16.newer-schema`, `r2-f16.malformed`; the experience that
reports one adds its id, seed and tick.

## Sources

Breadth-first search, A* (Hart, Nilsson and Raphael, 1968), shortest augmenting paths for maximum flow (Edmonds and
Karp, 1972) and backtracking subgraph matching are textbook algorithms. All code is original to VisualCore.
