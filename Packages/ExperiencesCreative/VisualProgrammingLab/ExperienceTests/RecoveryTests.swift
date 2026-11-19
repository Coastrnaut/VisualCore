// RecoveryTests — feature 170 (A23-P05) T-A23-504 (FR-A23-503; SC-A23-503, SC-A23-506; clarification Q3; User Story
// 3; research D3; Edge Case "A rebuild while a compile is waiting"). Through the one app's session host: in each of
// the preview states ready (the starter graph), invalid (the Output disconnected through the port), refused (a graph
// of 7 slots through `graphOverride`), failed (the Noise program's text replaced through the pipeline's
// `fragmentOverrides`, then a rebuild, as PreviewStateTests does) and hidden (the preview switched off), 10
// `recreateContext` calls, each followed by a frame, give a byte-identical off-screen still (frame time 0.5), the same
// preview and pipeline state, schedule and slot count, no compile, the same resource level (`LabLevel`: `liveCount` of
// every kind plus `totalBytes`) and `leaked` 0. An edit sent just before a rebuild compiles exactly once, at the first
// frame after it. Short runs only (no sleep, no wall-clock assertion).
import CoreGraphics
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct RecoveryTests {
    /// The side of the stills: 96 pixels (a 32-pixel inset).
    static let side = 96

    /// The state the preview is put in before the rebuilds.
    enum State: String, CaseIterable, Sendable {
        case ready, invalid, refused, failed, hidden
    }

    /// A Noise text that does not build (an undefined symbol).
    static let brokenNoise = """
    precision highp float;
    out vec4 color;
    void main() { color = vec4(undefinedSymbol, 1.0); }
    """

    /// Puts the preview of the starter graph opened in `session` into `state`.
    static func enter(_ state: State, session: ExperienceSession, shell: ExperienceShell<LabPresenter>) throws {
        let presenter = shell.presenter
        switch state {
        case .ready:
            try LabTest.draw(session)
            let now = presenter.previewState
            #expect(now == .ready, "\(now)")
        case .invalid:
            LabTest.accept(shell, "edge.disconnect", [2, 0])
            try LabTest.draw(session)
            let now = presenter.previewState
            #expect(now == .invalid("Output not connected"), "\(now)")
        case .refused:
            presenter.graphOverride = GraphBuild.fan(6)
            try LabTest.draw(session)
            let now = presenter.previewState
            #expect(now == .refused("This graph needs 7 textures; the preview allows 6."), "\(now)")
        case .failed:
            presenter.pipeline.fragmentOverrides["noise"] = brokenNoise
            try #require(session.renderHost).recreateContext()
            try LabTest.draw(session)
            let now = presenter.previewState
            if case .failed = now {} else { Issue.record("expected failed, got \(now)") }
        case .hidden:
            presenter.setPreviewVisible(false)
            try LabTest.draw(session)
            let now = presenter.previewState
            #expect(now == .hidden, "\(now)")
        }
    }

    /// Opens the starter graph with the preview shown, enters `state`, then rebuilds the context 10 times, each
    /// followed by a frame, and records an issue for any change of the still, the states, the schedule, the slots,
    /// the compile count or the level, or a leak.
    static func rebuildTenTimes(in state: State) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session)
        let presenter = shell.presenter
        let pipeline = presenter.pipeline
        try enter(state, session: session, shell: shell)
        let host = try #require(session.renderHost)
        let still = try LabTest.still(session, width: Self.side, height: Self.side, time: 0.5)
        let level = LabLevel(host)
        let preview = presenter.previewState
        let pipelineState = pipeline.state
        let schedule = pipeline.schedule
        let slots = pipeline.slots.count
        let compiles = pipeline.compileCount
        let objects = level.objects
        #expect(objects > 0, "\(state): the level counts the live objects (\(level))")
        for rebuild in 1...10 {
            host.recreateContext()
            try LabTest.draw(session)
            let label = "\(state), rebuild \(rebuild)"
            let now = try LabTest.still(session, width: Self.side, height: Self.side, time: 0.5)
            #expect(now == still, "\(label): the same picture")
            let nowLevel = LabLevel(host)
            #expect(nowLevel == level, "\(label): \(nowLevel.change(since: level)) (before: \(level); now: \(nowLevel))")
            let leaked = host.resources.stats.leaked
            #expect(leaked == 0, "\(label): leaked \(leaked)")
            let nowPreview = presenter.previewState
            #expect(nowPreview == preview, "\(label): the preview state (\(nowPreview))")
            let nowPipeline = pipeline.state
            #expect(nowPipeline == pipelineState, "\(label): the pipeline state (\(nowPipeline))")
            let nowSchedule = pipeline.schedule
            #expect(nowSchedule == schedule, "\(label): the schedule")
            let nowSlots = pipeline.slots.count
            #expect(nowSlots == slots, "\(label): \(nowSlots) slots")
            let nowCompiles = pipeline.compileCount
            #expect(nowCompiles == compiles, "\(label): no compile")
        }
    }

    @Test func tenRebuildsWhileReady() async throws { try await Self.rebuildTenTimes(in: .ready) }

    @Test func tenRebuildsWhileInvalid() async throws { try await Self.rebuildTenTimes(in: .invalid) }

    @Test func tenRebuildsWhileRefused() async throws { try await Self.rebuildTenTimes(in: .refused) }

    @Test func tenRebuildsWhileFailed() async throws { try await Self.rebuildTenTimes(in: .failed) }

    @Test func tenRebuildsWhileHidden() async throws { try await Self.rebuildTenTimes(in: .hidden) }

    @Test func anEditBeforeARebuildCompilesOnceAtTheFirstFrameAfterIt() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session)
        let presenter = shell.presenter
        let pipeline = presenter.pipeline
        let host = try #require(session.renderHost)
        let ready = presenter.previewState
        #expect(ready == .ready)
        let compiles = pipeline.compileCount
        // Gradient (kind 3) into the Output's place: Noise 1 off the Output, Gradient 3 into it.
        LabTest.accept(shell, "node.add", [3, 40, 300])
        LabTest.accept(shell, "edge.disconnect", [2, 0])
        LabTest.accept(shell, "edge.connect", [3, 0, 2, 0])
        let queued = pipeline.compileCount
        #expect(queued == compiles, "an edit compiles nothing by itself")
        host.recreateContext()
        let rebuilt = pipeline.compileCount
        #expect(rebuilt == compiles, "the rebuild restores the old schedule without a compile")
        try LabTest.draw(session)
        let first = pipeline.compileCount
        #expect(first == compiles + 1, "the edit compiles once at the first frame after the rebuild")
        let state = presenter.previewState
        #expect(state == .ready, "\(state)")
        let operators = pipeline.schedule?.passes.map { $0.operator } ?? []
        #expect(operators == [.gradient, .output], "the edited graph is drawn")
        try LabTest.draw(session, frames: 2)
        let later = pipeline.compileCount
        #expect(later == compiles + 1, "and never again")
        let level = LabLevel(host)
        host.recreateContext()
        try LabTest.draw(session)
        let after = LabLevel(host)
        #expect(after == level, "\(after.change(since: level))")
        let leaked = host.resources.stats.leaked
        #expect(leaked == 0)
    }
}
