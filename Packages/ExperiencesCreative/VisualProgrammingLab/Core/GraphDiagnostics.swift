// GraphDiagnostics — feature 169 (A23-P04) T-A23-407 (FR-A23-405; SC-A23-405; clarification Q5; User Story 4). Maps
// the checker's refusal to the nodes it concerns, with one plain sentence per problem, so the canvas overlay and the
// list form can mark each node involved: an empty required input marks its node ("Input <port> is empty."), a
// disconnected output marks the Output, a loop marks every source node of the named loop, several outputs mark each
// Output, a connection-stage issue marks the node it names (the target of a type mismatch, the fed input's node,
// the node of an unknown or wrong-direction port) with the `EditMessages` sentence where one exists, and a node-stage
// issue marks its node. A limit, a missing output and an unknown node that is not in the graph mark no node (the
// graph-level status says them). Choices recorded here: sentences keep the order of the issues, each sentence appears
// at most once per node, and a node named by an issue but absent from the graph is never marked. Pure: no UI, GPU or
// clock.
import Foundation

/// The per-node diagnostics of a checker result (clarification Q5).
public enum GraphDiagnostics {
    /// The sentence for an empty required input `port`: "Input <port> is empty."
    public static func emptyInput(_ port: String) -> String { "Input \(port) is empty." }

    /// The sentence for an Output whose image input is not fed.
    public static let outputDisconnected = "Nothing is connected to this Output."

    /// The sentence for a node that is the source of a connection of a loop.
    public static let partOfLoop = "This node is part of a loop."

    /// The sentence for each Output when the graph has more than one.
    public static let multipleOutputs = "Only one Output may exist."

    /// The sentence for a connection stored twice, marked on its target node.
    public static let duplicateEdge = "This connection is made twice."

    /// The sentence for two or more nodes sharing one identity.
    public static let duplicateNode = "Another node has the same identity."

    /// The sentence for a stored parameter `name` that the node's kind does not declare.
    public static func unknownParameter(_ name: String) -> String { "Parameter \(name) does not exist." }

    /// The sentence for a stored parameter `name` whose value is not finite or lies outside its range.
    public static func parameterOutOfRange(_ name: String) -> String { "Parameter \(name) is out of range." }

    /// The sentences of `result` by the node they concern, for the nodes of `graph`. An accepted result gives an
    /// empty map; a refusal marks only nodes present in `graph`, each with its sentences in the order of the issues
    /// and without repeats.
    public static func byNode(_ result: CheckResult, in graph: VisualGraph) -> [NodeID: [String]] {
        guard case .refused(let issues) = result else { return [:] }
        let present = Set(graph.nodes.map(\.id))
        var marks: [NodeID: [String]] = [:]
        for issue in issues {
            for (node, sentence) in issueMarks(issue, in: graph) where present.contains(node) {
                var sentences = marks[node, default: []]
                if !sentences.contains(sentence) { sentences.append(sentence) }
                marks[node] = sentences
            }
        }
        return marks
    }

    /// The sentences for `node` in `diagnostics` (empty when the node is not marked).
    public static func sentences(for node: NodeID, in diagnostics: [NodeID: [String]]) -> [String] {
        diagnostics[node, default: []]
    }

    // MARK: Helpers

    /// The (node, sentence) marks of one issue, in order.
    private static func issueMarks(_ issue: GraphIssue, in graph: VisualGraph) -> [(NodeID, String)] {
        switch issue {
        case .tooManyNodes, .tooManyEdges, .noOutput:
            return []
        case .duplicateNode(let node):
            return [(node, duplicateNode)]
        case .unknownParameter(let node, let name):
            return [(node, unknownParameter(name))]
        case .parameterOutOfRange(let node, let name):
            return [(node, parameterOutOfRange(name))]
        case .unknownNode(let node):
            // Only a node that exists is marked (byNode filters the rest); the checker names missing nodes.
            return [(node, EditMessages.sentence(for: .unknownNode(node), in: graph))]
        case .unknownPort(let node, _):
            return [(node, EditMessages.sentence(for: .unknownPort, in: graph))]
        case .wrongDirection(let node, _):
            return [(node, EditMessages.wrongDirection)]
        case .typeMismatch(let edge, let from, let to):
            return [(edge.targetNode, EditMessages.sentence(for: .typeMismatch(from: from, to: to), in: graph))]
        case .inputAlreadyConnected(let node, let port):
            return [(node, EditMessages.sentence(for: .inputTaken(node: node, port: port), in: graph))]
        case .duplicateEdge(let edge):
            return [(edge.targetNode, duplicateEdge)]
        case .cycle(let edges):
            return edges.map { ($0.sourceNode, partOfLoop) }
        case .multipleOutputs(let outputs):
            return outputs.map { ($0, multipleOutputs) }
        case .outputDisconnected(let node):
            return [(node, outputDisconnected)]
        case .inputUnconnected(let node, let port):
            return [(node, emptyInput(port))]
        }
    }
}
