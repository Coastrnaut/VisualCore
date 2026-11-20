// CertificateCheckerTests — feature 216 (R02-F16) T-R02F16-007 (FR-R02F16-006; SC-R02F16-005; clarifications Q2–Q4;
// research R4, R5, R7). Honest certificates of every kind, built by hand or by small reference searches in this file,
// are accepted; at least 100 seeded tampered certificates are refused, each with the rule it breaks. The checker is
// tested without the solvers. Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

/// The rule a check rejects with, nil when it accepts, or "other" for any other error.
fileprivate func rejection(_ body: () throws -> Void) -> String? {
    do {
        try body()
        return nil
    } catch let error as RouteError {
        if case let .certificateRejected(rule) = error { return rule }
        return "other: \(error)"
    } catch {
        return "other: \(error)"
    }
}

/// Reference cheapest costs from `start` (Dijkstra by linear scan; graphs here are small); nil when unreached.
fileprivate func referenceDistances(_ graph: RouteGraph, from start: Int,
                                    unit: Bool) -> (dist: [Int?], parent: [Int]) {
    var dist: [Int?] = Array(repeating: nil, count: graph.nodeCount)
    var parent: [Int] = Array(repeating: -1, count: graph.nodeCount)
    var done: [Bool] = Array(repeating: false, count: graph.nodeCount)
    dist[start] = 0
    while true {
        var best: Int = -1
        for v in 0..<graph.nodeCount where !done[v] {
            if let d = dist[v], best < 0 || d < (dist[best] ?? Int.max) { best = v }
        }
        if best < 0 { break }
        done[best] = true
        let base: Int = dist[best] ?? 0
        for edge in graph.edges(from: best) {
            let candidate: Int = base + (unit ? 1 : edge.cost)
            if dist[edge.to] == nil || candidate < (dist[edge.to] ?? Int.max) {
                dist[edge.to] = candidate
                parent[edge.to] = best
            }
        }
    }
    return (dist, parent)
}

/// An honest route certificate from `start` to `goal` (R4: π(v) = min(dist(v), C)), or nil when unreachable or trivial.
fileprivate func honestRoute(_ graph: RouteGraph, start: Int, goal: Int, unit: Bool,
                             truncation: Int = 0) -> SolverCertificate? {
    let (dist, parent) = referenceDistances(graph, from: start, unit: unit)
    guard let total = dist[goal], goal != start else { return nil }
    var nodes: [Int] = [goal]
    var v: Int = goal
    while v != start {
        v = parent[v]
        nodes.append(v)
    }
    nodes.reverse()
    let cap: Int = total - truncation
    var potentials: [Int] = []
    for d in dist { potentials.append(min(d ?? cap, cap)) }
    return .route(path: RoutePath(nodes: nodes, cost: total), potentials: potentials)
}

/// The nodes reachable from `start`, sorted.
fileprivate func referenceReachable(_ graph: RouteGraph, from start: Int) -> [Int] {
    var seen: [Bool] = Array(repeating: false, count: graph.nodeCount)
    seen[start] = true
    var queue: [Int] = [start]
    var head: Int = 0
    while head < queue.count {
        let u: Int = queue[head]
        head += 1
        for edge in graph.edges(from: u) where !seen[edge.to] {
            seen[edge.to] = true
            queue.append(edge.to)
        }
    }
    var result: [Int] = []
    for v in 0..<graph.nodeCount where seen[v] { result.append(v) }
    return result
}

/// The timed states reachable from (start, startTime) within the schedule, sorted by time, then node.
fileprivate func referenceTimedReachable(_ graph: RouteGraph, _ schedule: RouteSchedule, start: Int, startTime: Int,
                                         allowWaiting: Bool) -> [TimedState] {
    var layer: [Bool] = Array(repeating: false, count: graph.nodeCount)
    layer[start] = true
    var result: [TimedState] = [TimedState(node: start, time: startTime)]
    var t: Int = startTime
    while t + 1 < schedule.steps {
        var next: [Bool] = Array(repeating: false, count: graph.nodeCount)
        for v in 0..<graph.nodeCount where layer[v] {
            if allowWaiting && schedule.isOpen(v, at: t + 1) { next[v] = true }
            for edge in graph.edges(from: v) where schedule.isOpen(edge.to, at: t + 1) { next[edge.to] = true }
        }
        t += 1
        for v in 0..<graph.nodeCount where next[v] { result.append(TimedState(node: v, time: t)) }
        layer = next
    }
    return result
}

