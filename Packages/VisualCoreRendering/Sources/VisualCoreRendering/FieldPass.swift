// FieldPass.swift — a full-screen program with named sampler inputs and typed uniforms that draws into a render
// target or framebuffer (feature 019 T-A02-105; gap G-FIELDPASS; research R5). It refuses to sample its own output,
// so feedback and simulation steps cannot read and write the same texture (A02 Bounded GPU rule).
import CVisualCoreGL

/// A uniform value for a field pass.
public enum FieldUniform: Sendable, Equatable {
    /// `float`.
    case float(Float)
    /// `vec2`.
    case vec2(SIMD2<Float>)
    /// `vec4`.
    case vec4(SIMD4<Float>)
    /// `int` or `bool`.
    case int(Int32)

    var glTypes: [Int32] {
        switch self {
        case .float: [GL_FLOAT]
        case .vec2: [GL_FLOAT_VEC2]
        case .vec4: [GL_FLOAT_VEC4]
        case .int: [GL_INT, GL_BOOL]
        }
    }
}

/// Why a field pass did not run. Nothing is drawn when `run` throws.
public enum FieldPassError: Error, Equatable, Sendable {
    /// The named input is the output texture.
    case inputIsOutput(String)
    /// A declared input was not supplied.
    case missingInput(String)
    /// A supplied input is not declared.
    case unknownInput(String)
    /// The uniform is not an active uniform of the program (unused uniforms are removed by the compiler).
    case unknownUniform(String)
    /// The uniform exists with another type.
    case uniformTypeMismatch(String)
    /// The pass, an input or the output belongs to an earlier context or was released.
    case stale
    /// The program failed to compile or link (first diagnostic).
    case compile(String)
}

/// Runs a fragment shader over every pixel of its output. The fragment receives `in vec2 v_uv` (0…1, texel centers
/// when the output matches the input size) from `FullScreenShaderScene.vertexSource`; inputs are `sampler2D`
/// uniforms bound to texture units in the order of `inputs`.
@MainActor
public final class FieldPass {
    /// Where a pass draws.
    public enum Output {
        /// A render target (simulation step).
        case target(RenderTarget)
        /// A framebuffer such as `RenderContext.framebuffer` (display).
        case framebuffer(name: UInt32, width: Int, height: Int)
    }

    /// Sampler names, bound to texture units 0, 1, … in this order.
    public let inputs: [String]
    /// Diagnostic label.
    public let label: String
    /// The linked program (shared through the registry's program cache).
    public let program: ShaderProgram
    private weak var registry: ResourceRegistry?
    private var released = false

    /// Compiles `fragment` with the full-screen vertex shader; throws `.compile` with the first diagnostic.
    public init(registry: ResourceRegistry, fragment: String, inputs: [String], label: String) throws(FieldPassError) {
        do {
            program = try registry.program(vertex: FullScreenShaderScene.vertexSource, fragment: fragment,
                                           vertexName: "fullscreen.vert", fragmentName: label)
        } catch let ShaderError.compile(diagnostics) {
            throw .compile(diagnostics.first.map { "\($0.file):\($0.line): \($0.message)" } ?? "\(label): compile failed")
        } catch {
            throw .compile("\(label): \(error)")
        }
        self.inputs = inputs
        self.label = label
        self.registry = registry
    }

    /// Draws into `output`, sampling `inputs` (exactly the declared names) and setting `uniforms`.
    /// Everything is validated before any GL draw call. Blending and scissoring are disabled for the draw and their
    /// previous state is restored; the viewport is set to the output size and left there.
    public func run(output: Output, inputs supplied: [String: RenderTarget],
                    uniforms: [String: FieldUniform] = [:]) throws(FieldPassError) {
        guard !released, let registry, program.generation == registry.generation, !program.released else { throw .stale }
        for name in inputs where supplied[name] == nil { throw .missingInput(name) }
        for name in supplied.keys.sorted() where !inputs.contains(name) { throw .unknownInput(name) }
        for name in inputs {
            let target = supplied[name]!
            guard target.handle.generation == registry.generation, !target.released else { throw .stale }
            if case .target(let out) = output, out.colorTexture == target.colorTexture { throw .inputIsOutput(name) }
            if case .framebuffer(let fb, _, _) = output, fb == target.handle.name { throw .inputIsOutput(name) }
        }
        for (name, value) in uniforms {
            guard let declared = program.uniforms[name] else { throw .unknownUniform(name) }
            guard value.glTypes.contains(where: { GLenum($0) == declared.type }) else { throw .uniformTypeMismatch(name) }
        }
        let (framebuffer, width, height): (UInt32, Int, Int)
        switch output {
        case .target(let target):
            guard target.handle.generation == registry.generation, !target.released else { throw .stale }
            (framebuffer, width, height) = (target.handle.name, target.width, target.height)
        case .framebuffer(let name, let w, let h):
            (framebuffer, width, height) = (name, w, h)
        }

        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)
        vcglViewport(0, 0, GLsizei(width), GLsizei(height))
        let blend = vcglIsEnabled(GLenum(GL_BLEND)) == GLboolean(GL_TRUE)
        let scissor = vcglIsEnabled(GLenum(GL_SCISSOR_TEST)) == GLboolean(GL_TRUE)
        vcglDisable(GLenum(GL_BLEND))
        vcglDisable(GLenum(GL_SCISSOR_TEST))
        program.use()
        for (unit, name) in inputs.enumerated() {
            supplied[name]!.bindColor(unit: unit)
            if program.uniforms[name] != nil { program.set(name, Int32(unit)) }
        }
        for (name, value) in uniforms {
            switch value {
            case .float(let v): program.set(name, v)
            case .vec2(let v): program.set(name, v)
            case .vec4(let v): program.set(name, v)
            case .int(let v): program.set(name, v)
            }
        }
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        for unit in inputs.indices.reversed() {
            vcglActiveTexture(GLenum(GL_TEXTURE0 + Int32(unit)))
            vcglBindTexture(GLenum(GL_TEXTURE_2D), 0)
        }
        if blend { vcglEnable(GLenum(GL_BLEND)) }
        if scissor { vcglEnable(GLenum(GL_SCISSOR_TEST)) }
    }

    /// One simulation step: samples `pair.read` as `input` (plus `extraInputs`), draws into `pair.write`, then swaps.
    /// The pair is swapped only when the pass ran.
    public func run(pair: PingPongTarget, input: String, extraInputs: [String: RenderTarget] = [:],
                    uniforms: [String: FieldUniform] = [:]) throws(FieldPassError) {
        guard pair.isValid else { throw .stale }
        var all = extraInputs
        all[input] = pair.read
        try run(output: .target(pair.write), inputs: all, uniforms: uniforms)
        pair.swap()
    }

    /// Releases the program (idempotent). Passes built from identical sources share one cached program, so create
    /// one pass per source and release it once.
    public func release() {
        guard !released else { return }
        released = true
        registry?.release(program)
    }
}
