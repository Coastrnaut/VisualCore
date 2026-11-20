# Data model: R02-F16

| Entity | Fields | Rules |
|---|---|---|
| RouteGraph | nodeCount, edges per node (to, cost) in insertion order | 1 ≤ n ≤ 1,048,576; ≤ 4,194,304 edges; cost 0 … 1,000,000 |
| GridGraph | width, height, neighbourhood (four, eight), blocked cells | width, height 1 … 4,096; ≤ 1,048,576 cells; node y·width + x; no corner cutting |
| RoutePath | nodes, cost | consecutive nodes joined by an edge; steps = nodes.count − 1 |
| RouteSchedule | cellCount, steps T, open bits | T 1 … 4,096; cellCount × T ≤ 16,777,216 |
| TimedState | node, time | must be open in the schedule |
| CutEdge | from, to | an edge of the graph |
| SolverCertificate | route, unreachable, timedRoute, timedUnreachable, cut, placement, exhausted | JSON schema 1, sorted keys |
| RouteError | emptyGraph, graphLimit, nodeRange, negativeCost, blockedEndpoint, scheduleLimit, patternLimit, budget, certificateRejected, newerSchema, malformed | `reasonCode` `r2-f16.*` |