/// A random directed graph with costs in `costs`, a guaranteed chain 0 → 1 → … → n − 1 and some extra edges.
fileprivate func randomGraph(_ rng: inout SeededRandom, nodes: Int, costs: ClosedRange<Int>) throws -> RouteGraph {
    var graph: RouteGraph = try RouteGraph(nodeCount: nodes)
    for v in 1..<nodes { try graph.addEdge(from: v - 1, to: v, cost: rng.int(costs)) }
    let extra: Int = rng.int(nodes...(3 * nodes))
    for _ in 0..<extra {
        try graph.addEdge(from: rng.int(0...(nodes - 1)), to: rng.int(0...(nodes - 1)), cost: rng.int(costs))
    }
    return graph
}

@Suite struct CertificateCheckerTests {
    // MARK: Accepted

    @Test func handBuiltRouteCertificates() throws {
        // 0 → 1 (cost 5 and a parallel 2), 1 → 2 (0), 0 → 2 (9): cheapest route 0, 1, 2 with cost 2.
        var graph: RouteGraph = try RouteGraph(nodeCount: 4)
        try graph.addEdge(from: 0, to: 1, cost: 5)
        try graph.addEdge(from: 0, to: 1, cost: 2)
        try graph.addEdge(from: 1, to: 2, cost: 0)
        try graph.addEdge(from: 0, to: 2, cost: 9)
        try graph.addEdge(from: 3, to: 0, cost: 1)
        let cheapest: SolverCertificate = .route(path: RoutePath(nodes: [0, 1, 2], cost: 2), potentials: [0, 2, 2, 2])
        #expect(rejection { try CertificateChecker.verify(cheapest, in: graph) } == nil)
        // A one-node route costs 0.
        let trivial: SolverCertificate = .route(path: RoutePath(nodes: [3], cost: 0), potentials: [0, 0, 0, 0])
        #expect(rejection { try CertificateChecker.verify(trivial, in: graph) } == nil)
        // Fewest steps: 0 → 2 directly, cost 1 step, unit potentials; the costed check fails, the unit check passes.
        let fewest: SolverCertificate = .route(path: RoutePath(nodes: [0, 2], cost: 1), potentials: [0, 1, 1, 1])
        #expect(rejection { try CertificateChecker.verify(fewest, in: graph) } == nil)
        // The schedule and pattern overloads pass non-timed, non-placement kinds through.
        let schedule: RouteSchedule = try RouteSchedule(cellCount: 4, steps: 2) { _, _ in true }
        #expect(rejection { try CertificateChecker.verify(cheapest, in: graph, schedule: schedule) } == nil)
        #expect(rejection { try CertificateChecker.verify(cheapest, pattern: graph, in: graph) } == nil)
    }

    @Test func seededHonestCertificatesAreAccepted() throws {
        var rng: SeededRandom = SeededRandom(seed: 2_016)
        var accepted: Int = 0
        for _ in 0..<20 {
            let n: Int = rng.int(4...12)
            let graph: RouteGraph = try randomGraph(&rng, nodes: n, costs: 0...9)
            for unit in [false, true] {
                if let cert = honestRoute(graph, start: 0, goal: n - 1, unit: unit) {
                    #expect(rejection { try CertificateChecker.verify(cert, in: graph) } == nil)
                    accepted += 1
                }
            }
        }
        #expect(accepted == 40)
    }

