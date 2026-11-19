// TypeCheckTests — feature 166 (A23-P01) T-A23-107 (SC-A23-102; FR-A23-104; User Story 2; clarification Q4 stages
// 1–3). All 16 pairs of value types, exactly the 4 matching pairs connecting and the others refused naming both types;
// a connection to an unknown node or port, from an input, into an output, a second connection into a fed input and a
// duplicate connection, each refused by name; an undeclared parameter and a value outside its range refused by name
// (stage 2, before any connection is looked at); a missing parameter takes its default; the issue codes.
import Testing
import VisualProgrammingLabCore

@Suite struct TypeCheckTests {
    typealias F = GraphFixtures

    @Test func exactlyTheFourMatchingPairsConnect() {
        var connecting: [String] = []
        var pairs = 0
        for from in ValueType.allCases {
            for to in ValueType.allCases {
                pairs += 1
                let (graph, edge) = F.typePair(from: from, to: to)
                let result = GraphChecker.check(graph)
                if from == to {
                    if case .accepted = result {
                        connecting.append("\(from.rawValue)-\(to.rawValue)")
                    } else {
                        Issue.record("\(from) → \(to) should connect: \(result)")
                    }
                } else {
                    #expect(result == .refused([.typeMismatch(edge, from: from, to: to)]), "\(from) → \(to)")
                }
            }
        }
        #expect(pairs == 16)
        #expect(connecting == ["scalar-scalar", "colour-colour", "texture-texture", "time-time"])
    }

    @Test func colourIntoScalarNamesBothTypes() throws {
        let (graph, edge) = F.typePair(from: .colour, to: .scalar)
        let result = GraphChecker.check(graph)
        guard case .refused(let issues) = result else {
            Issue.record("colour into scalar was accepted")
            return
        }
        let issue = try #require(issues.first)
        #expect(issues.count == 1)
        #expect(issue == .typeMismatch(edge, from: .colour, to: .scalar))
        #expect(issue.code == "type-mismatch")
    }

    @Test func timeDoesNotFeedAScalarInput() {
        let (graph, edge) = F.typePair(from: .time, to: .scalar)
        #expect(GraphChecker.check(graph) == .refused([.typeMismatch(edge, from: .time, to: .scalar)]))
    }

    @Test func unknownNodesAreRefusedByIdentity() {
        #expect(GraphChecker.check(F.unknownTargetNode) == .refused([.unknownNode(NodeID(9))]))
        #expect(GraphChecker.check(F.unknownSourceNode) == .refused([.unknownNode(NodeID(9))]))
    }

    @Test func unknownPortsAreRefusedByName() {
        #expect(GraphChecker.check(F.unknownSourcePort) == .refused([.unknownPort(node: NodeID(1), port: "colour")]))
        #expect(GraphChecker.check(F.unknownTargetPort) == .refused([.unknownPort(node: NodeID(2), port: "picture")]))
    }

    @Test func aConnectionFromAnInputIsTheWrongDirection() {
        #expect(GraphChecker.check(F.fromAnInput) == .refused([.wrongDirection(node: NodeID(1), port: "time")]))
    }

    @Test func aConnectionIntoAnOutputIsTheWrongDirection() {
        #expect(GraphChecker.check(F.intoAnOutput) == .refused([.wrongDirection(node: NodeID(2), port: "image")]))
    }

    @Test func anInputFedTwiceIsRefused() {
        #expect(GraphChecker.check(F.inputFedTwice)
                == .refused([.inputAlreadyConnected(node: NodeID(3), port: "image")]))
    }

    @Test func aDuplicateConnectionIsRefusedOnce() {
        let edge = F.edge(1, "image", 2, "image")
        #expect(GraphChecker.check(F.duplicateEdge) == .refused([.duplicateEdge(edge)]))
    }

    @Test func aDuplicateIdentityIsRefused() {
        #expect(GraphChecker.check(F.duplicateNode) == .refused([.duplicateNode(NodeID(1))]))
    }

    @Test func anUndeclaredParameterIsRefusedByName() {
        #expect(GraphChecker.check(F.undeclaredParameter)
                == .refused([.unknownParameter(node: NodeID(1), name: "colour")]))
    }

    @Test func aValueOutsideItsRangeOrNotFiniteIsRefusedByName() {
        #expect(GraphChecker.check(F.parameterOutOfRange)
                == .refused([.parameterOutOfRange(node: NodeID(1), name: "scale")]))
        #expect(GraphChecker.check(F.parameterNotFinite)
                == .refused([.parameterOutOfRange(node: NodeID(1), name: "speed")]))
    }

    @Test func aMissingParameterTakesItsDefault() throws {
        let graph = F.missingParameters
        guard case .accepted = GraphChecker.check(graph) else {
            Issue.record("a graph with missing parameters was refused")
            return
        }
        let noise = try #require(graph.node(NodeID(1)))
        let scale = try #require(NodeKind.noise.parameter("scale"))
        #expect(noise.value(of: "scale") == scale.defaultValue)
        #expect(noise.value(of: "octaves") == 2)
    }

    @Test func theNodeStageStopsBeforeTheConnections() {
        #expect(GraphChecker.check(F.nodeAndEdgeIssues) == .refused([.unknownParameter(node: NodeID(1), name: "hue")]))
    }

    @Test func theLimitsAreCheckedFirstAtAndPastEachBound() {
        #expect(F.atLimits.nodes.count == GraphLimits.maxNodes)
        #expect(F.atLimits.edges.count == GraphLimits.maxEdges)
        if case .accepted = GraphChecker.check(F.atLimits) {} else { Issue.record("the graph at the limits was refused") }
        #expect(GraphChecker.check(F.oneNodePastLimit) == .refused([.tooManyNodes(33)]))
        #expect(GraphChecker.check(F.oneEdgePastLimit) == .refused([.tooManyEdges(65)]))
    }

    @Test func everyIssueHasItsOwnCode() {
        let edge = F.edge(1, "image", 2, "image")
        let id = NodeID(1)
        let issues: [GraphIssue] = [
            .tooManyNodes(33), .tooManyEdges(65), .duplicateNode(id), .unknownParameter(node: id, name: "x"),
            .parameterOutOfRange(node: id, name: "x"), .unknownNode(id), .unknownPort(node: id, port: "x"),
            .wrongDirection(node: id, port: "x"), .typeMismatch(edge, from: .colour, to: .scalar),
            .inputAlreadyConnected(node: id, port: "x"), .duplicateEdge(edge), .cycle([edge]), .noOutput,
            .multipleOutputs([id]), .outputDisconnected(id), .inputUnconnected(node: id, port: "x")]
        let codes = issues.map(\.code)
        #expect(codes == ["too-many-nodes", "too-many-edges", "duplicate-node", "unknown-parameter",
                          "parameter-out-of-range", "unknown-node", "unknown-port", "wrong-direction", "type-mismatch",
                          "input-already-connected", "duplicate-edge", "cycle", "no-output", "multiple-outputs",
                          "output-disconnected", "input-unconnected"])
        #expect(Set(codes).count == 16)
    }
}
