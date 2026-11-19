// EditorTests — feature 167 (A23-P02) T-A23-203 (SC-A23-201, SC-A23-202; FR-A23-202, FR-A23-203; clarification Q1;
// Edge Cases; User Stories 1 and 2). The pure edits of `GraphEditor`: a new node takes the smallest unused identity
// (reused after a remove), its position is clamped to ±4,096 (non-finite → 0), adding is refused at 32 nodes and for a
// second output; move clamps and refuses an unknown node; remove takes the node's connections; connect refuses an
// unknown node, a bad port index, colour into scalar (naming both types), a fed input (an identical connection
// included) and a loop (naming its connections), accepts an incomplete graph, and builds the journey graph Noise and
// Gradient → Mix → Blur → Output from the starter graph; disconnect. Every refusal leaves the graph's fingerprint
// unchanged and carries its rule id. Synthetic data only; no clock.
import Testing
import VisualCoreExperience
import VisualProgrammingLabCore

@Suite struct EditorTests {
    typealias F = GraphFixtures

    // MARK: Helpers

    /// The starter graph: Noise 1 → Output 2.
    private static var starter: VisualGraph { F.noiseToOutput }

    /// The refusal `edit` throws, or nil when it succeeds.
    private static func refusal(_ edit: () throws(GraphEditRefusal) -> VisualGraph) -> GraphEditRefusal? {
        do throws(GraphEditRefusal) {
            _ = try edit()
            return nil
        } catch {
            return error
        }
    }

    /// Checks that `edit` on `graph` is refused with `expected` and leaves the graph's fingerprint unchanged.
    private static func expectRefused(_ expected: GraphEditRefusal, on graph: VisualGraph,
                                      _ edit: (VisualGraph) throws(GraphEditRefusal) -> VisualGraph,
                                      sourceLocation: SourceLocation = #_sourceLocation) throws {
        let before = try GraphDocument.fingerprint(of: graph)
        let found = refusal { () throws(GraphEditRefusal) -> VisualGraph in try edit(graph) }
        let after = try GraphDocument.fingerprint(of: graph)
        #expect(found == expected, sourceLocation: sourceLocation)
        #expect(before == after, sourceLocation: sourceLocation)
    }

    /// A 65th connection is refused (lead, T-A23-203): Noise 1, Constant 2 and Mix 3…32 hold 90 inputs, so the
    /// connection limit is reachable by editing; 64 connections are made in order, then the next is refused.
    @Test func aConnectionPastSixtyFourIsRefused() throws {
        var graph = VisualGraph(nodes: [F.node(1, .noise), F.node(2, .constant)] + (3...32).map { F.node($0, .mix) })
        var feeds: [(source: Int, output: Int, target: Int, input: Int)] = []
        for target in 3...32 { feeds += [(1, 0, target, 0), (1, 0, target, 1), (2, 0, target, 2)] }
        for feed in feeds.prefix(GraphLimits.maxEdges) {
            graph = try GraphEditor.connect(source: NodeID(feed.source), outputIndex: feed.output,
                                            target: NodeID(feed.target), inputIndex: feed.input, in: graph)
        }
        #expect(graph.edges.count == GraphLimits.maxEdges)
        let next = feeds[GraphLimits.maxEdges]
        try Self.expectRefused(.tooManyEdges, on: graph) { graph throws(GraphEditRefusal) in
            try GraphEditor.connect(source: NodeID(next.source), outputIndex: next.output,
                                    target: NodeID(next.target), inputIndex: next.input, in: graph)
        }
    }

    /// Adds `kind` at the origin of `graph`, returning the edited graph.
    private static func adding(_ kind: NodeKind) -> (VisualGraph) throws(GraphEditRefusal) -> VisualGraph {
        { graph throws(GraphEditRefusal) in try GraphEditor.add(kind, at: CanvasPoint(x: 0, y: 0), to: graph).graph }
    }

