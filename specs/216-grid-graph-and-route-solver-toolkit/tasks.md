# Tasks: R02-F16 — Grid, graph, and route-solver toolkit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F16 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F16 --name <check> -- <command>`. Commit after every task
with its check record (no trailers). No {owner} and no {device} tasks (solve times are measured by the consumers in the
device campaign). New public names checked against Packages and Apps. Fixture seed 2_016; fixtures ≤ 2,500 nodes so
tests stay light beside the timed R02-F05 test.

## Phase 1: Setup

- [X] T-R02F16-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore`; the rendering — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F16.baseline-host-5.json (exit 0; attempts 1–4 failed only the timed R02-F05 mesh-budget and audio-analysis asserts at load average 40–95 on 18 cores from another session, fixed in the test commit before it); rendering baseline = R02-F15.rendering-27.json and rendering-26.json (exit 0)
  baseline is R02-F15's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02F16-002 Create `Packages/VisualCore/Sources/VisualCoreSimulation/RouteError.swift`, `Packages/VisualCore/Sources/VisualCoreSimulation/RouteGraph.swift` (RouteEdge, RouteGraph "1 ≤ n ≤ 1,048,576; — Verified 2026-11-19: lead 2026-11-19: R02-F16.host.json (exit 0, full suite; GraphFoundationTests 5 passed: limits and refusals, grid without corner cutting, schedule bounds, seven kinds round-trip byte for byte, newer and damaged refused)
  ≤ 4,194,304 edges; cost 0 … 1,000,000", RoutePath), `Packages/VisualCore/Sources/VisualCoreSimulation/GridGraph.swift` ("width, height 1 … 4,096; ≤ 1,048,576
  cells; node y·width + x; no corner cutting", offset order of contracts/api.md, Manhattan/Chebyshev estimates),
  `Packages/VisualCore/Sources/VisualCoreSimulation/RouteSchedule.swift` ("T 1 … 4,096; cellCount × T ≤ 16,777,216", TimedState) and `Packages/VisualCore/Sources/VisualCoreSimulation/SolverCertificate.swift`
  (seven kinds, JSON schema 1, sorted keys, newer refused, damaged malformed) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/GraphFoundationTests.swift`
  (limits and refusals, grid conversion and no corner cutting, schedule bounds, certificate round trip byte for byte
  for every kind, schema 2 and damaged JSON refused); `--name host`

## Phase 3: Story 1 — find a route (P1) 🎯

- [X] T-R02F16-003 [P] [US1] Create `Packages/VisualCore/Sources/VisualCoreSimulation/RouteSearch.swift` (RouteOutcome; breadth-first in edge insertion order; — Verified 2026-11-19: lead retest 2026-11-19: R02-F16.host-3.json (exit 0, full suite; R02-F16.host-2.json had failed only the mesh-budget timing beside the full suite, now asserted in R02-F16.timing.json, exit 0); RouteSearchTests 8 passed (500 seeded grids and 500 costed graphs equal reference optima and repeat; potentials hold; gaveUp; estimate refusal; estimates clamped against overflow)
  best-first by (g + h, h, node id) on an internal binary heap; budget "1 … 16,777,216, default n", gaveUp; potentials per
  research R4 and the "estimate" refusal; unreachable closed set) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/RouteSearchTests.swift` (500 seeded grids and
  500 seeded costed graphs equal a reference Bellman–Ford or exhaustive optimum and repeat identically; start = goal;
  blocked and out-of-range endpoints; budget gaveUp; overestimating estimate refused); `--name host-2`

## Phase 4: Story 2 — route through time (P1)

- [X] T-R02F16-004 [P] [US2] Create `Packages/VisualCore/Sources/VisualCoreSimulation/TimeExpandedGraph.swift` (TimedOutcome; breadth-first over (cell, t) in time order — Verified 2026-11-19: lead retest 2026-11-19: R02-F16.host-3.json (exit 0, full suite; R02-F16.host-2.json had failed only the mesh-budget timing beside the full suite, now asserted in R02-F16.timing.json, exit 0); TimeExpandedGraphTests 3 passed (200 seeded schedules equal a reference simulation, waits allowed and forbidden; closed unreachable sets; refusals)
  per research R6; waiting allowed or forbidden) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/TimeExpandedGraphTests.swift` (200 seeded schedules equal a
  step-by-step reference simulation; no closed state on any route; schedule mismatch and closed start refused);
  `--name host-3`

