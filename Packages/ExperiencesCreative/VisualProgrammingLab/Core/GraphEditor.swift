// GraphEditor — feature 167 (A23-P02) T-A23-203 (FR-A23-202, FR-A23-203; SC-A23-201, SC-A23-202; clarification Q1;
// data-model.md "GraphEditRefusal", "GraphEditor"). The pure edits of a visual graph: add a node (the smallest unused
// identity; refused at 32 nodes and for a second output), move it, remove it with its connections, connect an output
// port to an input port and disconnect an input. Each edit returns a new graph or throws a `GraphEditRefusal`; a
// refused edit never changes anything, because the graph is a value and the editor only returns a copy.
// Choices recorded here: positions are clamped to ±4,096 (a non-finite coordinate becomes 0). A connection is refused
// in this order: an unknown node (source first), an unknown port index, different value types (named before the
// checker runs, so the sentence never depends on the checker's stage order), an input already fed (an identical
// existing connection included), then `GraphChecker` on the graph with the new connection: a connection-stage issue or
// a cycle refuses it; output-stage issues (an incomplete graph) and acceptance do not. The checker's limit and node
// stages cannot be reached through these edits (a graph never holds more than 32 nodes, and every input is fed at
// most once); should one refuse anyway (a graph built elsewhere), its first issue maps to the closest refusal:
// too many nodes → `tooManyNodes`, too many connections → `tooManyEdges`, a node issue → `unknownNode` of that node.
// A connection past ``GraphLimits/maxEdges`` is refused as `tooManyEdges` before the checker runs (lead, T-A23-203:
// 32 nodes can hold more than 64 inputs, so this limit is reachable by editing). Pure: no UI,
// GPU or clock.
import Foundation

/// Why an edit of a visual graph was refused. Each refusal has a stable rule id.
public enum GraphEditRefusal: Error, Equatable, Sendable {
    /// An action value that must be a whole number was not one.
    case notWhole
    /// The edit names a node that is not in the graph.
    case unknownNode(NodeID)
    /// The edit names a port index the node's kind does not declare.
    case unknownPort
    /// The connection joins an output and an input of different value types (output type, input type).
    case typeMismatch(from: ValueType, to: ValueType)
    /// The input `port` of node `node` is already fed by a connection.
    case inputTaken(node: NodeID, port: String)
    /// The connection would close this loop (in the checker's forward order).
    case cycle([GraphEdge])
    /// The graph already holds ``GraphLimits/maxNodes`` nodes.
    case tooManyNodes
    /// The graph already holds ``GraphLimits/maxEdges`` connections.
    case tooManyEdges
    /// The graph already has an output node.
    case oneOutput

    /// The stable rule id of the refusal, such as `a23.type-mismatch`.
    public var rule: String {
        switch self {
        case .notWhole: "a23.not-whole"
        case .unknownNode: "a23.unknown-node"
        case .unknownPort: "a23.unknown-port"
        case .typeMismatch: "a23.type-mismatch"
        case .inputTaken: "a23.input-taken"
        case .cycle: "a23.cycle"
        case .tooManyNodes: "a23.too-many-nodes"
        case .tooManyEdges: "a23.too-many-edges"
        case .oneOutput: "a23.one-output"
        }
    }
}

/// The pure edits of a ``VisualGraph``. Every edit returns the edited copy or throws a ``GraphEditRefusal``.
public enum GraphEditor {
    /// Adds a node of `kind` with default parameters at `position` (clamped to ±4,096; a non-finite coordinate
    /// becomes 0). The node takes the smallest unused identity of 1…9,999. Refused with ``GraphEditRefusal/tooManyNodes``
    /// when the graph holds 32 nodes, then with ``GraphEditRefusal/oneOutput`` when `kind` is ``NodeKind/output`` and
    /// the graph already has an output.
    public static func add(_ kind: NodeKind, at position: CanvasPoint, to graph: VisualGraph)
        throws(GraphEditRefusal) -> (graph: VisualGraph, id: NodeID) {
        if graph.nodes.count >= GraphLimits.maxNodes { throw .tooManyNodes }
        if kind == .output && !graph.outputNodes.isEmpty { throw .oneOutput }
        let used = Set(graph.nodes.map(\.id.rawValue))
        guard let raw = NodeID.validRange.first(where: { !used.contains($0) }) else { throw .tooManyNodes }
        let id = NodeID(raw)
        var edited = graph
        edited.nodes.append(GraphNode(id: id, kind: kind, position: clamped(position)))
        return (edited, id)
    }

