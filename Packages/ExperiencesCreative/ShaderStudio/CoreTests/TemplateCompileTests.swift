// TemplateCompileTests — feature 159 (A22-P01) T-A22-111 (FR-A22-106; SC-A22-104; US5; clarification Q5; research D5).
// There are exactly three templates (`gradient`, `noise-flow`, `rings`), each with a licence record; each passes
// `ShaderValidator` with no issue, compiles and links inside the template off screen, draws one frame at 64 × 48 with
// its default uniform values, and its active uniforms (`ShaderProgram.uniforms` other than `u_time` and
// `u_resolution`) equal its declared ones.
import ShaderStudioCore
import Testing
import VisualCoreRendering

@MainActor
@Suite struct TemplateCompileTests {
    @Test func thereAreThreeTemplatesInOrderWithLicences() {
        #expect(ShaderTemplates.all.map(\.id) == ["gradient", "noise-flow", "rings"])
        #expect(ShaderTemplates.ids == ShaderTemplates.all.map(\.id))
        #expect(ShaderTemplates.all.map { $0.uniforms.map(\.name) }
                == [["u_speed"], ["u_scale", "u_speed"], ["u_count", "u_width"]])
        for template in ShaderTemplates.all {
            #expect(!template.licence.isEmpty, "\(template.id)")
            #expect(!template.title.isEmpty, "\(template.id)")
            #expect(template.project.limits == .standard, "\(template.id)")
            #expect(template.project.textureInputs.isEmpty, "\(template.id)")
            #expect(!template.source.contains("#version"), "\(template.id)")
            #expect(ShaderTemplates.template(id: template.id) == template)
        }
        #expect(ShaderTemplates.all.first { $0.id == "noise-flow" }?.source.contains("vc_fbm(") == true)
        #expect(ShaderTemplates.template(id: "missing") == nil)
    }

    @Test(arguments: ShaderTemplates.ids)
    func templateValidatesCompilesDrawsAndMatchesItsUniforms(_ id: String) throws {
        let template = try #require(ShaderTemplates.template(id: id))
        #expect(ShaderValidator.validate(template.project).isEmpty, "\(id): \(ShaderValidator.validate(template.project))")

        let scene = AssemblyCompileScene(assembly: ShaderAssembly(project: template.project))
        let host = try AssemblyCompiler.host(scene)
        defer { host.destroy() }
        #expect(scene.otherFailure == nil, "\(id): \(scene.otherFailure ?? "")")
        #expect(scene.diagnostics.isEmpty, "\(id): \(scene.diagnostics.map(\.description))")
        let program = try #require(scene.program, "\(id) links")

        let active = Set(program.uniforms.keys).subtracting(["u_time", "u_resolution"])
        #expect(active == Set(template.uniforms.map(\.name)), "\(id): active uniforms \(program.uniforms.keys.sorted())")

        let values = Dictionary(uniqueKeysWithValues: template.uniforms.map { ($0.name, $0.defaultValue) })
        let drawing = AssemblyCompiler.drawingScene(for: ShaderAssembly(project: template.project), values: values)
        let drawHost = try RenderHost(scene: drawing)
        defer { drawHost.destroy() }
        let image = try drawHost.renderOffscreen(width: 64, height: 48, time: 1.5)
        #expect(drawing.errorMessage == nil, "\(id): \(drawing.errorMessage ?? "")")
        #expect(image.width == 64 && image.height == 48)
        #expect(image.rgba.count == 64 * 48 * 4)
        var colours = Set<UInt32>()
        for i in stride(from: 0, to: image.rgba.count, by: 4) {
            colours.insert(UInt32(image.rgba[i]) << 16 | UInt32(image.rgba[i + 1]) << 8 | UInt32(image.rgba[i + 2]))
        }
        #expect(colours.count > 1, "\(id) draws a picture, not a flat clear")
    }
}
