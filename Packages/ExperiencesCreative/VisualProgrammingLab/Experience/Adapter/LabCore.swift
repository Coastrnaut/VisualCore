// LabCore — feature 167 (A23-P02) T-A23-205 (FR-A23-201, FR-A23-202, FR-A23-203; clarification Q1; data-model.md
// "LabCore"; contracts/experience.md "Core"). The state of Visual Programming Lab as an experience: the graph (A23-P01's
// `VisualGraph`) and the selected node (or none). Every edit is the core's `GraphEditor`; a refused edit changes
// nothing and is answered with the rule id of its `GraphEditRefusal`. The core never draws and reads no clock.
//
// Actions (the engine refuses a value outside the declared range, a non-finite value and a wrong value count before
// the core sees it; called directly, the core refuses them itself with the same reasons):
//   node.add [kind 0…6, x −4,096…4,096, y −4,096…4,096]   the kind at that index of `NodeKind.allCases` (time,
//                                   constant, noise, gradient, mix, blur, output) at (x, y); the new node takes the
//                                   smallest unused identity; refused at 32 nodes (`a23.too-many-nodes`) and for a
//                                   second output (`a23.one-output`);
//   node.move [id 1…9,999, x, y]    the node's new position, clamped to ±4,096 (`a23.unknown-node`);
//   node.remove [id 1…9,999]        removes the node and its connections; clears the selection if it was selected;
//   node.select [id 0…9,999]        selects the node (`a23.unknown-node`); 0 clears the selection;
//   edge.connect [source 1…9,999, output 0…1, target 1…9,999, input 0…2]   connects the source's output (index into
//                                   its kind's outputs in declaration order) to the target's input (index into its
//                                   inputs); refusals `a23.unknown-node`, `a23.unknown-port`, `a23.type-mismatch`,
//                                   `a23.input-taken`, `a23.cycle`, `a23.too-many-edges` (64 connections);
//   edge.disconnect [target 1…9,999, input 0…2]   removes the connection feeding that input (none: no change).
// Every identity, kind and port index must be a whole number (`a23.not-whole`). A refused action changes nothing.
//
// Digest ("a23.visual-programming-lab.v1"): the domain, then the hex text of the graph's fingerprint
// (`GraphDocument.fingerprint(of:)`, which covers the nodes in identity order and the connections in order). The
// selection is in the snapshot, not in the digest. Snapshot schema 1: the JSON object `{"graph", "selection"}` with
// sorted keys (`selection` 0 for none). Restoring a damaged payload throws `LabRestoreRefusal.damaged`; a graph the
// file format refuses, a graph with an issue before the checker's output stage (duplicate identities, unknown
// parameters or ports, wrong types, a fed input fed twice, a loop) or with two outputs, or a selection that is not 0
// or a node of the graph throws `.outOfRange(_:)`. An incomplete graph (no output, an empty required input) restores.
// Outcome `graph-ready` while `GraphChecker` accepts the graph, nil otherwise. Quality: one tier, `level-0`.
// The starter graph: Noise (id 1 at 40, 80) into Output (id 2 at 320, 80), `noise.image → output.image`.
import Foundation
import VisualCoreExperience
import VisualCoreParameters
import VisualCorePersistence
import VisualProgrammingLabCore

/// The rule ids of Visual Programming Lab's refusals (feature 167); each equals ``GraphEditRefusal/rule`` of the
/// refusal it names.
public enum LabRule {
    /// An identity, kind or port index that is not a whole number.
    public static let notWhole = "a23.not-whole"
    /// A node identity that is not in the graph.
    public static let unknownNode = "a23.unknown-node"
    /// A port index the node's kind does not declare.
    public static let unknownPort = "a23.unknown-port"
    /// An output and an input of different value types.
    public static let typeMismatch = "a23.type-mismatch"
    /// An input that is already fed.
    public static let inputTaken = "a23.input-taken"
    /// A connection that would close a loop.
    public static let cycle = "a23.cycle"
    /// A node added to a graph of 32 nodes.
    public static let tooManyNodes = "a23.too-many-nodes"
    /// A second Output node.
    public static let oneOutput = "a23.one-output"
    /// A connection added to a graph of 64 connections (added by the lead at T-A23-203).
    public static let tooManyEdges = "a23.too-many-edges"

    /// The nine rule ids: the eight of the spec's clarification Q1, then the connection limit.
    public static let all = [notWhole, unknownNode, unknownPort, typeMismatch, inputTaken, cycle, tooManyNodes,
                             oneOutput, tooManyEdges]
}

