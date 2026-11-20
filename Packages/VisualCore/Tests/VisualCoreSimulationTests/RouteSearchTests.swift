// RouteSearchTests — feature 216 (R02-F16) T-R02F16-003 (FR-R02F16-002; SC-R02F16-001; clarification Q2; research R3,
// R4, R5). Breadth-first steps and best-first costs on 500 seeded grids and 500 seeded costed graphs equal an independent
// O(V²) cheapest-first reference; every answer repeats identically; potentials and unreachable sets prove the answer;
// start = goal, out-of-range endpoints, bad budgets, a spent budget and an overestimating estimate.
// Test data uses explicit types and plain loops (CI type-check rule).
import Testing
@testable import VisualCoreSimulation

/// Cheapest cost from `from` to `to` by plain O(V²) Dijkstra; `unit` counts every edge as 1. Nil when unreachable.
fileprivate func referenceCost(_ graph: RouteGraph, from: Int, to: Int, unit: Bool) -> Int? {
    let n = graph.nodeCount
    if unit {
        // Unit costs: a plain layer-by-layer count (keeps the 20 × 20 grids fast in debug builds).
        var steps: [Int] = Array(repeating: -1, count: n)
        var layer: [Int] = [from]
        steps[from] = 0
        while !layer.isEmpty {
            var next: [Int] = []
            for u in layer {
                for edge in graph.edges(from: u) where steps[edge.to] < 0 {
                    steps[edge.to] = steps[u] + 1
                    next.append(edge.to)
                }
            }
            layer = next
        }
        return steps[to] < 0 ? nil : steps[to]
    }
    var dist: [Int] = Array(repeating: Int.max, count: n)
    var done: [Bool] = Array(repeating: false, count: n)
    dist[from] = 0
    for _ in 0..<n {
        var u = -1
        for v in 0..<n where !done[v] && dist[v] != Int.max && (u < 0 || dist[v] < dist[u]) { u = v }
        if u < 0 { break }
        done[u] = true
        for edge in graph.edges(from: u) {
            let c: Int = unit ? 1 : edge.cost
            if dist[u] + c < dist[edge.to] { dist[edge.to] = dist[u] + c }
        }
    }
    return dist[to] == Int.max ? nil : dist[to]
}

/// Checks a found route: endpoints, edges exist, cost matches, potentials prove optimality (unit: steps).
fileprivate func checkFound(_ path: RoutePath, _ certificate: SolverCertificate, in graph: RouteGraph,
                            from: Int, to: Int, unit: Bool) -> Bool {
    guard path.nodes.first == from, path.nodes.last == to else { return false }
    var total = 0
    for i in 0..<path.steps {
        guard let c = graph.cheapestCost(from: path.nodes[i], to: path.nodes[i + 1]) else { return false }
        total += unit ? 1 : c
    }
    guard total == path.cost else { return false }
    guard case let .route(certPath, potentials) = certificate, certPath == path else { return false }
    guard potentials.count == graph.nodeCount, potentials[from] == 0, potentials[to] == path.cost else { return false }
    for u in 0..<graph.nodeCount {
        for edge in graph.edges(from: u) {
            let c: Int = unit ? 1 : edge.cost
            if potentials[edge.to] > potentials[u] + c { return false }
        }
    }
    return true
}

/// Checks an unreachable proof: sorted, contains start, not goal, closed under edges.
fileprivate func checkUnreachable(_ certificate: SolverCertificate, in graph: RouteGraph, from: Int, to: Int) -> Bool {
    guard case let .unreachable(start, goal, reachable) = certificate, start == from, goal == to else { return false }
    guard reachable == reachable.sorted(), Set(reachable).count == reachable.count else { return false }
    let set: Set<Int> = Set(reachable)
    guard set.contains(from), !set.contains(to) else { return false }
    for u in reachable {
        for edge in graph.edges(from: u) where !set.contains(edge.to) { return false }
    }
    return true
}

