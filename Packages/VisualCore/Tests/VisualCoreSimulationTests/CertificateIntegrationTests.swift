// CertificateIntegrationTests — feature 216 (R02-F16) T-R02F16-007 (FR-R02F16-006; SC-R02F16-005). Every certificate a
// solver produces on seeded inputs is accepted by the checker, which never calls a solver, and a certificate checked
// against a different graph than the one it was made for is refused when it no longer holds.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct CertificateIntegrationTests {
    private func seededGrid(_ random: inout SeededRandom, side: Int, eight: Bool) throws -> GridGraph {
        var blocked = Set<Int>()
        for node in 0..<(side * side) where random.double() < 0.25 { blocked.insert(node) }
        blocked.remove(0)
        blocked.remove(side * side - 1)
        return try GridGraph(width: side, height: side, neighbourhood: eight ? .eight : .four, blocked: blocked)
    }

    private func seededGraph(_ random: inout SeededRandom, nodes: Int, edges: Int) throws -> RouteGraph {
        var graph = try RouteGraph(nodeCount: nodes)
        for _ in 0..<edges {
            try graph.addEdge(from: random.int(0...(nodes - 1)), to: random.int(0...(nodes - 1)),
                              cost: random.int(0...20))
        }
        return graph
    }

    private func certificate(of outcome: RouteOutcome) -> SolverCertificate? {
        switch outcome {
        case let .found(_, certificate): certificate
        case let .unreachable(certificate): certificate
        case .gaveUp: nil
        }
    }

    @Test func routeCertificatesFromBothSearchesAreAccepted() throws {
        var random = SeededRandom(seed: 2_016)
        var checked = 0
        for k in 0..<100 {
            let grid = try seededGrid(&random, side: 4 + k % 9, eight: k % 2 == 1)
            let graph = grid.graph()
            let goal = grid.width * grid.height - 1
            let bfs = try RouteSearch.breadthFirst(in: graph, from: 0, to: goal)
            let best = try RouteSearch.bestFirst(in: graph, from: 0, to: goal, estimate: grid.estimate(to: goal))
            for outcome in [bfs, best] {
                let cert = try #require(certificate(of: outcome))
                try CertificateChecker.verify(cert, in: graph)
                checked += 1
            }
            let costed = try seededGraph(&random, nodes: 8 + k % 30, edges: 20 + k)
            let outcome = try RouteSearch.bestFirst(in: costed, from: 0, to: costed.nodeCount - 1)
            try CertificateChecker.verify(try #require(certificate(of: outcome)), in: costed)
            checked += 1
        }
        #expect(checked == 300)
    }

    @Test func timedCutAndPlacementCertificatesAreAccepted() throws {
        var random = SeededRandom(seed: 2_016)
        for k in 0..<50 {
            let grid = try seededGrid(&random, side: 3 + k % 5, eight: false)
            let graph = grid.graph()
            let steps = 6 + k % 20
            var openBits: [Bool] = []
            for _ in 0..<(graph.nodeCount * steps) { openBits.append(random.double() < 0.75) }
            let cells = graph.nodeCount
            let schedule = try RouteSchedule(cellCount: cells, steps: steps) { cell, time in
                cell == 0 || openBits[time * cells + cell]
            }
            let timed = try TimeExpandedGraph.earliestArrival(in: graph, schedule: schedule, from: 0,
                                                              to: cells - 1, allowWaiting: k % 3 != 0)
            switch timed {
            case let .arrived(_, cert): try CertificateChecker.verify(cert, in: graph, schedule: schedule)
            case let .unreachable(cert): try CertificateChecker.verify(cert, in: graph, schedule: schedule)
            }
            let directed = try seededGraph(&random, nodes: 6 + k % 6, edges: 10 + k % 15)
            let cut = try MinimumCut.between(0, and: directed.nodeCount - 1, in: directed)
            try CertificateChecker.verify(cut.certificate, in: directed)
            #expect(cut.edges.count == cut.routes.count)
        }
        var pattern = try RouteGraph(nodeCount: 3)
        try pattern.addUndirectedEdge(0, 1)
        try pattern.addUndirectedEdge(1, 2)
        let target = try GridGraph(width: 3, height: 3).graph()
        let match = try SubgraphMatcher.placements(of: pattern, in: target)
        #expect(match.complete && !match.placements.isEmpty)
        for cert in match.certificates { try CertificateChecker.verify(cert, pattern: pattern, in: target) }
    }

    @Test func certificatesDoNotTransferToAChangedGraph() throws {
        // A corridor 0 → 1 → 2 → 3; the route certificate is refused once the middle edge is gone, and the
        // unreachable certificate of the broken corridor is refused once the edge is back.
        var corridor = try RouteGraph(nodeCount: 4)
        for node in 0..<3 { try corridor.addEdge(from: node, to: node + 1) }
        var broken = try RouteGraph(nodeCount: 4)
        try broken.addEdge(from: 0, to: 1)
        try broken.addEdge(from: 2, to: 3)
        let found = try #require(certificate(of: try RouteSearch.breadthFirst(in: corridor, from: 0, to: 3)))
        let blocked = try #require(certificate(of: try RouteSearch.breadthFirst(in: broken, from: 0, to: 3)))
        try CertificateChecker.verify(found, in: corridor)
        try CertificateChecker.verify(blocked, in: broken)
        do {
            try CertificateChecker.verify(found, in: broken)
            Issue.record("route accepted on a graph without its edge")
        } catch {
            #expect(error.reasonCode == "r2-f16.certificate-rejected")
        }
        do {
            try CertificateChecker.verify(blocked, in: corridor)
            Issue.record("unreachable accepted on a graph with a route")
        } catch {
            #expect(error.reasonCode == "r2-f16.certificate-rejected")
        }
    }
}
