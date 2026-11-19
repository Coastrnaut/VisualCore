// DocumentTests — feature 166 (A23-P01) T-A23-105 (FR-A23-101, FR-A23-102; SC-A23-101; clarifications Q2, Q3). The
// graph file round-trips byte-identical with the same identities, connections and positions (a sorted graph exactly,
// an unsorted one to the same bytes); one hand-built sample per refusal code on reading (damaged, newer-version,
// too-large, not-finite, out-of-range) and on writing; each limit at its bound accepted and one past refused; the
// fingerprint is stable, independent of input order, changes with one parameter, position or connection, and refuses
// a NaN. JSON has no NaN or infinity token, so a file carries one as the string "NaN", "Infinity" or "-Infinity";
// reading such a file gives `not-finite`. Synthetic data only.
import Foundation
import Testing
import VisualCoreExperience
@testable import VisualProgrammingLabCore

@Suite struct DocumentTests {
    // MARK: - Samples

    /// A valid graph, already in canonical order: time → noise → blur → mix(a); gradient → mix(b); constant →
    /// mix(amount); mix → output.
    private static func sample() -> VisualGraph {
        let nodes: [GraphNode] = [
            GraphNode(id: NodeID(1), kind: .time, parameters: ["rate": 2], position: CanvasPoint(x: -400, y: 120.5)),
            GraphNode(id: NodeID(2), kind: .noise, parameters: ["octaves": 3, "scale": 8],
                      position: CanvasPoint(x: -200, y: 80)),
            GraphNode(id: NodeID(3), kind: .blur, parameters: ["radius": 2.5], position: CanvasPoint(x: 0, y: 80)),
            GraphNode(id: NodeID(4), kind: .gradient, position: CanvasPoint(x: -200, y: 300)),
            GraphNode(id: NodeID(5), kind: .mix, parameters: ["amount": 0.25], position: CanvasPoint(x: 200, y: 160)),
            GraphNode(id: NodeID(6), kind: .output, position: CanvasPoint(x: 400, y: 160)),
            GraphNode(id: NodeID(7), kind: .constant, parameters: ["blue": 0.75, "value": -2],
                      position: CanvasPoint(x: 0, y: -60.25)),
        ]
        let edges: [GraphEdge] = [
            GraphEdge(from: NodeID(1), "time", to: NodeID(2), "time"),
            GraphEdge(from: NodeID(2), "image", to: NodeID(3), "image"),
            GraphEdge(from: NodeID(3), "image", to: NodeID(5), "a"),
            GraphEdge(from: NodeID(7), "value", to: NodeID(5), "amount"),
            GraphEdge(from: NodeID(4), "image", to: NodeID(5), "b"),
            GraphEdge(from: NodeID(5), "image", to: NodeID(6), "image"),
        ]
        return VisualGraph(nodes: nodes, edges: edges)
    }

    /// The sample with its nodes and connections in reverse order.
    private static func reversedSample() -> VisualGraph {
        let graph = sample()
        return VisualGraph(nodes: graph.nodes.reversed(), edges: graph.edges.reversed())
    }

    /// A graph of `count` time nodes with identities 1…count.
    private static func nodes(_ count: Int) -> VisualGraph {
        var nodes: [GraphNode] = []
        for index in 0..<count {
            nodes.append(GraphNode(id: NodeID(index + 1), kind: .time, position: CanvasPoint(x: Double(index), y: 0)))
        }
        return VisualGraph(nodes: nodes)
    }

    /// A graph of two nodes and `count` distinct connections between them (the file does not check ports).
    private static func edges(_ count: Int) -> VisualGraph {
        var edges: [GraphEdge] = []
        for index in 0..<count {
            edges.append(GraphEdge(from: NodeID(1), "time", to: NodeID(2), "port\(index)"))
        }
        return VisualGraph(nodes: [GraphNode(id: NodeID(1), kind: .time), GraphNode(id: NodeID(2), kind: .noise)],
                           edges: edges)
    }

    /// A one-node graph whose node is `node`.
    private static func single(_ node: GraphNode) -> VisualGraph {
        VisualGraph(nodes: [node])
    }

    // MARK: - Hand-built files