    @Test func handBuiltUnreachableAndTimedCertificates() throws {
        // 0 ↔ 1 → 2, 3 → 0: from 0 the set {0, 1, 2} is closed and does not contain 3.
        var graph: RouteGraph = try RouteGraph(nodeCount: 4)
        try graph.addUndirectedEdge(0, 1)
        try graph.addEdge(from: 1, to: 2)
        try graph.addEdge(from: 3, to: 0)
        let unreachable: SolverCertificate = .unreachable(start: 0, goal: 3, reachable: [0, 1, 2])
        #expect(rejection { try CertificateChecker.verify(unreachable, in: graph) } == nil)
        // Line 0 – 1 – 2 – 3; cell 2 closed at time 1 only.
        var line: RouteGraph = try RouteGraph(nodeCount: 4)
        for v in 1..<4 { try line.addUndirectedEdge(v - 1, v) }
        let schedule: RouteSchedule = try RouteSchedule(cellCount: 4, steps: 6) { cell, time in
            !(cell == 2 && time == 1)
        }
        let states: [TimedState] = [TimedState(node: 0, time: 0), TimedState(node: 1, time: 1),
                                    TimedState(node: 1, time: 2), TimedState(node: 2, time: 3),
                                    TimedState(node: 3, time: 4)]
        let timed: SolverCertificate = .timedRoute(states: states, allowWaiting: true)
        #expect(rejection { try CertificateChecker.verify(timed, in: line, schedule: schedule) } == nil)
        // Without waiting, cell 1 is a dead end at time 1 when 2 is closed and 0 is the only other neighbour:
        // a schedule closing 2 for all time makes 3 unreachable.
        let walled: RouteSchedule = try RouteSchedule(cellCount: 4, steps: 5) { cell, _ in cell != 2 }
        for allowWaiting in [false, true] {
            let reach: [TimedState] = referenceTimedReachable(line, walled, start: 0, startTime: 0,
                                                              allowWaiting: allowWaiting)
            let cert: SolverCertificate = .timedUnreachable(start: 0, goal: 3, startTime: 0,
                                                            allowWaiting: allowWaiting, reachable: reach)
            #expect(rejection { try CertificateChecker.verify(cert, in: line, schedule: walled) } == nil)
        }
        // The goal open only after the schedule ends: unreachable "within T" from a later start time.
        let late: RouteSchedule = try RouteSchedule(cellCount: 4, steps: 4) { cell, time in cell != 3 || time > 9 }
        let lateReach: [TimedState] = referenceTimedReachable(line, late, start: 1, startTime: 1, allowWaiting: true)
        let lateCert: SolverCertificate = .timedUnreachable(start: 1, goal: 3, startTime: 1, allowWaiting: true,
                                                            reachable: lateReach)
        #expect(rejection { try CertificateChecker.verify(lateCert, in: line, schedule: late) } == nil)
    }

    @Test func handBuiltCutAndPlacementCertificates() throws {
        // s = 0, t = 3; 0 → 1 → 3, 0 → 2 → 3, 1 → 2, and two parallel 0 → 3 edges: the minimum cut has 4 units.
        var graph: RouteGraph = try RouteGraph(nodeCount: 4)
        try graph.addEdge(from: 0, to: 1)
        try graph.addEdge(from: 0, to: 2)
        try graph.addEdge(from: 1, to: 3)
        try graph.addEdge(from: 2, to: 3)
        try graph.addEdge(from: 1, to: 2)
        try graph.addEdge(from: 0, to: 3)
        try graph.addEdge(from: 0, to: 3)
        try graph.addEdge(from: 3, to: 0)
        let edges: [CutEdge] = [CutEdge(from: 0, to: 3), CutEdge(from: 0, to: 3), CutEdge(from: 1, to: 3),
                                CutEdge(from: 2, to: 3)]
        let routes: [RoutePath] = [RoutePath(nodes: [0, 3], cost: 1), RoutePath(nodes: [0, 3], cost: 1),
                                   RoutePath(nodes: [0, 1, 3], cost: 2), RoutePath(nodes: [0, 2, 3], cost: 2)]
        let cut: SolverCertificate = .cut(source: 0, sink: 3, edges: edges, routes: routes)
        #expect(rejection { try CertificateChecker.verify(cut, in: graph) } == nil)
        // No route at all: an empty cut with no routes.
        let none: SolverCertificate = .cut(source: 3, sink: 1, edges: [], routes: [])
        var oneWay: RouteGraph = try RouteGraph(nodeCount: 4)
        try oneWay.addEdge(from: 1, to: 3)
        #expect(rejection { try CertificateChecker.verify(none, in: oneWay) } == nil)
        // A triangle placed in a square with one diagonal (edges in either direction, self-loop ignored).
        var triangle: RouteGraph = try RouteGraph(nodeCount: 3)
        try triangle.addEdge(from: 0, to: 1)
        try triangle.addEdge(from: 1, to: 2)
        try triangle.addEdge(from: 2, to: 0)
        try triangle.addEdge(from: 1, to: 1)
        var square: RouteGraph = try RouteGraph(nodeCount: 4)
        try square.addEdge(from: 0, to: 1)
        try square.addEdge(from: 2, to: 1)
        try square.addEdge(from: 2, to: 3)
        try square.addEdge(from: 3, to: 0)
        try square.addEdge(from: 0, to: 2)
        let placement: SolverCertificate = .placement(map: [2, 0, 1])
        #expect(rejection { try CertificateChecker.verify(placement, pattern: triangle, in: square) } == nil)
    }