    // MARK: Add

    @Test func addTakesTheSmallestUnusedIdentity() throws {
        let (first, firstID) = try GraphEditor.add(.noise, at: CanvasPoint(x: 10, y: 20), to: VisualGraph())
        #expect(firstID == NodeID(1))
        let gap = VisualGraph(nodes: [F.node(1, .noise), F.node(2, .blur), F.node(4, .output)])
        let (filled, gapID) = try GraphEditor.add(.mix, at: CanvasPoint(x: 0, y: 0), to: gap)
        #expect(gapID == NodeID(3))
        let (_, nextID) = try GraphEditor.add(.mix, at: CanvasPoint(x: 0, y: 0), to: filled)
        #expect(nextID == NodeID(5))
        let added = try #require(first.node(firstID))
        #expect(added == GraphNode(id: NodeID(1), kind: .noise, position: CanvasPoint(x: 10, y: 20)))
        #expect(first.nodes.count == 1)
        #expect(first.edges.isEmpty)
    }

    @Test func addReusesAnIdentityAfterARemove() throws {
        let removed = try GraphEditor.remove(NodeID(3), from: F.journeyMix)
        let (graph, id) = try GraphEditor.add(.gradient, at: CanvasPoint(x: 0, y: 0), to: removed)
        #expect(id == NodeID(3))
        #expect(graph.node(id)?.kind == .gradient)
    }

    @Test func addClampsThePosition() throws {
        let (graph, id) = try GraphEditor.add(.blur, at: CanvasPoint(x: 5_000, y: -9_000), to: VisualGraph())
        #expect(graph.node(id)?.position == CanvasPoint(x: 4_096, y: -4_096))
        let (inside, insideID) = try GraphEditor.add(.blur, at: CanvasPoint(x: -4_096, y: 12.5), to: VisualGraph())
        #expect(inside.node(insideID)?.position == CanvasPoint(x: -4_096, y: 12.5))
    }

    @Test func addMakesANonFinitePositionZero() throws {
        let (graph, id) = try GraphEditor.add(.time, at: CanvasPoint(x: .nan, y: .infinity), to: VisualGraph())
        #expect(graph.node(id)?.position == CanvasPoint(x: 0, y: 0))
        let (other, otherID) = try GraphEditor.add(.time, at: CanvasPoint(x: 7, y: -.infinity), to: VisualGraph())
        #expect(other.node(otherID)?.position == CanvasPoint(x: 7, y: 0))
    }

    @Test func addIsRefusedAtThirtyTwoNodes() throws {
        #expect(F.atLimits.nodes.count == GraphLimits.maxNodes)
        try Self.expectRefused(.tooManyNodes, on: F.atLimits, Self.adding(.noise))
        try Self.expectRefused(.tooManyNodes, on: F.atLimits, Self.adding(.output))   // the limit is checked first
        var thirtyOne = F.atLimits
        thirtyOne.nodes.removeAll { $0.id == NodeID(30) }
        let (graph, id) = try GraphEditor.add(.noise, at: CanvasPoint(x: 0, y: 0), to: thirtyOne)
        #expect(id == NodeID(30))
        #expect(graph.nodes.count == 32)
    }

    @Test func addIsRefusedForASecondOutput() throws {
        try Self.expectRefused(.oneOutput, on: Self.starter, Self.adding(.output))
        let removed = try GraphEditor.remove(NodeID(2), from: Self.starter)
        let (graph, id) = try GraphEditor.add(.output, at: CanvasPoint(x: 0, y: 0), to: removed)
        #expect(id == NodeID(2))
        #expect(graph.output == NodeID(2))
    }

    // MARK: Move

