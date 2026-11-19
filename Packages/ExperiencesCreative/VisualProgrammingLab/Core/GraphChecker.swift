// GraphChecker — feature 166 (A23-P01) T-A23-106 (FR-A23-104, FR-A23-105, FR-A23-106, FR-A23-107; clarification Q4;
// data-model "GraphIssue" and "CheckResult"). The graph checker: five stages in order (limits, nodes, connections,
// order, output), stopping after the first stage that refused, so a graph is checked completely before any graphics
// work. Kahn's order takes the smallest ready identity first; a cycle is named by walking backwards from the smallest
// remaining identity along its smallest incoming connection until a node repeats, and is reported in forward order
// starting with the connection whose source has the smallest identity in the loop. Pure: no graphics call, no clock,
// nothing global.
import Foundation
import VisualCoreParameters

/// One reason a graph is refused, naming the nodes, ports, connections or types involved.
public enum GraphIssue: Error, Equatable, Hashable, Sendable {
    /// More nodes than ``GraphLimits/maxNodes`` (the count found).
    case tooManyNodes(Int)
    /// More connections than ``GraphLimits/maxEdges`` (the count found).
    case tooManyEdges(Int)
    /// Two or more nodes share this identity.
    case duplicateNode(NodeID)
    /// The node stores a parameter its kind does not declare.
    case unknownParameter(node: NodeID, name: String)
    /// The node stores a declared parameter whose value is not finite or lies outside its range.
    case parameterOutOfRange(node: NodeID, name: String)
    /// A connection names a node that is not in the graph.
    case unknownNode(NodeID)
    /// A connection names a port the node's kind does not declare.
    case unknownPort(node: NodeID, port: String)
    /// A connection leaves from an input or arrives at an output.
    case wrongDirection(node: NodeID, port: String)
    /// A connection joins an output and an input of different value types (output type, input type).
    case typeMismatch(GraphEdge, from: ValueType, to: ValueType)
    /// A second, distinct connection feeds an input that is already fed.
    case inputAlreadyConnected(node: NodeID, port: String)
    /// A connection equal to an earlier one.
    case duplicateEdge(GraphEdge)
    /// A loop of connections, in forward order, starting with the connection whose source has the smallest identity.
    case cycle([GraphEdge])
    /// The graph has no node of kind ``NodeKind/output``.
    case noOutput
    /// The graph has more than one output node (their identities, ascending).
    case multipleOutputs([NodeID])
    /// The output node's `image` input is not fed.
    case outputDisconnected(NodeID)
    /// A required input of this node is not fed.
    case inputUnconnected(node: NodeID, port: String)

    /// The stable refusal code (kebab case), as the data model names it.
    public var code: String {
        switch self {
        case .tooManyNodes: "too-many-nodes"
        case .tooManyEdges: "too-many-edges"
        case .duplicateNode: "duplicate-node"
        case .unknownParameter: "unknown-parameter"
        case .parameterOutOfRange: "parameter-out-of-range"
        case .unknownNode: "unknown-node"
        case .unknownPort: "unknown-port"
        case .wrongDirection: "wrong-direction"
        case .typeMismatch: "type-mismatch"
        case .inputAlreadyConnected: "input-already-connected"
        case .duplicateEdge: "duplicate-edge"
        case .cycle: "cycle"
        case .noOutput: "no-output"
        case .multipleOutputs: "multiple-outputs"
        case .outputDisconnected: "output-disconnected"
        case .inputUnconnected: "input-unconnected"
        }
    }
}

/// The outcome of checking a graph.
public enum CheckResult: Equatable, Sendable {
    /// The graph is valid: `order` lists every node after every node feeding it (smallest ready identity first), and
    /// `reaching` holds the nodes from which the output can be reached, the output included.
    case accepted(order: [NodeID], reaching: Set<NodeID>)
    /// The graph is refused with every issue of the first stage that found any, in a deterministic order.
    case refused([GraphIssue])
}

