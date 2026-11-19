// CycleTests — feature 166 (A23-P01) T-A23-107 (SC-A23-103; FR-A23-105; User Story 3; edge cases "two connections
// forming a loop", "several separate loops"; clarification Q4 stage 4). Loops of 1, 2, 3 and 8 nodes and two separate
// loops are each refused with exactly the connections of the named loop, in forward order from the connection whose
// source has the smallest identity; the loop named is the one reached from the smallest remaining identity; a loop
// through an otherwise valid graph is reported only as a cycle; every acyclic fixture is ordered with each node after
// every node feeding it, identically across 10 checks.
import Testing
import VisualProgrammingLabCore

@Suite struct CycleTests {
    typealias F = GraphFixtures

    /// Expects `graph` refused with exactly `.cycle(expected)`, and that `expected` is a closed loop of the graph's
    /// connections, each once.
    static func expectCycle(_ graph: VisualGraph, _ expected: [GraphEdge], _ name: String,
                            sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(GraphChecker.check(graph) == .refused([.cycle(expected)]), "\(name)", sourceLocation: sourceLocation)
        #expect(Set(expected).count == expected.count, "\(name): each connection once", sourceLocation: sourceLocation)
        for (index, edge) in expected.enumerated() {
            #expect(graph.edges.contains(edge), "\(name): \(edge) is in the graph", sourceLocation: sourceLocation)
            let next = expected[(index + 1) % expected.count]
            #expect(edge.targetNode == next.sourceNode, "\(name): the loop follows on at \(index)",
                    sourceLocation: sourceLocation)
        }
        let smallest = expected.map(\.sourceNode).min()
        #expect(expected.first?.sourceNode == smallest, "\(name): starts at the smallest source",
                sourceLocation: sourceLocation)
    }

    @Test func aNodeFedByItselfIsALoopOfOne() {
        Self.expectCycle(F.loopOfOne, [F.edge(1, "image", 1, "image")], "loop of one")
    }

    @Test func aLoopOfTwo() {
        Self.expectCycle(F.loopOfTwo, [F.edge(1, "image", 2, "image"), F.edge(2, "image", 1, "image")], "loop of two")
    }

    @Test func aLoopOfThreeIsNamedInLoopOrder() {
        Self.expectCycle(F.loopOfThree, [F.edge(1, "image", 2, "image"), F.edge(2, "image", 3, "image"),
                                         F.edge(3, "image", 1, "image")], "loop of three")
    }

    @Test func aLoopOfEightStartsAtItsSmallestSource() {
        let ring = [1, 8, 3, 4, 7, 2, 9, 5]   // F.ringOfEight rotated to start at identity 1
        var expected: [GraphEdge] = []
        for (index, id) in ring.enumerated() { expected.append(F.edge(id, "image", ring[(index + 1) % 8], "image")) }
        #expect(expected.count == 8)
        Self.expectCycle(F.loopOfEight, expected, "loop of eight")
    }

    @Test func ofTwoLoopsTheOneReachedFirstIsNamed() {
        Self.expectCycle(F.twoLoops, [F.edge(1, "image", 5, "image"), F.edge(5, "image", 3, "image"),
                                      F.edge(3, "image", 1, "image")], "two loops")
    }

    @Test func aLoopBelowTheSmallestRemainingIdentityIsFoundByTheBackwardWalk() {
        Self.expectCycle(F.loopAboveOutput, [F.edge(5, "image", 6, "image"), F.edge(6, "image", 5, "image")],
                         "loop above the output")
    }

    @Test func aLoopThroughAnOtherwiseValidGraphIsOnlyACycle() {
        Self.expectCycle(F.loopThroughValidGraph, [F.edge(2, "image", 3, "image"), F.edge(3, "image", 2, "b")],
                         "loop through a valid graph")
    }

    @Test func everyAcyclicFixturePutsEachNodeAfterItsInputs() throws {
        for (name, graph) in F.acyclic {
            guard case .accepted(let order, _) = GraphChecker.check(graph) else {
                Issue.record("\(name) was refused")
                continue
            }
            #expect(order.sorted() == graph.nodes.map(\.id).sorted(), "\(name): every node once")
            var position: [NodeID: Int] = [:]
            for (index, id) in order.enumerated() { position[id] = index }
            for edge in graph.edges {
                let source = try #require(position[edge.sourceNode])
                let target = try #require(position[edge.targetNode])
                #expect(source < target, "\(name): \(edge)")
            }
        }
    }

    @Test func theOrderTakesTheSmallestReadyIdentityFirst() {
        let expected: [(VisualGraph, [Int])] = [(F.noiseToOutput, [1, 2]), (F.journeyMix, [1, 2, 3, 4, 5]),
                                                (F.fullLibrary, [1, 3, 2, 4, 5, 6, 7]), (F.descendingIDs, [9, 5, 1]),
                                                (F.atLimits, Array(1...32))]
        for (graph, ids) in expected {
            guard case .accepted(let order, _) = GraphChecker.check(graph) else {
                Issue.record("refused: \(graph)")
                continue
            }
            #expect(order == F.ids(ids))
        }
    }

    @Test func tenChecksGiveTheSameResult() {
        for (name, graph) in F.acyclic + F.cycles {
            let first = GraphChecker.check(graph)
            var same = 0
            for _ in 0..<10 where GraphChecker.check(graph) == first { same += 1 }
            #expect(same == 10, "\(name)")
        }
    }

    @Test func theStoredOrderOfConnectionsDoesNotChangeTheNamedLoop() {
        var reversed = F.loopOfEight
        reversed.edges.reverse()
        reversed.nodes.reverse()
        #expect(GraphChecker.check(reversed) == GraphChecker.check(F.loopOfEight))
    }
}