/// Checks an outcome against the reference answer.
fileprivate func agrees(_ outcome: RouteOutcome, reference: Int?, in graph: RouteGraph,
                        from: Int, to: Int, unit: Bool) -> Bool {
    switch outcome {
    case let .found(path, certificate):
        return path.cost == reference && checkFound(path, certificate, in: graph, from: from, to: to, unit: unit)
    case let .unreachable(certificate):
        return reference == nil && checkUnreachable(certificate, in: graph, from: from, to: to)
    case .gaveUp:
        return false
    }
}

@Suite struct RouteSearchTests {
    @Test func seededGridsMatchReference() throws {
        var random = SeededRandom(seed: 2_016)
        var failures = 0
        for _ in 0..<500 {
            let width = random.int(1...20), height = random.int(1...20)
            let cells = width * height
            let from = random.int(0...(cells - 1)), to = random.int(0...(cells - 1))
            var blocked: Set<Int> = []
            for cell in 0..<cells where cell != from && cell != to && random.double() < 0.25 { blocked.insert(cell) }
            let neighbourhood: GridNeighbourhood = random.int(0...1) == 0 ? .four : .eight
            let grid = try GridGraph(width: width, height: height, neighbourhood: neighbourhood, blocked: blocked)
            let graph = grid.graph()
            let reference = referenceCost(graph, from: from, to: to, unit: true)
            let bfs = try RouteSearch.breadthFirst(in: graph, from: from, to: to)
            let astar = try RouteSearch.bestFirst(in: graph, from: from, to: to, estimate: grid.estimate(to: to))
            if !agrees(bfs, reference: reference, in: graph, from: from, to: to, unit: true) { failures += 1 }
            if !agrees(astar, reference: reference, in: graph, from: from, to: to, unit: false) { failures += 1 }
            if try RouteSearch.breadthFirst(in: graph, from: from, to: to) != bfs { failures += 1 }
            if try RouteSearch.bestFirst(in: graph, from: from, to: to, estimate: grid.estimate(to: to)) != astar {
                failures += 1
            }
        }
        #expect(failures == 0)
    }

    @Test func seededCostedGraphsMatchReference() throws {
        var random = SeededRandom(seed: 2_016)
        var failures = 0
        var unreachableCount = 0
        for _ in 0..<500 {
            let n = random.int(1...60)
            var graph = try RouteGraph(nodeCount: n)
            let edgeCount = random.int(0...(3 * n))
            for _ in 0..<edgeCount {
                try graph.addEdge(from: random.int(0...(n - 1)), to: random.int(0...(n - 1)), cost: random.int(0...20))
            }
            let from = random.int(0...(n - 1)), to = random.int(0...(n - 1))
            let reference = referenceCost(graph, from: from, to: to, unit: false)
            if reference == nil { unreachableCount += 1 }
            let cheapest = try RouteSearch.bestFirst(in: graph, from: from, to: to)
            if !agrees(cheapest, reference: reference, in: graph, from: from, to: to, unit: false) { failures += 1 }
            if try RouteSearch.bestFirst(in: graph, from: from, to: to) != cheapest { failures += 1 }
            let steps = referenceCost(graph, from: from, to: to, unit: true)
            let bfs = try RouteSearch.breadthFirst(in: graph, from: from, to: to)
            if !agrees(bfs, reference: steps, in: graph, from: from, to: to, unit: true) { failures += 1 }
            if try RouteSearch.breadthFirst(in: graph, from: from, to: to) != bfs { failures += 1 }
        }
        #expect(failures == 0)
        #expect(unreachableCount > 0 && unreachableCount < 500)
    }

    @Test func startEqualsGoal() throws {
        var graph = try RouteGraph(nodeCount: 3)
        try graph.addEdge(from: 0, to: 1, cost: 4)
        let path = RoutePath(nodes: [1], cost: 0)
        let expected = RouteOutcome.found(path, .route(path: path, potentials: [0, 0, 0]))
        #expect(try RouteSearch.breadthFirst(in: graph, from: 1, to: 1) == expected)
        #expect(try RouteSearch.bestFirst(in: graph, from: 1, to: 1) == expected)
    }