/// Why a saved Visual Programming Lab state was refused on restore (feature 167). A refused restore changes nothing.
public enum LabRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"graph", "selection"}` or a field has the wrong type.
    case damaged
    /// A field is outside its range; the value names it (`graph` or `selection`).
    case outOfRange(String)
}

/// The state of Visual Programming Lab (see the file header). Snapshot schema 1.
public struct LabCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a23.visual-programming-lab"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "a23.visual-programming-lab.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["node.add", "node.move", "node.remove", "node.select", "edge.connect",
                                   "edge.disconnect"]
    /// The outcome code while the checker accepts the graph.
    public static let readyCode = "graph-ready"
    /// The accepted kind index of `node.add` (`NodeKind.allCases`).
    public static let kindRange: ClosedRange<Double> = 0...Double(NodeKind.allCases.count - 1)
    /// The accepted coordinate of a position.
    public static let coordinateRange: ClosedRange<Double> = -CanvasPoint.bound...CanvasPoint.bound
    /// The accepted node identity of an edit.
    public static let idRange: ClosedRange<Double> = Double(NodeID.validRange.lowerBound)...Double(NodeID.validRange.upperBound)
    /// The accepted identity of `node.select` (0 clears).
    public static let selectRange: ClosedRange<Double> = 0...Double(NodeID.validRange.upperBound)
    /// The accepted output index (the most outputs a kind declares is 2).
    public static let outputIndexRange: ClosedRange<Double> = 0...1
    /// The accepted input index (the most inputs a kind declares is 3).
    public static let inputIndexRange: ClosedRange<Double> = 0...2

    /// The starter graph: Noise (id 1 at 40, 80) into Output (id 2 at 320, 80).
    public static let starterGraph = VisualGraph(
        nodes: [GraphNode(id: NodeID(1), kind: .noise, position: CanvasPoint(x: 40, y: 80)),
                GraphNode(id: NodeID(2), kind: .output, position: CanvasPoint(x: 320, y: 80))],
        edges: [GraphEdge(from: NodeID(1), "image", to: NodeID(2), "image")])

    /// The person's graph.
    public private(set) var graph: VisualGraph
    /// The selected node, or nil (in the snapshot, not in the digest).
    public private(set) var selection: NodeID?

    /// The opening state: the starter graph, nothing selected.
    public init() {
        self.init(graph: Self.starterGraph, selection: nil)
    }

    /// A state with `graph` and `selection` as given (nothing is checked; ``restore(payload:seed:)`` checks).
    public init(graph: VisualGraph, selection: NodeID? = nil) {
        self.graph = graph
        self.selection = selection
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "node.add", ranges: [kindRange, coordinateRange, coordinateRange]),
        ExperienceControl(id: "node.move", ranges: [idRange, coordinateRange, coordinateRange]),
        ExperienceControl(id: "node.remove", ranges: [idRange]),
        ExperienceControl(id: "node.select", ranges: [selectRange]),
        ExperienceControl(id: "edge.connect", ranges: [idRange, outputIndexRange, idRange, inputIndexRange]),
        ExperienceControl(id: "edge.disconnect", ranges: [idRange, inputIndexRange]),
    ]

    /// The six controls with their declared ranges (see the file header).
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state; nothing depends on the seed and no clock is read.
    public static func prepare(seed: UInt64) async throws -> LabCore {
        try Task.checkCancellation()
        return LabCore()
    }

    /// A host step changes nothing: the graph changes only by edits.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        if let refusal = ExperienceInput.validate(control: action.control, values: action.values,
                                                  controls: Self.declaredControls) {
            return .rejected(refusal)
        }
        switch applying(action.control, action.values) {
        case .success(let next):
            self = next
            return .accepted
        case .failure(let refusal):
            return .rejected(.rule(code: refusal.rule))
        }
    }

    /// The state after the edit `control` with `values`, or the edit's refusal; `self` is not changed. The values are
    /// assumed well formed (declared control, count and ranges: ``apply(_:)`` checks them first); an undeclared
    /// control gives the state unchanged. The presenter uses it to explain a refusal with
    /// ``EditMessages/sentence(for:)``.
    public func applying(_ control: String, _ values: [Double]) -> Result<LabCore, GraphEditRefusal> {
        do throws(GraphEditRefusal) {
            return .success(try edited(control, values))
        } catch {
            return .failure(error)
        }
    }

    /// The edit itself (see ``applying(_:_:)``).
    private func edited(_ control: String, _ values: [Double]) throws(GraphEditRefusal) -> LabCore {
        var next = self
        switch control {
        case "node.add":
            guard values.count == 3 else { return self }
            let index = try Self.whole(values[0])
            guard NodeKind.allCases.indices.contains(index) else { throw .notWhole }
            let added = try GraphEditor.add(NodeKind.allCases[index], at: CanvasPoint(x: values[1], y: values[2]),
                                            to: graph)
            next.graph = added.graph
        case "node.move":
            guard values.count == 3 else { return self }
            let id = NodeID(try Self.whole(values[0]))
            next.graph = try GraphEditor.move(id, to: CanvasPoint(x: values[1], y: values[2]), in: graph)
        case "node.remove":
            guard values.count == 1 else { return self }
            let id = NodeID(try Self.whole(values[0]))
            next.graph = try GraphEditor.remove(id, from: graph)
            if selection == id { next.selection = nil }
        case "node.select":
            guard values.count == 1 else { return self }
            let raw = try Self.whole(values[0])
            if raw == 0 {
                next.selection = nil
            } else {
                let id = NodeID(raw)
                guard graph.node(id) != nil else { throw .unknownNode(id) }
                next.selection = id
            }
        case "edge.connect":
            guard values.count == 4 else { return self }
            let source = NodeID(try Self.whole(values[0]))
            let output = try Self.whole(values[1])
            let target = NodeID(try Self.whole(values[2]))
            let input = try Self.whole(values[3])
            next.graph = try GraphEditor.connect(source: source, outputIndex: output, target: target,
                                                 inputIndex: input, in: graph)
        case "edge.disconnect":
            guard values.count == 2 else { return self }
            let target = NodeID(try Self.whole(values[0]))
            let input = try Self.whole(values[1])
            next.graph = try GraphEditor.disconnect(target: target, inputIndex: input, in: graph)
        default:
            return self
        }
        return next
    }

    /// `value` as an `Int` when it is a finite whole number; throws ``GraphEditRefusal/notWhole`` otherwise.
    static func whole(_ value: Double) throws(GraphEditRefusal) -> Int {
        guard value.isFinite, value == value.rounded(), abs(value) <= Double(Int32.max) else { throw .notWhole }
        return Int(value)
    }

    /// Back to the opening state.
    public mutating func reset() {
        self = LabCore()
    }

    /// The checker's verdict on the graph.
    public var check: CheckResult { GraphChecker.check(graph) }

    /// `graph-ready` while the checker accepts the graph; nil otherwise.
    public var outcome: ExperienceOutcome? {
        if case .accepted = check { return ExperienceOutcome(code: Self.readyCode) }
        return nil
    }

    /// "a23.visual-programming-lab.v1", then the hex text of the graph's fingerprint (not the selection). Throws
    /// `DigestError.nonFinite` when the graph holds a non-finite number (no edit can make one).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        let fingerprint: StateDigest
        do {
            fingerprint = try GraphDocument.fingerprint(of: graph)
        } catch {
            throw DigestError.nonFinite(field: builder.fieldCount)
        }
        builder.add(fingerprint.hex)
    }

    // MARK: Snapshot

    /// The payload's JSON form.
    private struct Payload: Codable {
        var graph: VisualGraph
        var selection: Int
    }

    /// The JSON object `{"graph", "selection"}` with sorted keys; `selection` is 0 for none.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Payload(graph: graph, selection: selection?.rawValue ?? 0))
    }

    /// The core of `payload` (see the file header for the refusals). The seed changes nothing.
    public static func restore(payload: Data, seed: UInt64) throws -> LabCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw LabRestoreRefusal.damaged
        }
        let graph = decoded.graph
        do {
            _ = try GraphDocument.encode(graph)
        } catch {
            throw LabRestoreRefusal.outOfRange("graph")
        }
        if case .refused(let issues) = GraphChecker.check(graph),
           !issues.allSatisfy(Self.isIncompleteness) {
            throw LabRestoreRefusal.outOfRange("graph")
        }
        let selection: NodeID?
        if decoded.selection == 0 {
            selection = nil
        } else {
            let id = NodeID(decoded.selection)
            guard graph.node(id) != nil else { throw LabRestoreRefusal.outOfRange("selection") }
            selection = id
        }
        return LabCore(graph: graph, selection: selection)
    }

    /// Whether `issue` only says the graph is incomplete (no output, the output or a required input not fed): such a
    /// graph is a valid state of the editor.
    static func isIncompleteness(_ issue: GraphIssue) -> Bool {
        switch issue {
        case .noOutput, .outputDisconnected, .inputUnconnected: return true
        default: return false
        }
    }
}
