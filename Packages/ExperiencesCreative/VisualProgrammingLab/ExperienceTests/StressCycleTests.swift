// StressCycleTests — feature 170 (A23-P05) T-A23-502 (FR-A23-501; SC-A23-501, SC-A23-506; clarification Q1; User
// Story 1; research D1; data-model.md "LabLevel"). Through the one app's session host: 50 mixed cycles, each adding a
// Mix (kind 4), connecting it, disconnecting it and removing it through the port, opening the next example (of three,
// through the presenter's `openExample(id:)`, the restore path of the Examples menu) and drawing, drawing a graph of 7
// slots through `graphOverride` (refused: the registry's level is unchanged by it), returning to the example and
// drawing, and every 10th cycle rebuilding the context (`recreateContext`) and drawing. The order of the examples
// starts with the journey (`mixed-clouds`), so cycle 1, the warm-up, builds every operator program the examples use.
//
// The level (`LabLevel`: the registry's `liveCount` of every kind plus `totalBytes`) after cycle 1 equals the level
// after every later cycle that shows the journey (4, 7, …, 49); because the three examples hold 1, 2 and 3 slots and
// 49 is no multiple of 3, the level after cycle 50 (Clouds) is compared with that after cycle 2 (Clouds, the first
// cycle after the warm-up showing it), and every cycle with the first of the same example. Nothing is reported leaked
// after any cycle. Short runs only (no sleep, no wall-clock assertion).
import CoreGraphics
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

/// The resource level of a render host (feature 170, data-model.md "LabLevel", after Shader Studio's `StudioLevel`):
/// the live object count of every resource kind (keyed by the kind's name) and the live bytes across all kinds.
struct LabLevel: Equatable, CustomStringConvertible {
    /// Live objects per resource kind, keyed by the kind's name.
    var liveCount: [String: Int]
    /// Live bytes across all kinds.
    var totalBytes: Int

    /// The level of `host`'s registry now.
    @MainActor
    init(_ host: RenderHost) {
        let stats = host.resources.stats
        var counts: [String: Int] = [:]
        for (kind, count) in stats.liveCount { counts[String(describing: kind)] = count }
        liveCount = counts
        totalBytes = stats.totalBytes
    }

    /// The live objects of every kind together.
    var objects: Int { liveCount.values.reduce(0, +) }

    /// The kinds whose count differs from `earlier` (with the signed change) and the byte change; empty when equal.
    func change(since earlier: LabLevel) -> String {
        var parts: [String] = []
        for kind in Set(liveCount.keys).union(earlier.liveCount.keys).sorted() {
            let delta = liveCount[kind, default: 0] - earlier.liveCount[kind, default: 0]
            if delta != 0 { parts.append("\(kind) \(delta > 0 ? "+" : "")\(delta)") }
        }
        let bytes = totalBytes - earlier.totalBytes
        if bytes != 0 { parts.append("bytes \(bytes > 0 ? "+" : "")\(bytes)") }
        return parts.joined(separator: ", ")
    }

    /// "kind=n …, bytes=n", in kind-name order.
    var description: String {
        liveCount.keys.sorted().map { "\($0)=\(liveCount[$0, default: 0])" }.joined(separator: " ")
            + " bytes=\(totalBytes)"
    }
}

@MainActor
@Suite(.serialized) struct StressCycleTests {
    /// The number of cycles.
    static let cycles = 50

    /// The kind index of Mix in `NodeKind.allCases` (the `node.add` value).
    static let mixKind = 4

    /// The example of cycle `k` (from 1): the menu's examples in turn, starting with the journey `mixed-clouds`.
    static func example(ofCycle k: Int) -> LabExample {
        LabExamples.all[(k + 1) % LabExamples.all.count]
    }

    /// The first cycle showing the same example as cycle `k` (1, 2 or 3).
    static func firstCycle(like k: Int) -> Int {
        (k - 1) % LabExamples.all.count + 1
    }