    @Test func moveSetsAndClampsThePosition() throws {
        let moved = try GraphEditor.move(NodeID(1), to: CanvasPoint(x: 120, y: -48), in: Self.starter)
        #expect(moved.node(NodeID(1))?.position == CanvasPoint(x: 120, y: -48))
        #expect(moved.edges == Self.starter.edges)
        let far = try GraphEditor.move(NodeID(2), to: CanvasPoint(x: -1e9, y: 4_097), in: Self.starter)
        #expect(far.node(NodeID(2))?.position == CanvasPoint(x: -4_096, y: 4_096))
        let lost = try GraphEditor.move(NodeID(2), to: CanvasPoint(x: .nan, y: 3), in: Self.starter)
        #expect(lost.node(NodeID(2))?.position == CanvasPoint(x: 0, y: 3))
    }

    @Test func moveRefusesAnUnknownNode() throws {
        try Self.expectRefused(.unknownNode(NodeID(9)), on: Self.starter) { graph throws(GraphEditRefusal) in
            try GraphEditor.move(NodeID(9), to: CanvasPoint(x: 1, y: 1), in: graph)
        }
    }

    // MARK: Remove

    @Test func removeTakesTheNodesConnections() throws {
        let removed = try GraphEditor.remove(NodeID(3), from: F.journeyMix)
        #expect(removed.nodes.map(\.id) == F.ids([1, 2, 4, 5]))
        #expect(removed.edges == [F.edge(4, "image", 5, "image")])
    }

    @Test func removingTheOutputIsAllowed() throws {
        let removed = try GraphEditor.remove(NodeID(2), from: Self.starter)
        #expect(removed.nodes.map(\.id) == F.ids([1]))
        #expect(removed.edges.isEmpty)
        #expect(GraphChecker.check(removed) == .refused([.noOutput]))
    }

    @Test func removeRefusesAnUnknownNode() throws {
        try Self.expectRefused(.unknownNode(NodeID(7)), on: Self.starter) { graph throws(GraphEditRefusal) in
            try GraphEditor.remove(NodeID(7), from: graph)
        }
    }

    // MARK: Connect

    @Test func connectAddsTheConnectionByDeclarationOrder() throws {
        let graph = VisualGraph(nodes: [F.node(1, .constant), F.node(2, .noise), F.node(3, .output)])
        let scale = try GraphEditor.connect(source: NodeID(1), outputIndex: 0, target: NodeID(2), inputIndex: 1,
                                            in: graph)
        #expect(scale.edges == [F.edge(1, "value", 2, "scale")])
        #expect(scale.nodes == graph.nodes)
    }

    @Test func connectRefusesUnknownNodes() throws {
        let starter = Self.starter
        try Self.expectRefused(.unknownNode(NodeID(9)), on: starter) { graph throws(GraphEditRefusal) in
            try GraphEditor.connect(source: NodeID(9), outputIndex: 0, target: NodeID(2), inputIndex: 0, in: graph)
        }
        try Self.expectRefused(.unknownNode(NodeID(8)), on: starter) { graph throws(GraphEditRefusal) in
            try GraphEditor.connect(source: NodeID(1), outputIndex: 0, target: NodeID(8), inputIndex: 0, in: graph)
        }
    }

    @Test func connectRefusesBadPortIndices() throws {
        let graph = VisualGraph(nodes: [F.node(1, .noise), F.node(2, .blur), F.node(3, .output)])
        let cases: [(source: Int, output: Int, target: Int, input: Int)] = [
            (1, 1, 2, 0),    // noise has one output
            (1, -1, 2, 0),   // negative output index
            (1, 0, 2, 2),    // blur has two inputs
            (1, 0, 2, -1),   // negative input index
            (3, 0, 2, 0),    // output has no outputs
            (2, 0, 1, 2),    // noise has two inputs
        ]
        for item in cases {
            try Self.expectRefused(.unknownPort, on: graph) { graph throws(GraphEditRefusal) in
                try GraphEditor.connect(source: NodeID(item.source), outputIndex: item.output,
                                        target: NodeID(item.target), inputIndex: item.input, in: graph)
            }
        }
    }

