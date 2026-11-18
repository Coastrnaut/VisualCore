// RecoveryTests — feature 163 (A22-P05) T-A22-504 (FR-A22-502; SC-A22-502; US2; edge case "a cycle that ends while a
// compile is queued"; contracts/recovery.md "Recovery"). Through the one app's session host at 32 × 24: in each of the
// states running, failed (a broken compile with a last good shader), refused, stopped (the watchdog seam) and
// textured (`texture-mix` with a texture choice), 10 `recreateContext` calls, each followed by a frame, give a
// byte-identical off-screen still (`StudioTest.still`, frame time 0), an unchanged resource level (`StudioLevel`:
// `liveCount` for every kind plus `totalBytes`), the same status, no compile and `leaked` 0. A request waiting in the
// pipeline, and a Run accepted but not yet drawn, are dropped by the rebuild's teardown: no compile, the same level.
// Short runs only (no sleep, no wall-clock assertion).
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct RecoveryTests {
    /// The state the studio is put in before the rebuilds.
    enum State: String, CaseIterable {
        case running, failed, refused, stopped, textured
    }

    /// Puts the studio opened in `session` into `state`.
    static func enter(_ state: State, session: ExperienceSession, shell: ExperienceShell<StudioPresenter>) throws {
        let presenter = shell.presenter
        switch state {
        case .running:
            try StudioTest.run(session, shell, source: StudioTest.fixedSource)
            #expect(presenter.pipeline.status == .compiled([]))
        case .failed:
            try StudioTest.run(session, shell, source: StudioTest.fixedSource)
            try StudioTest.run(session, shell, source: StudioTest.brokenSource)
            if case .failed = presenter.pipeline.status {} else { Issue.record("the broken source did not fail") }
            #expect(presenter.pipeline.liveProject.source == StudioTest.fixedSource, "the last good shader is live")
        case .refused:
            try StudioTest.run(session, shell, source: StudioTest.fixedSource)
            try StudioTest.run(session, shell, source: StudioTest.refusedSource)
            if case .refused = presenter.pipeline.status {} else { Issue.record("the #version source was not refused") }
        case .stopped:
            try StudioTest.run(session, shell, source: StudioTest.fixedSource)
            presenter.feedWatchdog([0.03] + Array(repeating: 0.3, count: FrameWatchdog.window))
            try StudioTest.draw(session)
            #expect(presenter.mirror.stopped)
        case .textured:
            let mix = ShaderTemplates.ids.firstIndex(of: "texture-mix") ?? 3
            StudioTest.accept(shell, "template.select", [Double(mix)])
            try StudioTest.draw(session)
            StudioTest.accept(shell, "texture.set", [1, 2])
            try StudioTest.draw(session)
            #expect(presenter.pipeline.live is TexturedPreview)
        }
    }

    /// Opens the studio, enters `state`, then rebuilds the context 10 times, each followed by a frame, and records an
    /// issue for any change of the still, the level, the status, the stopped flag or the compile count, or a leak.
    static func rebuildTenTimes(in state: State) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        try enter(state, session: session, shell: shell)
        let host = try #require(session.renderHost)
        let still = try StudioTest.still(session)
        let level = StudioLevel(host)
        let status = presenter.pipeline.status
        let stopped = presenter.mirror.stopped
        let compiles = presenter.pipeline.compileCount, programs = host.resources.compileCount
        let live = presenter.pipeline.liveProject
        for rebuild in 1...10 {
            host.recreateContext()
            try StudioTest.draw(session)
            let label = "\(state), rebuild \(rebuild)"
            #expect(try StudioTest.still(session) == still, "\(label): the same picture")
            let now = StudioLevel(host)
            #expect(now == level, "\(label): \(now.change(since: level)) (before: \(level); now: \(now))")
            #expect(host.resources.stats.leaked == 0, "\(label): leaked \(host.resources.stats.leaked)")
            #expect(presenter.pipeline.status == status, "\(label): the status")
            #expect(presenter.mirror.stopped == stopped, "\(label): the stopped flag")
            #expect(presenter.pipeline.liveProject == live, "\(label): the live project")
            #expect(presenter.pipeline.compileCount == compiles, "\(label): no run compiled")
            #expect(presenter.pipeline.setupCount >= rebuild, "\(label): the scene was rebuilt")
        }
        #expect(host.resources.compileCount >= programs, "the rebuilt programs were compiled again in the new context")
    }

    @Test func tenRebuildsWhileRunning() async throws { try await Self.rebuildTenTimes(in: .running) }

    @Test func tenRebuildsAfterAFailedCompile() async throws { try await Self.rebuildTenTimes(in: .failed) }

    @Test func tenRebuildsAfterARefusal() async throws { try await Self.rebuildTenTimes(in: .refused) }

    @Test func tenRebuildsWhileStopped() async throws { try await Self.rebuildTenTimes(in: .stopped) }

    @Test func tenRebuildsWhileTextured() async throws { try await Self.rebuildTenTimes(in: .textured) }

    @Test func aRequestWaitingInThePipelineIsDroppedByARebuild() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let host = try #require(session.renderHost)
        try StudioTest.run(session, shell, source: StudioTest.fixedSource)
        let still = try StudioTest.still(session)
        let level = StudioLevel(host)
        let compiles = presenter.pipeline.compileCount
        #expect(presenter.setSource(StressCycleTests.uniqueSource(7, salt: 3)))
        presenter.pipeline.submit(presenter.document)   // the seam of A22-P02 RunQueueTests
        #expect(presenter.pipeline.pending != nil)
        host.recreateContext()
        #expect(presenter.pipeline.pending == nil, "the rebuild's teardown dropped the request")
        try StudioTest.draw(session)
        #expect(presenter.pipeline.compileCount == compiles, "no compile")
        #expect(presenter.pipeline.liveProject.source == StudioTest.fixedSource)
        #expect(try StudioTest.still(session) == still)
        let now = StudioLevel(host)
        #expect(now == level, "\(now.change(since: level)) (before: \(level); now: \(now))")
        #expect(host.resources.stats.leaked == 0)
    }

    /// A Run the core accepted before a rebuild is the person's request and the core has counted it (`runs`), so it
    /// compiles once at the first frame after the rebuild (decision at T-A22-504; only a request already waiting
    /// inside the pipeline is dropped by the teardown, as above). Nothing leaks.
    @Test func aRunAcceptedBeforeARebuildCompilesOnceAfterIt() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let host = try #require(session.renderHost)
        try StudioTest.run(session, shell, source: StudioTest.fixedSource)
        let level = StudioLevel(host)
        let compiles = presenter.pipeline.compileCount
        let next = StressCycleTests.uniqueSource(8, salt: 3)
        #expect(presenter.setSource(next))
        StudioTest.accept(shell, "shader.run", [1])   // accepted: the presenter submits it at the next frame
        host.recreateContext()                        // before that frame
        try StudioTest.draw(session)
        #expect(presenter.pipeline.compileCount == compiles + 1, "the accepted Run compiled once after the rebuild")
        #expect(presenter.pipeline.liveProject.source == next, "the requested shader is live")
        try StudioTest.draw(session)
        #expect(presenter.pipeline.compileCount == compiles + 1, "and only once")
        let now = StudioLevel(host)
        #expect(now == level, "\(now.change(since: level)) (before: \(level); now: \(now))")
        #expect(host.resources.stats.leaked == 0)
    }
}