    /// Adds a Mix, connects the first image node of the open graph into its input `a`, disconnects it and removes the
    /// Mix, each through the port; the graph is the same as before by its fingerprint.
    static func editMix(_ shell: ExperienceShell<LabPresenter>, cycle k: Int) throws {
        let graph = try LabTest.core(shell).graph
        let before = LabLibraryTest.fingerprint(graph)
        let images: Set<NodeKind> = [.noise, .gradient, .mix, .blur]
        let firstImage = graph.nodes.first(where: { images.contains($0.kind) })
        let source = try #require(firstImage, "cycle \(k): an image node")
        let used = Set(graph.nodes.map { $0.id.rawValue })
        let mix = (1...GraphLimits.maxNodes + 1).first(where: { !used.contains($0) }) ?? 1
        LabTest.accept(shell, "node.add", [Double(mixKind), 600, 420])
        let added = try LabTest.core(shell).graph.node(NodeID(mix))
        #expect(added?.kind == .mix, "cycle \(k): the Mix is node \(mix)")
        LabTest.accept(shell, "edge.connect", [Double(source.id.rawValue), 0, Double(mix), 0])
        LabTest.accept(shell, "edge.disconnect", [Double(mix), 0])
        LabTest.accept(shell, "node.remove", [Double(mix)])
        let after = LabLibraryTest.fingerprint(try LabTest.core(shell).graph)
        #expect(after == before, "cycle \(k): the edits leave the graph as it was")
    }

    /// Runs cycle `k` (see the file header) and returns the level after it.
    static func cycle(_ k: Int, session: ExperienceSession, shell: ExperienceShell<LabPresenter>) throws -> LabLevel {
        let presenter = shell.presenter
        let host = try #require(session.renderHost)
        try editMix(shell, cycle: k)

        let example = Self.example(ofCycle: k)
        let opened = presenter.openExample(id: example.id)
        guard case .success = opened else {
            Issue.record("cycle \(k): \(example.id) did not open: \(opened)")
            return LabLevel(host)
        }
        try LabTest.draw(session)
        let shown = presenter.previewState
        #expect(shown == .ready, "cycle \(k): \(example.id) is drawn (\(shown))")

        let beforeRefusal = LabLevel(host)
        presenter.graphOverride = GraphBuild.fan(6)
        try LabTest.draw(session)
        let refused = presenter.previewState
        #expect(refused == .refused("This graph needs 7 textures; the preview allows 6."), "cycle \(k): \(refused)")
        let afterRefusal = LabLevel(host)
        #expect(afterRefusal == beforeRefusal,
                "cycle \(k): the refusal changed the level: \(afterRefusal.change(since: beforeRefusal))")

        presenter.graphOverride = nil
        try LabTest.draw(session)
        let back = presenter.previewState
        #expect(back == .ready, "cycle \(k): back to \(example.id) (\(back))")

        if k % 10 == 0 {
            host.recreateContext()
            try LabTest.draw(session)
            let rebuilt = presenter.previewState
            #expect(rebuilt == .ready, "cycle \(k): drawn after the rebuild (\(rebuilt))")
        }
        let leaked = host.resources.stats.leaked
        #expect(leaked == 0, "cycle \(k): leaked \(leaked)")
        return LabLevel(host)
    }

    @Test func fiftyMixedCyclesLeaveTheLevelOfTheFirst() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session)
        let presenter = shell.presenter
        let compiles = presenter.pipeline.compileCount
        var levels: [Int: LabLevel] = [:]
        for k in 1...Self.cycles {
            levels[k] = try Self.cycle(k, session: session, shell: shell)
        }
        let first = try #require(levels[1])
        let programs = first.liveCount["program", default: 0]
        let objects = first.objects
        #expect(programs > 0 && objects > 0, "the level counts the live objects (\(first))")
        for k in 2...Self.cycles {
            let reference = Self.firstCycle(like: k)
            guard k != reference, let now = levels[k], let then = levels[reference] else { continue }
            let message = "after cycle \(k) (\(Self.example(ofCycle: k).id)): \(now.change(since: then)) "
                + "against cycle \(reference) (then: \(then); now: \(now))"
            #expect(now == then, Comment(rawValue: message))
        }
        let last = try #require(levels[Self.cycles])
        let second = try #require(levels[2])
        #expect(last == second, "after cycle 50 against cycle 2 (both Clouds): \(last.change(since: second))")
        let journey = try #require(levels[49])
        #expect(journey == first, "after cycle 49 against cycle 1 (both the journey): \(journey.change(since: first))")
        let count = presenter.pipeline.compileCount
        #expect(count == compiles + 3 * Self.cycles, "three compiles per cycle, none from an edit or a rebuild")
        let leaked = try #require(session.renderHost).resources.stats.leaked
        #expect(leaked == 0)
    }
}
