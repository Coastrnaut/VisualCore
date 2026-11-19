// HostCountTests — feature 173 (A24-P01) T-A24-110 (SC-A24-105; FR-A24-107; User Story 5; clarification Q5). A
// `RenderScene` on `RenderHost(scene:)` validates every built-in case, summarises every fixture and encodes a run in
// `setup` and in `render`, with the host's context current, and the host's resource level (`ResourceRegistry.stats`:
// `liveCount` for every kind and `totalBytes`) is the same before and after each pass, right after the host is up and
// after rendered frames. Each result inside the host equals the result outside it. The scene draws nothing and issues
// no GL call; the host only clears the frame. The fixtures are read from the bundle before the host starts, so the
// callbacks do no file work.
import Foundation
import Testing
import UIKit
import VisualCoreRendering
import GraphicsBenchmarkLabCore

/// A host's resource level: live objects per resource kind (keyed by the kind's name, every kind present) and live
/// bytes across all kinds.
struct BenchmarkHostLevel: Equatable, CustomStringConvertible {
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

/// The core work of one pass: every built-in case validated, every fixture summarised, one run encoded.
struct BenchmarkCoreWork: Equatable {
    /// How many built-in cases validated.
    let validatedCases: Int
    /// The summary of each fixture, in the order given.
    let summaries: [Summary]
    /// The encoded run file.
    let encodedRun: Data

    /// Does the work over `fixtures`; the run is the first built-in case with the samples of the first fixture.
    static func perform(_ fixtures: [NamedFixture]) throws -> BenchmarkCoreWork {
        var validated = 0
        for benchmarkCase in BenchmarkCase.builtIn {
            try benchmarkCase.validate()
            validated += 1
        }
        var summaries: [Summary] = []
        for named in fixtures { summaries.append(try Summary.make(named.fixture.samples)) }
        guard let benchmarkCase = BenchmarkCase.builtIn.first, let first = fixtures.first,
              let summary = summaries.first else {
            return BenchmarkCoreWork(validatedCases: validated, summaries: summaries, encodedRun: Data())
        }
        let run = try BenchmarkRun(benchmarkCase: benchmarkCase, samples: first.fixture.samples, summary: summary,
                                   state: .completed)
        return BenchmarkCoreWork(validatedCases: validated, summaries: summaries, encodedRun: try RunDocument.encode(run))
    }
}

/// A render scene that does the core work in `setup` and in every `render`, recording the results and the resource
/// level around each pass. It creates no resource and draws nothing.
@MainActor
final class BenchmarkCoreScene: RenderScene {
    /// One pass inside a host callback: the level before, the work, the level after.
    struct Pass {
        /// "setup" or "render <frame index>".
        let callback: String
        /// The level when the callback began.
        let before: BenchmarkHostLevel
        /// The work done in the callback.
        let work: BenchmarkCoreWork
        /// The level after the work.
        let after: BenchmarkHostLevel
    }

    /// The fixtures to summarise, loaded before the host starts.
    private let fixtures: [NamedFixture]
    /// Every pass, in callback order.
    private(set) var passes: [Pass] = []

    /// A scene over `fixtures`.
    init(fixtures: [NamedFixture]) { self.fixtures = fixtures }

    private func workAll(_ context: RenderContext, callback: String) throws {
        let before = BenchmarkHostLevel(context.resources)
        let work = try BenchmarkCoreWork.perform(fixtures)
        passes.append(Pass(callback: callback, before: before, work: work, after: BenchmarkHostLevel(context.resources)))
    }

    func setup(_ context: RenderContext) throws { try workAll(context, callback: "setup") }

    func resize(_ context: RenderContext) {}

    /// Does the core work again and draws nothing (the host clears the frame).
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        try workAll(context, callback: "render \(frame.index)")
    }

    func teardown(_ context: RenderContext) {}
}

@MainActor
@Suite(.serialized) struct HostCountTests {
    @Test func theCoreWorkInsideTheHostCreatesNoGraphicsResource() throws {
        let fixtures = try SampleFixtures.all()
        let outside = try BenchmarkCoreWork.perform(fixtures)
        let caseCount = BenchmarkCase.builtIn.count
        #expect(outside.validatedCases == caseCount)
        #expect(caseCount == 3)
        #expect(outside.summaries.count == SampleFixtures.names.count, "every fixture is summarised")
        #expect(!outside.encodedRun.isEmpty)

        let scene = BenchmarkCoreScene(fixtures: fixtures)
        let host = try RenderHost(scene: scene)
        defer { host.destroy() }
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 12)
        host.view.layoutIfNeeded()
        let up = BenchmarkHostLevel(host.resources)
        #expect(!up.liveCount.isEmpty, "the level lists every resource kind (\(up))")

        let first = host.renderOneFrame(present: false)
        let afterFirst = BenchmarkHostLevel(host.resources)
        let second = host.renderOneFrame(present: false)
        let afterSecond = BenchmarkHostLevel(host.resources)
        #expect(first && second, "the host rendered two frames")
        #expect(afterFirst == up, "after the first frame: \(afterFirst) (up: \(up))")
        #expect(afterSecond == up, "after the second frame: \(afterSecond) (up: \(up))")

        let passes = scene.passes
        let callbacks = passes.map { $0.callback }
        #expect(callbacks.first == "setup")
        let renders = callbacks.filter { $0.hasPrefix("render") }
        #expect(renders.count == 2, "two rendered frames: \(callbacks)")
        for pass in passes {
            #expect(pass.after == pass.before, "\(pass.callback): \(pass.after) (before: \(pass.before))")
            #expect(pass.after == up, "\(pass.callback): \(pass.after) (up: \(up))")
            #expect(pass.work == outside, "\(pass.callback): the work inside the host equals the work outside")
        }
    }
}
