// DiagnosticsTests — feature 169 (A23-P04) T-A23-407 (FR-A23-405; SC-A23-405; clarification Q5; User Story 4). For
// every invalid fixture of GraphFixtures, exactly the nodes the checker names (and that are in the graph) are marked,
// each with its exact sentences; every accepted fixture marks none; a loop marks each node of the named loop; the 12
// mismatched type pairs mark the target with the EditMessages sentence; sentences keep the issue order, never repeat,
// and a node absent from the graph is never marked.
import Testing
import VisualProgrammingLabCore

@Suite struct DiagnosticsTests {
    typealias F = GraphFixtures
    typealias D = GraphDiagnostics

    /// Expects the diagnostics of `graph` to be exactly `expected` (identity → sentences).
    static func expectMarks(_ graph: VisualGraph, _ expected: [Int: [String]], _ name: String,
                            sourceLocation: SourceLocation = #_sourceLocation) {
        var wanted: [NodeID: [String]] = [:]
        for (id, sentences) in expected { wanted[NodeID(id)] = sentences }
        let marks = D.byNode(GraphChecker.check(graph), in: graph)
        #expect(marks == wanted, "\(name)", sourceLocation: sourceLocation)
    }

    /// The nodes an issue names, independently of GraphDiagnostics.
    static func named(_ issue: GraphIssue) -> [NodeID] {
        switch issue {
        case .tooManyNodes, .tooManyEdges, .noOutput: return []
        case .duplicateNode(let node), .unknownNode(let node), .outputDisconnected(let node): return [node]
        case .unknownParameter(let node, _), .parameterOutOfRange(let node, _): return [node]
        case .unknownPort(let node, _), .wrongDirection(let node, _), .inputAlreadyConnected(let node, _),
             .inputUnconnected(let node, _): return [node]
        case .typeMismatch(let edge, _, _), .duplicateEdge(let edge): return [edge.targetNode]
        case .cycle(let edges): return edges.map(\.sourceNode)
        case .multipleOutputs(let outputs): return outputs
        }
    }

    @Test func everyFixtureMarksExactlyTheNodesTheCheckerNames() {
        for (name, graph) in F.all {
            let result = GraphChecker.check(graph)
            let present = Set(graph.nodes.map(\.id))
            var expected: Set<NodeID> = []
            if case .refused(let issues) = result {
                for issue in issues { expected.formUnion(Self.named(issue).filter { present.contains($0) }) }
            }
            let marks = D.byNode(result, in: graph)
            #expect(Set(marks.keys) == expected, "\(name)")
            for (node, sentences) in marks {
                #expect(!sentences.isEmpty, "\(name): node \(node) has a sentence")
                #expect(Set(sentences).count == sentences.count, "\(name): node \(node) has no repeat")
            }
        }
    }

    @Test func acceptedGraphsMarkNoNode() {
        for (name, graph) in F.acyclic {
            #expect(D.byNode(GraphChecker.check(graph), in: graph).isEmpty, "\(name)")
        }
        let accepted = CheckResult.accepted(order: F.ids([1, 2]), reaching: Set(F.ids([1, 2])))
        #expect(D.byNode(accepted, in: F.noiseToOutput).isEmpty)
    }

    @Test func limitsAndAMissingOutputMarkNoNode() {
        Self.expectMarks(F.oneNodePastLimit, [:], "one node past the limit")
        Self.expectMarks(F.oneEdgePastLimit, [:], "one connection past the limit")
        Self.expectMarks(F.empty, [:], "empty")
        Self.expectMarks(F.noOutputNode, [:], "no output node")
    }

    @Test func nodeStageIssuesMarkTheirNode() {
        Self.expectMarks(F.duplicateNode, [1: ["Another node has the same identity."]], "duplicate node")
        Self.expectMarks(F.undeclaredParameter, [1: ["Parameter colour does not exist."]], "undeclared parameter")
        Self.expectMarks(F.parameterOutOfRange, [1: ["Parameter scale is out of range."]], "out of range")
        Self.expectMarks(F.parameterNotFinite, [1: ["Parameter speed is out of range."]], "not finite")
        Self.expectMarks(F.nodeAndEdgeIssues, [1: ["Parameter hue does not exist."]], "node and edge issues")
    }

