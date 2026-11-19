// EditMessages — feature 167 (A23-P02) T-A23-203 (FR-A23-203, FR-A23-205; SC-A23-202; clarifications Q1, Q4;
// data-model.md "EditMessages"; User Stories 2 and 4). The words of the editor, built in the core so they are tested
// without the GPU: one plain sentence per refusal (naming both value types for a mismatch, the fed input, the loop,
// the limit or the second output), the feedback for a drag between two ports of the same direction, one status line
// per checker result, and the spoken labels of a node ("Noise 2"), a port ("Mix 3, input amount, scalar, optional")
// and a connection ("Noise 2 image → Output 1 image") used by the canvas overlay and the list form.
// Choices recorded here: the sentence for a taken input names the node by its kind when the graph is given
// (`sentence(for:in:)`, the graph before the refused edit) and as "Node <id>" otherwise; a label of a node that is not
// in the graph uses "Node <id>" too. The status is taken from the first issue of the refusing stage. Pure: no UI, GPU
// or clock.
import Foundation

/// The sentences, status lines and spoken labels of the Visual Programming Lab editor.
public enum EditMessages {
    /// The feedback for a drag that ends on a port of the same direction as it started.
    public static let wrongDirection = "Connect an output to an input."

    /// The one plain sentence saying why `refusal` was refused. `graph` (the graph the edit was refused on) names a
    /// node of a taken input by its kind; without it the node is "Node <id>".
    public static func sentence(for refusal: GraphEditRefusal, in graph: VisualGraph? = nil) -> String {
        switch refusal {
        case .notWhole:
            return "Use a whole number."
        case .unknownNode:
            return "That node is not in the graph."
        case .unknownPort:
            return "That port does not exist."
        case .typeMismatch(let from, let to):
            return "\(article(from.rawValue, capitalised: true)) \(from.rawValue) output cannot feed "
                + "\(article(to.rawValue, capitalised: false)) \(to.rawValue) input."
        case .inputTaken(let node, let port):
            return "\(name(of: node, in: graph)): input \(port) is already connected."
        case .cycle:
            return "That connection would make a loop."
        case .tooManyNodes:
            return "A graph holds at most \(GraphLimits.maxNodes) nodes."
        case .tooManyEdges:
            return "A graph holds at most \(GraphLimits.maxEdges) connections."
        case .oneOutput:
            return "A graph has one Output."
        }
    }

    /// The status line for the checker's `result` on `graph`: "Ready", "No output", "Output not connected",
    /// "<Title> <id>: input <port> is empty", "More than one output", "The graph has a loop", or "The graph has a
    /// problem: <code>" for any other refusal. A refusal is described by its first issue.
    public static func status(for result: CheckResult, in graph: VisualGraph) -> String {
        guard case .refused(let issues) = result else { return "Ready" }
        guard let issue = issues.first else { return "The graph has a problem" }
        switch issue {
        case .noOutput: return "No output"
        case .outputDisconnected: return "Output not connected"
        case .inputUnconnected(let node, let port): return "\(name(of: node, in: graph)): input \(port) is empty"
        case .multipleOutputs: return "More than one output"
        case .cycle: return "The graph has a loop"
        default: return "The graph has a problem: \(issue.code)"
        }
    }

    /// The title of `kind`: "Time", "Constant", "Noise", "Gradient", "Mix", "Blur" or "Output".
    public static func title(of kind: NodeKind) -> String {
        switch kind {
        case .time: "Time"
        case .constant: "Constant"
        case .noise: "Noise"
        case .gradient: "Gradient"
        case .mix: "Mix"
        case .blur: "Blur"
        case .output: "Output"
        }
    }

    /// The spoken label of `node`: its title and identity, such as "Noise 2".
    public static func label(node: GraphNode) -> String {
        "\(title(of: node.kind)) \(node.id)"
    }

    /// The spoken label of `port` of `node`: node, direction and name, type, and "optional" for an input that need
    /// not be fed, such as "Noise 2, output image, texture" or "Mix 3, input amount, scalar, optional".
    public static func label(port: PortDeclaration, of node: GraphNode) -> String {
        var text = "\(label(node: node)), \(port.direction.rawValue) \(port.name), \(port.type.rawValue)"
        if port.direction == .input && !port.required { text += ", optional" }
        return text
    }

    /// The spoken label of `edge` in `graph`: source node and port, an arrow, target node and port, such as
    /// "Noise 2 image → Output 1 image".
    public static func label(edge: GraphEdge, in graph: VisualGraph) -> String {
        "\(name(of: edge.sourceNode, in: graph)) \(edge.sourcePort) → \(name(of: edge.targetNode, in: graph)) "
            + edge.targetPort
    }

    // MARK: Helpers

    /// The node `id` named by its kind's title ("Mix 3"), or "Node <id>" when it is not in `graph`.
    private static func name(of id: NodeID, in graph: VisualGraph?) -> String {
        guard let node = graph?.node(id) else { return "Node \(id)" }
        return label(node: node)
    }

    /// The indefinite article for `word`: "an" before a vowel, else "a"; "A"/"An" when `capitalised`.
    private static func article(_ word: String, capitalised: Bool) -> String {
        let vowel = word.first.map { "aeiou".contains($0) } ?? false
        switch (vowel, capitalised) {
        case (true, true): return "An"
        case (true, false): return "an"
        case (false, true): return "A"
        case (false, false): return "a"
        }
    }
}
