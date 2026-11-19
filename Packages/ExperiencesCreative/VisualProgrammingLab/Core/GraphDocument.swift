// GraphDocument — feature 166 (A23-P01) T-A23-104 (FR-A23-101, FR-A23-102; clarifications Q2, Q3; data-model.md
// "GraphDocument"). The graph file: a versioned JSON envelope `{"body", "kind", "version"}` of kind
// `a23.visual-graph` (schema 1, at most 65,536 bytes encoded), canonical (sorted keys, nodes in identity order,
// connections in ``GraphEdge`` order, parameters as a JSON object), so that encode(decode(encode(g))) is
// byte-identical to encode(g). Five typed refusals: `damaged`, `newer-version`, `too-large`, `not-finite` and
// `out-of-range`; and the graph's fingerprint, a `StateDigest`.
// Choices recorded here: reading checks, in order, the size, the JSON object, the kind, the version, the body through
// ``GraphDocument/migrations`` (`MigrationChain(currentVersion: 1)`, no steps yet; the hook for schema 2), the
// decoding of the body, then the graph: the limits (`too-large`), every number finite (`not-finite`), then every
// identity, position and declared parameter in range (`out-of-range`). Writing refuses the same graphs with the same
// codes, then a result above 65,536 bytes. JSON has no NaN or infinity token; a file that carries one as the string
// "NaN", "Infinity" or "-Infinity" where a number belongs is read as that value and refused as `not-finite`.
// Undeclared parameters and duplicate identities are not the file's business (``GraphChecker`` refuses them). The
// fingerprint covers the version and the nodes in identity order (identity, kind, parameters in name order, position)
// and the connections in ``GraphEdge`` order; the output node is a node of kind `output`, so it is covered by the
// nodes. Pure Foundation; no UI, GPU or clock.
import Foundation
import VisualCoreExperience
import VisualCoreParameters
import VisualCorePersistence

/// Why a graph file was refused or a graph could not be written or fingerprinted. The raw value is the stable code.
public enum GraphDocumentRefusal: String, Error, Equatable, Sendable {
    /// The file is not a JSON object, has the wrong kind, lacks a field (the version included), has a field of the
    /// wrong type, names an unknown node kind, or has a version below 1 or one without a migration step.
    case damaged
    /// The file was written by a newer version (above ``GraphDocument/schemaVersion``).
    case newerVersion = "newer-version"
    /// The file or the encoding is above ``GraphDocument/maxEncodedBytes``, or the graph holds more than
    /// ``GraphLimits/maxNodes`` nodes or ``GraphLimits/maxEdges`` connections.
    case tooLarge = "too-large"
    /// A position or a parameter value is NaN or infinite.
    case notFinite = "not-finite"
    /// A node identity is outside ``NodeID/validRange``, a position is outside ±``CanvasPoint/bound``, or a declared
    /// parameter value is outside its definition's range.
    case outOfRange = "out-of-range"

    /// The stable code: `damaged`, `newer-version`, `too-large`, `not-finite` or `out-of-range`.
    public var code: String { rawValue }
}

/// Reads, writes and fingerprints graph files (kind `a23.visual-graph`, schema 1).
public enum GraphDocument {
    /// The envelope kind of a graph file.
    public static let kind = "a23.visual-graph"
    /// The schema version this code writes and reads.
    public static let schemaVersion = 1
    /// The largest graph file accepted or written, in bytes.
    public static let maxEncodedBytes = 65_536
    /// The migrations of the body to ``schemaVersion`` (none yet; the hook for schema 2).
    public static let migrations = MigrationChain(currentVersion: schemaVersion)

    /// The strings that stand for non-finite numbers in a file, so that they are refused as
    /// ``GraphDocumentRefusal/notFinite`` rather than as damage.
    private static let positiveInfinityText = "Infinity"
    private static let negativeInfinityText = "-Infinity"
    private static let nanText = "NaN"

    /// The written envelope.
    private struct Envelope: Encodable {
        var body: VisualGraph
        var kind: String
        var version: Int
    }

    /// The stored file of `graph`: the canonical JSON envelope, the same bytes for the same nodes (in any order),
    /// connections (in any order) and values. Throws ``GraphDocumentRefusal/tooLarge`` (more than 32 nodes or 64
    /// connections, or a result above ``maxEncodedBytes``), ``GraphDocumentRefusal/notFinite`` and
    /// ``GraphDocumentRefusal/outOfRange`` exactly as ``decode(_:)`` would refuse the result.
    public static func encode(_ graph: VisualGraph) throws(GraphDocumentRefusal) -> Data {
        try validate(graph)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data: Data
        do {
            data = try encoder.encode(Envelope(body: canonical(graph), kind: kind, version: schemaVersion))
        } catch {
            // Every number was checked finite above; a non-conforming float is the only encoding failure left.
            throw .notFinite
        }
        guard data.count <= maxEncodedBytes else { throw .tooLarge }
        return data
    }

