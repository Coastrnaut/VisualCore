// SubgraphMatcherTests — feature 216 (R02-F16) T-R02F16-006 (FR-R02F16-005; SC-R02F16-004; clarification Q4; research
// R8). 200 seeded pattern cases equal an exhaustive permutation reference; every placement is injective and maps every
// pattern edge to a graph edge; the order is deterministic; isomorphic relabellings are recognised and equal-size
// non-isomorphic graphs are not; a pattern larger than the graph has none; limits are refused; a budget gives up.
// Test data uses explicit types and plain loops (CI type-check rule).
import Testing
@testable import VisualCoreSimulation

/// A random undirected graph of `nodes` nodes, each pair joined with probability `density`.
fileprivate func randomGraph(nodes: Int, density: Double, random: inout SeededRandom) throws -> RouteGraph {
    var graph = try RouteGraph(nodeCount: nodes)
    for a in 0..<nodes {
        for b in (a + 1)..<nodes where random.double() < density {
            try graph.addUndirectedEdge(a, b)
        }
    }
    return graph
}

/// Every injective map pattern → graph that sends every pattern edge to a graph edge, by brute-force enumeration.
fileprivate func referencePlacements(of pattern: RouteGraph, in graph: RouteGraph) -> [[Int]] {
    var result: [[Int]] = []
    var map: [Int] = []
    var used: [Bool] = Array(repeating: false, count: graph.nodeCount)
    func enumerate() {
        if map.count == pattern.nodeCount {
            for i in 0..<pattern.nodeCount {
                for j in 0..<pattern.nodeCount where i != j && pattern.adjacent(i, j) {
                    if !graph.adjacent(map[i], map[j]) { return }
                }
            }
            result.append(map)
            return
        }
        for candidate in 0..<graph.nodeCount where !used[candidate] {
            used[candidate] = true
            map.append(candidate)
            enumerate()
            map.removeLast()
            used[candidate] = false
        }
    }
    enumerate()
    return result
}

/// Sorts placements lexicographically by pattern index.
fileprivate func sortedPlacements(_ placements: [[Int]]) -> [[Int]] {
    placements.sorted { (a: [Int], b: [Int]) -> Bool in a.lexicographicallyPrecedes(b) }
}

@Suite struct SubgraphMatcherTests {
    @Test func seededCasesEqualExhaustiveReference() throws {
        var random = SeededRandom(seed: 2_016)
        var withPlacements = 0
        for _ in 0..<200 {
            let pattern = try randomGraph(nodes: random.int(2...5), density: 0.5, random: &random)
            let graph = try randomGraph(nodes: random.int(4...8), density: 0.6, random: &random)
            let outcome = try SubgraphMatcher.placements(of: pattern, in: graph)
            let reference = referencePlacements(of: pattern, in: graph)
            #expect(outcome.complete)
            #expect(outcome.placements.count == reference.count)
            #expect(sortedPlacements(outcome.placements) == sortedPlacements(reference))
            for map in outcome.placements {
                #expect(Set(map).count == map.count)
                for i in 0..<pattern.nodeCount {
                    for j in 0..<pattern.nodeCount where i != j && pattern.adjacent(i, j) {
                        #expect(graph.adjacent(map[i], map[j]))
                    }
                }
            }
            if reference.isEmpty {
                #expect(outcome.certificates == [.exhausted(examined: outcome.examined)])
            } else {
                withPlacements += 1
                var expected: [SolverCertificate] = []
                for map in outcome.placements { expected.append(.placement(map: map)) }
                #expect(outcome.certificates == expected)
            }
            let again = try SubgraphMatcher.placements(of: pattern, in: graph)
            #expect(again == outcome)
        }
        #expect(withPlacements >= 50)
    }

    @Test func isomorphicRelabellingsAreRecognised() throws {
        var random = SeededRandom(seed: 2_016)
        for _ in 0..<50 {
            let nodes = random.int(3...8)
            let graph = try randomGraph(nodes: nodes, density: 0.5, random: &random)
            var permutation: [Int] = Array(0..<nodes)
            for index in stride(from: nodes - 1, to: 0, by: -1) {
                permutation.swapAt(index, random.int(0...index))
            }
            var relabelled = try RouteGraph(nodeCount: nodes)
            for a in 0..<nodes {
                for b in (a + 1)..<nodes where graph.adjacent(a, b) {
                    try relabelled.addUndirectedEdge(permutation[a], permutation[b])
                }
            }
            #expect(try SubgraphMatcher.isomorphic(graph, relabelled) == true)
        }
    }