    @Test func colourIntoScalarIsRefusedNamingBothTypes() throws {
        let graph = VisualGraph(nodes: [F.node(1, .constant), F.node(2, .noise), F.node(3, .output)],
                                edges: [F.edge(2, "image", 3, "image")])
        try Self.expectRefused(.typeMismatch(from: .colour, to: .scalar), on: graph) { graph throws(GraphEditRefusal) in
            try GraphEditor.connect(source: NodeID(1), outputIndex: 1, target: NodeID(2), inputIndex: 1, in: graph)
        }
        try Self.expectRefused(.typeMismatch(from: .scalar, to: .time), on: graph) { graph throws(GraphEditRefusal) in
            try GraphEditor.connect(source: NodeID(1), outputIndex: 0, target: NodeID(2), inputIndex: 0, in: graph)
        }
    }

    @Test func aFedInputIsRefused() throws {
        let graph = VisualGraph(nodes: [F.node(1, .noise), F.node(2, .output), F.node(3, .gradient)],
                                edges: [F.edge(1, "image", 2, "image")])
        try Self.expectRefused(.inputTaken(node: NodeID(2), port: "image"), on: graph) { graph throws(GraphEditRefusal) in
            try GraphEditor.connect(source: NodeID(3), outputIndex: 0, target: NodeID(2), inputIndex: 0, in: graph)
        }
        // The identical existing connection is refused the same way.
        try Self.expectRefused(.inputTaken(node: NodeID(2), port: "image"), on: graph) { graph throws(GraphEditRefusal) in
            try GraphEditor.connect(source: NodeID(1), outputIndex: 0, target: NodeID(2), inputIndex: 0, in: graph)
        }
    }

    @Test func aLoopIsRefusedNamingItsConnections() throws {
        let pair = VisualGraph(nodes: [F.node(1, .blur), F.node(2, .blur), F.node(3, .output)],
                               edges: [F.edge(1, "image", 2, "image")])
        try Self.expectRefused(.cycle([F.edge(1, "image", 2, "image"), F.edge(2, "image", 1, "image")]),
                               on: pair) { graph throws(GraphEditRefusal) in
            try GraphEditor.connect(source: NodeID(2), outputIndex: 0, target: NodeID(1), inputIndex: 0, in: graph)
        }
        try Self.expectRefused(.cycle([F.edge(1, "image", 1, "image")]), on: pair) { graph throws(GraphEditRefusal) in
            try GraphEditor.connect(source: NodeID(1), outputIndex: 0, target: NodeID(1), inputIndex: 0, in: graph)
        }
        let throughMix = VisualGraph(nodes: [F.node(1, .noise), F.node(2, .mix), F.node(3, .blur), F.node(4, .output)],
                                     edges: [F.edge(1, "image", 2, "a"), F.edge(2, "image", 3, "image")])
        try Self.expectRefused(.cycle([F.edge(2, "image", 3, "image"), F.edge(3, "image", 2, "b")]),
                               on: throughMix) { graph throws(GraphEditRefusal) in
            try GraphEditor.connect(source: NodeID(3), outputIndex: 0, target: NodeID(2), inputIndex: 1, in: graph)
        }
    }