    @Test func refusals() throws {
        let graph = try RouteGraph(nodeCount: 4)
        #expect(throws: RouteError.nodeRange(-1)) { try RouteSearch.breadthFirst(in: graph, from: -1, to: 0) }
        #expect(throws: RouteError.nodeRange(4)) { try RouteSearch.breadthFirst(in: graph, from: 0, to: 4) }
        #expect(throws: RouteError.nodeRange(4)) { try RouteSearch.bestFirst(in: graph, from: 4, to: 0) }
        #expect(throws: RouteError.nodeRange(-2)) { try RouteSearch.bestFirst(in: graph, from: 0, to: -2) }
        #expect(throws: RouteError.budget(0)) { try RouteSearch.breadthFirst(in: graph, from: 0, to: 1, budget: 0) }
        #expect(throws: RouteError.budget(RouteSearch.maxBudget + 1)) {
            try RouteSearch.bestFirst(in: graph, from: 0, to: 1, budget: RouteSearch.maxBudget + 1)
        }
        #expect(RouteError.budget(0).reasonCode == "r2-f16.budget")
    }

    @Test func blockedGridEndpointIsUnreachable() throws {
        // A blocked cell has no edges, so a route to it is unreachable with a closed proof.
        let grid = try GridGraph(width: 3, height: 1, blocked: [2])
        let graph = grid.graph()
        let outcome = try RouteSearch.bestFirst(in: graph, from: 0, to: 2, estimate: grid.estimate(to: 2))
        #expect(outcome == .unreachable(.unreachable(start: 0, goal: 2, reachable: [0, 1])))
        #expect(try RouteSearch.breadthFirst(in: graph, from: 0, to: 2) == outcome)
    }

    @Test func spentBudgetGivesUp() throws {
        var corridor = try RouteGraph(nodeCount: 10)
        for i in 0..<9 { try corridor.addUndirectedEdge(i, i + 1, cost: 2) }
        #expect(try RouteSearch.breadthFirst(in: corridor, from: 0, to: 9, budget: 1) == .gaveUp(expanded: 1))
        #expect(try RouteSearch.bestFirst(in: corridor, from: 0, to: 9, budget: 1) == .gaveUp(expanded: 1))
        #expect(try RouteSearch.bestFirst(in: corridor, from: 0, to: 9, budget: 5) == .gaveUp(expanded: 5))
        guard case let .found(path, _) = try RouteSearch.bestFirst(in: corridor, from: 0, to: 9) else {
            Issue.record("default budget finds the route")
            return
        }
        #expect(path.cost == 18 && path.steps == 9)
    }

    @Test func overestimatingEstimateIsRefused() throws {
        // 0 → 1 → 2 costs 2; 0 → 2 costs 5. Overestimating at node 1 makes best-first settle 2 via the costly edge.
        var graph = try RouteGraph(nodeCount: 3)
        try graph.addEdge(from: 0, to: 1, cost: 1)
        try graph.addEdge(from: 1, to: 2, cost: 1)
        try graph.addEdge(from: 0, to: 2, cost: 5)
        #expect(throws: RouteError.certificateRejected("estimate")) {
            try RouteSearch.bestFirst(in: graph, from: 0, to: 2, estimate: { node in node == 1 ? 100 : 0 })
        }
        guard case let .found(path, _) = try RouteSearch.bestFirst(in: graph, from: 0, to: 2) else {
            Issue.record("admissible search finds the route")
            return
        }
        #expect(path == RoutePath(nodes: [0, 1, 2], cost: 2))
    }

    @Test func tieRuleIsFixed() throws {
        // Two equal routes 0 → 1 → 3 and 0 → 2 → 3: insertion order (BFS) and the lower node id (best-first) decide.
        var graph = try RouteGraph(nodeCount: 4)
        try graph.addEdge(from: 0, to: 2, cost: 1)
        try graph.addEdge(from: 0, to: 1, cost: 1)
        try graph.addEdge(from: 1, to: 3, cost: 1)
        try graph.addEdge(from: 2, to: 3, cost: 1)
        guard case let .found(bfs, _) = try RouteSearch.breadthFirst(in: graph, from: 0, to: 3),
              case let .found(cheapest, _) = try RouteSearch.bestFirst(in: graph, from: 0, to: 3) else {
            Issue.record("both searches find a route")
            return
        }
        #expect(bfs.nodes == [0, 2, 3])
        #expect(cheapest.nodes == [0, 1, 3])
    }
}
