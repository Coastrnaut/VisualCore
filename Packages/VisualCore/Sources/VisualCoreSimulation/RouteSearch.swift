// RouteSearch — feature 216 (R02-F16) T-R02F16-003 (FR-R02F16-002; SC-R02F16-001; clarification Q2; research R3, R4).
// Two deterministic route searches over a `RouteGraph`, each with a budget of node expansions (1 … 16,777,216, default
// the node count; running out answers "gave up", never "unreachable").
// Order: breadth-first takes nodes first in, first out and each node's edges in insertion order, the first discovery of
// a node fixing its parent; it counts steps and ignores edge costs. Best-first keeps a binary min-heap ordered by the
// total order (g + h, h, node id) with lazy deletion (a popped entry whose g is stale is skipped), settles each node once
// and relaxes edges with their costs, so the popped sequence and the route are unique and repeat exactly.
// Certificates: a found route carries node potentials π with π(start) = 0, π(v) ≤ π(u) + c for every edge and
// π(goal) = the route's cost C (research R4), taken from a cheapest-first pass truncated at C, π(v) = min(dist(v), C),
// unreached nodes C; when an overestimating estimate produced a costlier route (π(goal) < C) the answer is refused with
// `certificateRejected("estimate")`. For breadth-first the potentials are step counts (every edge counted as 1). An
// unreachable goal carries the sorted set of nodes reached from the start, which is closed under edges (research R5).
// All arithmetic is in `Int`.

/// The answer of a route search.
public enum RouteOutcome: Sendable, Equatable {
    /// A route from start to goal and its ``SolverCertificate/route(path:potentials:)`` proof of optimality.
    case found(RoutePath, SolverCertificate)
    /// The goal cannot be reached; the ``SolverCertificate/unreachable(start:goal:reachable:)`` proof lists the nodes
    /// reached from the start, a set closed under edges.
    case unreachable(SolverCertificate)
    /// The budget of node expansions ran out first; `expanded` is the number of nodes expanded.
    case gaveUp(expanded: Int)
}

/// Deterministic breadth-first (fewest steps) and best-first (cheapest) route searches with certificates.
public enum RouteSearch {
    /// The largest budget of node expansions a search takes.
    public static let maxBudget = 16_777_216

    /// The fewest-steps route from `from` to `to`: nodes are taken first in, first out and each node's edges in
    /// insertion order, the first discovery of a node fixing its parent. Edge costs are ignored: the returned
    /// ``RoutePath/cost`` counts steps and the certificate's potentials are step counts.
    ///
    /// Refuses an endpoint outside the graph with ``RouteError/nodeRange(_:)`` and a budget outside 1 … ``maxBudget``
    /// with ``RouteError/budget(_:)``; `budget` nil means the node count. A node is expanded when it is taken from the
    /// queue and its edges examined; when the budget is spent before the goal is discovered the answer is
    /// ``RouteOutcome/gaveUp(expanded:)``.
    public static func breadthFirst(in graph: RouteGraph, from: Int, to: Int,
                                    budget: Int? = nil) throws(RouteError) -> RouteOutcome {
        let limit = try validate(graph, from: from, to: to, budget: budget)
        if from == to { return trivial(graph, at: from) }
        let n = graph.nodeCount
        var dist = Array(repeating: -1, count: n)
        var parent = Array(repeating: -1, count: n)
        var queue: [Int] = [from]
        var head = 0
        var expanded = 0
        dist[from] = 0
        while head < queue.count {
            let u = queue[head]
            head += 1
            if expanded == limit { return .gaveUp(expanded: expanded) }
            expanded += 1
            for edge in graph.edges(from: u) where dist[edge.to] < 0 {
                let v = edge.to
                dist[v] = dist[u] + 1
                parent[v] = u
                if v == to {
                    // Every node at fewer than C steps is discovered by now; the rest are at least C steps away.
                    let steps = dist[v]
                    var potentials = Array(repeating: steps, count: n)
                    for node in 0..<n where dist[node] >= 0 { potentials[node] = min(dist[node], steps) }
                    let path = RoutePath(nodes: route(to: to, parent: parent), cost: steps)
                    return .found(path, .route(path: path, potentials: potentials))
                }
                queue.append(v)
            }
        }
        return unreachable(from: from, to: to, reached: dist.map { $0 >= 0 })
    }

