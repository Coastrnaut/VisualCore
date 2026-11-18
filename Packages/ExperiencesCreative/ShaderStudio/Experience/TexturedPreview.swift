// TexturedPreview — feature 161 (A22-P03) T-A22-308 (FR-A22-304; clarification Q4; research D3; contracts/editor.md
// "Textures"; contract gap G-TEXTURES). The preview scene of a live project with texture inputs:
//
//   - Textures: in `setup` one 64 × 64 `.rgba8` `RenderTarget` per recipe of `TextureRecipes` (checker, ramp, noise),
//     made by `ResourceRegistry.makeRenderTarget` (so charged to the host's `ResourceBudget`, 16 KiB each) and filled
//     by `RenderTarget.upload(rgbaFloats:)`. After a context loss `setup` runs again and makes them anew from code;
//     `teardown` releases them (a stale target's release is a no-op).
//   - Drawing: a VisualCore `FieldPass` of the assembly's entry (`ss/main.frag` with the `ss/` files, compiled with
//     `FullScreenShaderScene.vertexSource` under the same names as the pipeline's probe, so the program is the cached
//     one) draws into the context's framebuffer. Input `k` of the project (unit `k`) samples the recipe of
//     `choices[k]`, the checker when the choice is missing or unknown. The uniforms set are the active float ones:
//     `u_time` (frame time), `u_resolution` (pixels) and each `u_<name>` of `parameters` the program keeps.
//   - Failure: a pass that does not build sets `errorMessage` and draws nothing.
//
// No GL call of its own: textures, program and draw are VisualCore's (`RenderTarget`, `FieldPass`).
import Foundation
import ShaderStudioCore
import VisualCoreRendering
import VisualCoreShaderSource

/// A scene the preview pipeline draws: `FullScreenShaderScene` for projects without texture inputs, or
/// ``TexturedPreview``.
@MainActor
protocol PreviewScene: AnyObject {
    /// Parameter values bound as `u_<name>` floats.
    var parameters: [String: Double] { get set }
    /// The first build failure as `file:line: message`, or nil.
    var errorMessage: String? { get }
    /// Builds the GPU objects in the host's context.
    func setup(_ context: RenderContext) throws
    /// Records the new drawable size.
    func resize(_ context: RenderContext)
    /// Draws one frame.
    func render(_ context: RenderContext, frame: FrameInfo) throws
    /// Releases the GPU objects.
    func teardown(_ context: RenderContext)
}

extension FullScreenShaderScene: PreviewScene {}

/// The preview of a project with texture inputs (see the file header).
@MainActor
final class TexturedPreview: PreviewScene {
    /// The recipes made in setup, in choice order.
    static let recipes = TextureRecipes.all

    /// Parameter values bound as `u_<name>` floats (only those the program keeps).
    var parameters: [String: Double] = [:]
    /// The recipe index chosen for each texture input (`StudioCore.textures`).
    var choices: [Int] = StudioCore.defaultTextures
    /// The first build failure, or nil.
    private(set) var errorMessage: String?
    /// The project drawn.
    let project: ShaderProject
    /// The texture targets, one per recipe in ``recipes`` order; empty while not set up.
    private(set) var targets: [RenderTarget] = []
    /// The field pass; nil while not set up or after a failure.
    private(set) var pass: FieldPass?
    /// The drawable size in pixels.
    private var size = SIMD2<Float>(1, 1)

    /// A preview of `project` (which has texture inputs).
    init(project: ShaderProject) {
        self.project = project
    }

    /// The inputs of a run: input `k` of `inputs` samples `targets[choices[k]]`, or the first target (checker) when the
    /// choice is missing or outside `targets`.
    static func bindings(inputs: [String], choices: [Int], targets: [RenderTarget]) -> [String: RenderTarget] {
        guard let first = targets.first else { return [:] }
        var bound: [String: RenderTarget] = [:]
        for (k, name) in inputs.enumerated() {
            let choice = choices.indices.contains(k) ? choices[k] : 0
            bound[name] = targets.indices.contains(choice) ? targets[choice] : first
        }
        return bound
    }

    /// Makes the textures from code and builds the pass (again after a context loss).
    func setup(_ context: RenderContext) throws {
        release(context)
        size = SIMD2(Float(max(1, context.pixelWidth)), Float(max(1, context.pixelHeight)))
        var made: [RenderTarget] = []
        for recipe in Self.recipes {
            let target = try context.resources.makeRenderTarget(width: TextureRecipes.size, height: TextureRecipes.size,
                                                                format: .rgba8, label: "ss.texture." + recipe.title)
            made.append(target)
            guard target.upload(rgbaFloats: recipe.pixels) else {
                for target in made { context.resources.release(target) }
                errorMessage = "texture " + recipe.title + ": upload failed"
                return
            }
        }
        targets = made
        let assembly = ShaderAssembly(project: project)
        do {
            pass = try FieldPass(registry: context.resources, fragment: assembly.entryText,
                                 inputs: project.textureInputs, label: ShaderAssembly.entryFile,
                                 library: ShaderBundle(files: assembly.files).library)
            errorMessage = nil
        } catch {
            if case .compile(let message) = error { errorMessage = message } else { errorMessage = "\(error)" }
        }
    }

    /// Records the new pixel size for `u_resolution`.
    func resize(_ context: RenderContext) {
        size = SIMD2(Float(max(1, context.pixelWidth)), Float(max(1, context.pixelHeight)))
    }

    /// The active float uniforms of `program` for `frame`: `u_time`, `u_resolution` and the parameters it keeps.
    func uniforms(_ program: ShaderProgram, time: Double) -> [String: FieldUniform] {
        let active = program.uniforms
        var uniforms: [String: FieldUniform] = [:]
        if active["u_time"] != nil { uniforms["u_time"] = .float(Float(time)) }
        if active["u_resolution"] != nil { uniforms["u_resolution"] = .vec2(size) }
        for (name, value) in parameters where active["u_" + name] != nil { uniforms["u_" + name] = .float(Float(value)) }
        return uniforms
    }

    /// Draws the pass into the context's framebuffer with the chosen textures; nothing when not built.
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        guard let pass else { return }
        try pass.run(output: .framebuffer(name: context.framebuffer, width: context.pixelWidth,
                                          height: context.pixelHeight),
                     inputs: Self.bindings(inputs: pass.inputs, choices: choices, targets: targets),
                     uniforms: uniforms(pass.program, time: frame.time))
    }

    /// Releases the pass and the textures.
    func teardown(_ context: RenderContext) {
        release(context)
    }

    /// Releases what setup made (a stale object's release is a no-op).
    private func release(_ context: RenderContext) {
        pass?.release()
        pass = nil
        for target in targets { context.resources.release(target) }
        targets = []
    }
}
