# Feature Specification: R02-F16 — Grid, graph, and route-solver toolkit

**Feature Branch**: `216-grid-graph-and-route-solver-toolkit` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Clarified

**Ledger gate**: R02-F16 (migration ledger, shared round feature) · ID namespace FR-R02F16-###, SC-R02F16-###, T-R02F16-###

**Input**: User description: the archived R02-F16 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"BFS/A*; time-expanded graphs; cut sets; graph isomorphism subsets; solver certificates", with the canonical overrides
of ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/216-grid-graph-and-route-solver-toolkit`; FR-R02F16-###, SC-R02F16-###,
  T-R02F16-###.
- **Section 13 disposition: new, in an existing module.** The framework has no shared graph search, flow or matching
  code. LightMaze's `Solver` is an orientation search bound to its own board, Visual Programming Lab's graphs are node
  editors, and `FieldGrid` holds numeric fields, not connectivity. The section 13.4 map names a new module
  (VisualCorePuzzle); following the R02-F05 precedent (its mesh compiler went into an existing module rather than a new
  one), this toolkit is added to an existing pure module without a new module. LightMaze and Visual Programming Lab are
  unchanged.
- **Who the users are:** the player of Colorfall Canyons, Echo Cartographer, Acoustic Constellator, Mycelium Architect or
  Crystal Quarry, who is given puzzles that are always solvable (or honestly marked impossible) and hints that lead
  along a real route; the engineer and release QA, who need every generated puzzle certified by a proof that a small,
  independent checker accepts.
- **Prerequisites:** R02-F03 (numerical foundations, seeded randomness) is pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** none; the consumers measure solve times on D1–D3 in the device
  campaign. **Owner-only items:** none.

## Clarifications

### Session 2026-11-19

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-19): VisualCoreSimulation (depends on VisualCoreMath only) holds `FieldGrid`,
`SeededRandom` and the fixed-step runner; no shared graph, heap, flow or matching type exists in Packages or Apps;
LightMaze's `Solver` and Visual Programming Lab's `VisualGraph` are experience-local; the names `GridGraph`,
`RouteGraph`, `RouteSearch`, `RoutePath`, `TimeExpandedGraph`, `MinimumCut`, `SubgraphMatcher`, `SolverCertificate`,
`CertificateChecker` and `RouteError` are free.

- Q: Where does the toolkit live and what are its sizes and units? → A: in VisualCoreSimulation (pure, host-tested,
  seeded fixtures through `SeededRandom`), no new module. Nodes are `Int` ids 0 ..< n with n ≤ 1,048,576 and at most
  4,194,304 directed edges; edge costs are `Int` 0 … 1,000,000 (totals cannot overflow). A `GridGraph` is width × height
  (each 1 … 4,096, at most 1,048,576 cells), node id y·width + x, neighbourhood four or eight, unit costs; a diagonal
  move is allowed only when both orthogonal cells beside it are open (no corner cutting). Rationale: integer costs make
  every answer exact and identical on every device. Impact: FR-R02F16-001, 002; SC-R02F16-001.
- Q: How are searches ordered, budgeted and proved optimal? → A: breadth-first search expands each node's edges in
  insertion order and returns the first route found; best-first search pops the smallest (g + h, h, node id) and the
  estimate h is a caller function that must never overestimate (an overestimate gives a valid but possibly costlier
  route, which the optimality check below then refuses). Each search takes a budget of node expansions (1 … 16,777,216,
  default n); running out returns "gave up", never "unreachable". A found route's certificate carries node potentials
  π (π(start) = 0, π(v) ≤ π(u) + c(u, v) for every edge, π(goal) = the route's cost), computed by a truncated
  cheapest-first pass, which proves no cheaper route exists; "unreachable" carries the set of reachable nodes, which
  contains the start, not the goal, and is closed under edges. Impact: FR-R02F16-002, 006; SC-R02F16-001, 005.
- Q: How are schedules and time-expanded searches defined? → A: a schedule says for each step t in 0 ..< T
  (T 1 … 4,096, cells × T ≤ 16,777,216) whether each cell is open; a move or a wait takes one step; a state (cell, t)
  must be open; waiting can be forbidden. The answer is the earliest arrival time with its timed route, found
  breadth-first over (cell, t) in time order; its certificate proves the route is feasible (every state open, every move
  an edge or a permitted wait), earliest-ness being proved by the tests against a reference simulation; "unreachable
  within T" carries the closed set of reachable states. Impact: FR-R02F16-003; SC-R02F16-002.
- Q: What do cuts and pattern matches mean exactly? → A: a cut is a minimum set of directed edges whose removal leaves no
  route from s to t, found by shortest augmenting routes on unit capacities; its certificate lists the cut edges and as
  many pairwise edge-disjoint s–t routes, and the checker confirms both counts, the disjointness and the separation (a
  closed reachable set after removal). Matching works on undirected simple graphs: a placement is an injective map from
  pattern nodes (at most 32) to graph nodes taking every pattern edge to a graph edge (not necessarily induced);
  placements are listed in lexicographic order of the map, at most 100,000, within a budget of 10,000,000 extension
  steps ("gave up" past it); two graphs with equal node and edge counts are isomorphic exactly when a placement exists.
  A placement certificate is checked edge by edge; "no placement" records the exhaustive count and is not independently
  checkable. Impact: FR-R02F16-004, 005; SC-R02F16-003, 004.
- Q: What is stored, and what are the failure codes? → A: `SolverCertificate` is `Codable` JSON schema 1 with sorted keys
  (`{"schema":1,"kind":…}` and the kind's fields: route, unreachable, timedRoute, timedUnreachable, cut, placement,
  exhausted); schema 1 is the first stored form, schema above 1 is refused. Reason codes (`RouteError`):
  `r2-f16.empty-graph`, `r2-f16.graph-limit`, `r2-f16.node-range`, `r2-f16.negative-cost`, `r2-f16.blocked-endpoint`,
  `r2-f16.schedule-limit`, `r2-f16.pattern-limit`, `r2-f16.budget`, `r2-f16.certificate-rejected` (with the failed rule),
  `r2-f16.newer-schema`, `r2-f16.malformed`; "gave up" is a result, not an error; the experience adds its id, seed and
  tick. Impact: FR-R02F16-006, 007, 008; SC-R02F16-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find a route (Priority: P1) 🎯

The engineer describes a grid of open and blocked cells, or a general graph with costs, and asks for the fewest-step or
cheapest route between two places. The same question always gives the same route.

**Why this priority**: every consumer routes something (water, echoes, roots, light).

**Independent Test**: on seeded grids and graphs, the route found is as short or as cheap as an exhaustive reference
says, ties are broken by a stated rule, and repeated runs give the identical route.

**Acceptance Scenarios**:

1. **Given** a grid with a route, **When** asked for the fewest steps, **Then** a shortest route is returned.
2. **Given** costed edges and an admissible estimate, **When** asked for the cheapest route, **Then** its cost equals the
   reference optimum.
3. **Given** no route, **When** asked, **Then** the answer is "unreachable" with a proof.

### User Story 2 - Route through time (Priority: P1)

Cells open and close on a schedule (gates, tides, pulses). The engineer asks for the earliest arrival when waiting is
allowed or forbidden.

**Independent Test**: on seeded schedules, the earliest arrival equals a step-by-step reference simulation; no route
steps onto a closed cell.

### User Story 3 - Find cut sets (Priority: P2)

The engineer asks for the fewest edges whose removal separates two places (where a wall must go, which roots to cut).

**Independent Test**: the cut's size equals the maximum number of edge-disjoint routes, and removing the cut separates
the two places.

### User Story 4 - Find a pattern inside a graph (Priority: P2)

The engineer asks whether a small pattern graph appears inside a larger graph (a constellation in the sky, a crystal
motif), and where.

**Independent Test**: every reported placement maps pattern edges to graph edges; seeded cases match an exhaustive
reference count; isomorphic graphs are recognised as such.

### User Story 5 - Certify and store a proof (Priority: P1)

Every answer carries a certificate (a route with its cost, an unreachable region closed under moves, a cut with matching
routes, a placement) that an independent checker verifies; certificates are saved with a schema version and checked
again later.

**Independent Test**: the checker accepts every honest certificate and refuses every tampered one in seeded fixtures;
stored certificates round-trip; newer and damaged forms are refused.

### Edge Cases

- **Start equals goal:** a route of zero steps.
- **Start or goal blocked or outside the graph:** refused with a named reason.
- **Negative costs or costs above 1,000,000:** refused with `r2-f16.negative-cost`.
- **An estimate that overestimates:** the route may be costlier than optimal and its certificate is then refused.
- **Search budget exceeded:** the answer is "gave up", never a wrong "unreachable".
- **A pattern larger than the graph:** no placement.
- **Empty graph or schedule of length 0:** refused or trivial, with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F16-001**: A grid MUST describe open and blocked cells with a chosen neighbourhood and convert to a graph.
- **FR-R02F16-002**: A route search MUST return a fewest-step route (breadth-first) or a cheapest route (best-first with an
  admissible estimate) with a stated deterministic tie rule, or an unreachable verdict, within a stated budget.
- **FR-R02F16-003**: A time-expanded search MUST find the earliest arrival over a cell schedule with waiting allowed or
  forbidden.
- **FR-R02F16-004**: A cut search MUST find a minimum edge cut between two nodes together with as many edge-disjoint
  routes as the cut has edges.
- **FR-R02F16-005**: A matcher MUST find placements of a pattern graph inside a graph (and decide isomorphism of equal
  sizes) within a stated budget.
- **FR-R02F16-006**: Every answer MUST carry a certificate that an independent checker verifies without re-running the
  solver (routes with optimality potentials, unreachable regions, timed routes, cuts with matching routes, placements);
  tampered certificates MUST be refused. Two claims are not independently checkable and are proved by the tests against
  references instead: that a timed route is the earliest, and an exhaustive "no placement" (recorded with its count).
- **FR-R02F16-007**: Certificates MUST have a versioned stored form; newer and damaged forms MUST be refused.
- **FR-R02F16-008**: Invalid requests MUST be refused with a stable reason code naming the feature.
- **FR-R02F16-009**: Existing experiences and their tests MUST be unchanged; every new public name carries
  documentation; the API baseline and the reference regression are updated.

### Key Entities

- **Grid**: size, blocked cells, neighbourhood.
- **Graph**: nodes, directed edges with non-negative costs.
- **Route**: node sequence, cost, steps.
- **Schedule**: which cells are open at each time step.
- **Cut**: edge set and matching edge-disjoint routes.
- **Placement**: map from pattern nodes to graph nodes.
- **Certificate**: one of the above, or an unreachable region, with what it proves.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F16-001**: On 500 seeded grids and 500 seeded costed graphs, every route equals the reference optimum in steps
  or cost and repeats identically.
- **SC-R02F16-002**: On 200 seeded schedules, the earliest arrival equals a reference simulation in every case.
- **SC-R02F16-003**: On 200 seeded graphs, the cut size equals the number of edge-disjoint routes and the cut separates the
  two nodes.
- **SC-R02F16-004**: On 200 seeded pattern cases, placement counts equal an exhaustive reference.
- **SC-R02F16-005**: The checker accepts every honest certificate and refuses every one of at least 100 seeded tampered
  certificates; stored certificates round-trip byte for byte; newer and damaged forms are refused.
- **SC-R02F16-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- Graphs are finite with integer costs; no geometry beyond grids is needed here.
- The consumer games do not exist yet; this slice ships the library and its proofs.
- No user interface: hint display, layout and accessibility belong to the consuming experiences.

## Traceability

| Source deliverable | Requirement |
|---|---|
| BFS/A* | FR-R02F16-001, 002 |
| Time-expanded graphs | FR-R02F16-003 |
| Cut sets | FR-R02F16-004 |
| Graph isomorphism subsets | FR-R02F16-005 |
| Solver certificates | FR-R02F16-006, 007 |
| Observability | FR-R02F16-008 |
| No Stage One breakage | FR-R02F16-009 |

## Negative Requirements / Excluded scope

- No GPU code, no new module, no change to LightMaze or Visual Programming Lab, no general constraint solver, no
  continuous path planning, no device run before ImplementationLock-100, no analytics.
