// MinimumCutTests — feature 216 (R02-F16) T-R02F16-005 (FR-R02F16-004; clarification Q4; research R7). 200 seeded small
// directed graphs: the cut has as many edges as there are routes, the routes are valid and pairwise edge-disjoint (as
// edge units), removing the cut separates the sink, and on graphs of at most 12 edges the cut size equals a brute-force
// minimum over all edge subsets. A handmade example, parallel edges and the refusals.
// Test data uses explicit types and plain loops (CI type-check rule).
import Testing
@testable import VisualCoreSimulation

/// A directed edge unit list `(from, to)` in insertion order.
fileprivate typealias EdgeList = [(from: Int, to: Int)]

/// Whether `sink` is reachable from `source` using the edges whose `removed` flag is false.
fileprivate func reaches(_ source: Int, _ sink: Int, nodeCount: Int, edges: EdgeList, removed: [Bool]) -> Bool {
    var seen = [Bool](repeating: false, count: nodeCount)
    var stack: [Int] = [source]
    seen[source] = true
    while let u = stack.popLast() {
        if u == sink { return true }
        for i in 0..<edges.count where !removed[i] && edges[i].from == u && !seen[edges[i].to] {
            seen[edges[i].to] = true
            stack.append(edges[i].to)
        }
    }
    return false
}

/// The fewest edges whose removal separates `sink` from `source`, by trying every subset.
fileprivate func bruteForceCutSize(_ source: Int, _ sink: Int, nodeCount: Int, edges: EdgeList) -> Int {
    var best = edges.count
    for mask in 0..<(1 << edges.count) {
        let size = mask.nonzeroBitCount
        guard size < best else { continue }
        var removed: [Bool] = []
        for i in 0..<edges.count { removed.append(mask & (1 << i) != 0) }
        if !reaches(source, sink, nodeCount: nodeCount, edges: edges, removed: removed) { best = size }
    }
    return best
}

/// The number of units of each directed pair.
fileprivate func multiplicity(_ edges: EdgeList) -> [CutEdge: Int] {
    var counts: [CutEdge: Int] = [:]
    for edge in edges { counts[CutEdge(from: edge.from, to: edge.to), default: 0] += 1 }
    return counts
}

