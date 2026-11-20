# Contract: public API (R02-F16)

VisualCoreSimulation (pure). All throwing members use `throws(RouteError)`.
- `public enum RouteError: Error, Equatable, Sendable { case emptyGraph, graphLimit(String), nodeRange(Int), negativeCost(Int), blockedEndpoint(Int), scheduleLimit, patternLimit(Int), budget(Int), certificateRejected(String), newerSchema(Int), malformed(String); public var reasonCode: String }`
- `public struct RouteEdge: Sendable, Equatable, Hashable { public let to: Int; public let cost: Int }`
- `public struct RouteGraph: Sendable, Equatable { public static let maxNodes = 1_048_576; public static let maxEdges = 4_194_304; public static let maxCost = 1_000_000; public let nodeCount: Int; public private(set) var edgeCount: Int; public init(nodeCount: Int) throws; public mutating func addEdge(from: Int, to: Int, cost: Int = 1) throws; public mutating func addUndirectedEdge(_ a: Int, _ b: Int, cost: Int = 1) throws; public func edges(from: Int) -> [RouteEdge]; public func contains(_ node: Int) -> Bool; public func hasEdge(from: Int, to: Int) -> Bool; public func cheapestCost(from: Int, to: Int) -> Int?; public func adjacent(_ a: Int, _ b: Int) -> Bool /* undirected view: either direction */ }`
- `public struct RoutePath: Sendable, Equatable, Codable { public let nodes: [Int]; public let cost: Int; public var steps: Int; public init(nodes: [Int], cost: Int) }`
- `public enum GridNeighbourhood: String, Sendable, Codable, CaseIterable { case four, eight }`
- `public struct GridGraph: Sendable, Equatable { public static let maxSide = 4_096; public static let maxCells = 1_048_576; public let width: Int; public let height: Int; public let neighbourhood: GridNeighbourhood; public init(width: Int, height: Int, neighbourhood: GridNeighbourhood = .four, blocked: Set<Int> = []) throws; public func node(x: Int, y: Int) -> Int; public func cell(of node: Int) -> (x: Int, y: Int); public func isOpen(_ node: Int) -> Bool; public func graph() -> RouteGraph /* unit costs; offsets in order (0,−1),(1,0),(0,1),(−1,0) then (1,−1),(1,1),(−1,1),(−1,−1); diagonal only if both orthogonal neighbours open */; public func estimate(to goal: Int) -> @Sendable (Int) -> Int /* Manhattan for four, Chebyshev for eight */ }`
- `public struct TimedState: Sendable, Equatable, Hashable, Codable { public let node: Int; public let time: Int; public init(node: Int, time: Int) }`
- `public struct RouteSchedule: Sendable, Equatable { public static let maxSteps = 4_096; public static let maxStates = 16_777_216; public let cellCount: Int; public let steps: Int; public init(cellCount: Int, steps: Int, isOpen: (_ cell: Int, _ time: Int) -> Bool) throws; public func isOpen(_ cell: Int, at time: Int) -> Bool /* false outside 0..<steps or the cells */ }`
- `public struct CutEdge: Sendable, Equatable, Hashable, Codable { public let from: Int; public let to: Int; public init(from: Int, to: Int) }`
- `public enum SolverCertificate: Sendable, Equatable { public static let schema = 1; case route(path: RoutePath, potentials: [Int]); case unreachable(start: Int, goal: Int, reachable: [Int] /* sorted */); case timedRoute(states: [TimedState], allowWaiting: Bool); case timedUnreachable(start: Int, goal: Int, startTime: Int, allowWaiting: Bool, reachable: [TimedState] /* sorted by time, node */); case cut(source: Int, sink: Int, edges: [CutEdge], routes: [RoutePath]); case placement(map: [Int]); case exhausted(examined: Int); public var kind: String; public func encoded() -> Data; public static func decode(_ data: Data) throws -> SolverCertificate }` and `Codable`.
- `public enum RouteOutcome: Sendable, Equatable { case found(RoutePath, SolverCertificate); case unreachable(SolverCertificate); case gaveUp(expanded: Int) }`
- `public enum RouteSearch { public static let maxBudget = 16_777_216; public static func breadthFirst(in graph: RouteGraph, from: Int, to: Int, budget: Int? = nil) throws -> RouteOutcome; public static func bestFirst(in graph: RouteGraph, from: Int, to: Int, estimate: (Int) -> Int = { _ in 0 }, budget: Int? = nil) throws -> RouteOutcome }` — endpoints outside the graph → `nodeRange`; budget outside 1 … maxBudget → `budget`; the certificate of `found` is `.route` with potentials (research R4), of `unreachable` `.unreachable`.
- `public enum TimedOutcome: Sendable, Equatable { case arrived(states: [TimedState], certificate: SolverCertificate); case unreachable(SolverCertificate) }`
- `public enum TimeExpandedGraph { public static func earliestArrival(in graph: RouteGraph, schedule: RouteSchedule, from: Int, to: Int, startTime: Int = 0, allowWaiting: Bool = true) throws -> TimedOutcome }` — schedule cellCount ≠ nodeCount → `scheduleLimit`; start state closed → `blockedEndpoint(from)`; graph edge costs are ignored (each move is one step).
- `public struct CutResult: Sendable, Equatable { public let edges: [CutEdge] /* sorted */; public let routes: [RoutePath]; public let certificate: SolverCertificate }`
- `public enum MinimumCut { public static func between(_ source: Int, and sink: Int, in graph: RouteGraph) throws -> CutResult }` — source == sink → `graphLimit("source-equals-sink")`.
- `public struct MatchOutcome: Sendable, Equatable { public let placements: [[Int]]; public let complete: Bool; public let examined: Int; public let certificates: [SolverCertificate] /* one .placement per placement, or [.exhausted] when complete and none */ }`
- `public enum SubgraphMatcher { public static let maxPatternNodes = 32; public static let maxPlacements = 100_000; public static let maxSteps = 10_000_000; public static func placements(of pattern: RouteGraph, in graph: RouteGraph, limit: Int = maxPlacements, budget: Int = maxSteps) throws -> MatchOutcome; public static func isomorphic(_ a: RouteGraph, _ b: RouteGraph, budget: Int = maxSteps) throws -> Bool? /* nil when the budget ran out */ }` — matching uses the undirected view (`adjacent`), ignoring self-loops and costs.
- `public enum CertificateChecker { public static func verify(_ certificate: SolverCertificate, in graph: RouteGraph) throws; public static func verify(_ certificate: SolverCertificate, in graph: RouteGraph, schedule: RouteSchedule) throws; public static func verify(_ certificate: SolverCertificate, pattern: RouteGraph, in graph: RouteGraph) throws }` — a failed rule throws `certificateRejected(<rule>)`; `.exhausted` is refused with `certificateRejected("not-checkable")`.