    // MARK: Refused

    @Test func refusalsWithoutContext() throws {
        var graph: RouteGraph = try RouteGraph(nodeCount: 3)
        try graph.addUndirectedEdge(0, 1)
        let schedule: RouteSchedule = try RouteSchedule(cellCount: 3, steps: 3) { _, _ in true }
        var refused: Int = 0
        for examined in [0, 1, 99, 10_000_000] {
            let cert: SolverCertificate = .exhausted(examined: examined)
            #expect(rejection { try CertificateChecker.verify(cert, in: graph) } == "not-checkable")
            #expect(rejection { try CertificateChecker.verify(cert, in: graph, schedule: schedule) } == "not-checkable")
            #expect(rejection { try CertificateChecker.verify(cert, pattern: graph, in: graph) } == "not-checkable")
            refused += 3
        }
        let timed: SolverCertificate = .timedRoute(states: [TimedState(node: 0, time: 0)], allowWaiting: true)
        let timedNone: SolverCertificate = .timedUnreachable(start: 0, goal: 2, startTime: 0, allowWaiting: true,
                                                             reachable: [TimedState(node: 0, time: 0)])
        #expect(rejection { try CertificateChecker.verify(timed, in: graph) } == "needs-schedule")
        #expect(rejection { try CertificateChecker.verify(timedNone, in: graph) } == "needs-schedule")
        #expect(rejection { try CertificateChecker.verify(timed, pattern: graph, in: graph) } == "needs-schedule")
        let placement: SolverCertificate = .placement(map: [0, 1])
        #expect(rejection { try CertificateChecker.verify(placement, in: graph) } == "needs-pattern")
        #expect(rejection { try CertificateChecker.verify(placement, in: graph, schedule: schedule) } == "needs-pattern")
        refused += 5
        #expect(refused == 17)
        #expect(RouteError.certificateRejected("x").reasonCode == "r2-f16.certificate-rejected")
    }

