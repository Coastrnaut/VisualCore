// VisualGraph — feature 166 (A23-P01) T-A23-103 (FR-A23-101; clarification Q2; data-model.md "NodeID",
// "CanvasPoint", "GraphNode", "GraphEdge", "GraphLimits", "VisualGraph"). The person's node graph: nodes (identity
// 1…9,999, kind, parameter values, canvas position) and connections (from an output port of one node to an input port
// of another), with the limits of at most 32 nodes and 64 connections.
// Choices recorded here: the output is not a stored field; it is the node of kind `output` (``VisualGraph/output``
// is nil when there is none or several, which the checker refuses). The model holds whatever it is given: validity
// (identities, positions, parameter ranges) is checked by ``GraphDocument`` and ``GraphChecker``, not on assignment.
// Canvas positions are in canvas points, origin top-left, y down. Pure Foundation; no UI, GPU or clock.
import Foundation

/// The identity of a node in a graph: an integer, valid within 1…9,999, unique in the graph. Encoded as a single
/// integer and ordered by its value.
public struct NodeID: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    /// The identity's integer value.
    public let rawValue: Int

    /// The identities a node may have.
    public static let validRange = 1...9_999

    /// An identity with the value `rawValue` (not checked; see ``isValid``).
    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Whether the value lies within ``validRange``.
    public var isValid: Bool { Self.validRange.contains(rawValue) }

    /// The value as decimal text.
    public var description: String { String(rawValue) }

    /// Orders identities by their value.
    public static func < (lhs: NodeID, rhs: NodeID) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Decodes an identity from a single integer.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(Int.self)
    }

    /// Encodes the identity as a single integer.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A position on the canvas, in canvas points (origin top-left, y down). Valid when both coordinates are finite and
/// within −``bound``…``bound``.
public struct CanvasPoint: Equatable, Codable, Sendable {
    /// The horizontal coordinate, in canvas points.
    public var x: Double
    /// The vertical coordinate, in canvas points (down is positive).
    public var y: Double

    /// The largest magnitude a coordinate may have: 4,096 canvas points.
    public static let bound: Double = 4_096

    /// A point at `x`, `y` (not checked; see ``isFinite`` and ``isInBounds``).
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// Whether both coordinates are finite (neither NaN nor infinite).
    public var isFinite: Bool { x.isFinite && y.isFinite }

    /// Whether both coordinates are finite and within −``bound``…``bound``.
    public var isInBounds: Bool {
        isFinite && (-Self.bound...Self.bound).contains(x) && (-Self.bound...Self.bound).contains(y)
    }
}

/// One node of a graph: its identity, kind, stored parameter values and canvas position.
public struct GraphNode: Equatable, Codable, Sendable {
    /// The node's identity, unique in the graph.
    public var id: NodeID
    /// The node's kind, which declares its ports and parameters.
    public var kind: NodeKind
    /// The stored parameter values by name; a declared parameter that is missing takes its default.
    public var parameters: [String: Double]
    /// The node's position on the canvas.
    public var position: CanvasPoint

    /// A node with identity `id` of kind `kind`, the stored `parameters` (none by default) at `position` (the origin
    /// by default).
    public init(id: NodeID, kind: NodeKind, parameters: [String: Double] = [:],
                position: CanvasPoint = CanvasPoint(x: 0, y: 0)) {
        self.id = id
        self.kind = kind
        self.parameters = parameters
        self.position = position
    }

    /// The value of the parameter `name`: the stored value, else the kind's default, else nil when it is neither
    /// stored nor declared.
    public func value(of name: String) -> Double? {
        parameters[name] ?? kind.parameter(name)?.defaultValue
    }
}

/// One connection: from the output port `sourcePort` of node `sourceNode` to the input port `targetPort` of node
/// `targetNode`. Ordered by target node, target port, source node, then source port.
public struct GraphEdge: Hashable, Comparable, Codable, Sendable {
    /// The node the value comes from.
    public var sourceNode: NodeID
    /// The output port of the source node.
    public var sourcePort: String
    /// The node the value goes to.
    public var targetNode: NodeID
    /// The input port of the target node.
    public var targetPort: String

    /// A connection from `sourceNode`'s port `sourcePort` to `targetNode`'s port `targetPort`.
    public init(from sourceNode: NodeID, _ sourcePort: String, to targetNode: NodeID, _ targetPort: String) {
        self.sourceNode = sourceNode
        self.sourcePort = sourcePort
        self.targetNode = targetNode
        self.targetPort = targetPort
    }

    /// Orders by (target node, target port, source node, source port).
    public static func < (lhs: GraphEdge, rhs: GraphEdge) -> Bool {
        (lhs.targetNode, lhs.targetPort, lhs.sourceNode, lhs.sourcePort)
            < (rhs.targetNode, rhs.targetPort, rhs.sourceNode, rhs.sourcePort)
    }
}

/// The size limits of a graph.
public enum GraphLimits {
    /// The largest number of nodes a graph may hold: 32.
    public static let maxNodes = 32
    /// The largest number of connections a graph may hold: 64.
    public static let maxEdges = 64
}

/// A node graph: its nodes and connections. The output is the node of kind ``NodeKind/output``.
public struct VisualGraph: Equatable, Codable, Sendable {
    /// The nodes, in any order (``GraphDocument`` writes them in identity order).
    public var nodes: [GraphNode]
    /// The connections, in any order (``GraphDocument`` writes them in ``GraphEdge`` order).
    public var edges: [GraphEdge]

    /// A graph of `nodes` and `edges` (empty by default).
    public init(nodes: [GraphNode] = [], edges: [GraphEdge] = []) {
        self.nodes = nodes
        self.edges = edges
    }

    /// The identities of the nodes of kind ``NodeKind/output``, ascending.
    public var outputNodes: [NodeID] {
        nodes.filter { $0.kind == .output }.map(\.id).sorted()
    }

    /// The identity of the single output node, or nil when there is none or more than one.
    public var output: NodeID? {
        let ids = outputNodes
        return ids.count == 1 ? ids.first : nil
    }

    /// The first node with identity `id`, or nil when there is none.
    public func node(_ id: NodeID) -> GraphNode? {
        nodes.first { $0.id == id }
    }
}