    /// Moves the node `id` to `position` (clamped to ±4,096; a non-finite coordinate becomes 0). Refused with
    /// ``GraphEditRefusal/unknownNode(_:)`` when there is no such node.
    public static func move(_ id: NodeID, to position: CanvasPoint, in graph: VisualGraph)
        throws(GraphEditRefusal) -> VisualGraph {
        guard let index = graph.nodes.firstIndex(where: { $0.id == id }) else { throw .unknownNode(id) }
        var edited = graph
        edited.nodes[index].position = clamped(position)
        return edited
    }

    /// Removes the node `id` and every connection from or to it. Refused with ``GraphEditRefusal/unknownNode(_:)``
    /// when there is no such node. Removing the output is allowed (the status then says there is no output).
    public static func remove(_ id: NodeID, from graph: VisualGraph) throws(GraphEditRefusal) -> VisualGraph {
        guard graph.node(id) != nil else { throw .unknownNode(id) }
        var edited = graph
        edited.nodes.removeAll { $0.id == id }
        edited.edges.removeAll { $0.sourceNode == id || $0.targetNode == id }
        return edited
    }

    /// Connects output `outputIndex` of node `source` to input `inputIndex` of node `target` (indices into the
    /// kind's ``NodeKind/outputs`` and ``NodeKind/inputs`` in declaration order). Refused with an unknown node, an
    /// unknown port, a type mismatch naming both types, a taken input, or the loop the connection would close; an
    /// incomplete graph (output-stage issues) is accepted.
    public static func connect(source: NodeID, outputIndex: Int, target: NodeID, inputIndex: Int,
                               in graph: VisualGraph) throws(GraphEditRefusal) -> VisualGraph {
        guard let sourceNode = graph.node(source) else { throw .unknownNode(source) }
        guard let targetNode = graph.node(target) else { throw .unknownNode(target) }
        let outputs = sourceNode.kind.outputs
        let inputs = targetNode.kind.inputs
        guard outputs.indices.contains(outputIndex), inputs.indices.contains(inputIndex) else { throw .unknownPort }
        let output = outputs[outputIndex]
        let input = inputs[inputIndex]
        if output.type != input.type { throw .typeMismatch(from: output.type, to: input.type) }
        if graph.edges.contains(where: { $0.targetNode == target && $0.targetPort == input.name }) {
            throw .inputTaken(node: target, port: input.name)
        }
        if graph.edges.count >= GraphLimits.maxEdges { throw .tooManyEdges }
        var edited = graph
        edited.edges.append(GraphEdge(from: source, output.name, to: target, input.name))
        switch GraphChecker.check(edited) {
        case .accepted:
            return edited
        case .refused(let issues):
            if let found = issues.lazy.compactMap(refusal(for:)).first { throw found }
            return edited
        }
    }

    /// Removes the connection feeding input `inputIndex` of node `target`. Refused with an unknown node or port;
    /// disconnecting an input that is not fed returns the graph unchanged.
    public static func disconnect(target: NodeID, inputIndex: Int, in graph: VisualGraph)
        throws(GraphEditRefusal) -> VisualGraph {
        guard let targetNode = graph.node(target) else { throw .unknownNode(target) }
        let inputs = targetNode.kind.inputs
        guard inputs.indices.contains(inputIndex) else { throw .unknownPort }
        let name = inputs[inputIndex].name
        var edited = graph
        edited.edges.removeAll { $0.targetNode == target && $0.targetPort == name }
        return edited
    }

    // MARK: Helpers

    /// `point` with each coordinate clamped to ±``CanvasPoint/bound``; a non-finite coordinate becomes 0.
    private static func clamped(_ point: CanvasPoint) -> CanvasPoint {
        CanvasPoint(x: clamped(point.x), y: clamped(point.y))
    }

    /// `value` clamped to ±``CanvasPoint/bound``; a non-finite value becomes 0.
    private static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, -CanvasPoint.bound), CanvasPoint.bound)
    }

    /// The refusal a checker issue gives for a new connection, or nil for an output-stage issue (an incomplete graph
    /// is accepted while editing).
    private static func refusal(for issue: GraphIssue) -> GraphEditRefusal? {
        switch issue {
        case .tooManyNodes: .tooManyNodes
        case .tooManyEdges: .tooManyEdges
        case .duplicateNode(let id): .unknownNode(id)
        case .unknownParameter(let node, _), .parameterOutOfRange(let node, _): .unknownNode(node)
        case .unknownNode(let id): .unknownNode(id)
        case .unknownPort, .wrongDirection: .unknownPort
        case .typeMismatch(_, let from, let to): .typeMismatch(from: from, to: to)
        case .inputAlreadyConnected(let node, let port): .inputTaken(node: node, port: port)
        case .duplicateEdge(let edge): .inputTaken(node: edge.targetNode, port: edge.targetPort)
        case .cycle(let edges): .cycle(edges)
        case .noOutput, .multipleOutputs, .outputDisconnected, .inputUnconnected: nil
        }
    }
}
