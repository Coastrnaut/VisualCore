// WatchdogTests — feature 162 (A22-P04) T-A22-407 (FR-A22-403, FR-A22-404; SC-A22-402; US2 AC1–AC4; clarifications
// Q2, Q3; contracts/limits.md "Watchdog", "Reset"). Through the one app's session host, with drawn-frame intervals
// injected through the presenter's `feedWatchdog(_:)` seam (no slow frame is drawn): eight slow intervals stop the
// preview and the read-back is the flat stopped colour; normal intervals, or slow ones broken by a normal one, never
// stop it; Reset brings back the fallback's picture with no compile; with no fallback Reset queues the template's
// starter; a Run while stopped draws again and does not keep the stopped scene as the fallback; a context loss while
// stopped stays stopped and rebuilds the fallback; an A22-P03 snapshot without `resets` restores with 0. Short runs
// only.
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct WatchdogTests {
    /// One normal interval (consumes a pending skip) and then `count` slow ones.
    static func slow(_ count: Int) -> [Double] { [0.03] + Array(repeating: 0.3, count: count) }

    /// Whether every pixel of `still` is the stopped colour (0.05, 0.05, 0.07), within one step.
    static func isStoppedColour(_ still: [UInt8]) -> Bool {
        let expected = PreviewPipeline.stoppedColor
        let bytes = [expected.x, expected.y, expected.z].map { Int(($0 * 255).rounded()) }
        return !still.isEmpty && stride(from: 0, to: still.count, by: 4).allSatisfy { i in
            (0..<3).allSatisfy { abs(Int(still[i + $0]) - bytes[$0]) <= 1 }
        }
    }

    @Test func eightSlowIntervalsStopThePreviewAndTheFrameIsFlat() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let compiles = presenter.pipeline.compileCount
        presenter.feedWatchdog(Self.slow(FrameWatchdog.window - 1))
        #expect(!presenter.mirror.stopped, "seven slow intervals do not stop it")
        presenter.feedWatchdog([0.3])
        #expect(presenter.mirror.stopped && presenter.mirror.status == StudioPresenter.stoppedStatus)
        #expect(presenter.mirror.guidance == StudioPresenter.stoppedGuidance)
        #expect(StudioControls.labels(presenter.mirror).contains { $0.name == "preview-reset" })
        #expect(presenter.describe(try StudioTest.core(shell)).hasSuffix(StudioPresenter.stoppedStatus))
        try StudioTest.draw(session, frames: 2)
        #expect(presenter.mirror.stopped, "normal frames after the stop do not resume it")
        #expect(Self.isStoppedColour(try StudioTest.still(session)), "no frame of the shader is drawn")
        #expect(presenter.pipeline.compileCount == compiles)
    }

    @Test func normalIntervalsNeverStopIt() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        var intervals: [Double] = []
        for k in 0..<120 { intervals.append(k % 5 == 4 ? 0.4 : 0.033) }
        presenter.feedWatchdog(intervals + [0.033])
        presenter.feedWatchdog(Array(repeating: 0.3, count: 7) + [0.03] + Array(repeating: 0.3, count: 7))
        presenter.feedWatchdog([.nan, .infinity, 0, -1])
        #expect(!presenter.mirror.stopped && presenter.watchdog.state == .watching)
        try StudioTest.draw(session, frames: 3)
        #expect(!Self.isStoppedColour(try StudioTest.still(session)))
        #expect(!StudioControls.labels(presenter.mirror).contains { $0.name == "preview-reset" })
    }

    @Test func resetBringsBackTheFallbackWithNoCompile() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let host = try #require(session.renderHost)
        let gradient = try StudioTest.still(session)
        try StudioTest.run(session, shell, source: StudioTest.fixedSource)
        #expect(presenter.pipeline.fallbackProject == ShaderTemplates.all[0].project, "the previous live scene is kept")
        #expect(StudioTest.differs(gradient, try StudioTest.still(session)))
        presenter.feedWatchdog(Self.slow(FrameWatchdog.window))
        try StudioTest.draw(session)
        #expect(Self.isStoppedColour(try StudioTest.still(session)))
        let compiles = presenter.pipeline.compileCount, programs = host.resources.compileCount

        StudioTest.accept(shell, "preview.reset", [1])
        #expect(try StudioTest.core(shell).resets == 1)
        try StudioTest.draw(session)
        #expect(!presenter.mirror.stopped && presenter.mirror.status == "Compiled")
        #expect(try StudioTest.still(session) == gradient, "the fallback's picture")
        #expect(presenter.pipeline.compileCount == compiles && host.resources.compileCount == programs, "no compile")
        #expect(presenter.pipeline.fallback == nil && presenter.mirror.source == StudioTest.fixedSource,
                "the editor keeps the document")
        #expect(host.resources.stats.leaked == 0)
    }

    @Test func withNoFallbackResetQueuesTheStarter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let first = try StudioTest.still(session)
        #expect(presenter.pipeline.fallback == nil)
        presenter.feedWatchdog(Self.slow(FrameWatchdog.window))
        try StudioTest.draw(session)
        let compiles = presenter.pipeline.compileCount
        StudioTest.accept(shell, "preview.reset", [1])
        try StudioTest.draw(session)
        #expect(presenter.pipeline.compileCount == compiles + 1, "the starter was queued and run at the frame")
        #expect(presenter.pipeline.liveProject == ShaderTemplates.all[0].project)
        #expect(!presenter.mirror.stopped)
        #expect(try StudioTest.still(session) == first)
    }

    @Test func aRunWhileStoppedDrawsAgainAndDropsTheStoppedScene() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        presenter.feedWatchdog(Self.slow(FrameWatchdog.window))
        try StudioTest.draw(session)
        try StudioTest.run(session, shell, source: StudioTest.fixedSource)
        #expect(!presenter.mirror.stopped && presenter.mirror.status == "Compiled")
        #expect(presenter.pipeline.fallback == nil, "the stopped scene is not a fallback")
        #expect(!Self.isStoppedColour(try StudioTest.still(session)))
        #expect(try #require(session.renderHost).resources.stats.leaked == 0)
    }

    @Test func aContextLossWhileStoppedStaysStoppedAndRebuildsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let gradient = try StudioTest.still(session)
        try StudioTest.run(session, shell, source: StudioTest.fixedSource)
        presenter.feedWatchdog(Self.slow(FrameWatchdog.window))
        try StudioTest.draw(session)
        let host = try #require(session.renderHost)
        host.recreateContext()
        try StudioTest.draw(session, frames: 2)
        #expect(presenter.mirror.stopped, "still stopped after the context loss")
        #expect(Self.isStoppedColour(try StudioTest.still(session)))
        #expect(presenter.pipeline.fallback != nil, "the fallback was rebuilt from its source")
        #expect(host.resources.stats.leaked == 0)
        StudioTest.accept(shell, "preview.reset", [1])
        try StudioTest.draw(session)
        #expect(try StudioTest.still(session) == gradient)
    }

    @Test func snapshotsWithoutResetsRestoreWithZero() throws {
        let zeros = Array(repeating: "0", count: 15).joined(separator: ",")
        let old = #"{"runs":2,"template":0,"textures":[1,2],"values":[0.25,\#(zeros)]}"#
        let restored = try StudioCore.restore(payload: Data(old.utf8), seed: 1)
        #expect(restored.resets == 0 && restored.textures == [1, 2] && restored.runs == 2)

        var core = StudioCore()
        #expect(core.apply(ExperienceAction(control: "preview.reset", values: [1], step: 0)) == .accepted)
        #expect(core.resets == 1)
        let back = try StudioCore.restore(payload: core.snapshotPayload(), seed: 1)
        #expect(back == core)
        #expect(try studioDigest(core) != studioDigest(StudioCore()), "the digest covers the resets")
        #expect(core.apply(ExperienceAction(control: "preview.reset", values: [0], step: 0)) != .accepted)
    }
}