/// Checks the invariants of a cut result against the edge list it came from.
fileprivate func checkCut(_ result: CutResult, source: Int, sink: Int, nodeCount: Int, edges: EdgeList) {
    #expect(result.edges.count == result.routes.count)
    #expect(result.edges == result.edges.sorted())
    #expect(result.certificate == .cut(source: source, sink: sink, edges: result.edges, routes: result.routes))
    let available = multiplicity(edges)
    // Routes: valid, from source to sink, and together use no pair more often than it has units.
    var used: [CutEdge: Int] = [:]
    for route in result.routes {
        #expect(route.nodes.first == source && route.nodes.last == sink)
        #expect(route.cost == route.steps)
        #expect(Set<Int>(route.nodes).count == route.nodes.count)
        for i in 1..<max(1, route.nodes.count) {
            used[CutEdge(from: route.nodes[i - 1], to: route.nodes[i]), default: 0] += 1
        }
    }
    for (pair, count) in used { #expect(count <= available[pair, default: 0]) }
    // Cut: made of existing units; removing one unit per cut entry separates the sink.
    var toRemove: [CutEdge: Int] = [:]
    for edge in result.edges { toRemove[edge, default: 0] += 1 }
    for (pair, count) in toRemove { #expect(count <= available[pair, default: 0]) }
    var removed: [Bool] = []
    for edge in edges {
        let pair = CutEdge(from: edge.from, to: edge.to)
        let left = toRemove[pair, default: 0]
        removed.append(left > 0)
        if left > 0 { toRemove[pair] = left - 1 }
    }
    #expect(!reaches(source, sink, nodeCount: nodeCount, edges: edges, removed: removed))
}

@Suite struct MinimumCutTests {
    @Test func seededGraphsCutEqualsRoutesAndBruteForce() throws {
        var random = SeededRandom(seed: 2_016)
        var bruteForced = 0
        var nonEmpty = 0
        for _ in 0..<200 {
            let n = random.int(2...12)
            let edgeCount = random.int(0...24)
            var edges: EdgeList = []
            var graph = try RouteGraph(nodeCount: n)
            for _ in 0..<edgeCount {
                let a = random.int(0...(n - 1))
                let b = random.int(0...(n - 1))
                try graph.addEdge(from: a, to: b, cost: random.int(0...9))
            }
            // The edge units in (tail, index) order, as the solver names them.
            for u in 0..<n {
                for edge in graph.edges(from: u) { edges.append((from: u, to: edge.to)) }
            }
            let source = random.int(0...(n - 1))
            var sink = random.int(0...(n - 2))
            if sink >= source { sink += 1 }
            let result = try MinimumCut.between(source, and: sink, in: graph)
            checkCut(result, source: source, sink: sink, nodeCount: n, edges: edges)
            if !result.edges.isEmpty { nonEmpty += 1 }
            let allKept = [Bool](repeating: false, count: edges.count)
            if !reaches(source, sink, nodeCount: n, edges: edges, removed: allKept) {
                #expect(result.edges.isEmpty && result.routes.isEmpty)
            }
            if edges.count <= 12 {
                bruteForced += 1
                #expect(result.edges.count == bruteForceCutSize(source, sink, nodeCount: n, edges: edges))
            }
        }
        #expect(bruteForced > 50)
        #expect(nonEmpty > 50)
    }

    @Test func handmadeExampleAndParallelEdges() throws {
        // 0 → 1, 0 → 2, 1 → 3, 2 → 3, 1 → 2: two disjoint routes; the residual search cannot leave 0,
        // so the cut is the source side {0→1, 0→2}.
        var graph = try RouteGraph(nodeCount: 4)
        try graph.addEdge(from: 0, to: 1)
        try graph.addEdge(from: 0, to: 2)
        try graph.addEdge(from: 1, to: 3)
        try graph.addEdge(from: 2, to: 3)
        try graph.addEdge(from: 1, to: 2)
        let result = try MinimumCut.between(0, and: 3, in: graph)
        #expect(result.edges == [CutEdge(from: 0, to: 1), CutEdge(from: 0, to: 2)])
        #expect(result.routes == [RoutePath(nodes: [0, 1, 3], cost: 2), RoutePath(nodes: [0, 2, 3], cost: 2)])

        // Three parallel 0 → 1 units then one 1 → 2: the cut is the single 1 → 2.
        var parallel = try RouteGraph(nodeCount: 3)
        for _ in 0..<3 { try parallel.addEdge(from: 0, to: 1) }
        try parallel.addEdge(from: 1, to: 2)
        let narrow = try MinimumCut.between(0, and: 2, in: parallel)
        #expect(narrow.edges == [CutEdge(from: 1, to: 2)])
        // Two parallel 0 → 1 units alone: both are cut, listed twice, with two routes.
        var twin = try RouteGraph(nodeCount: 2)
        try twin.addEdge(from: 0, to: 1)
        try twin.addEdge(from: 0, to: 1)
        let wide = try MinimumCut.between(0, and: 1, in: twin)
        #expect(wide.edges == [CutEdge(from: 0, to: 1), CutEdge(from: 0, to: 1)])
        #expect(wide.routes.count == 2)

        // Unreachable sink: empty cut, no routes.
        let none = try MinimumCut.between(1, and: 0, in: twin)
        #expect(none.edges.isEmpty && none.routes.isEmpty)
        #expect(none.certificate == .cut(source: 1, sink: 0, edges: [], routes: []))
    }

    @Test func refusals() throws {
        let graph = try RouteGraph(nodeCount: 3)
        #expect(throws: RouteError.graphLimit("source-equals-sink")) { try MinimumCut.between(1, and: 1, in: graph) }
        #expect(throws: RouteError.nodeRange(3)) { try MinimumCut.between(0, and: 3, in: graph) }
        #expect(throws: RouteError.nodeRange(-1)) { try MinimumCut.between(-1, and: 0, in: graph) }
    }
}
