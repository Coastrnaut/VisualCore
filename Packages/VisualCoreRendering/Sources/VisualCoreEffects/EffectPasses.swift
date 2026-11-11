// EffectPasses.swift — built-in pass runners (feature 005; FR-F405, FR-F406). Each pass owns its
// program(s) (from the registry cache) and draws into a pooled target supplied by EffectRenderer.
import CVisualCoreGL
import VisualCoreRendering

/// Everything a pass needs for one frame.
@MainActor
struct PassIO {
    let inputs: [String: RenderTarget]
    let output: RenderTarget
    let params: [String: [Double]]
    let time: Double
    let delta: Double
    let registry: ResourceRegistry
}

@MainActor
protocol EffectPassRunner: AnyObject {
    func run(_ io: PassIO) throws
}

/// Draws a full-screen triangle with `program` into `target`, binding `textures` as `u_<slot>`.
@MainActor
func drawFullscreen(_ program: ShaderProgram, into target: RenderTarget, textures: [(slot: String, target: RenderTarget)],
                    uniforms: (ShaderProgram) -> Void = { _ in }) {
    target.bind()
    vcglViewport(0, 0, GLsizei(target.width), GLsizei(target.height))
    vcglDisable(GLenum(GL_BLEND))
    program.use()
    for (unit, input) in textures.enumerated() {
        input.target.bindColor(unit: unit)
        if program.uniforms["u_\(input.slot)"] != nil { program.set("u_\(input.slot)", Int32(unit)) }
    }
    uniforms(program)
    vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
}

extension Dictionary where Key == String, Value == [Double] {
    func scalar(_ key: String, _ fallback: Double = 0) -> Float { Float(self[key]?.first ?? fallback) }
}

/// `copy`: output = input (also the pass-through fallback for failed passes, FR-F408).
@MainActor
final class CopyPass: EffectPassRunner {
    private let program: ShaderProgram
    init(registry: ResourceRegistry) throws {
        program = try registry.program(vertex: EffectShaders.vertex, fragment: EffectShaders.copy)
    }
    func run(_ io: PassIO) throws {
        guard let input = io.inputs["input"] ?? io.inputs.values.first else { return }
        drawFullscreen(program, into: io.output, textures: [("input", input)])
    }
}

/// `colorMatrix`: output = clamp(M · input + offset). `matrix` is 16 values, row-major.
@MainActor
final class ColorMatrixPass: EffectPassRunner {
    private let program: ShaderProgram
    init(registry: ResourceRegistry) throws {
        program = try registry.program(vertex: EffectShaders.vertex, fragment: EffectShaders.colorMatrix)
    }
    func run(_ io: PassIO) throws {
        guard let input = io.inputs["input"] else { return }
        let m = (io.params["matrix"] ?? []).map(Float.init)
        // Row-major parameter → column-major GL matrix.
        let columnMajor: [Float] = m.count == 16 ? (0..<16).map { m[($0 % 4) * 4 + $0 / 4] } : [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
        let o = (io.params["offset"] ?? [0, 0, 0, 0]).map(Float.init) + [0, 0, 0, 0]
        drawFullscreen(program, into: io.output, textures: [("input", input)]) { p in
            p.set("u_matrix", matrix4: columnMajor)
            p.set("u_offset", SIMD4<Float>(o[0], o[1], o[2], o[3]))
        }
    }
}

/// `blur`: separable Gaussian (horizontal into a pooled temporary, then vertical), radius 1–32.
@MainActor
final class BlurPass: EffectPassRunner {
    private let program: ShaderProgram
    init(registry: ResourceRegistry) throws {
        program = try registry.program(vertex: EffectShaders.vertex, fragment: EffectShaders.blur)
    }
    func run(_ io: PassIO) throws {
        guard let input = io.inputs["input"] else { return }
        try BlurPass.blur(program, input: input, output: io.output, radius: io.params.scalar("radius", 4), registry: io.registry)
    }

    static func blur(_ program: ShaderProgram, input: RenderTarget, output: RenderTarget, radius: Float, registry: ResourceRegistry) throws {
        let temp = try registry.acquireTarget(width: output.width, height: output.height, format: output.format)
        defer { registry.recycle(temp) }
        drawFullscreen(program, into: temp, textures: [("input", input)]) { p in
            p.set("u_direction", SIMD2<Float>(1, 0)); p.set("u_radius", radius)
        }
        drawFullscreen(program, into: output, textures: [("input", temp)]) { p in
            p.set("u_direction", SIMD2<Float>(0, 1)); p.set("u_radius", radius)
        }
    }
}

/// `bloom`: bright pass (threshold, soft knee) → separable blur (radius) → add × intensity onto the input.
@MainActor
final class BloomPass: EffectPassRunner {
    private let bright: ShaderProgram, blur: ShaderProgram, add: ShaderProgram
    init(registry: ResourceRegistry) throws {
        bright = try registry.program(vertex: EffectShaders.vertex, fragment: EffectShaders.brightPass)
        blur = try registry.program(vertex: EffectShaders.vertex, fragment: EffectShaders.blur)
        add = try registry.program(vertex: EffectShaders.vertex, fragment: EffectShaders.addScaled)
    }
    func run(_ io: PassIO) throws {
        guard let input = io.inputs["input"] else { return }
        let r = io.registry
        let highlights = try r.acquireTarget(width: io.output.width, height: io.output.height, format: io.output.format)
        let glow = try r.acquireTarget(width: io.output.width, height: io.output.height, format: io.output.format)
        defer { r.recycle(highlights); r.recycle(glow) }
        drawFullscreen(bright, into: highlights, textures: [("input", input)]) { $0.set("u_threshold", io.params.scalar("threshold", 0.8)) }
        try BlurPass.blur(blur, input: highlights, output: glow, radius: io.params.scalar("radius", 8), registry: r)
        drawFullscreen(add, into: io.output, textures: [("base", input), ("overlay", glow)]) { $0.set("u_intensity", io.params.scalar("intensity", 1)) }
    }
}

/// `distort`: animated sinusoidal displacement (strength 0–0.2 of the image, frequency, speed).
@MainActor
final class DistortPass: EffectPassRunner {
    private let program: ShaderProgram
    init(registry: ResourceRegistry) throws {
        program = try registry.program(vertex: EffectShaders.vertex, fragment: EffectShaders.distort)
    }
    func run(_ io: PassIO) throws {
        guard let input = io.inputs["input"] else { return }
        drawFullscreen(program, into: io.output, textures: [("input", input)]) { p in
            p.set("u_strength", io.params.scalar("strength", 0.02))
            p.set("u_frequency", io.params.scalar("frequency", 8))
            p.set("u_phase", Float(io.time) * io.params.scalar("speed", 1))
        }
    }
}

/// `composite`: base + overlay, mode 0 = over (alpha × opacity), mode 1 = add.
@MainActor
final class CompositePass: EffectPassRunner {
    private let program: ShaderProgram
    init(registry: ResourceRegistry) throws {
        program = try registry.program(vertex: EffectShaders.vertex, fragment: EffectShaders.composite)
    }
    func run(_ io: PassIO) throws {
        guard let base = io.inputs["base"], let overlay = io.inputs["overlay"] else { return }
        drawFullscreen(program, into: io.output, textures: [("base", base), ("overlay", overlay)]) { p in
            p.set("u_mode", io.params.scalar("mode", 0))
            p.set("u_opacity", io.params.scalar("opacity", 1))
        }
    }
}