## Phase 5: Story 3 — cut sets (P2)

- [X] T-R02F16-005 [P] [US3] Create `Packages/VisualCore/Sources/VisualCoreSimulation/MinimumCut.swift` (CutResult; Edmonds–Karp on unit capacities per research R7; — Verified 2026-11-19: lead retest 2026-11-19: R02-F16.host-3.json (exit 0, full suite; R02-F16.host-2.json had failed only the mesh-budget timing beside the full suite, now asserted in R02-F16.timing.json, exit 0); MinimumCutTests 3 passed (200 seeded graphs: cut = edge-disjoint routes, separates, equals brute force on ≤ 12 edges; parallel edges; refusals)
  cut edges sorted; edge-disjoint routes) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/MinimumCutTests.swift` (200 seeded graphs: cut size equals the
  route count, routes pairwise edge-disjoint, removing the cut separates, size equals a brute-force minimum on graphs
  of ≤ 12 edges; source = sink refused); `--name host-4`

## Phase 6: Story 4 — patterns (P2)

- [X] T-R02F16-006 [P] [US4] Create `Packages/VisualCore/Sources/VisualCoreSimulation/SubgraphMatcher.swift` (MatchOutcome; pattern "at most 32" nodes; placements in — Verified 2026-11-19: lead retest 2026-11-19: R02-F16.host-3.json (exit 0, full suite; R02-F16.host-2.json had failed only the mesh-budget timing beside the full suite, now asserted in R02-F16.timing.json, exit 0); SubgraphMatcherTests 6 passed (200 seeded cases equal brute-force placement lists; isomorphism of 50 relabellings; P4 vs K1,3 and C6 vs 2·K3; limits and budgets)
  lexicographic order per research R8, "at most 100,000", budget 10,000,000 steps; isomorphism) with
  `Packages/VisualCore/Tests/VisualCoreSimulationTests/SubgraphMatcherTests.swift` (200 seeded cases equal an exhaustive permutation count; isomorphic relabellings
  recognised, non-isomorphic equal-size graphs not; pattern larger than graph gives none; limits refused; budget gives
  incomplete); `--name host-5`

## Phase 7: Story 5 — certify (P1)

- [X] T-R02F16-007 [US5] Create `Packages/VisualCore/Sources/VisualCoreSimulation/CertificateChecker.swift` (three verify overloads; rule names in — Verified 2026-11-19: lead retest 2026-11-19: R02-F16.host-3.json (exit 0, full suite; R02-F16.host-2.json had failed only the mesh-budget timing beside the full suite, now asserted in R02-F16.timing.json, exit 0); CertificateCheckerTests 10 passed (every kind accepted; ≥ 413 seeded tampered certificates refused with their exact rule) and CertificateIntegrationTests 3 passed (300 route, 50 timed and 50 cut certificates from the solvers accepted; placements accepted; certificates refused on a changed graph)
  `certificate-rejected`; exhausted refused "not-checkable") with `Packages/VisualCore/Tests/VisualCoreSimulationTests/CertificateCheckerTests.swift` (every certificate
  from seeded runs of all solvers accepted; at least 100 seeded tampered certificates refused: wrong edge, wrong cost,
  broken potentials, open reachable set, closed timed state, overlapping cut routes, cut that does not separate,
  placement missing an edge, non-injective placement); `--name host-6`

## Phase 8: Regression, documentation and close

- [ ] T-R02F16-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26` and `--name experiences`
- [ ] T-R02F16-009 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/route-solvers.md`;
  section in `Packages/VisualCore/README.md`; section 13.4 row R02-F16 "As built" in
  `docs/catalog/shared-feature-map.json` and `render_autocreator.py`
- [ ] T-R02F16-010 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02F16-011 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02F16-012 Script tests (`--name script-tests`)
- [ ] T-R02F16-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003, 004, 005, 006} in parallel → 007 (needs every solver's certificates) → 008 → 009 → 010 → 011 → 012 →
013. Agents: A (003), B (004 and 005), C (006), D (007, written beside them against contracts/api.md and run after them).
Shared files (002) stay with the lead. MVP: Stories 1 and 5.