    /// The JSON object of the sample's file.
    private static func envelope() throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: GraphDocument.encode(Self.sample())) as? [String: Any])
    }

    /// The body of the sample's file.
    private static func body() throws -> [String: Any] {
        try #require(Self.envelope()["body"] as? [String: Any])
    }

    /// A hand-built file with `body`, `kind` and `version` (left out when nil).
    private static func file(_ body: Any, kind: String = GraphDocument.kind, version: Int? = 1) throws -> Data {
        var object: [String: Any] = ["body": body, "kind": kind]
        if let version {
            object["version"] = version
        }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The sample's file with the first node's `key` set to `value` (removed when nil).
    private static func file(settingNode key: String, to value: Any?) throws -> Data {
        var object = try Self.body()
        var nodes = try #require(object["nodes"] as? [[String: Any]])
        nodes[0][key] = value
        object["nodes"] = nodes
        return try file(object)
    }

    /// The sample's file with the first node's position coordinate `key` set to `value`.
    private static func file(settingPosition key: String, to value: Any) throws -> Data {
        let nodes = try #require(Self.body()["nodes"] as? [[String: Any]])
        var position = try #require(nodes[0]["position"] as? [String: Any])
        position[key] = value
        return try file(settingNode: "position", to: position)
    }

    /// The sample's file with the second node's (noise) parameter `name` set to `value`.
    private static func file(settingNoiseParameter name: String, to value: Any) throws -> Data {
        var object = try Self.body()
        var nodes = try #require(object["nodes"] as? [[String: Any]])
        var parameters = try #require(nodes[1]["parameters"] as? [String: Any])
        parameters[name] = value
        nodes[1]["parameters"] = parameters
        object["nodes"] = nodes
        return try file(object)
    }

    /// The file of `graph` with one more entry appended to its body's array `key`, copied from the last entry with
    /// `changes` applied.
    private static func file(of graph: VisualGraph, appendingTo key: String,
                             changes: [String: Any]) throws -> Data {
        let object = try #require(try JSONSerialization.jsonObject(with: GraphDocument.encode(graph)) as? [String: Any])
        var body = try #require(object["body"] as? [String: Any])
        var entries = try #require(body[key] as? [[String: Any]])
        var entry = try #require(entries.last)
        for (field, value) in changes {
            entry[field] = value
        }
        entries.append(entry)
        body[key] = entries
        return try file(body)
    }

    // MARK: - Refusal capture

    /// The refusal thrown by decoding `data`, or nil when it decoded.
    private static func refusal(_ data: Data) -> GraphDocumentRefusal? {
        do {
            _ = try GraphDocument.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// The refusal thrown by encoding `graph`, or nil when it encoded.
    private static func refusal(encoding graph: VisualGraph) -> GraphDocumentRefusal? {
        do {
            _ = try GraphDocument.encode(graph)
            return nil
        } catch {
            return error
        }
    }

    /// The refusal thrown by fingerprinting `graph`, or nil when it was fingerprinted.
    private static func refusal(fingerprinting graph: VisualGraph) -> GraphDocumentRefusal? {
        do {
            _ = try GraphDocument.fingerprint(of: graph)
            return nil
        } catch {
            return error
        }
    }

    // MARK: - Constants and round trips

    @Test func constants() {
        #expect(GraphDocument.kind == "a23.visual-graph")
        #expect(GraphDocument.schemaVersion == 1)
        #expect(GraphDocument.maxEncodedBytes == 65_536)
        #expect(GraphDocument.migrations.currentVersion == 1)
        #expect(GraphDocumentRefusal.damaged.code == "damaged")
        #expect(GraphDocumentRefusal.newerVersion.code == "newer-version")
        #expect(GraphDocumentRefusal.tooLarge.code == "too-large")
        #expect(GraphDocumentRefusal.notFinite.code == "not-finite")
        #expect(GraphDocumentRefusal.outOfRange.code == "out-of-range")
    }

    @Test func sortedGraphRoundTripsByteIdentical() throws {
        let graph = Self.sample()
        #expect(graph.edges == graph.edges.sorted())
        let data = try GraphDocument.encode(graph)
        #expect(data.count <= GraphDocument.maxEncodedBytes)
        let decoded = try GraphDocument.decode(data)
        #expect(decoded == graph)
        #expect(try GraphDocument.encode(decoded) == data)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix(#"{"body":{"edges":[{"sourceNode":1,"sourcePort":"time","targetNode":2"#))
        #expect(text.hasSuffix(#""kind":"a23.visual-graph","version":1}"#))
        #expect(text.contains(#""parameters":{"octaves":3,"scale":8}"#))
        #expect(text.contains(#""position":{"x":-400,"y":120.5}"#))
    }

    @Test func unsortedGraphEncodesToTheSameBytes() throws {
        let unsorted = Self.reversedSample()
        let data = try GraphDocument.encode(unsorted)
        #expect(data == (try GraphDocument.encode(Self.sample())))
        let decoded = try GraphDocument.decode(data)
        #expect(try GraphDocument.encode(decoded) == data)
        #expect(decoded == Self.sample())
        #expect(decoded.nodes.map(\.id) == unsorted.nodes.map(\.id).sorted())
        #expect(Set(decoded.edges) == Set(unsorted.edges))
        for node in unsorted.nodes {
            #expect(decoded.node(node.id) == node)
        }
    }

    @Test func emptyGraphRoundTrips() throws {
        let data = try GraphDocument.encode(VisualGraph())
        #expect(String(data: data, encoding: .utf8)
                == #"{"body":{"edges":[],"nodes":[]},"kind":"a23.visual-graph","version":1}"#)
        #expect(try GraphDocument.decode(data) == VisualGraph())
    }

    @Test func documentLeavesCheckerMattersAlone() throws {
        // Undeclared parameters, duplicate identities and unknown ports are the checker's refusals, not the file's.
        let graph = VisualGraph(nodes: [GraphNode(id: NodeID(3), kind: .output, parameters: ["extra": 99]),
                                        GraphNode(id: NodeID(3), kind: .time)],
                                edges: [GraphEdge(from: NodeID(3), "nothing", to: NodeID(8), "nowhere")])
        let data = try GraphDocument.encode(graph)
        #expect(try GraphDocument.encode(GraphDocument.decode(data)) == data)
    }

    // MARK: - Refusals on reading

    @Test func damaged() throws {
        #expect(Self.refusal(Data("not json".utf8)) == .damaged)
        #expect(Self.refusal(Data("[1, 2]".utf8)) == .damaged)
        #expect(Self.refusal(try Self.file(try Self.body(), kind: "a22.shader-project")) == .damaged)
        #expect(Self.refusal(try Self.file(try Self.body(), version: nil)) == .damaged)
        #expect(Self.refusal(try Self.file(try Self.body(), version: 0)) == .damaged)
        #expect(Self.refusal(try Self.file("no body")) == .damaged)
        #expect(Self.refusal(try Self.file(settingNode: "kind", to: "sparkle")) == .damaged)
        #expect(Self.refusal(try Self.file(settingNode: "position", to: nil)) == .damaged)
        #expect(Self.refusal(try Self.file(settingNode: "parameters", to: nil)) == .damaged)
        #expect(Self.refusal(try Self.file(settingNode: "id", to: "one")) == .damaged)
        #expect(Self.refusal(try Self.file(settingNode: "id", to: 1.5)) == .damaged)
        var noEdges = try Self.body()
        noEdges["edges"] = nil
        #expect(Self.refusal(try Self.file(noEdges)) == .damaged)
    }

    @Test func newerVersion() throws {
        #expect(Self.refusal(try Self.file(try Self.body(), version: 2)) == .newerVersion)
        #expect(Self.refusal(try Self.file("any body", version: 7)) == .newerVersion)
    }

    @Test func tooLargeFile() throws {
        let atLimit = Data(repeating: 0x20, count: GraphDocument.maxEncodedBytes)
        #expect(Self.refusal(atLimit) == .damaged)
        let past = Data(repeating: 0x20, count: GraphDocument.maxEncodedBytes + 1)
        #expect(Self.refusal(past) == .tooLarge)
    }

    @Test func tooManyNodesOrEdgesInAFile() throws {
        let nodes = try Self.file(of: Self.nodes(GraphLimits.maxNodes), appendingTo: "nodes",
                                  changes: ["id": GraphLimits.maxNodes + 1])
        #expect(Self.refusal(nodes) == .tooLarge)
        let edges = try Self.file(of: Self.edges(GraphLimits.maxEdges), appendingTo: "edges",
                                  changes: ["targetPort": "extra"])
        #expect(Self.refusal(edges) == .tooLarge)
    }

    @Test func notFiniteInAFile() throws {
        for text in ["NaN", "Infinity", "-Infinity"] {
            #expect(Self.refusal(try Self.file(settingPosition: "x", to: text)) == .notFinite, "x \(text)")
            #expect(Self.refusal(try Self.file(settingPosition: "y", to: text)) == .notFinite, "y \(text)")
            #expect(Self.refusal(try Self.file(settingNoiseParameter: "scale", to: text)) == .notFinite, "\(text)")
        }
        #expect(Self.refusal(try Self.file(settingPosition: "x", to: "fast")) == .damaged)
    }

    @Test func outOfRangeInAFile() throws {
        #expect(Self.refusal(try Self.file(settingNode: "id", to: 0)) == .outOfRange)
        #expect(Self.refusal(try Self.file(settingNode: "id", to: 10_000)) == .outOfRange)
        #expect(Self.refusal(try Self.file(settingPosition: "x", to: 4_096.5)) == .outOfRange)
        #expect(Self.refusal(try Self.file(settingPosition: "y", to: -4_096.5)) == .outOfRange)
        #expect(Self.refusal(try Self.file(settingNoiseParameter: "scale", to: 33)) == .outOfRange)
        #expect(Self.refusal(try Self.file(settingNoiseParameter: "octaves", to: 0)) == .outOfRange)
        // An undeclared parameter is the checker's, whatever its value.
        #expect(Self.refusal(try Self.file(settingNoiseParameter: "extra", to: 1_000)) == nil)
    }

    // MARK: - Refusals on writing

    @Test func notFiniteOnWriting() {
        let values: [Double] = [.nan, .infinity, -.infinity]
        for value in values {
            let x = GraphNode(id: NodeID(1), kind: .time, position: CanvasPoint(x: value, y: 0))
            #expect(Self.refusal(encoding: Self.single(x)) == .notFinite)
            let y = GraphNode(id: NodeID(1), kind: .time, position: CanvasPoint(x: 0, y: value))
            #expect(Self.refusal(encoding: Self.single(y)) == .notFinite)
            let declared = GraphNode(id: NodeID(1), kind: .time, parameters: ["rate": value])
            #expect(Self.refusal(encoding: Self.single(declared)) == .notFinite)
            let undeclared = GraphNode(id: NodeID(1), kind: .time, parameters: ["extra": value])
            #expect(Self.refusal(encoding: Self.single(undeclared)) == .notFinite)
        }
    }

    @Test func outOfRangeOnWriting() {
        let refused: [GraphNode] = [
            GraphNode(id: NodeID(0), kind: .time),
            GraphNode(id: NodeID(10_000), kind: .time),
            GraphNode(id: NodeID(1), kind: .time, position: CanvasPoint(x: 4_096.5, y: 0)),
            GraphNode(id: NodeID(1), kind: .time, position: CanvasPoint(x: 0, y: -4_096.5)),
            GraphNode(id: NodeID(1), kind: .time, parameters: ["rate": 4.5]),
            GraphNode(id: NodeID(1), kind: .constant, parameters: ["value": -8.5]),
            GraphNode(id: NodeID(1), kind: .gradient, parameters: ["angle": 361]),
        ]
        for node in refused {
            #expect(Self.refusal(encoding: Self.single(node)) == .outOfRange, "\(node)")
        }
        let edge = VisualGraph(nodes: [GraphNode(id: NodeID(1), kind: .time)],
                               edges: [GraphEdge(from: NodeID(1), "time", to: NodeID(0), "time")])
        #expect(Self.refusal(encoding: edge) == .outOfRange)
    }

    @Test func tooLargeOnWriting() {
        #expect(Self.refusal(encoding: Self.nodes(GraphLimits.maxNodes + 1)) == .tooLarge)
        #expect(Self.refusal(encoding: Self.edges(GraphLimits.maxEdges + 1)) == .tooLarge)
        // One node with many undeclared parameters (the checker's matter) whose file passes 65,536 bytes.
        var parameters: [String: Double] = [:]
        let padding = String(repeating: "p", count: 100)
        for index in 0..<700 {
            parameters["\(padding)\(index)"] = 1
        }
        let big = Self.single(GraphNode(id: NodeID(1), kind: .time, parameters: parameters))
        #expect(Self.refusal(encoding: big) == .tooLarge)
    }

    // MARK: - Limits at the bound

    @Test func limitsAtTheBoundAreAccepted() throws {
        let fullNodes = Self.nodes(GraphLimits.maxNodes)
        #expect(try GraphDocument.decode(GraphDocument.encode(fullNodes)).nodes.count == 32)
        let fullEdges = Self.edges(GraphLimits.maxEdges)
        #expect(try GraphDocument.decode(GraphDocument.encode(fullEdges)).edges.count == 64)
        let bounds = VisualGraph(nodes: [
            GraphNode(id: NodeID(1), kind: .time, parameters: ["rate": 0], position: CanvasPoint(x: -4_096, y: 4_096)),
            GraphNode(id: NodeID(9_999), kind: .time, parameters: ["rate": 4],
                      position: CanvasPoint(x: 4_096, y: -4_096)),
        ])
        let data = try GraphDocument.encode(bounds)
        #expect(try GraphDocument.decode(data) == bounds)
    }

    @Test func limitsOnePastTheBoundAreRefused() throws {
        #expect(Self.refusal(encoding: Self.nodes(GraphLimits.maxNodes + 1)) == .tooLarge)
        #expect(Self.refusal(encoding: Self.edges(GraphLimits.maxEdges + 1)) == .tooLarge)
        #expect(Self.refusal(encoding: Self.single(GraphNode(id: NodeID(0), kind: .time))) == .outOfRange)
        #expect(Self.refusal(encoding: Self.single(GraphNode(id: NodeID(10_000), kind: .time))) == .outOfRange)
        let past = GraphNode(id: NodeID(1), kind: .time, position: CanvasPoint(x: -4_096.5, y: 0))
        #expect(Self.refusal(encoding: Self.single(past)) == .outOfRange)
        #expect(Self.refusal(try Self.file(settingNode: "id", to: 1)) == nil)
        #expect(Self.refusal(try Self.file(settingNode: "id", to: 9_999)) == nil)
        #expect(Self.refusal(try Self.file(settingPosition: "x", to: 4_096)) == nil)
        #expect(Self.refusal(try Self.file(settingPosition: "x", to: -4_096)) == nil)
    }

    // MARK: - Fingerprint

    @Test func fingerprintIsStable() throws {
        let first = try GraphDocument.fingerprint(of: Self.sample())
        let second = try GraphDocument.fingerprint(of: Self.sample())
        #expect(first == second)
        #expect(try GraphDocument.fingerprint(of: Self.reversedSample()) == first)
        #expect(try GraphDocument.fingerprint(of: GraphDocument.decode(GraphDocument.encode(Self.sample()))) == first)
        #expect(first.hex.count == 64)
    }

    @Test func fingerprintChangesWithOneValue() throws {
        let base = try GraphDocument.fingerprint(of: Self.sample())
        var parameter = Self.sample()
        parameter.nodes[2].parameters["radius"] = 2.75
        #expect(try GraphDocument.fingerprint(of: parameter) != base)
        var position = Self.sample()
        position.nodes[0].position.y = 121
        #expect(try GraphDocument.fingerprint(of: position) != base)
        var edge = Self.sample()
        edge.edges[3] = GraphEdge(from: NodeID(7), "value", to: NodeID(2), "scale")
        #expect(try GraphDocument.fingerprint(of: edge) != base)
        var kind = Self.sample()
        kind.nodes[3].kind = .noise
        #expect(try GraphDocument.fingerprint(of: kind) != base)
        var removed = Self.sample()
        removed.edges.removeLast()
        #expect(try GraphDocument.fingerprint(of: removed) != base)
    }

    @Test func fingerprintRefusesNotFinite() {
        var position = Self.sample()
        position.nodes[1].position.x = .nan
        #expect(Self.refusal(fingerprinting: position) == .notFinite)
        var parameter = Self.sample()
        parameter.nodes[1].parameters["scale"] = .infinity
        #expect(Self.refusal(fingerprinting: parameter) == .notFinite)
        #expect(Self.refusal(fingerprinting: Self.sample()) == nil)
    }
}