    @Test func anIncompleteGraphIsAccepted() throws {
        let graph = VisualGraph(nodes: [F.node(1, .noise), F.node(2, .mix), F.node(3, .output)])
        let partial = try GraphEditor.connect(source: NodeID(1), outputIndex: 0, target: NodeID(2), inputIndex: 0,
                                              in: graph)
        #expect(partial.edges == [F.edge(1, "image", 2, "a")])
        #expect(GraphChecker.check(partial) == .refused([.outputDisconnected(NodeID(3)),
                                                         .inputUnconnected(node: NodeID(2), port: "b")]))
    }

    @Test func theJourneyGraphIsBuiltFromTheStarter() throws {
        var graph = Self.starter
        graph = try GraphEditor.add(.gradient, at: CanvasPoint(x: 0, y: 200), to: graph).graph   // 3
        graph = try GraphEditor.add(.mix, at: CanvasPoint(x: 240, y: 100), to: graph).graph      // 4
        graph = try GraphEditor.add(.blur, at: CanvasPoint(x: 480, y: 100), to: graph).graph     // 5
        graph = try GraphEditor.disconnect(target: NodeID(2), inputIndex: 0, in: graph)
        graph = try GraphEditor.connect(source: NodeID(1), outputIndex: 0, target: NodeID(4), inputIndex: 0, in: graph)
        graph = try GraphEditor.connect(source: NodeID(3), outputIndex: 0, target: NodeID(4), inputIndex: 1, in: graph)
        graph = try GraphEditor.connect(source: NodeID(4), outputIndex: 0, target: NodeID(5), inputIndex: 0, in: graph)
        graph = try GraphEditor.connect(source: NodeID(5), outputIndex: 0, target: NodeID(2), inputIndex: 0, in: graph)
        #expect(graph.nodes.map(\.kind) == [.noise, .output, .gradient, .mix, .blur])
        #expect(graph.edges.sorted() == [F.edge(5, "image", 2, "image"), F.edge(1, "image", 4, "a"),
                                         F.edge(3, "image", 4, "b"), F.edge(4, "image", 5, "image")])
        #expect(GraphChecker.check(graph) == .accepted(order: F.ids([1, 3, 4, 5, 2]), reaching: Set(F.ids([1, 2, 3, 4, 5]))))
    }

    // MARK: Disconnect

    @Test func disconnectRemovesTheFeedingConnection() throws {
        let graph = try GraphEditor.disconnect(target: NodeID(3), inputIndex: 1, in: F.journeyMix)
        #expect(graph.edges == [F.edge(1, "image", 3, "a"), F.edge(3, "image", 4, "image"),
                                F.edge(4, "image", 5, "image")])
        #expect(graph.nodes == F.journeyMix.nodes)
    }

    @Test func disconnectingAnUnfedInputChangesNothing() throws {
        let graph = try GraphEditor.disconnect(target: NodeID(1), inputIndex: 0, in: Self.starter)
        #expect(graph == Self.starter)
    }

    @Test func disconnectRefusesAnUnknownNodeOrPort() throws {
        try Self.expectRefused(.unknownNode(NodeID(6)), on: Self.starter) { graph throws(GraphEditRefusal) in
            try GraphEditor.disconnect(target: NodeID(6), inputIndex: 0, in: graph)
        }
        try Self.expectRefused(.unknownPort, on: Self.starter) { graph throws(GraphEditRefusal) in
            try GraphEditor.disconnect(target: NodeID(2), inputIndex: 1, in: graph)
        }
        try Self.expectRefused(.unknownPort, on: Self.starter) { graph throws(GraphEditRefusal) in
            try GraphEditor.disconnect(target: NodeID(2), inputIndex: -1, in: graph)
        }
    }

    // MARK: Rule ids

    @Test func everyRefusalHasItsRuleID() {
        let rules: [(GraphEditRefusal, String)] = [
            (.notWhole, "a23.not-whole"), (.unknownNode(NodeID(1)), "a23.unknown-node"),
            (.unknownPort, "a23.unknown-port"), (.typeMismatch(from: .colour, to: .scalar), "a23.type-mismatch"),
            (.inputTaken(node: NodeID(2), port: "image"), "a23.input-taken"),
            (.cycle([F.edge(1, "image", 1, "image")]), "a23.cycle"), (.tooManyNodes, "a23.too-many-nodes"),
            (.tooManyEdges, "a23.too-many-edges"),
            (.oneOutput, "a23.one-output"),
        ]
        for (refusal, rule) in rules {
            #expect(refusal.rule == rule)
        }
        #expect(Set(rules.map(\.1)).count == 9)
    }
}
