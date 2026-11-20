// RouteGraph — feature 216 (R02-F16) T-R02F16-002 (FR-R02F16-001, FR-R02F16-002; clarification Q1; research R2). A
// directed graph on nodes 0 ..< n with integer edge costs 0 … 1,000,000, kept per node in insertion order so every
// search over it is deterministic. Integer costs make every total exact and identical on every device; a route of at
// most 4,194,304 edges cannot overflow `Int`. The undirected view (`adjacent`) is what pattern matching uses.

/// A directed edge to a node with a cost.
public struct RouteEdge: Sendable, Equatable, Hashable {
    /// The node the edge leads to.
    public let to: Int
    /// The edge's cost, 0 … ``RouteGraph/maxCost``.
    public let cost: Int
}

/// A directed graph with integer edge costs, edges kept per node in insertion order.
public struct RouteGraph: Sendable, Equatable {
    /// The most nodes a graph has.
    public static let maxNodes = 1_048_576
    /// The most directed edges a graph has.
    public static let maxEdges = 4_194_304
    /// The largest edge cost.
    public static let maxCost = 1_000_000

    /// The number of nodes; nodes are 0 ..< nodeCount.
    public let nodeCount: Int
    /// The number of directed edges added.
    public private(set) var edgeCount: Int = 0
    private var adjacency: [[RouteEdge]]

    /// Creates a graph of `nodeCount` nodes and no edges; refuses 0 nodes with ``RouteError/emptyGraph`` and more than
    /// ``maxNodes`` with ``RouteError/graphLimit(_:)``.
    public init(nodeCount: Int) throws(RouteError) {
        guard nodeCount > 0 else { throw .emptyGraph }
        guard nodeCount <= Self.maxNodes else { throw .graphLimit("nodes") }
        self.nodeCount = nodeCount
        adjacency = Array(repeating: [], count: nodeCount)
    }

    /// Adds a directed edge after the existing edges of `from`; refuses nodes outside the graph, a cost outside
    /// 0 … ``maxCost`` and an edge beyond ``maxEdges``.
    public mutating func addEdge(from: Int, to: Int, cost: Int = 1) throws(RouteError) {
        guard contains(from) else { throw .nodeRange(from) }
        guard contains(to) else { throw .nodeRange(to) }
        guard (0...Self.maxCost).contains(cost) else { throw .negativeCost(cost) }
        guard edgeCount < Self.maxEdges else { throw .graphLimit("edges") }
        adjacency[from].append(RouteEdge(to: to, cost: cost))
        edgeCount += 1
    }

    /// Adds the edges a → b and b → a with the same cost (two directed edges).
    public mutating func addUndirectedEdge(_ a: Int, _ b: Int, cost: Int = 1) throws(RouteError) {
        guard contains(a) else { throw .nodeRange(a) }
        guard contains(b) else { throw .nodeRange(b) }
        guard edgeCount + 2 <= Self.maxEdges else { throw .graphLimit("edges") }
        try addEdge(from: a, to: b, cost: cost)
        try addEdge(from: b, to: a, cost: cost)
    }

    /// The edges leaving `from` in insertion order; empty for a node outside the graph.
    public func edges(from: Int) -> [RouteEdge] { contains(from) ? adjacency[from] : [] }

    /// Whether `node` is in 0 ..< ``nodeCount``.
    public func contains(_ node: Int) -> Bool { node >= 0 && node < nodeCount }

    /// Whether a directed edge `from` → `to` exists.
    public func hasEdge(from: Int, to: Int) -> Bool { edges(from: from).contains { $0.to == to } }

    /// The cheapest cost of an edge `from` → `to`, or nil when there is none.
    public func cheapestCost(from: Int, to: Int) -> Int? { edges(from: from).filter { $0.to == to }.map(\.cost).min() }

    /// Whether `a` and `b` are joined in the undirected view (an edge in either direction).
    public func adjacent(_ a: Int, _ b: Int) -> Bool { hasEdge(from: a, to: b) || hasEdge(from: b, to: a) }
}

/// A route: a node sequence and its total cost.
public struct RoutePath: Sendable, Equatable, Codable {
    /// The nodes from start to goal; one node for a route from a node to itself.
    public let nodes: [Int]
    /// The sum of the costs of the edges taken.
    public let cost: Int

    /// The number of edges taken, `nodes.count − 1` (0 for an empty or one-node route).
    public var steps: Int { max(0, nodes.count - 1) }

    /// Creates a route from its nodes and total cost (not checked here; ``CertificateChecker`` checks routes).
    public init(nodes: [Int], cost: Int) {
        self.nodes = nodes
        self.cost = cost
    }
}
