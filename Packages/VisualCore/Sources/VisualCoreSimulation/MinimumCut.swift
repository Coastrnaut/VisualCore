// MinimumCut — feature 216 (R02-F16) T-R02F16-005 (FR-R02F16-004; clarification Q4; research R7). The fewest directed
// edges whose removal leaves no route from a source to a sink, with as many pairwise edge-disjoint routes as proof.
// Every directed edge is one unit of capacity (parallel edges are separate units, named by their tail and their index in
// `edges(from:)`). Edmonds–Karp: a breadth-first search in the residual graph — forward along an edge without flow, then
// backward along an edge with flow, both in edge insertion order — finds a fewest-step augmenting route, which carries one
// more unit; with k units the work is bounded by k·E. When no augmenting route is left, the set R the residual search
// reaches from the source holds the source and not the sink, and the edges from R to its complement are the cut (one entry
// per edge unit, sorted). Max-flow = min-cut: the flow is decomposed into as many edge-disjoint routes by following used
// edges from the source and consuming them (a cycle met on the way is dropped), so the cut and the routes have equal size.

/// A minimum cut between two nodes and the edge-disjoint routes that prove it minimal.
public struct CutResult: Sendable, Equatable {
    /// The cut edges, sorted by tail then head; a parallel edge appears once per edge cut.
    public let edges: [CutEdge]
    /// Pairwise edge-disjoint routes from source to sink, as many as cut edges; each cost is its step count.
    public let routes: [RoutePath]
    /// ``SolverCertificate/cut(source:sink:edges:routes:)`` with the same edges and routes.
    public let certificate: SolverCertificate
}

/// Minimum edge cuts by maximum flow on unit capacities.
public enum MinimumCut {
    /// The minimum cut between `source` and `sink` in `graph`, every directed edge counting as one unit; empty with no
    /// routes when the sink is unreachable.
    ///
    /// Refuses a node outside the graph with ``RouteError/nodeRange(_:)`` and `source == sink` with
    /// ``RouteError/graphLimit(_:)`` (`"source-equals-sink"`).
    public static func between(_ source: Int, and sink: Int, in graph: RouteGraph) throws(RouteError) -> CutResult {
        guard graph.contains(source) else { throw .nodeRange(source) }
        guard graph.contains(sink) else { throw .nodeRange(sink) }
        guard source != sink else { throw .graphLimit("source-equals-sink") }

        let n = graph.nodeCount
        // Edge units in (tail, index) order; outgoing and incoming unit ids per node in that same order.
        var tails: [Int] = []
        var heads: [Int] = []
        var outgoing = [[Int]](repeating: [], count: n)
        var incoming = [[Int]](repeating: [], count: n)
        for u in 0..<n {
            for edge in graph.edges(from: u) {
                let id = tails.count
                tails.append(u)
                heads.append(edge.to)
                outgoing[u].append(id)
                incoming[edge.to].append(id)
            }
        }
        var flow = [Bool](repeating: false, count: tails.count)

        // Augment one unit at a time until the residual search no longer reaches the sink.
        var reached: [Bool]
        while true {
            let search = residualSearch(from: source, n: n, tails: tails, heads: heads, outgoing: outgoing,
                                        incoming: incoming, flow: flow)
            reached = search.reached
            guard reached[sink] else { break }
            var node = sink
            while node != source {
                let id = search.viaEdge[node]
                if search.forward[node] {
                    flow[id] = true
                    node = tails[id]
                } else {
                    flow[id] = false
                    node = heads[id]
                }
            }
        }

        var cut: [CutEdge] = []
        for id in 0..<tails.count where reached[tails[id]] && !reached[heads[id]] {
            cut.append(CutEdge(from: tails[id], to: heads[id]))
        }
        cut.sort()

        let routes = decompose(source: source, sink: sink, outgoing: outgoing, heads: heads, flow: flow,
                               count: cut.count)
        return CutResult(edges: cut, routes: routes,
                         certificate: .cut(source: source, sink: sink, edges: cut, routes: routes))
    }

    /// Breadth-first search in the residual graph; for each reached node the unit it was reached by and whether that unit
    /// was used forward.
    private static func residualSearch(from source: Int, n: Int, tails: [Int], heads: [Int], outgoing: [[Int]],
                                       incoming: [[Int]], flow: [Bool])
        -> (reached: [Bool], viaEdge: [Int], forward: [Bool]) {
        var reached = [Bool](repeating: false, count: n)
        var viaEdge = [Int](repeating: -1, count: n)
        var forward = [Bool](repeating: false, count: n)
        var queue: [Int] = [source]
        var head = 0
        reached[source] = true
        while head < queue.count {
            let u = queue[head]
            head += 1
            for id in outgoing[u] where !flow[id] && !reached[heads[id]] {
                let w = heads[id]
                reached[w] = true
                viaEdge[w] = id
                forward[w] = true
                queue.append(w)
            }
            for id in incoming[u] where flow[id] && !reached[tails[id]] {
                let w = tails[id]
                reached[w] = true
                viaEdge[w] = id
                forward[w] = false
                queue.append(w)
            }
        }
        return (reached, viaEdge, forward)
    }

    /// Splits the flow into `count` edge-disjoint source → sink routes, following the first unused flow unit out of each
    /// node and dropping any cycle met on the way.
    private static func decompose(source: Int, sink: Int, outgoing: [[Int]], heads: [Int], flow: [Bool],
                                  count: Int) -> [RoutePath] {
        var unused = flow
        var routes: [RoutePath] = []
        for _ in 0..<count {
            var nodes: [Int] = [source]
            var position: [Int: Int] = [source: 0]
            var node = source
            while node != sink {
                // Flow conservation guarantees an unused flow unit out of every node on the walk but the sink.
                guard let id = outgoing[node].first(where: { unused[$0] }) else { break }
                unused[id] = false
                node = heads[id]
                if let earlier = position[node] {
                    for dropped in nodes[(earlier + 1)...] { position[dropped] = nil }
                    nodes.removeSubrange((earlier + 1)...)
                } else {
                    position[node] = nodes.count
                    nodes.append(node)
                }
            }
            routes.append(RoutePath(nodes: nodes, cost: nodes.count - 1))
        }
        return routes
    }
}
