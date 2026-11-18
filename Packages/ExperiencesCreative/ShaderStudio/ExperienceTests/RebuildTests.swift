// RebuildTests — feature 160 (A22-P02) T-A22-207 (FR-A22-206; contracts/experience.md). Through the one app's
// session host: a person's shader that compiled, with a uniform moved, draws the same picture off screen after
// `recreateContext` (the presenter's `setup` runs again and the last good scene is rebuilt) and after a resize of the
// view and back, with no new run compiled and no GPU object leaked. Short runs only.
import CoreGraphics
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct RebuildTests {
    @Test func theLastGoodShaderIsDrawnAgainAfterAContextLossAndAResize() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        StudioTest.accept(shell, "template.select", [2])
        try StudioTest.draw(session)
        StudioTest.accept(shell, "uniform.set", [0, 0.3])
        StudioTest.accept(shell, "uniform.set", [1, 0.7])
        try StudioTest.draw(session)
        try StudioTest.run(session, shell, source: StudioTest.brokenSource.replacingOccurrences(
            of: "u_speed", with: "u_count"))   // a refused run after the good one does not change what is rebuilt
        let live = presenter.pipeline.liveProject
        #expect(live == ShaderTemplates.all[2].project)
        let before = try StudioTest.still(session)
        let setups = presenter.pipeline.setupCount
        let compiles = presenter.pipeline.compileCount

        let host = try #require(session.renderHost)
        host.recreateContext()
        try StudioTest.draw(session)
        #expect(presenter.pipeline.setupCount == setups + 1, "the scene was rebuilt")
        #expect(presenter.pipeline.liveProject == live)
        #expect(try StudioTest.still(session) == before, "the same picture after the context loss")

        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 36)
        view.layoutIfNeeded()
        try StudioTest.draw(session, frames: 2)
        view.frame = CGRect(x: 0, y: 0, width: 32, height: 24)
        view.layoutIfNeeded()
        try StudioTest.draw(session)
        #expect(try StudioTest.still(session) == before, "the same picture after the resize")
        #expect(presenter.pipeline.compileCount == compiles, "no run was compiled again")
        #expect(host.resources.stats.leaked == 0)
    }
}
