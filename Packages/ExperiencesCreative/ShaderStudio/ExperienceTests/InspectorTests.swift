// InspectorTests — feature 161 (A22-P03) T-A22-307 (FR-A22-303, FR-A22-305; SC-A22-303; US3 AC1–AC3;
// clarification Q3; contract gap G-INSPECTOR). Through the one app's session host: the inspector's rows are the live
// project's uniforms (title, value with its unit at two decimals, range "a to b"); a value past either end stops at the
// end; NaN and infinities are refused with nothing sent; Reset restores the defaults; a uniform dropped by a
// successful recompile leaves the rows without a crash; and none of it compiles. Short runs only.
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreParameters
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct InspectorTests {
    @Test func theRowsMatchTheLiveProject() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let gradient = StudioInspector.rows(presenter.mirror)
        #expect(gradient == [InspectorRow(index: 0, name: "u_speed", title: "Speed", valueText: "1.00",
                                          rangeText: "0.00 to 4.00", normalized: 0.25)])
        for (index, template) in ShaderTemplates.all.enumerated() {
            StudioTest.accept(shell, "template.select", [Double(index)])
            try StudioTest.draw(session)
            let rows = StudioInspector.rows(presenter.mirror)
            #expect(rows.map(\.name) == template.uniforms.map(\.name), "\(template.id)")
            #expect(rows.map(\.title) == template.uniforms.map(\.title))
            #expect(rows.map(\.rangeText) == template.uniforms.map(StudioInspector.rangeText))
            for (row, definition) in zip(rows, template.uniforms) {
                #expect(row.valueText == StudioInspector.valueText(definition.defaultValue, unit: definition.unit))
            }
            let spoken = StudioControls.labels(presenter.mirror).filter { $0.name.hasPrefix("uniform-") }
            #expect(spoken.map(\.value) == rows.map(\.valueText) && spoken.map(\.title) == rows.map(\.title))
        }
        #expect(StudioInspector.valueText(2.5, unit: "Hz") == "2.50 Hz")
        #expect(StudioInspector.valueText(0.5, unit: "") == "0.50")
    }

    @Test func valuesStopAtTheEndsNonFiniteIsRefusedAndResetRestores() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        StudioTest.accept(shell, "template.select", [2])   // Rings: u_count 1…24, u_width 0.02…0.9
        try StudioTest.draw(session)
        let host = try #require(session.renderHost)
        let compiles = presenter.pipeline.compileCount
        let programs = host.resources.compileCount

        #expect(presenter.setUniform(0, value: 99) == .accepted)
        #expect(try StudioTest.core(shell).values[0] == 1)
        #expect(presenter.setUniform(1, value: -5) == .accepted)
        #expect(try StudioTest.core(shell).values[1] == 0)
        try StudioTest.draw(session)
        #expect(StudioInspector.rows(presenter.mirror).map(\.valueText) == ["24.00", "0.02"])
        #expect(presenter.setUniform(0, normalized: 1.7) == .accepted)
        #expect(presenter.setUniform(0, normalized: -0.3) == .accepted)
        #expect(try StudioTest.core(shell).values[0] == 0)

        let before = try StudioTest.core(shell)
        for bad in [Double.nan, .infinity, -.infinity] {
            #expect(presenter.setUniform(0, normalized: bad) == nil, "\(bad) sends nothing")
            #expect(presenter.setUniform(0, value: bad) == nil)
            #expect(shell.handle(control: "uniform.set", values: [0, bad]) != .accepted, "the engine refuses it too")
        }
        #expect(try StudioTest.core(shell) == before)
        #expect(presenter.setUniform(5, value: 1) == nil, "not a live uniform")

        let results = presenter.resetUniforms()
        #expect(results == [.accepted, .accepted])
        #expect(try StudioTest.core(shell).values == StudioCore.defaultValues(template: 2))
        try StudioTest.draw(session, frames: 2)
        #expect(StudioInspector.rows(presenter.mirror).map(\.valueText) == ["6.00", "0.30"])
        #expect(presenter.pipeline.compileCount == compiles, "nothing compiles")
        #expect(host.resources.compileCount == programs, "no program compiled")
    }

    @Test func aUniformDroppedByARecompileLeavesTheRows() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        StudioTest.accept(shell, "template.select", [2])   // Rings: two uniforms
        try StudioTest.draw(session)
        #expect(StudioInspector.rows(presenter.mirror).count == 2)
        let count = ShaderTemplates.all[2].uniforms[0]
        let source = "uniform float u_count;\nvoid main() { fragColor = vec4(fract(v_uv.x * u_count), 0.2, 0.4, 1.0); }\n"
        presenter.replaceDocument(try ShaderProject(name: "One ring", source: source, uniforms: [count]))
        StudioTest.accept(shell, "shader.run", [1])
        try StudioTest.draw(session)
        #expect(presenter.pipeline.status == .compiled([]))
        #expect(StudioInspector.rows(presenter.mirror).map(\.name) == ["u_count"], "u_width is dropped")
        #expect(presenter.setUniform(1, value: 0.5) == nil, "the dropped uniform is not set")
        #expect(presenter.resetUniforms() == [.accepted])
        try StudioTest.draw(session, frames: 2)
        #expect(presenter.pipeline.live?.parameters.keys.sorted() == ["count"])
        #expect(try #require(session.renderHost).resources.stats.leaked == 0)
    }
}
