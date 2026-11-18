// RunQueueTests — feature 160 (A22-P02) T-A22-206 (FR-A22-203; SC-A22-203; clarification Q2; edge cases). Through
// the one app's session host: three runs before one frame give one compile (of the newest source); an action alone
// compiles nothing; a template switch while a run waits compiles the new template; closing with a run waiting
// compiles nothing. Short runs only.
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct RunQueueTests {
    @Test func threeRunsBeforeAFrameGiveOneCompileOfTheNewestSource() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let compiles = presenter.pipeline.compileCount
        #expect(presenter.setSource(StudioTest.brokenSource))
        StudioTest.accept(shell, "shader.run", [1])
        #expect(presenter.setSource(StudioTest.refusedSource))
        StudioTest.accept(shell, "shader.run", [1])
        #expect(presenter.setSource(StudioTest.fixedSource))
        StudioTest.accept(shell, "shader.run", [1])
        #expect(presenter.pipeline.compileCount == compiles, "an action compiles nothing")
        try StudioTest.draw(session)
        #expect(presenter.pipeline.compileCount == compiles + 1)
        #expect(presenter.pipeline.status == .compiled([]))
        #expect(presenter.pipeline.liveProject.source == StudioTest.fixedSource, "the newest source")
        try StudioTest.draw(session, frames: 3)
        #expect(presenter.pipeline.compileCount == compiles + 1, "nothing more to compile")
    }

    @Test func setSourceAloneNeverCompiles() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let compiles = presenter.pipeline.compileCount
        #expect(presenter.setSource(StudioTest.fixedSource))
        try StudioTest.draw(session, frames: 2)
        #expect(presenter.pipeline.compileCount == compiles)
        #expect(presenter.pipeline.liveProject == ShaderTemplates.all[0].project)
    }

    @Test func aTemplateSwitchWhileARunWaitsCompilesTheNewTemplate() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let compiles = presenter.pipeline.compileCount
        #expect(presenter.setSource(StudioTest.fixedSource))
        StudioTest.accept(shell, "shader.run", [1])
        StudioTest.accept(shell, "template.select", [2])
        try StudioTest.draw(session)
        #expect(presenter.pipeline.compileCount == compiles + 1)
        #expect(presenter.pipeline.liveProject == ShaderTemplates.all[2].project)
        #expect(presenter.document == ShaderTemplates.all[2].project)
        #expect(presenter.pipeline.status == .compiled([]))
    }

    @Test func closingWithARunWaitingCompilesNothing() async throws {
        let session = ExperienceSession()
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let compiles = presenter.pipeline.compileCount
        #expect(presenter.setSource(StudioTest.fixedSource))
        StudioTest.accept(shell, "shader.run", [1])
        presenter.pipeline.submit(presenter.document)
        #expect(presenter.pipeline.pending != nil)
        session.close()
        #expect(presenter.pipeline.pending == nil, "teardown dropped the request")
        #expect(presenter.pipeline.compileCount == compiles)
        #expect(!presenter.pipeline.isSetUp)
    }
}