As built (2026-11-19), where the contract above left a choice open:
- `RouteSearch.bestFirst` clamps the estimate to 0 … maxEdges · maxCost so no priority overflows; `breadthFirst` ignores
  edge costs and its `RoutePath.cost` and potentials count steps, which the checker accepts as a fewest-steps
  certificate when `cost == steps`.
- `MinimumCut.between` checks the node range before source = sink and returns the source-side cut (duplicates kept
  for parallel edges).
- `TimeExpandedGraph.earliestArrival` checks schedule size, then endpoints, then the start time, then the start
  state; a goal that is never open comes back unreachable.
- `SubgraphMatcher.isomorphic` rules out differing degree sequences first and refuses graphs above 32 nodes with
  `patternLimit`; a search stopped by its limit or budget with nothing found returns no certificate.
- `CertificateChecker` rule names: route `empty-route`, `node-range`, `missing-edge`, `cost-mismatch`,
  `potentials-size`, `potential-start`, `potential-edge`, `potential-goal`; unreachable `node-range`, `unsorted`,
  `start-missing`, `goal-present`, `not-closed`; timedRoute `empty-route`, `node-range`, `closed-state`, `time-step`,
  `missing-edge`, `wait-forbidden`; timedUnreachable `node-range`, `unsorted`, `start-missing`, `goal-present`,
  `not-closed`; cut `node-range`, `unsorted`, `count-mismatch`, `route-invalid`, `not-disjoint`, `edge-missing`,
  `not-separating`; placement `size-mismatch`, `node-range`, `not-injective`, `missing-edge`; any overload
  `not-checkable`, `needs-schedule`, `needs-pattern`.
