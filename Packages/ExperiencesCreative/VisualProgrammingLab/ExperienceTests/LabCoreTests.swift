// LabCoreTests — feature 167 (A23-P02) T-A23-207 (FR-A23-201, FR-A23-202, FR-A23-203; SC-A23-201, SC-A23-202;
// clarification Q1; data-model.md "LabCore"). The adapter core `LabCore`: the six actions with their ranges, the
// starter graph, the rule ids, the edits (smallest unused identity, removal with its connections and the selection),
// a refused edit changing nothing, the journey graph built by actions, the digest over the graph only (not the
// selection), the snapshot round trip and the restore refusals, one quality tier `level-0`. Then every refusal
// fixture sent through the presenter: the digest is unchanged and the feedback is the refusal's sentence. Short runs.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct LabCoreTests {
    @Test func theSixControlsAreDeclaredWithTheirRanges() {
        #expect(LabCore.experienceID == "a23.visual-programming-lab")
        #expect(VisualProgrammingLabExperience.id?.rawValue == "a23.visual-programming-lab")
        #expect(LabCore.digestDomain == "a23.visual-programming-lab.v1")
        #expect(LabCore.controls.map(\.id) == LabCore.actionIDs)
        let ranges = Dictionary(uniqueKeysWithValues: LabCore.controls.map { ($0.id, $0.ranges) })
        #expect(ranges["node.add"] == [0...6, -4096...4096, -4096...4096])
        #expect(ranges["node.move"] == [1...9999, -4096...4096, -4096...4096])
        #expect(ranges["node.remove"] == [1...9999])
        #expect(ranges["node.select"] == [0...9999])
        #expect(ranges["edge.connect"] == [1...9999, 0...1, 1...9999, 0...2])
        #expect(ranges["edge.disconnect"] == [1...9999, 0...2])
        #expect(LabCore.qualityTiers == 1 && LabCore.qualityProfile.names == ["level-0"])
        #expect(LabCore.migrations.currentVersion == 1)
    }

    @Test func theRuleIdsAreTheEditorsRefusals() {
        let refusals: [GraphEditRefusal] = [.notWhole, .unknownNode(NodeID(1)), .unknownPort,
                                            .typeMismatch(from: .colour, to: .scalar),
                                            .inputTaken(node: NodeID(2), port: "image"), .cycle([]), .tooManyNodes,
                                            .oneOutput, .tooManyEdges]
        #expect(refusals.map(\.rule) == LabRule.all)
    }

    @Test func theStarterGraphIsNoiseIntoOutput() {
        let core = LabCore()
        #expect(core.graph == LabCore.starterGraph && core.selection == nil)
        let noise = core.graph.node(NodeID(1))
        let output = core.graph.node(NodeID(2))
        #expect(noise?.kind == .noise && noise?.position == CanvasPoint(x: 40, y: 80))
        #expect(output?.kind == .output && output?.position == CanvasPoint(x: 320, y: 80))
        #expect(core.graph.edges == [GraphEdge(from: NodeID(1), "image", to: NodeID(2), "image")])
        #expect(core.outcome?.code == "graph-ready")
        #expect(EditMessages.status(for: core.check, in: core.graph) == "Ready")
    }

    @Test func editsChangeTheGraphAndTheSelection() {
        var (core, result) = labApplied(LabCore(), "node.add", [4, 320, 240])
        #expect(result == .accepted && core.graph.node(NodeID(3))?.kind == .mix)
        #expect(core.outcome == nil, "Mix's inputs a and b are empty")
        (core, result) = labApplied(core, "node.select", [3])
        #expect(result == .accepted && core.selection == NodeID(3))
        (core, result) = labApplied(core, "node.move", [3, 4_096, -4_096])
        #expect(result == .accepted && core.graph.node(NodeID(3))?.position == CanvasPoint(x: 4_096, y: -4_096))
        (core, result) = labApplied(core, "edge.connect", [1, 0, 3, 0])
        #expect(result == .accepted && core.graph.edges.count == 2)
        (core, result) = labApplied(core, "node.remove", [3])
        #expect(result == .accepted && core.graph.node(NodeID(3)) == nil && core.selection == nil)
        #expect(core.graph.edges == LabCore.starterGraph.edges, "its connection went with it")
        (core, result) = labApplied(core, "node.add", [5, 0, 0])
        #expect(result == .accepted && core.graph.node(NodeID(3))?.kind == .blur, "the smallest unused identity")
        (core, result) = labApplied(core, "node.select", [1])
        (core, result) = labApplied(core, "node.select", [0])
        #expect(result == .accepted && core.selection == nil)
        (core, result) = labApplied(core, "edge.disconnect", [2, 0])
        #expect(result == .accepted && core.graph.edges.isEmpty)
        #expect(EditMessages.status(for: core.check, in: core.graph) == "Output not connected")
        (core, result) = labApplied(core, "edge.disconnect", [2, 0])
        #expect(result == .accepted && core.graph.edges.isEmpty, "an empty input stays empty")
        (core, result) = labApplied(core, "node.remove", [2])
        #expect(result == .accepted && EditMessages.status(for: core.check, in: core.graph) == "No output")
    }

    @Test func refusedEditsChangeNothing() {
        let cases: [(control: String, values: [Double], code: String)] = [
            ("node.add", [0.5, 0, 0], "action.rule.a23.not-whole"),
            ("node.select", [1.5], "action.rule.a23.not-whole"),
            ("edge.connect", [1, 0.5, 2, 0], "action.rule.a23.not-whole"),
            ("node.move", [9, 0, 0], "action.rule.a23.unknown-node"),
            ("node.remove", [9], "action.rule.a23.unknown-node"),
            ("node.select", [9], "action.rule.a23.unknown-node"),
            ("edge.connect", [1, 0, 9, 0], "action.rule.a23.unknown-node"),
            ("edge.disconnect", [9, 0], "action.rule.a23.unknown-node"),
            ("edge.connect", [1, 1, 2, 0], "action.rule.a23.unknown-port"),
            ("edge.disconnect", [2, 1], "action.rule.a23.unknown-port"),
            ("edge.connect", [1, 0, 1, 0], "action.rule.a23.type-mismatch"),
            ("edge.connect", [1, 0, 2, 0], "action.rule.a23.input-taken"),
            ("node.add", [6, 0, 0], "action.rule.a23.one-output"),
            ("node.add", [7, 0, 0], "action.out-of-range"),
            ("node.move", [1, 4_097, 0], "action.out-of-range"),
            ("node.select", [-1], "action.out-of-range"),
            ("node.add", [0, .nan, 0], "action.non-finite"),
            ("node.add", [0, 0], "action.wrong-value-count"),
        ]
        for item in cases {
            let (next, result) = labApplied(LabCore(), item.control, item.values)
            #expect(result.code == item.code, "\(item.control) \(item.values)")
            #expect(next == LabCore(), "\(item.control) \(item.values) changes nothing")
        }
    }

    @Test func theNodeLimitAndALoopAreRefused() {
        var core = LabCore()
        for k in 0..<(GraphLimits.maxNodes - 2) {
            let (next, result) = labApplied(core, "node.add", [1, Double(k * 10), 400])
            #expect(result == .accepted)
            core = next
        }
        #expect(core.graph.nodes.count == 32)
        let (full, refused) = labApplied(core, "node.add", [1, 0, 0])
        #expect(refused.code == "action.rule.a23.too-many-nodes" && full == core)

        var loop = labApplied(LabCore(), "node.add", [4, 320, 240]).0     // Mix 3
        loop = labApplied(loop, "node.add", [5, 600, 240]).0             // Blur 4
        loop = labApplied(loop, "edge.connect", [3, 0, 4, 0]).0          // Mix → Blur
        let (closed, result) = labApplied(loop, "edge.connect", [4, 0, 3, 0])
        #expect(result.code == "action.rule.a23.cycle" && closed == loop)
    }

    @Test func theJourneyGraphIsBuiltByActions() throws {
        var core = LabCore()
        for action in LabCore.journeyActions {
            let (next, result) = labApplied(core, action.control, action.values)
            #expect(result == .accepted, "\(action.control) \(action.values)")
            core = next
        }
        #expect(core.graph.nodes.map(\.kind).sorted { $0.rawValue < $1.rawValue }
            == [NodeKind.blur, .gradient, .mix, .noise, .output])
        #expect(Set(core.graph.edges) == [GraphEdge(from: NodeID(1), "image", to: NodeID(4), "a"),
                                          GraphEdge(from: NodeID(3), "image", to: NodeID(4), "b"),
                                          GraphEdge(from: NodeID(4), "image", to: NodeID(5), "image"),
                                          GraphEdge(from: NodeID(5), "image", to: NodeID(2), "image")])
        #expect(core.outcome?.code == "graph-ready")
    }

    @Test func theDigestCoversTheGraphButNotTheSelection() throws {
        let opening = try labDigest(LabCore())
        let (selected, _) = labApplied(LabCore(), "node.select", [1])
        #expect(try labDigest(selected) == opening)
        let (moved, _) = labApplied(LabCore(), "node.move", [1, 41, 80])
        #expect(try labDigest(moved) != opening)
        var builder = DigestBuilder(domain: LabCore.experienceID)
        builder.add(LabCore.digestDomain)
        builder.add(try GraphDocument.fingerprint(of: LabCore.starterGraph).hex)
        #expect(builder.finish().hex == opening)
    }

    @Test func theSnapshotRoundTripsAndDamagedSnapshotsAreRefused() throws {
        var core = LabCore()
        for action in LabCore.journeyActions { core = labApplied(core, action.control, action.values).0 }
        core = labApplied(core, "node.select", [4]).0
        let payload = try core.snapshotPayload()
        #expect(try LabCore.restore(payload: payload, seed: 9) == core)
        let text = try #require(String(data: payload, encoding: .utf8))
        #expect(text.hasPrefix("{\"graph\":") && text.contains("\"selection\":4"))

        let incomplete = labApplied(LabCore(), "node.remove", [2]).0
        #expect(try LabCore.restore(payload: incomplete.snapshotPayload(), seed: 1) == incomplete)

        func refusal(_ json: String) -> LabRestoreRefusal? {
            do {
                _ = try LabCore.restore(payload: Data(json.utf8), seed: 1)
                return nil
            } catch {
                return error as? LabRestoreRefusal
            }
        }
        let noise = #"{"id":1,"kind":"noise","parameters":{},"position":{"x":40,"y":80}}"#
        let output = #"{"id":2,"kind":"output","parameters":{},"position":{"x":320,"y":80}}"#
        let edge = #"{"sourceNode":1,"sourcePort":"image","targetNode":2,"targetPort":"image"}"#
        #expect(refusal("[]") == .damaged)
        #expect(refusal(#"{"selection":0}"#) == .damaged)
        #expect(refusal(#"{"graph":{"nodes":[\#(noise),\#(output)],"edges":[\#(edge)]},"selection":3}"#)
            == .outOfRange("selection"))
        #expect(refusal(#"{"graph":{"nodes":[\#(noise),\#(noise)],"edges":[]},"selection":0}"#)
            == .outOfRange("graph"), "a duplicate identity")
        let far = #"{"id":1,"kind":"noise","parameters":{},"position":{"x":5000,"y":80}}"#
        #expect(refusal(#"{"graph":{"nodes":[\#(far)],"edges":[]},"selection":0}"#) == .outOfRange("graph"))
        let selfLoop = #"{"sourceNode":1,"sourcePort":"image","targetNode":1,"targetPort":"time"}"#
        #expect(refusal(#"{"graph":{"nodes":[\#(noise)],"edges":[\#(selfLoop)]},"selection":0}"#)
            == .outOfRange("graph"), "a type mismatch")
        let secondOutput = #"{"id":3,"kind":"output","parameters":{},"position":{"x":0,"y":0}}"#
        #expect(refusal(#"{"graph":{"nodes":[\#(output),\#(secondOutput)],"edges":[]},"selection":0}"#)
            == .outOfRange("graph"), "two outputs")
    }

    /// SC-A23-202: every refusal fixture sent through the presenter leaves the digest unchanged and shows its
    /// sentence.
    @Test func everyRefusalFixtureKeepsTheDigestAndShowsItsSentence() async throws {
        let shell = try await LabTest.shell()
        let presenter = shell.presenter
        LabTest.accept(shell, "node.add", [1, 40, 400])          // Constant 3
        LabTest.accept(shell, "node.add", [3, 40, 560])          // Gradient 4
        LabTest.accept(shell, "node.add", [4, 600, 240])         // Mix 5
        LabTest.accept(shell, "node.add", [5, 880, 240])         // Blur 6
        LabTest.accept(shell, "edge.connect", [5, 0, 6, 0])      // Mix → Blur
        let fixtures: [(control: String, values: [Double], refusal: GraphEditRefusal)] = [
            ("edge.connect", [3, 1, 1, 1], .typeMismatch(from: .colour, to: .scalar)),
            ("edge.connect", [4, 0, 2, 0], .inputTaken(node: NodeID(2), port: "image")),
            ("edge.connect", [6, 0, 5, 0], .cycle([])),
            ("node.add", [6, 0, 0], .oneOutput),
        ]
        for fixture in fixtures {
            let before = try LabTest.digest(shell)
            let graph = try LabTest.core(shell).graph
            let result = presenter.send(fixture.control, fixture.values, port: shell.port)
            #expect(result.code == "action.rule." + fixture.refusal.rule, "\(fixture.values)")
            #expect(try LabTest.digest(shell) == before, "\(fixture.values) changes nothing")
            if case .cycle = fixture.refusal {
                #expect(presenter.feedback == "That connection would make a loop.")
            } else {
                #expect(presenter.feedback == EditMessages.sentence(for: fixture.refusal, in: graph))
            }
        }
        #expect(EditMessages.sentence(for: .typeMismatch(from: .colour, to: .scalar))
            == "A colour output cannot feed a scalar input.")
        LabTest.accept(shell, "node.select", [3])
        #expect(presenter.feedback == nil, "an accepted edit clears the feedback")
        for k in 0..<(GraphLimits.maxNodes - 6) { LabTest.accept(shell, "node.add", [1, Double(k * 8), 800]) }
        let before = try LabTest.digest(shell)
        let result = presenter.send("node.add", [1, 0, 0], port: shell.port)
        #expect(result.code == "action.rule.a23.too-many-nodes")
        #expect(try LabTest.digest(shell) == before)
        #expect(presenter.feedback == "A graph holds at most 32 nodes.")
    }
}
