// StressCycleTests — feature 163 (A22-P05) T-A22-502 (FR-A22-501; SC-A22-501; clarification "resource level";
// research R1, R3; contracts/recovery.md "Stress"). Through the one app's session host at 32 × 24: 50 cycles of a new
// source that compiles (a unique constant per cycle), a source that fails to compile and a refused source (a
// `#version` line), each run and drawn once; 20 template changes across all four templates (with a texture choice on
// `texture-mix`); 10 stop-and-reset cycles through the watchdog seam (`feedWatchdog(_:)`). The resource level (the
// registry's `liveCount` for every kind plus `totalBytes`) after the first cycle (the warm-up, which legitimately
// makes the fallback) equals the level after the last, and nothing is reported leaked. Short runs only (no sleep, no
// wall-clock assertion).
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// The resource level of a render host (feature 163, data-model.md "Resource level"): the live object count of every
/// resource kind (keyed by the kind's name) and the live bytes across all kinds.
struct StudioLevel: Equatable, CustomStringConvertible {
    /// Live objects per resource kind, keyed by the kind's name (every kind present).
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

    /// The kinds whose count differs from `earlier` (with the signed change) and the byte change; empty when equal.
    func change(since earlier: StudioLevel) -> String {
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
    /// A source that compiles and draws a flat colour unique to `cycle` (keeps `uniform float u_speed;`, so the
    /// Gradient template's validator accepts it).
    static func uniqueSource(_ cycle: Int, salt: Int = 0) -> String {
        """
        // Stress cycle \(cycle) (\(salt)): a flat colour of its own.
        uniform float u_speed;
        void main() {
            fragColor = vec4(float(\(cycle)) / 64.0, 0.1 * u_speed, float(\(salt)) / 8.0, 1.0);
        }

        """
    }

    /// One normal interval (consumes a pending skip) and then the watchdog's window of slow ones.
    static var stopIntervals: [Double] { [0.03] + Array(repeating: 0.3, count: FrameWatchdog.window) }

    /// Runs one stress cycle: the cycle's unique source (compiled), the broken source (failed) and the refused
    /// source (refused), each drawn once.
    static func cycle(_ k: Int, session: ExperienceSession, shell: ExperienceShell<StudioPresenter>) throws {
        let pipeline = shell.presenter.pipeline
        try StudioTest.run(session, shell, source: uniqueSource(k))
        #expect(pipeline.status == .compiled([]), "cycle \(k): the new source compiled")
        try StudioTest.run(session, shell, source: StudioTest.brokenSource)
        if case .failed = pipeline.status {} else { Issue.record("cycle \(k): the broken source did not fail") }
        try StudioTest.run(session, shell, source: StudioTest.refusedSource)
        if case .refused = pipeline.status {} else { Issue.record("cycle \(k): the #version source was not refused") }
    }

    /// Records an issue naming what grew unless `last` equals `first`, one unless nothing is leaked, and one when
    /// `first` counts no live object (a level that measures nothing).
    static func expectFlat(_ first: StudioLevel, _ last: StudioLevel, host: RenderHost, cycles: Int,
                           trail: [String] = [], sourceLocation: SourceLocation = #_sourceLocation) {
        let along = trail.isEmpty ? "" : "; " + trail.joined(separator: "; ")
        #expect(first.liveCount["program", default: 0] > 0 && first.liveCount.values.reduce(0, +) > 0,
                "the level counts the live scenes' objects (\(first))", sourceLocation: sourceLocation)
        #expect(last == first,
                "after \(cycles) cycles: \(last.change(since: first)) (first: \(first); last: \(last))\(along)",
                sourceLocation: sourceLocation)
        #expect(host.resources.stats.leaked == 0, sourceLocation: sourceLocation)
    }

    @Test func fiftyMixedCyclesLeaveTheLevelOfTheFirst() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let host = try #require(session.renderHost)
        let compiles = shell.presenter.pipeline.compileCount
        try Self.cycle(0, session: session, shell: shell)
        let first = StudioLevel(host)
        var trail: [String] = []   // the change after cycles 2 and 26, so a failure shows the growth per cycle
        for k in 1..<50 {
            try Self.cycle(k, session: session, shell: shell)
            if k == 1 || k == 25 { trail.append("after cycle \(k + 1): \(StudioLevel(host).change(since: first))") }
        }
        let last = StudioLevel(host)
        Self.expectFlat(first, last, host: host, cycles: 50, trail: trail)
        #expect(shell.presenter.pipeline.compileCount == compiles + 100, "two compiles per cycle, none for a refusal")
        #expect(shell.presenter.pipeline.liveProject.source == Self.uniqueSource(49), "the last good source is live")
    }

    @Test func twentyTemplateChangesAcrossAllFourLeaveTheLevelOfTheFirstPass() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let host = try #require(session.renderHost)
        let presenter = shell.presenter
        let count = ShaderTemplates.all.count
        #expect(count == 4)
        let mix = ShaderTemplates.ids.firstIndex(of: "texture-mix") ?? 3
        var first: StudioLevel?
        for change in 0..<20 {
            let template = change % count
            StudioTest.accept(shell, "template.select", [Double(template)])
            try StudioTest.draw(session)
            #expect(presenter.pipeline.liveProject == ShaderTemplates.all[template].project, "change \(change)")
            if template == mix {
                #expect(presenter.pipeline.live is TexturedPreview, "change \(change): texture-mix is textured")
                StudioTest.accept(shell, "texture.set", [0, Double(change % TextureRecipes.all.count)])
                try StudioTest.draw(session)
            }
            if change == count - 1 { first = StudioLevel(host) }   // after the first pass of the four
        }
        let last = StudioLevel(host)
        Self.expectFlat(try #require(first), last, host: host, cycles: 20)
    }

    @Test func tenStopAndResetCyclesLeaveTheLevelOfTheFirst() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let host = try #require(session.renderHost)
        let presenter = shell.presenter
        let gradient = try StudioTest.still(session)
        var first: StudioLevel?
        for k in 0..<10 {
            try StudioTest.run(session, shell, source: Self.uniqueSource(k, salt: 1))
            #expect(presenter.pipeline.status == .compiled([]), "cycle \(k): the run compiled")
            presenter.feedWatchdog(Self.stopIntervals)
            try StudioTest.draw(session)
            #expect(presenter.mirror.stopped, "cycle \(k): the watchdog stopped the preview")
            let compiles = presenter.pipeline.compileCount
            StudioTest.accept(shell, "preview.reset", [1])
            try StudioTest.draw(session)
            #expect(!presenter.mirror.stopped, "cycle \(k): Reset resumed the preview")
            #expect(presenter.pipeline.compileCount == compiles, "cycle \(k): Reset compiled nothing")
            #expect(try StudioTest.still(session) == gradient, "cycle \(k): Reset brought back the fallback")
            if k == 0 { first = StudioLevel(host) }
        }
        let last = StudioLevel(host)
        Self.expectFlat(try #require(first), last, host: host, cycles: 10)
        #expect(try StudioTest.core(shell).resets == 10)
    }
}