    /// Reads a graph file. Checks, in order: the size (``GraphDocumentRefusal/tooLarge``), the JSON object and its
    /// kind (``GraphDocumentRefusal/damaged``), the version (missing or below 1: ``GraphDocumentRefusal/damaged``;
    /// above ``schemaVersion``: ``GraphDocumentRefusal/newerVersion``), the body through ``migrations``, the decoding
    /// of the body (``GraphDocumentRefusal/damaged``), then the graph's limits, finiteness and ranges. The graph is
    /// returned in the file's order.
    public static func decode(_ data: Data) throws(GraphDocumentRefusal) -> VisualGraph {
        guard data.count <= maxEncodedBytes else { throw .tooLarge }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fileKind = object["kind"] as? String, fileKind == kind,
              let version = object["version"] as? Int else { throw .damaged }
        guard version <= schemaVersion else { throw .newerVersion }
        guard version >= 1, let body = object["body"] as? [String: Any] else { throw .damaged }
        let migrated: [String: Any]
        do {
            migrated = try migrations.migrate(body, from: version)
        } catch MigrationError.newerVersion(_) {
            throw .newerVersion
        } catch {
            throw .damaged
        }
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: positiveInfinityText, negativeInfinity: negativeInfinityText, nan: nanText)
        guard let bodyData = try? JSONSerialization.data(withJSONObject: migrated),
              let graph = try? decoder.decode(VisualGraph.self, from: bodyData) else { throw .damaged }
        try validate(graph)
        return graph
    }

    /// The fingerprint of `graph`: a `StateDigest` of domain `a23.visual-graph` over the schema version, the nodes in
    /// identity order (identity, kind, parameters in name order, position) and the connections in ``GraphEdge``
    /// order (target node, target port, source node, source port). The same for the same graph whatever the order of
    /// its nodes and connections. Throws ``GraphDocumentRefusal/notFinite`` when a position or parameter is NaN or
    /// infinite.
    public static func fingerprint(of graph: VisualGraph) throws(GraphDocumentRefusal) -> StateDigest {
        let sorted = canonical(graph)
        var builder = DigestBuilder(domain: kind)
        builder.add(schemaVersion)
        do {
            builder.add(count: sorted.nodes.count)
            for node in sorted.nodes {
                builder.add(node.id.rawValue)
                builder.add(node.kind.rawValue)
                builder.add(count: node.parameters.count)
                for (name, value) in node.parameters.sorted(by: { $0.key < $1.key }) {
                    builder.add(name)
                    try builder.add(value)
                }
                try builder.add(node.position.x)
                try builder.add(node.position.y)
            }
            builder.add(count: sorted.edges.count)
            for edge in sorted.edges {
                builder.add(edge.targetNode.rawValue)
                builder.add(edge.targetPort)
                builder.add(edge.sourceNode.rawValue)
                builder.add(edge.sourcePort)
            }
        } catch {
            throw .notFinite
        }
        return builder.finish()
    }

    /// `graph` with its nodes in identity order (ties by kind, then position) and its connections in ``GraphEdge``
    /// order.
    static func canonical(_ graph: VisualGraph) -> VisualGraph {
        let nodes = graph.nodes.sorted { lhs, rhs in
            if lhs.id != rhs.id { return lhs.id < rhs.id }
            if lhs.kind != rhs.kind { return lhs.kind.rawValue < rhs.kind.rawValue }
            if lhs.position.x != rhs.position.x { return lhs.position.x < rhs.position.x }
            return lhs.position.y < rhs.position.y
        }
        return VisualGraph(nodes: nodes, edges: graph.edges.sorted())
    }

    /// Refuses a graph the file may not hold: more than ``GraphLimits/maxNodes`` nodes or ``GraphLimits/maxEdges``
    /// connections (``GraphDocumentRefusal/tooLarge``), then any non-finite position or parameter
    /// (``GraphDocumentRefusal/notFinite``), then any identity, position or declared parameter out of range
    /// (``GraphDocumentRefusal/outOfRange``). Undeclared parameters and duplicate identities are the checker's.
    static func validate(_ graph: VisualGraph) throws(GraphDocumentRefusal) {
        guard graph.nodes.count <= GraphLimits.maxNodes, graph.edges.count <= GraphLimits.maxEdges else {
            throw .tooLarge
        }
        for node in graph.nodes {
            guard node.position.isFinite, node.parameters.values.allSatisfy(\.isFinite) else { throw .notFinite }
        }
        for node in graph.nodes {
            guard node.id.isValid, node.position.isInBounds else { throw .outOfRange }
            for (name, value) in node.parameters {
                if let definition = node.kind.parameter(name), definition.range.contains(value) == false {
                    throw .outOfRange
                }
            }
        }
        for edge in graph.edges {
            guard edge.sourceNode.isValid, edge.targetNode.isValid else { throw .outOfRange }
        }
    }
}
