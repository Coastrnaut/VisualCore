// TemplateCompileTests — feature 159 (A22-P01) T-A22-111 (FR-A22-106; SC-A22-104; US5; clarification Q5; research D5);
// feature 161 (A22-P03) T-A22-303 (FR-A22-304; SC-A22-304; clarification Q4).
// There are exactly four templates (`gradient`, `noise-flow`, `rings`, `texture-mix`), each with a licence record;
// each passes `ShaderValidator` with no issue and compiles and links inside the template off screen; its active
// sampler uniforms (`GL_SAMPLER_2D`) equal its declared texture inputs and its active float uniforms (`GL_FLOAT`,
// other than `u_time`) equal its declared uniforms, with nothing else active but `u_resolution`. A template without
// texture inputs also draws one frame at 64 × 48 with its default uniform values through `FullScreenShaderScene`
// (the drawing of `texture-mix` with bound textures is the experience's `TexturedPreview`, tested there).
import ShaderStudioCore
import Testing
import VisualCoreRendering

@MainActor
@Suite struct TemplateCompileTests {
    /// `GL_FLOAT` and `GL_SAMPLER_2D`, as `ShaderProgram.Uniform.type` reports them.
    static let floatType = 0x1406
    static let sampler2DType = 0x8B5E

    @Test func thereAreFourTemplatesInOrderWithLicences() {
        #expect(ShaderTemplates.all.map(\.id) == ["gradient", "noise-flow", "rings", "texture-mix"])
        #expect(ShaderTemplates.ids == ShaderTemplates.all.map(\.id))
        #expect(ShaderTemplates.all.map { $0.uniforms.map(\.name) }
                == [["u_speed"], ["u_scale", "u_speed"], ["u_count", "u_width"], ["u_blend"]])
        #expect(ShaderTemplates.all.map(\.textureInputs) == [[], [], [], ["u_texture0", "u_texture1"]])
        for template in ShaderTemplates.all {
            #expect(!template.licence.isEmpty, "\(template.id)")
            #expect(!template.title.isEmpty, "\(template.id)")
            #expect(template.project.limits == .standard, "\(template.id)")
            #expect(!template.source.contains("#version"), "\(template.id)")
            #expect(ShaderTemplates.template(id: template.id) == template)
        }
        #expect(ShaderTemplates.all.first { $0.id == "noise-flow" }?.source.contains("vc_fbm(") == true)
        #expect(ShaderTemplates.template(id: "missing") == nil)
    }

    @Test func textureMixDeclaresTwoInputsAndABlend() throws {
        let template = try #require(ShaderTemplates.template(id: "texture-mix"))
        #expect(template.textureInputs == ["u_texture0", "u_texture1"])
        let blend = try #require(template.uniforms.first)
        #expect(template.uniforms.count == 1)
        #expect(blend.name == "u_blend")
        #expect(blend.range == 0...1)
        #expect(blend.defaultValue == 0.5)
        #expect(template.source.contains("uniform sampler2D u_texture0;"))
        #expect(template.source.contains("uniform sampler2D u_texture1;"))
        #expect(template.source.contains("mix(texture(u_texture0, v_uv), texture(u_texture1, v_uv), u_blend)"))
        #expect(template.project.textureInputs.count <= template.project.limits.maxTextureInputs)
        #expect(ShaderValidator.validate(template.project).isEmpty)
    }

    @Test(arguments: ShaderTemplates.ids)
    func templateValidatesCompilesAndMatchesItsUniforms(_ id: String) throws {
        let template = try #require(ShaderTemplates.template(id: id))
        #expect(ShaderValidator.validate(template.project).isEmpty, "\(id): \(ShaderValidator.validate(template.project))")

        let scene = AssemblyCompileScene(assembly: ShaderAssembly(project: template.project))
        let host = try AssemblyCompiler.host(scene)
        defer { host.destroy() }
        #expect(scene.otherFailure == nil, "\(id): \(scene.otherFailure ?? "")")
        #expect(scene.diagnostics.isEmpty, "\(id): \(scene.diagnostics.map(\.description))")
        let program = try #require(scene.program, "\(id) links")

        let active = Set(program.uniforms.keys).subtracting(["u_time", "u_resolution"])
        #expect(active == Set(template.uniforms.map(\.name) + template.textureInputs),
                "\(id): active uniforms \(program.uniforms.keys.sorted())")
        let samplers = Set(program.uniforms.filter { Int($0.value.type) == Self.sampler2DType }.keys)
        let floats = Set(program.uniforms.filter { Int($0.value.type) == Self.floatType }.keys).subtracting(["u_time"])
        #expect(samplers == Set(template.textureInputs), "\(id): active samplers \(samplers.sorted())")
        #expect(floats == Set(template.uniforms.map(\.name)), "\(id): active floats \(floats.sorted())")
        guard template.textureInputs.isEmpty else { return }

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