/// Checks a ``VisualGraph`` before any graphics work (clarification Q4).
public enum GraphChecker {
    /// Checks `graph` through the stages limits, nodes, connections, order and output, stopping after the first stage
    /// that produced an issue. Deterministic: the same graph always gives the same result.
    public static func check(_ graph: VisualGraph) -> CheckResult {
        let limits = limitIssues(graph)
        if !limits.isEmpty { return .refused(limits) }
        let nodeStage = nodeIssues(graph)
        if !nodeStage.isEmpty { return .refused(nodeStage) }
        var byID: [NodeID: GraphNode] = [:]
        for node in graph.nodes { byID[node.id] = node }
        let edges = graph.edges.sorted()
        let edgeStage = edgeIssues(edges, byID: byID)
        if !edgeStage.isEmpty { return .refused(edgeStage) }
        let ids = byID.keys.sorted()
        switch order(ids: ids, edges: edges) {
        case .failure(let loop):
            return .refused([.cycle(loop.edges)])
        case .success(let order):
            let outputStage = outputIssues(ids: ids, byID: byID, edges: edges)
            if !outputStage.issues.isEmpty { return .refused(outputStage.issues) }
            guard let output = outputStage.output else { return .refused([.noOutput]) }
            return .accepted(order: order, reaching: reaching(output, edges: edges))
        }
    }

    // MARK: Stage 1 — limits

    private static func limitIssues(_ graph: VisualGraph) -> [GraphIssue] {
        var issues: [GraphIssue] = []
        if graph.nodes.count > GraphLimits.maxNodes { issues.append(.tooManyNodes(graph.nodes.count)) }
        if graph.edges.count > GraphLimits.maxEdges { issues.append(.tooManyEdges(graph.edges.count)) }
        return issues
    }

    // MARK: Stage 2 — nodes

    private static func nodeIssues(_ graph: VisualGraph) -> [GraphIssue] {
        // Identity order, stable for equal identities (the stored order breaks ties).
        let nodes = graph.nodes.enumerated().sorted { lhs, rhs in
            lhs.element.id == rhs.element.id ? lhs.offset < rhs.offset : lhs.element.id < rhs.element.id
        }.map(\.element)
        var issues: [GraphIssue] = []
        var seen: Set<NodeID> = []
        var reported: Set<NodeID> = []
        for node in nodes {
            if seen.contains(node.id) {
                if reported.insert(node.id).inserted { issues.append(.duplicateNode(node.id)) }
            } else {
                seen.insert(node.id)
            }
            for name in node.parameters.keys.sorted() {
                let value = node.parameters[name, default: 0]
                guard let definition = node.kind.parameter(name) else {
                    issues.append(.unknownParameter(node: node.id, name: name))
                    continue
                }
                if !value.isFinite || !definition.range.contains(value) {
                    issues.append(.parameterOutOfRange(node: node.id, name: name))
                }
            }
        }
        return issues
    }

    // MARK: Stage 3 — connections

    private static func edgeIssues(_ edges: [GraphEdge], byID: [NodeID: GraphNode]) -> [GraphIssue] {
        var issues: [GraphIssue] = []
        var fed: Set<PortKey> = []
        var previous: GraphEdge?
        for edge in edges {
            defer { previous = edge }
            let source = byID[edge.sourceNode]
            let target = byID[edge.targetNode]
            if source == nil { issues.append(.unknownNode(edge.sourceNode)) }
            if target == nil { issues.append(.unknownNode(edge.targetNode)) }
            var fromType: ValueType?
            if let source {
                if let port = source.kind.output(edge.sourcePort) {
                    fromType = port.type
                } else if source.kind.input(edge.sourcePort) != nil {
                    issues.append(.wrongDirection(node: edge.sourceNode, port: edge.sourcePort))
                } else {
                    issues.append(.unknownPort(node: edge.sourceNode, port: edge.sourcePort))
                }
            }
            var toType: ValueType?
            if let target {
                if let port = target.kind.input(edge.targetPort) {
                    toType = port.type
                } else if target.kind.output(edge.targetPort) != nil {
                    issues.append(.wrongDirection(node: edge.targetNode, port: edge.targetPort))
                } else {
                    issues.append(.unknownPort(node: edge.targetNode, port: edge.targetPort))
                }
            }
            if let fromType, let toType, fromType != toType {
                issues.append(.typeMismatch(edge, from: fromType, to: toType))
            }
            if edge == previous {
                issues.append(.duplicateEdge(edge))
            } else if toType != nil {
                let key = PortKey(node: edge.targetNode, port: edge.targetPort)
                if !fed.insert(key).inserted {
                    issues.append(.inputAlreadyConnected(node: edge.targetNode, port: edge.targetPort))
                }
            }
        }
        return issues
    }

    // MARK: Stage 4 — order