    @Test func connectionStageIssuesMarkTheNamedNode() {
        Self.expectMarks(F.unknownTargetNode, [:], "unknown target node (node 9 is not in the graph)")
        Self.expectMarks(F.unknownSourceNode, [:], "unknown source node (node 9 is not in the graph)")
        Self.expectMarks(F.unknownSourcePort, [1: ["That port does not exist."]], "unknown source port")
        Self.expectMarks(F.unknownTargetPort, [2: ["That port does not exist."]], "unknown target port")
        Self.expectMarks(F.fromAnInput, [1: ["Connect an output to an input."]], "from an input")
        Self.expectMarks(F.intoAnOutput, [2: ["Connect an output to an input."]], "into an output")
        Self.expectMarks(F.inputFedTwice, [3: ["Output 3: input image is already connected."]], "input fed twice")
        Self.expectMarks(F.duplicateEdge, [2: ["This connection is made twice."]], "duplicate connection")
    }

    @Test func aTypeMismatchMarksTheTargetWithBothTypes() {
        Self.expectMarks(F.typePair(from: .time, to: .scalar).graph, [2: ["A time output cannot feed a scalar input."]],
                         "time into scalar")
        var mismatched = 0
        for from in ValueType.allCases {
            for to in ValueType.allCases {
                let graph = F.typePair(from: from, to: to).graph
                let expected: [Int: [String]]
                if from == to {
                    expected = [:]
                } else {
                    mismatched += 1
                    expected = [2: [EditMessages.sentence(for: .typeMismatch(from: from, to: to), in: graph)]]
                }
                Self.expectMarks(graph, expected, "type \(from.rawValue) into \(to.rawValue)")
            }
        }
        #expect(mismatched == 12)
    }

    @Test func aLoopMarksEachNodeOfTheLoop() {
        let loop = ["This node is part of a loop."]
        Self.expectMarks(F.loopOfOne, [1: loop], "loop of one")
        Self.expectMarks(F.loopOfTwo, [1: loop, 2: loop], "loop of two")
        Self.expectMarks(F.loopOfThree, [1: loop, 2: loop, 3: loop], "loop of three")
        var eight: [Int: [String]] = [:]
        for id in F.ringOfEight { eight[id] = loop }
        #expect(eight.count == 8)
        Self.expectMarks(F.loopOfEight, eight, "loop of eight")
        Self.expectMarks(F.twoLoops, [1: loop, 3: loop, 5: loop], "two loops: the named loop only")
        Self.expectMarks(F.loopThroughValidGraph, [2: loop, 3: loop], "loop through a valid graph")
        Self.expectMarks(F.loopAboveOutput, [5: loop, 6: loop], "loop above the output")
    }

    @Test func outputStageIssuesMarkTheirNodes() {
        Self.expectMarks(F.twoOutputs, [2: ["Only one Output may exist."], 3: ["Only one Output may exist."]],
                         "two outputs")
        Self.expectMarks(F.disconnectedOutput, [2: ["Nothing is connected to this Output."]], "disconnected output")
        Self.expectMarks(F.mixMissingB, [2: ["Input b is empty."]], "mix missing b")
        Self.expectMarks(F.mixMissingA, [2: ["Input a is empty."]], "mix missing a")
        Self.expectMarks(F.unreachedEmptyInput, [3: ["Input image is empty."]], "unreached empty input")
    }

    @Test func sentencesKeepIssueOrderWithoutRepeats() {
        let graph = VisualGraph(nodes: [F.node(1, .noise), F.node(2, .mix), F.node(3, .output)])
        let result = CheckResult.refused([.inputUnconnected(node: NodeID(2), port: "b"),
                                          .outputDisconnected(NodeID(3)),
                                          .inputUnconnected(node: NodeID(2), port: "a"),
                                          .inputUnconnected(node: NodeID(2), port: "b")])
        let marks = D.byNode(result, in: graph)
        #expect(D.sentences(for: NodeID(2), in: marks) == ["Input b is empty.", "Input a is empty."])
        #expect(D.sentences(for: NodeID(3), in: marks) == ["Nothing is connected to this Output."])
        #expect(D.sentences(for: NodeID(1), in: marks).isEmpty)
        #expect(marks.count == 2)
    }

    @Test func aNodeAbsentFromTheGraphIsNeverMarked() {
        let result = CheckResult.refused([.outputDisconnected(NodeID(42)), .unknownNode(NodeID(9)),
                                          .inputUnconnected(node: NodeID(1), port: "image")])
        let marks = D.byNode(result, in: F.unreachedEmptyInput)
        #expect(Set(marks.keys) == [NodeID(1)])
    }
}
