// UniformPreviewTests — feature 160 (A22-P02) T-A22-207 (FR-A22-205; clarification Q3). Through the one app's
// session host: two values of a uniform give different pictures with no compile; the live scene's parameters are the
// core's values denormalized by the live project's definitions (named without `u_`); an out-of-range value and a
// fractional or missing uniform index are refused and change nothing. Short runs only.
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct UniformPreviewTests {
    @Test func twoValuesGiveDifferentPicturesWithoutACompile() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        StudioTest.accept(shell, "template.select", [2])   // Rings: u_count, u_width
        try StudioTest.draw(session)
        let compiles = presenter.pipeline.compileCount
        let programs = try #require(session.renderHost).resources.compileCount
        StudioTest.accept(shell, "uniform.set", [0, 0.1])
        let low = try StudioTest.still(session)
        let rings = ShaderTemplates.all[2].uniforms
        #expect(presenter.pipeline.live?.parameters["count"] == rings[0].value(normalized: 0.1))
        #expect(presenter.pipeline.live?.parameters["width"]
                == rings[1].value(normalized: rings[1].normalized(rings[1].defaultValue)))
        StudioTest.accept(shell, "uniform.set", [0, 0.9])
        let high = try StudioTest.still(session)
        #expect(presenter.pipeline.live?.parameters["count"] == rings[0].value(normalized: 0.9))
        #expect(StudioTest.differs(low, high), "the picture follows the uniform")
        #expect(presenter.pipeline.compileCount == compiles, "no compile")
        #expect(try #require(session.renderHost).resources.compileCount == programs, "no program compiled")
        #expect(presenter.mirror.values[0] == 0.9)
    }

    @Test func outOfRangeAndFractionalIndicesAreRefused() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let before = try StudioTest.still(session)
        let core = try StudioTest.core(shell)
        for (values, code) in [([0, 1.5], "action.out-of-range"), ([16, 0.5], "action.out-of-range"),
                               ([0.5, 0.5], "action.rule.a22.not-whole"), ([1, 0.5], "action.rule.a22.no-uniform")] {
            #expect(shell.handle(control: "uniform.set", values: values).code == code, "\(values)")
        }
        #expect(try StudioTest.core(shell) == core)
        #expect(try StudioTest.still(session) == before)
        #expect(presenter.pipeline.status == .compiled([]))
    }

    @Test func parametersAreDenormalizedWithoutThePrefix() throws {
        let noise = ShaderTemplates.all[1].project
        let parameters = StudioPresenter.parameters(noise, values: [0, 1] + Array(repeating: 0, count: 14))
        #expect(parameters == ["scale": 0.5, "speed": 2])
    }
}