    /// Kahn's order (smallest ready identity first), or the named loop when nodes remain.
    private static func order(ids: [NodeID], edges: [GraphEdge]) -> Result<[NodeID], LoopFound> {
        var indegree: [NodeID: Int] = [:]
        var outgoing: [NodeID: [NodeID]] = [:]
        for id in ids { indegree[id] = 0 }
        for edge in edges {
            indegree[edge.targetNode, default: 0] += 1
            outgoing[edge.sourceNode, default: []].append(edge.targetNode)
        }
        var ready = ids.filter { indegree[$0, default: 0] == 0 }   // ascending: ids is sorted
        var order: [NodeID] = []
        order.reserveCapacity(ids.count)
        while !ready.isEmpty {
            let next = ready.removeFirst()
            order.append(next)
            for target in outgoing[next, default: []] {
                indegree[target, default: 0] -= 1
                if indegree[target, default: 0] == 0 { insertSorted(target, into: &ready) }
            }
        }
        if order.count == ids.count { return .success(order) }
        let placed = Set(order)
        let remaining = Set(ids.filter { !placed.contains($0) })
        return .failure(LoopFound(edges: loop(remaining: remaining, edges: edges)))
    }

    /// The loop reached by walking backwards from the smallest remaining identity, in forward order, rotated to start
    /// with the connection whose source has the smallest identity in the loop.
    private static func loop(remaining: Set<NodeID>, edges: [GraphEdge]) -> [GraphEdge] {
        var incoming: [NodeID: GraphEdge] = [:]   // per remaining node: its smallest incoming edge from a remaining node
        for edge in edges where remaining.contains(edge.sourceNode) && remaining.contains(edge.targetNode) {
            if let best = incoming[edge.targetNode], !walkPrecedes(edge, best) { continue }
            incoming[edge.targetNode] = edge
        }
        guard var current = remaining.min() else { return [] }
        var visitedAt: [NodeID: Int] = [current: 0]
        var walked: [GraphEdge] = []   // walked[i] goes from node i + 1 to node i of the walk
        while let edge = incoming[current] {
            walked.append(edge)
            current = edge.sourceNode
            if let first = visitedAt[current] {
                let forward = Array(walked[first...].reversed())
                guard let start = forward.indices.min(by: { forward[$0].sourceNode < forward[$1].sourceNode }) else {
                    return forward
                }
                return Array(forward[start...] + forward[..<start])
            }
            visitedAt[current] = walked.count
        }
        return Array(walked.reversed())   // unreachable for a true remainder of Kahn's algorithm
    }

    /// The walk's order of incoming edges: source identity, then source port, then target port.
    private static func walkPrecedes(_ a: GraphEdge, _ b: GraphEdge) -> Bool {
        if a.sourceNode != b.sourceNode { return a.sourceNode < b.sourceNode }
        if a.sourcePort != b.sourcePort { return a.sourcePort < b.sourcePort }
        return a.targetPort < b.targetPort
    }

    private static func insertSorted(_ id: NodeID, into ready: inout [NodeID]) {
        let index = ready.firstIndex { $0 > id } ?? ready.endIndex
        ready.insert(id, at: index)
    }

    // MARK: Stage 5 — output

    private static func outputIssues(ids: [NodeID], byID: [NodeID: GraphNode], edges: [GraphEdge])
        -> (issues: [GraphIssue], output: NodeID?) {
        let outputs = ids.filter { byID[$0]?.kind == .output }
        guard let output = outputs.first else { return ([.noOutput], nil) }
        if outputs.count > 1 { return ([.multipleOutputs(outputs)], nil) }
        var fed: Set<PortKey> = []
        for edge in edges { fed.insert(PortKey(node: edge.targetNode, port: edge.targetPort)) }
        var issues: [GraphIssue] = []
        if !fed.contains(PortKey(node: output, port: "image")) { issues.append(.outputDisconnected(output)) }
        for id in ids where id != output {
            guard let node = byID[id] else { continue }
            for input in node.kind.inputs where input.required && !fed.contains(PortKey(node: id, port: input.name)) {
                issues.append(.inputUnconnected(node: id, port: input.name))
            }
        }
        return (issues, output)
    }

    /// The nodes from which `output` is reachable along the connections, `output` included.
    private static func reaching(_ output: NodeID, edges: [GraphEdge]) -> Set<NodeID> {
        var sources: [NodeID: [NodeID]] = [:]
        for edge in edges { sources[edge.targetNode, default: []].append(edge.sourceNode) }
        var found: Set<NodeID> = [output]
        var pending = [output]
        while let next = pending.popLast() {
            for source in sources[next, default: []] where found.insert(source).inserted { pending.append(source) }
        }
        return found
    }

    /// A node's port, as a key.
    private struct PortKey: Hashable {
        let node: NodeID
        let port: String
    }

    /// The loop that stopped the order, as a failure value.
    private struct LoopFound: Error {
        let edges: [GraphEdge]
    }
}