    @Test func nonIsomorphicEqualSizeGraphsAreNot() throws {
        var path = try RouteGraph(nodeCount: 4)
        try path.addUndirectedEdge(0, 1)
        try path.addUndirectedEdge(1, 2)
        try path.addUndirectedEdge(2, 3)
        var star = try RouteGraph(nodeCount: 4)
        try star.addUndirectedEdge(0, 1)
        try star.addUndirectedEdge(0, 2)
        try star.addUndirectedEdge(0, 3)
        #expect(try SubgraphMatcher.isomorphic(path, star) == false)
        // Same degree sequence (all 2): a 6-cycle against two triangles, which the search must decide.
        var cycle = try RouteGraph(nodeCount: 6)
        for node in 0..<6 { try cycle.addUndirectedEdge(node, (node + 1) % 6) }
        var triangles = try RouteGraph(nodeCount: 6)
        for base in [0, 3] {
            try triangles.addUndirectedEdge(base, base + 1)
            try triangles.addUndirectedEdge(base + 1, base + 2)
            try triangles.addUndirectedEdge(base + 2, base)
        }
        #expect(try SubgraphMatcher.isomorphic(cycle, triangles) == false)
        #expect(try SubgraphMatcher.isomorphic(path, try RouteGraph(nodeCount: 5)) == false)
        // A directed edge and a duplicate are read as one undirected edge.
        var directed = try RouteGraph(nodeCount: 2)
        try directed.addEdge(from: 1, to: 0, cost: 9)
        try directed.addEdge(from: 1, to: 0)
        try directed.addEdge(from: 0, to: 0)
        var plain = try RouteGraph(nodeCount: 2)
        try plain.addUndirectedEdge(0, 1)
        #expect(try SubgraphMatcher.isomorphic(directed, plain) == true)
    }

    @Test func patternLargerThanGraphHasNone() throws {
        let pattern = try RouteGraph(nodeCount: 5)
        let graph = try RouteGraph(nodeCount: 4)
        let outcome = try SubgraphMatcher.placements(of: pattern, in: graph)
        #expect(outcome.placements.isEmpty && outcome.complete && outcome.examined == 0)
        #expect(outcome.certificates == [.exhausted(examined: 0)])
    }

    @Test func limitsAreRefused() throws {
        let big = try RouteGraph(nodeCount: 33)
        let graph = try RouteGraph(nodeCount: 40)
        let small = try RouteGraph(nodeCount: 2)
        #expect(throws: RouteError.patternLimit(33)) { try SubgraphMatcher.placements(of: big, in: graph) }
        #expect(throws: RouteError.budget(0)) { try SubgraphMatcher.placements(of: small, in: graph, limit: 0) }
        #expect(throws: RouteError.budget(SubgraphMatcher.maxPlacements + 1)) {
            try SubgraphMatcher.placements(of: small, in: graph, limit: SubgraphMatcher.maxPlacements + 1)
        }
        #expect(throws: RouteError.budget(0)) { try SubgraphMatcher.placements(of: small, in: graph, budget: 0) }
        #expect(throws: RouteError.budget(SubgraphMatcher.maxSteps + 1)) {
            try SubgraphMatcher.placements(of: small, in: graph, budget: SubgraphMatcher.maxSteps + 1)
        }
        #expect(throws: RouteError.budget(0)) { try SubgraphMatcher.isomorphic(small, small, budget: 0) }
    }

    @Test func limitAndBudgetStopEarly() throws {
        var pattern = try RouteGraph(nodeCount: 2)
        try pattern.addUndirectedEdge(0, 1)
        var graph = try RouteGraph(nodeCount: 6)
        for a in 0..<6 {
            for b in (a + 1)..<6 { try graph.addUndirectedEdge(a, b) }
        }
        let first = try SubgraphMatcher.placements(of: pattern, in: graph, limit: 1)
        #expect(first.placements == [[0, 1]] && !first.complete)
        #expect(first.certificates == [.placement(map: [0, 1])])
        let all = try SubgraphMatcher.placements(of: pattern, in: graph)
        #expect(all.placements.count == 30 && all.complete)
        let tiny = try SubgraphMatcher.placements(of: pattern, in: graph, budget: 1)
        #expect(!tiny.complete && tiny.examined == 1 && tiny.placements.isEmpty && tiny.certificates.isEmpty)
        var triangle = try RouteGraph(nodeCount: 3)
        try triangle.addUndirectedEdge(0, 1)
        try triangle.addUndirectedEdge(1, 2)
        try triangle.addUndirectedEdge(2, 0)
        #expect(try SubgraphMatcher.isomorphic(triangle, triangle, budget: 1) == nil)
    }
}