    /// The cheapest route from `from` to `to` by best-first search: the heap pops the smallest (g + h, h, node id),
    /// entries whose g is stale are skipped, each node is settled once and edges are relaxed with their costs. With
    /// the default estimate (0) this is cheapest-first search. `estimate` must never overestimate the remaining cost;
    /// when an overestimate leads to a costlier route the answer is refused with
    /// ``RouteError/certificateRejected(_:)`` ("estimate").
    ///
    /// Refuses an endpoint outside the graph with ``RouteError/nodeRange(_:)`` and a budget outside 1 … ``maxBudget``
    /// with ``RouteError/budget(_:)``; `budget` nil means the node count; the estimate is clamped to
    /// 0 … maxEdges · maxCost so no value it returns can overflow a priority. A node is expanded when it is settled; when
    /// the budget is spent before the goal is settled the answer is ``RouteOutcome/gaveUp(expanded:)``.
    public static func bestFirst(in graph: RouteGraph, from: Int, to: Int, estimate: (Int) -> Int = { _ in 0 },
                                 budget: Int? = nil) throws(RouteError) -> RouteOutcome {
        let limit = try validate(graph, from: from, to: to, budget: budget)
        if from == to { return trivial(graph, at: from) }
        // A route costs at most maxEdges · maxCost (about 4.2e12); an estimate is clamped to 0 … that bound so
        // g + h never overflows, whatever the caller's function returns.
        let ceiling = RouteGraph.maxEdges * RouteGraph.maxCost
        func bounded(_ node: Int) -> Int { min(max(estimate(node), 0), ceiling) }
        let n = graph.nodeCount
        var best = Array(repeating: Int.max, count: n)
        var parent = Array(repeating: -1, count: n)
        var settled = Array(repeating: false, count: n)
        var heap = MinHeap()
        var expanded = 0
        best[from] = 0
        let h0 = bounded(from)
        heap.push(MinHeap.Entry(f: h0, h: h0, node: from, g: 0))
        while let entry = heap.pop() {
            let u = entry.node
            if settled[u] || entry.g != best[u] { continue }
            if expanded == limit { return .gaveUp(expanded: expanded) }
            expanded += 1
            settled[u] = true
            if u == to {
                let cost = best[u]
                let potentials = try truncatedPotentials(graph, from: from, to: to, cost: cost)
                let path = RoutePath(nodes: route(to: to, parent: parent), cost: cost)
                return .found(path, .route(path: path, potentials: potentials))
            }
            for edge in graph.edges(from: u) where !settled[edge.to] {
                let v = edge.to
                let g = entry.g + edge.cost
                if g < best[v] {
                    best[v] = g
                    parent[v] = u
                    let h = bounded(v)
                    heap.push(MinHeap.Entry(f: g + h, h: h, node: v, g: g))
                }
            }
        }
        // The queue is empty: every node reachable from the start has been settled.
        return unreachable(from: from, to: to, reached: settled)
    }

    // MARK: - Shared parts

    private static func validate(_ graph: RouteGraph, from: Int, to: Int, budget: Int?) throws(RouteError) -> Int {
        guard graph.contains(from) else { throw .nodeRange(from) }
        guard graph.contains(to) else { throw .nodeRange(to) }
        guard let budget else { return graph.nodeCount }
        guard (1...maxBudget).contains(budget) else { throw .budget(budget) }
        return budget
    }

    private static func trivial(_ graph: RouteGraph, at node: Int) -> RouteOutcome {
        let path = RoutePath(nodes: [node], cost: 0)
        return .found(path, .route(path: path, potentials: Array(repeating: 0, count: graph.nodeCount)))
    }

    private static func route(to goal: Int, parent: [Int]) -> [Int] {
        var nodes: [Int] = [goal]
        var node = goal
        while parent[node] >= 0 {
            node = parent[node]
            nodes.append(node)
        }
        return nodes.reversed()
    }

    private static func unreachable(from: Int, to: Int, reached: [Bool]) -> RouteOutcome {
        var reachable: [Int] = []
        for node in 0..<reached.count where reached[node] { reachable.append(node) }
        return .unreachable(.unreachable(start: from, goal: to, reachable: reachable))
    }

    /// π(v) = min(dist(v), cost) from a cheapest-first pass stopped once the popped distance reaches `cost`; refuses
    /// with "estimate" when the goal is closer than `cost`.
    private static func truncatedPotentials(_ graph: RouteGraph, from: Int, to: Int,
                                            cost: Int) throws(RouteError) -> [Int] {
        let n = graph.nodeCount
        var dist = Array(repeating: Int.max, count: n)
        var done = Array(repeating: false, count: n)
        var heap = MinHeap()
        dist[from] = 0
        heap.push(MinHeap.Entry(f: 0, h: 0, node: from, g: 0))
        while let entry = heap.pop() {
            if entry.g >= cost { break }
            let u = entry.node
            if done[u] || entry.g != dist[u] { continue }
            done[u] = true
            for edge in graph.edges(from: u) where !done[edge.to] {
                let g = entry.g + edge.cost
                if g < dist[edge.to] {
                    dist[edge.to] = g
                    heap.push(MinHeap.Entry(f: g, h: 0, node: edge.to, g: g))
                }
            }
        }
        var potentials = Array(repeating: cost, count: n)
        for node in 0..<n where done[node] { potentials[node] = min(dist[node], cost) }
        guard potentials[to] == cost else { throw .certificateRejected("estimate") }
        return potentials
    }
}

/// A binary min-heap of search entries ordered by (f, h, node), then g; the order is total, so pops are repeatable.
struct MinHeap {
    /// One queued node with its priority f = g + h, estimate h and cost so far g.
    struct Entry {
        let f: Int
        let h: Int
        let node: Int
        let g: Int

        func precedes(_ other: Entry) -> Bool { (f, h, node, g) < (other.f, other.h, other.node, other.g) }
    }

    private var items: [Entry] = []

    /// Whether the heap is empty.
    var isEmpty: Bool { items.isEmpty }

    /// Adds an entry.
    mutating func push(_ entry: Entry) {
        items.append(entry)
        var child = items.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            if !items[child].precedes(items[parent]) { break }
            items.swapAt(child, parent)
            child = parent
        }
    }

    /// Removes and returns the smallest entry, or nil when empty.
    mutating func pop() -> Entry? {
        guard let first = items.first else { return nil }
        let last = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            var parent = 0
            while true {
                let left = 2 * parent + 1, right = left + 1
                var smallest = parent
                if left < items.count && items[left].precedes(items[smallest]) { smallest = left }
                if right < items.count && items[right].precedes(items[smallest]) { smallest = right }
                if smallest == parent { break }
                items.swapAt(parent, smallest)
                parent = smallest
            }
        }
        return first
    }
}
