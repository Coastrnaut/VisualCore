// HostCountTests — feature 166 (A23-P01) T-A23-108 (SC-A23-105; FR-A23-107; User Story 5; clarification Q5). A
// `RenderScene` on `RenderHost(scene:)` checks every fixture of `GraphFixtures.all` in `setup` and in `render`, with
// the host's context current, and the host's resource level (`ResourceRegistry.stats`: `liveCount` for every kind and
// `totalBytes`) is the same before and after each check pass, right after the host is up and after rendered frames.
// Each result inside the host equals the result of checking the graph outside it. The scene draws nothing and issues
// no GL call (`scripts/check_app_isolation.py`); the host only clears the frame.
import Testing
import UIKit
import VisualCoreRendering
import VisualProgrammingLabCore

/// A host's resource level: live objects per resource kind (keyed by the kind's name, every kind present) and live
/// bytes across all kinds.
struct GraphHostLevel: Equatable, CustomStringConvertible {
    /// Live objects per resource kind, keyed by the kind's name.
    var liveCount: [String: Int]
    /// Live bytes across all kinds.
    var totalBytes: Int

    /// The level of `registry` now.
    @MainActor
    init(_ registry: ResourceRegistry) {
        let stats = registry.stats
        var counts: [String: Int] = [:]
        for (kind, count) in stats.liveCount { counts[String(describing: kind)] = count }
        liveCount = counts
        totalBytes = stats.totalBytes
    }

    /// "kind=n …, bytes=n", in kind-name order.
    var description: String {
        liveCount.keys.sorted().map { "\($0)=\(liveCount[$0, default: 0])" }.joined(separator: " ")
            + " bytes=\(totalBytes)"
    }
}

/// A render scene that checks every fixture graph in `setup` and in every `render`, recording the results and the
/// resource level around each pass. It creates no resource and draws nothing.
@MainActor
final class GraphCheckScene: RenderScene {
    /// One check pass inside a host callback: the level before, the results, the level after.
    struct Pass {
        /// "setup" or "render <frame index>".
        let callback: String
        /// The level when the callback began.
        let before: GraphHostLevel
        /// The result of each fixture, in `GraphFixtures.all` order.
        let results: [CheckResult]
        /// The level after every fixture was checked.
        let after: GraphHostLevel
    }

    /// Every pass, in callback order.
    private(set) var passes: [Pass] = []

    private func checkAll(_ context: RenderContext, callback: String) {
        let before = GraphHostLevel(context.resources)
        let results = GraphFixtures.all.map { GraphChecker.check($0.graph) }
        passes.append(Pass(callback: callback, before: before, results: results, after: GraphHostLevel(context.resources)))
    }

    func setup(_ context: RenderContext) throws { checkAll(context, callback: "setup") }

    func resize(_ context: RenderContext) {}

    /// Checks every fixture again and draws nothing (the host clears the frame).
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        checkAll(context, callback: "render \(frame.index)")
    }

    func teardown(_ context: RenderContext) {}
}

@MainActor
@Suite(.serialized) struct HostCountTests {
    @Test func checkingEveryFixtureInsideTheHostCreatesNoGraphicsResource() throws {
        let outside = GraphFixtures.all.map { GraphChecker.check($0.graph) }
        #expect(outside.count == GraphFixtures.all.count)
        #expect(GraphFixtures.all.count >= 50, "every fixture is checked (\(GraphFixtures.all.count))")

        let scene = GraphCheckScene()
        let host = try RenderHost(scene: scene)
        defer { host.destroy() }
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 12)
        host.view.layoutIfNeeded()
        let up = GraphHostLevel(host.resources)
        #expect(!up.liveCount.isEmpty, "the level lists every resource kind (\(up))")

        let first = host.renderOneFrame(present: false)
        let afterFirst = GraphHostLevel(host.resources)
        let second = host.renderOneFrame(present: false)
        let afterSecond = GraphHostLevel(host.resources)
        #expect(first && second, "the host rendered two frames")
        #expect(afterFirst == up, "after the first frame: \(afterFirst) (up: \(up))")
        #expect(afterSecond == up, "after the second frame: \(afterSecond) (up: \(up))")

        let passes = scene.passes
        #expect(passes.first?.callback == "setup")
        let renders = passes.filter { $0.callback.hasPrefix("render") }
        #expect(renders.count == 2, "two rendered frames: \(passes.map(\.callback))")
        for pass in passes {
            #expect(pass.after == pass.before, "\(pass.callback): \(pass.after) (before: \(pass.before))")
            #expect(pass.after == up, "\(pass.callback): \(pass.after) (up: \(up))")
            #expect(pass.results.count == outside.count)
            for (index, result) in pass.results.enumerated() where index < outside.count {
                #expect(result == outside[index], "\(pass.callback): \(GraphFixtures.all[index].name)")
            }
        }
    }
}
