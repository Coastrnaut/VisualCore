# Implementation Plan: R02-F16 — Grid, graph, and route-solver toolkit

**Branch**: `216-grid-graph-and-route-solver-toolkit` (spec directory only; work on `main`) | **Date**:
2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

In VisualCoreSimulation: a `RouteGraph` (directed, integer costs) and a `GridGraph` that builds one; `RouteSearch`
(breadth-first and best-first with deterministic ties and a budget); `TimeExpandedGraph` (earliest arrival over a
`RouteSchedule`); `MinimumCut` (unit-capacity shortest augmenting routes); `SubgraphMatcher` (placements and
isomorphism of undirected simple graphs); `SolverCertificate` (`Codable` schema 1) for every answer and a
`CertificateChecker` that verifies each one without the solvers. Failures are `RouteError` with `r2-f16.*` codes.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`SeededRandom` for fixtures), which
depends on VisualCoreMath only. No new module, dependency, GPU, GLSL or Objective-C++ code (nothing renders; consumers
draw routes and hints with the existing curve and mesh paths).
**Seeds**: fixtures use `SeededRandom` seeded 2_016; references are small exhaustive or step-by-step searches written in
the tests.
**Testing**: `swift test --package-path Packages/VisualCore`; ExperiencesCreative on sim-27.2 and VisualCoreRendering on
sim-27.2 and sim-26.5 as regression (LightMaze and Visual Programming Lab are unchanged); reference regression in two
chunks; script tests.
**Performance**: bounded by arithmetic — searches O((V + E) log V) within their expansion budget; cuts O(k·E) for a cut of
size k; matching within 10,000,000 extension steps; checkers O(V + E) per certificate. Fixtures are small graphs
(≤ 2,500 nodes) so each test stays well under a second and light beside the timed R02-F05 test.
**Constraints**: additive; integer arithmetic only; every limit refused with a reason code.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering. |
| II App-neutral API · II-a reference | PASS — generic graphs, no game rules; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — none. |
| IV Host-testable | PASS — pure, host-tested. |
| IX Bounded input | PASS — node, edge, cost, schedule, pattern and budget limits, each refused by code. |
| X Licensing and provenance | PASS — textbook algorithms (breadth-first search, A*, Edmonds–Karp, backtracking matching); original code. |
| XI Stable identity | PASS — certificates in schema 1; newer refused. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/RouteError.swift          new  RouteError + reasonCode (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/RouteGraph.swift          new  RouteEdge, RouteGraph, RoutePath (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/GridGraph.swift           new  GridNeighbourhood, GridGraph (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/RouteSchedule.swift       new  RouteSchedule, TimedState (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/SolverCertificate.swift   new  SolverCertificate, CutEdge, Codable schema 1 (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/RouteSearch.swift         new  RouteOutcome, RouteSearch, internal MinHeap (agent A)
Packages/VisualCore/Sources/VisualCoreSimulation/TimeExpandedGraph.swift   new  TimedOutcome, TimeExpandedGraph (agent B)
Packages/VisualCore/Sources/VisualCoreSimulation/MinimumCut.swift          new  CutResult, MinimumCut (agent B)
Packages/VisualCore/Sources/VisualCoreSimulation/SubgraphMatcher.swift     new  MatchOutcome, SubgraphMatcher (agent C)
Packages/VisualCore/Sources/VisualCoreSimulation/CertificateChecker.swift  new  CertificateChecker (agent D)
Packages/VisualCore/Tests/VisualCoreSimulationTests/GraphFoundationTests.swift (lead), RouteSearchTests.swift (A),
  TimeExpandedGraphTests.swift, MinimumCutTests.swift (B), SubgraphMatcherTests.swift (C),
  CertificateCheckerTests.swift (D)   new
docs/architecture/route-solvers.md (new), docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none of existing data. **Rollback**: revert the commits (additive files only).

## Parallel work

Lead first writes the five shared files and their test. Then agents A–D in parallel, each writing only its own files
against contracts/api.md. Lead: docs, API baseline, runs, commits.