    @Test func tamperedRoutesAreRefused() throws {
        var rng: SeededRandom = SeededRandom(seed: 2_016)
        var refused: Int = 0
        var rules: Set<String> = []
        for _ in 0..<12 {
            let n: Int = rng.int(5...10)
            // Costs of 2 or more: a tampered cost never equals the step count, so the unit fallback cannot apply.
            let graph: RouteGraph = try randomGraph(&rng, nodes: n, costs: 2...9)
            guard let honest = honestRoute(graph, start: 0, goal: n - 1, unit: false),
                  case let .route(path, potentials) = honest,
                  let truncated = honestRoute(graph, start: 0, goal: n - 1, unit: false, truncation: 1),
                  case let .route(_, lowered) = truncated else {
                Issue.record("chain guarantees a route")
                continue
            }
            var cases: [(SolverCertificate, String)] = []
            cases.append((.route(path: RoutePath(nodes: [], cost: 0), potentials: potentials), "empty-route"))
            cases.append((.route(path: RoutePath(nodes: path.nodes + [n], cost: path.cost), potentials: potentials),
                          "node-range"))
            // Append a node the goal has no edge to.
            var stranger: Int = -1
            for w in 0..<n where !graph.hasEdge(from: n - 1, to: w) { stranger = w }
            if stranger >= 0 {
                cases.append((.route(path: RoutePath(nodes: path.nodes + [stranger], cost: path.cost),
                                     potentials: potentials), "missing-edge"))
            }
            cases.append((.route(path: RoutePath(nodes: path.nodes, cost: path.cost + rng.int(1...5)),
                                 potentials: potentials), "cost-mismatch"))
            cases.append((.route(path: path, potentials: Array(potentials.dropLast())), "potentials-size"))
            var badStart: [Int] = potentials
            badStart[0] = 1
            cases.append((.route(path: path, potentials: badStart), "potential-start"))
            // Raise the far end of an edge above π(u) + c.
            var badEdge: [Int] = potentials
            var raised: Bool = false
            for u in 0..<n where !raised {
                for edge in graph.edges(from: u) where edge.to != 0 && !raised {
                    badEdge[edge.to] = potentials[u] + edge.cost + 1
                    raised = true
                }
            }
            cases.append((.route(path: path, potentials: badEdge), "potential-edge"))
            cases.append((.route(path: path, potentials: lowered), "potential-goal"))
            for (cert, rule) in cases {
                #expect(rejection { try CertificateChecker.verify(cert, in: graph) } == rule)
                rules.insert(rule)
                refused += 1
            }
        }
        #expect(refused >= 90)
        #expect(rules == ["empty-route", "node-range", "missing-edge", "cost-mismatch", "potentials-size",
                          "potential-start", "potential-edge", "potential-goal"])
    }

    @Test func tamperedUnreachableSetsAreRefused() throws {
        var rng: SeededRandom = SeededRandom(seed: 2_016)
        var refused: Int = 0
        var rules: Set<String> = []
        for _ in 0..<10 {
            // Nodes 0 ..< a form a strongly joined part; a ..< n can reach it but not the other way round.
            let a: Int = rng.int(3...6)
            let n: Int = a + rng.int(2...4)
            var graph: RouteGraph = try RouteGraph(nodeCount: n)
            for v in 1..<a { try graph.addUndirectedEdge(v - 1, v) }
            for _ in 0..<a { try graph.addEdge(from: rng.int(0...(a - 1)), to: rng.int(0...(a - 1))) }
            for v in a..<n { try graph.addEdge(from: v, to: rng.int(0...(a - 1))) }
            let goal: Int = rng.int(a...(n - 1))
            let reach: [Int] = referenceReachable(graph, from: 0)
            #expect(rejection {
                try CertificateChecker.verify(.unreachable(start: 0, goal: goal, reachable: reach), in: graph)
            } == nil)
            var cases: [(SolverCertificate, String)] = []
            cases.append((.unreachable(start: 0, goal: n, reachable: reach), "node-range"))
            cases.append((.unreachable(start: 0, goal: goal, reachable: reach + [n]), "node-range"))
            cases.append((.unreachable(start: 0, goal: goal, reachable: Array(reach.reversed())), "unsorted"))
            cases.append((.unreachable(start: 0, goal: goal, reachable: Array(reach.dropFirst())), "start-missing"))
            cases.append((.unreachable(start: 0, goal: goal, reachable: (reach + [goal]).sorted()), "goal-present"))
            // Leave out a member other than the start: an edge from the start's part now leaves the set.
            let dropped: Int = rng.int(1...(reach.count - 1))
            var open: [Int] = reach
            open.remove(at: dropped)
            cases.append((.unreachable(start: 0, goal: goal, reachable: open), "not-closed"))
            for (cert, rule) in cases {
                #expect(rejection { try CertificateChecker.verify(cert, in: graph) } == rule)
                rules.insert(rule)
                refused += 1
            }
        }
        #expect(refused == 60)
        #expect(rules == ["node-range", "unsorted", "start-missing", "goal-present", "not-closed"])
    }

    @Test func tamperedTimedCertificatesAreRefused() throws {
        var rng: SeededRandom = SeededRandom(seed: 2_016)
        var refused: Int = 0
        var rules: Set<String> = []
        for _ in 0..<8 {
            // A 4 × 3 grid without self-loops; a random walk with waits; the schedule closes random states off the walk.
            let grid: GridGraph = try GridGraph(width: 4, height: 3)
            let graph: RouteGraph = grid.graph()
            let steps: Int = 10
            let startTime: Int = rng.int(0...2)
            var walk: [TimedState] = [TimedState(node: rng.int(0...11), time: startTime)]
            var waited: Bool = false
            while walk.count < steps - startTime {
                let last: TimedState = walk[walk.count - 1]
                let moves: [RouteEdge] = graph.edges(from: last.node)
                if rng.int(0...3) == 0 || (!waited && walk.count == 2) {
                    walk.append(TimedState(node: last.node, time: last.time + 1))
                    waited = true
                } else {
                    walk.append(TimedState(node: moves[rng.int(0...(moves.count - 1))].to, time: last.time + 1))
                }
            }
            var onWalk: Set<TimedState> = []
            for state in walk { onWalk.insert(state) }
            var closed: Set<TimedState> = []
            for _ in 0..<8 {
                let state: TimedState = TimedState(node: rng.int(0...11), time: rng.int(0...(steps - 1)))
                if !onWalk.contains(state) { closed.insert(state) }
            }
            let closedCopy: Set<TimedState> = closed
            let schedule: RouteSchedule = try RouteSchedule(cellCount: 12, steps: steps) { cell, time in
                !closedCopy.contains(TimedState(node: cell, time: time))
            }
            let open: RouteSchedule = try RouteSchedule(cellCount: 12, steps: steps) { _, _ in true }
            let honest: SolverCertificate = .timedRoute(states: walk, allowWaiting: true)
            #expect(rejection { try CertificateChecker.verify(honest, in: graph, schedule: schedule) } == nil)

            var cases: [(SolverCertificate, RouteSchedule, String)] = []
            cases.append((.timedRoute(states: [], allowWaiting: true), schedule, "empty-route"))
            var outside: [TimedState] = walk
            outside[1] = TimedState(node: 12, time: walk[1].time)
            cases.append((.timedRoute(states: outside, allowWaiting: true), schedule, "node-range"))
            // Close one state of the walk.
            let shut: TimedState = walk[rng.int(0...(walk.count - 1))]
            let shutSchedule: RouteSchedule = try RouteSchedule(cellCount: 12, steps: steps) { cell, time in
                !(cell == shut.node && time == shut.time)
            }
            cases.append((.timedRoute(states: walk, allowWaiting: true), shutSchedule, "closed-state"))
            // A time gap: drop an inner state.
            var gap: [TimedState] = walk
            gap.remove(at: rng.int(1...(walk.count - 2)))
            cases.append((.timedRoute(states: gap, allowWaiting: true), open, "time-step"))
            // A jump to a cell that is not a neighbour.
            var jump: [TimedState] = Array(walk.prefix(2))
            let from: Int = jump[1].node
            var far: Int = -1
            for w in 0..<12 where w != from && !graph.hasEdge(from: from, to: w) { far = w }
            jump.append(TimedState(node: far, time: jump[1].time + 1))
            cases.append((.timedRoute(states: jump, allowWaiting: true), open, "missing-edge"))
            cases.append((.timedRoute(states: walk, allowWaiting: false), schedule, "wait-forbidden"))

            // Timed unreachable: column x = 2 closed for all time walls off the right column from a left start.
            let wall: RouteSchedule = try RouteSchedule(cellCount: 12, steps: steps) { cell, _ in cell % 4 != 2 }
            let start: Int = grid.node(x: rng.int(0...1), y: rng.int(0...2))
            let goal: Int = grid.node(x: 3, y: rng.int(0...2))
            let allowWaiting: Bool = rng.int(0...1) == 1
            let reach: [TimedState] = referenceTimedReachable(graph, wall, start: start, startTime: startTime,
                                                              allowWaiting: allowWaiting)
            let none: SolverCertificate = .timedUnreachable(start: start, goal: goal, startTime: startTime,
                                                            allowWaiting: allowWaiting, reachable: reach)
            #expect(rejection { try CertificateChecker.verify(none, in: graph, schedule: wall) } == nil)
            var withGoal: [TimedState] = reach
            withGoal.append(TimedState(node: goal, time: steps - 1))
            withGoal.sort { (a: TimedState, b: TimedState) -> Bool in (a.time, a.node) < (b.time, b.node) }
            var missingStart: [TimedState] = reach
            missingStart.removeFirst()
            var dropped: [TimedState] = reach
            dropped.remove(at: rng.int(1...(reach.count - 1)))
            let unreached: [(TimedState, [TimedState], String)] = [
                (TimedState(node: start, time: startTime), reach + [TimedState(node: 12, time: steps - 1)],
                 "node-range"),
                (TimedState(node: start, time: startTime), reach + [TimedState(node: 0, time: steps)], "node-range"),
                (TimedState(node: start, time: startTime), Array(reach.reversed()), "unsorted"),
                (TimedState(node: start, time: startTime), missingStart, "start-missing"),
                (TimedState(node: start, time: startTime), withGoal, "goal-present"),
                (TimedState(node: start, time: startTime), dropped, "not-closed")
            ]
            for (startState, members, rule) in unreached {
                let cert: SolverCertificate = .timedUnreachable(start: startState.node, goal: goal,
                                                                startTime: startState.time,
                                                                allowWaiting: allowWaiting, reachable: members)
                cases.append((cert, wall, rule))
            }
            for (cert, sched, rule) in cases {
                #expect(rejection { try CertificateChecker.verify(cert, in: graph, schedule: sched) } == rule)
                rules.insert(rule)
                refused += 1
            }
        }
        #expect(refused == 96)
        #expect(rules == ["empty-route", "node-range", "closed-state", "time-step", "missing-edge", "wait-forbidden",
                          "unsorted", "start-missing", "goal-present", "not-closed"])
    }

    @Test func tamperedCutsAreRefused() throws {
        var rng: SeededRandom = SeededRandom(seed: 2_016)
        var refused: Int = 0
        var rules: Set<String> = []
        for _ in 0..<10 {
            // k disjoint chains from s = 0 to t = 1, plus edges back into the source (they add no flow).
            let k: Int = rng.int(2...4)
            var lengths: [Int] = []
            var total: Int = 2
            for _ in 0..<k {
                let length: Int = rng.int(1...3)
                lengths.append(length)
                total += length
            }
            var graph: RouteGraph = try RouteGraph(nodeCount: total + 1)
            var routes: [RoutePath] = []
            var edges: [CutEdge] = []
            var next: Int = 2
            for length in lengths {
                var nodes: [Int] = [0]
                for _ in 0..<length {
                    nodes.append(next)
                    next += 1
                }
                nodes.append(1)
                for i in 1..<nodes.count { try graph.addEdge(from: nodes[i - 1], to: nodes[i]) }
                try graph.addEdge(from: nodes[1], to: 0)
                routes.append(RoutePath(nodes: nodes, cost: nodes.count - 1))
                edges.append(CutEdge(from: nodes[0], to: nodes[1]))
            }
            edges.sort()
            let isolated: Int = total
            let honest: SolverCertificate = .cut(source: 0, sink: 1, edges: edges, routes: routes)
            #expect(rejection { try CertificateChecker.verify(honest, in: graph) } == nil)

            var cases: [(SolverCertificate, String)] = []
            cases.append((.cut(source: 0, sink: total + 1, edges: edges, routes: routes), "node-range"))
            cases.append((.cut(source: 0, sink: 1, edges: Array(edges.reversed()), routes: routes), "unsorted"))
            cases.append((.cut(source: 0, sink: 1, edges: edges, routes: Array(routes.dropLast())), "count-mismatch"))
            var short: [RoutePath] = routes
            short[0] = RoutePath(nodes: Array(routes[0].nodes.dropLast()), cost: 0)
            cases.append((.cut(source: 0, sink: 1, edges: edges, routes: short), "route-invalid"))
            var skip: [RoutePath] = routes
            skip[1] = RoutePath(nodes: [0, isolated, 1], cost: 2)
            cases.append((.cut(source: 0, sink: 1, edges: edges, routes: skip), "route-invalid"))
            var overlap: [RoutePath] = routes
            overlap[1] = routes[0]
            cases.append((.cut(source: 0, sink: 1, edges: edges, routes: overlap), "not-disjoint"))
            var fake: [CutEdge] = edges
            fake[rng.int(0...(k - 1))] = CutEdge(from: 0, to: isolated)
            fake.sort()
            cases.append((.cut(source: 0, sink: 1, edges: fake, routes: routes), "edge-missing"))
            var doubled: [CutEdge] = edges
            doubled[1] = edges[0]
            doubled.sort()
            cases.append((.cut(source: 0, sink: 1, edges: doubled, routes: routes), "edge-missing"))
            // Leave one chain uncut and one route out: the counts match but the sink stays reachable.
            let left: Int = rng.int(0...(k - 1))
            var fewer: [CutEdge] = edges
            fewer.remove(at: left)
            cases.append((.cut(source: 0, sink: 1, edges: fewer, routes: Array(routes.dropLast())), "not-separating"))
            for (cert, rule) in cases {
                #expect(rejection { try CertificateChecker.verify(cert, in: graph) } == rule)
                rules.insert(rule)
                refused += 1
            }
        }
        #expect(refused == 90)
        #expect(rules == ["node-range", "unsorted", "count-mismatch", "route-invalid", "not-disjoint", "edge-missing",
                          "not-separating"])
    }

    @Test func tamperedPlacementsAreRefused() throws {
        var rng: SeededRandom = SeededRandom(seed: 2_016)
        var refused: Int = 0
        var rules: Set<String> = []
        for _ in 0..<12 {
            // A pattern with a spanning path plus random edges, copied into a graph under a random injective map; the
            // graph's other nodes are isolated.
            let k: Int = rng.int(3...6)
            let n: Int = k + rng.int(2...5)
            var pattern: RouteGraph = try RouteGraph(nodeCount: k)
            for v in 1..<k { try pattern.addEdge(from: v - 1, to: v) }
            for _ in 0..<k { try pattern.addEdge(from: rng.int(0...(k - 1)), to: rng.int(0...(k - 1))) }
            var pool: [Int] = []
            for v in 0..<n { pool.append(v) }
            var map: [Int] = []
            for _ in 0..<k { map.append(pool.remove(at: rng.int(0...(pool.count - 1)))) }
            var graph: RouteGraph = try RouteGraph(nodeCount: n)
            for i in 0..<k {
                for edge in pattern.edges(from: i) where edge.to != i {
                    // Store each copied edge in a random direction; matching reads the undirected view.
                    if rng.int(0...1) == 0 {
                        try graph.addEdge(from: map[i], to: map[edge.to])
                    } else {
                        try graph.addEdge(from: map[edge.to], to: map[i])
                    }
                }
            }
            #expect(rejection { try CertificateChecker.verify(.placement(map: map), pattern: pattern, in: graph) } == nil)
            var cases: [(SolverCertificate, String)] = []
            cases.append((.placement(map: Array(map.dropLast())), "size-mismatch"))
            cases.append((.placement(map: map + [pool[0]]), "size-mismatch"))
            var outside: [Int] = map
            outside[rng.int(0...(k - 1))] = n
            cases.append((.placement(map: outside), "node-range"))
            var twice: [Int] = map
            twice[1] = map[0]
            cases.append((.placement(map: twice), "not-injective"))
            // Move a pattern node (every one has an edge on the spanning path) onto an isolated graph node.
            var moved: [Int] = map
            moved[rng.int(0...(k - 1))] = pool[rng.int(0...(pool.count - 1))]
            cases.append((.placement(map: moved), "missing-edge"))
            for (cert, rule) in cases {
                #expect(rejection { try CertificateChecker.verify(cert, pattern: pattern, in: graph) } == rule)
                rules.insert(rule)
                refused += 1
            }
        }
        #expect(refused == 60)
        #expect(rules == ["size-mismatch", "node-range", "not-injective", "missing-edge"])
    }
}
