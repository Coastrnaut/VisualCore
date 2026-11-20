// GraphFoundationTests — feature 216 (R02-F16) T-R02F16-002 (FR-R02F16-001, FR-R02F16-007, FR-R02F16-008;
// clarifications Q1, Q3, Q5). Limits and refusals of graphs, grids and schedules; grid conversion without corner
// cutting; certificates round-trip byte for byte and newer or damaged forms are refused.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct GraphFoundationTests {
    @Test func graphLimitsAndRefusals() throws {
        #expect(throws: RouteError.emptyGraph) { try RouteGraph(nodeCount: 0) }
        #expect(throws: RouteError.graphLimit("nodes")) { try RouteGraph(nodeCount: RouteGraph.maxNodes + 1) }
        var graph = try RouteGraph(nodeCount: 3)
        #expect(throws: RouteError.nodeRange(3)) { try graph.addEdge(from: 0, to: 3) }
        #expect(throws: RouteError.nodeRange(-1)) { try graph.addEdge(from: -1, to: 0) }
        #expect(throws: RouteError.negativeCost(-1)) { try graph.addEdge(from: 0, to: 1, cost: -1) }
        #expect(throws: RouteError.negativeCost(RouteGraph.maxCost + 1)) {
            try graph.addEdge(from: 0, to: 1, cost: RouteGraph.maxCost + 1)
        }
        try graph.addEdge(from: 0, to: 1, cost: 5)
        try graph.addEdge(from: 0, to: 1, cost: 2)
        try graph.addUndirectedEdge(1, 2, cost: 7)
        #expect(graph.edgeCount == 4)
        #expect(graph.edges(from: 0) == [RouteEdge(to: 1, cost: 5), RouteEdge(to: 1, cost: 2)])
        #expect(graph.cheapestCost(from: 0, to: 1) == 2)
        #expect(graph.cheapestCost(from: 1, to: 0) == nil)
        #expect(graph.adjacent(1, 0) && graph.adjacent(2, 1) && !graph.adjacent(0, 2))
        #expect(graph.edges(from: 9).isEmpty)
        #expect(RouteError.negativeCost(1).reasonCode == "r2-f16.negative-cost")
    }

    @Test func gridConversionHasNoCornerCutting() throws {
        // 3 × 3 with the centre-top (1) and centre-left (3) blocked: from 0 nothing is reachable diagonally to 4.
        let grid = try GridGraph(width: 3, height: 3, neighbourhood: .eight, blocked: [1, 3])
        let graph = grid.graph()
        #expect(graph.edges(from: 0).isEmpty)
        #expect(!graph.hasEdge(from: 4, to: 0))
        #expect(graph.edges(from: 1).isEmpty && graph.edges(from: 3).isEmpty)
        // From the centre: right, down, then the open diagonal (1, 1) → 8; (1, −1) → 2 is cut by 1, (−1, 1) → 6 by 3.
        #expect(graph.edges(from: 4).map(\.to) == [5, 7, 8])
        let four = try GridGraph(width: 3, height: 2).graph()
        #expect(four.edges(from: 4).map(\.to) == [1, 5, 3])
        #expect(grid.node(x: 2, y: 1) == 5)
        #expect(grid.cell(of: 7) == (1, 2))
        let estimate = grid.estimate(to: 8)
        #expect(estimate(0) == 2)
        #expect(try GridGraph(width: 3, height: 3).estimate(to: 8)(0) == 4)
        #expect(throws: RouteError.emptyGraph) { try GridGraph(width: 0, height: 3) }
        #expect(throws: RouteError.graphLimit("side")) { try GridGraph(width: 4_097, height: 1) }
        #expect(throws: RouteError.graphLimit("cells")) { try GridGraph(width: 4_096, height: 257) }
        #expect(throws: RouteError.nodeRange(9)) { try GridGraph(width: 3, height: 3, blocked: [9]) }
    }

    @Test func scheduleBounds() throws {
        let schedule = try RouteSchedule(cellCount: 4, steps: 3) { cell, time in (cell + time) % 2 == 0 }
        #expect(schedule.isOpen(0, at: 0) && !schedule.isOpen(1, at: 0) && schedule.isOpen(1, at: 1))
        #expect(!schedule.isOpen(0, at: 3) && !schedule.isOpen(0, at: -1) && !schedule.isOpen(4, at: 0))
        #expect(throws: RouteError.emptyGraph) { try RouteSchedule(cellCount: 0, steps: 1) { _, _ in true } }
        #expect(throws: RouteError.scheduleLimit) { try RouteSchedule(cellCount: 1, steps: 4_097) { _, _ in true } }
        #expect(throws: RouteError.scheduleLimit) {
            try RouteSchedule(cellCount: 4_097, steps: 4_096) { _, _ in true }
        }
    }

    private func everyKind() -> [SolverCertificate] {
        var all: [SolverCertificate] = []
        all.append(.route(path: RoutePath(nodes: [0, 1, 2], cost: 3), potentials: [0, 1, 3]))
        all.append(.unreachable(start: 0, goal: 5, reachable: [0, 1, 4]))
        all.append(.timedRoute(states: [TimedState(node: 0, time: 0), TimedState(node: 0, time: 1)], allowWaiting: true))
        all.append(.timedUnreachable(start: 0, goal: 3, startTime: 2, allowWaiting: false,
                                     reachable: [TimedState(node: 0, time: 2), TimedState(node: 1, time: 3)]))
        all.append(.cut(source: 0, sink: 3, edges: [CutEdge(from: 0, to: 1)],
                        routes: [RoutePath(nodes: [0, 1, 3], cost: 2)]))
        all.append(.placement(map: [4, 2, 7]))
        all.append(.exhausted(examined: 1_234))
        return all
    }

    @Test func certificatesRoundTripByteForByte() throws {
        for certificate in everyKind() {
            let data = certificate.encoded()
            let decoded = try SolverCertificate.decode(data)
            #expect(decoded == certificate, "\(certificate.kind)")
            #expect(decoded.encoded() == data, "\(certificate.kind)")
            let text = String(decoding: data, as: UTF8.self)
            #expect(text.contains("\"kind\":\"\(certificate.kind)\"") && text.contains("\"schema\":1"))
        }
    }

    @Test func newerAndDamagedCertificatesAreRefused() throws {
        let newer = Data(#"{"examined":3,"kind":"exhausted","schema":2}"#.utf8)
        #expect(throws: RouteError.newerSchema(2)) { try SolverCertificate.decode(newer) }
        let damaged: [String] = [
            #"{"examined":3,"kind":"exhausted"}"#,
            #"{"kind":"exhausted","schema":1}"#,
            #"{"kind":"teleport","schema":1}"#,
            #"{"examined":3,"kind":"exhausted","schema":0}"#,
            #"{"kind":"route","path":{"nodes":[0]},"potentials":[0],"schema":1}"#,
            #"{"examined":3,"kind":"exha"#,
            "",
        ]
        for text in damaged {
            do {
                _ = try SolverCertificate.decode(Data(text.utf8))
                Issue.record("accepted \(text)")
            } catch {
                #expect(error.reasonCode == "r2-f16.malformed", "\(text)")
            }
        }
    }
}
