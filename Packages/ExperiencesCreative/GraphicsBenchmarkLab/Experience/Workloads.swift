// Workloads — feature 174 (A24-P02) T-A24-205 (FR-A24-201, FR-A24-202; clarification Q1; data-model.md "Workload").
// The three benchmark workloads drawn through VisualCore alone (`FieldPass`, registry render targets and
// `ParticleRenderer`), built from a validated `BenchmarkCase`. Every picture is a function of the case and the
// workload frame number n only, never of the clock:
//   quads      at build a field pass writes a code-made texture (a checker of 16 cells mixed with VisualCore's value
//              noise) into a textureSize × textureSize render target; each frame draws `layers` full-screen field
//              passes, layer k sampling the texture turned by (k + n) / 64 of a turn, so every layer fills every pixel
//   alu        one full-screen field pass whose loop runs `iterations` steps of a bounded trigonometric recurrence (the
//              loop bound is the constant 1,024 with an early exit at the uniform `u_iterations`), phase n / 60
//   particles  a field pass clears the output to a dark colour, then `ParticleRenderer` draws `particles` instances of
//              the core's `ParticleField` at frame n (view points equal drawable pixels, as Neon Arcade draws)
// The resolution scale is applied to the drawable size: below 1.0 the workload draws into a scaled render target that
// a field pass then stretches over the framebuffer; at 1.0 the framebuffer is drawn directly.
// Choices recorded here: the case is validated first (`invalidCase` with the `CaseError` description); then the
// texture size is checked against the registry's `maxTextureSize` (and the optional `textureLimit` seam of the tests),
// before any program is compiled or any target made (`overLimit`). A build that fails half-way releases what it made
// and throws `build`. Programs are shared through the registry's program cache, so one registry should hold one
// workload of a kind at a time: release the old workload before building the next. After a context loss (the
// context's generation differs from the build's) `draw` and `resize` drop the dead objects and rebuild from the case.
// No GL call of its own.
import Foundation
import GraphicsBenchmarkLabCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// Why a workload could not be built or drawn.
enum WorkloadError: Error, Equatable {
    /// The case failed `BenchmarkCase.validate()`; the payload is the `CaseError`'s description.
    case invalidCase(String)
    /// The named configuration field exceeds what this context can allocate (`limit`, for example the registry's
    /// `maxTextureSize`); nothing was allocated.
    case overLimit(field: String, limit: Int)
    /// A program, target or renderer could not be made (the first diagnostic or error description); whatever was
    /// made before the failure has been released.
    case build(String)
}

/// One benchmark workload of a validated case on one render context: built at init, drawn per workload frame,
/// resized with the drawable, rebuilt after a context loss and released once.
@MainActor
final class WorkloadRenderer {
    /// The case this workload draws.
    let benchmarkCase: BenchmarkCase
    /// The context generation the GPU objects belong to.
    private(set) var generation: Int
    /// True once ``release()`` ran; a released workload draws nothing more.
    private(set) var isReleased = false

    /// A test seam: a texture-size limit below the registry's `maxTextureSize` (nil: the registry's limit alone).
    private let textureLimit: Int?
    /// The particle placement of the particles workload.
    private let field: ParticleField?
    /// The registry the objects were made in (the host's one registry; kept weakly, as `FieldPass` does).
    private weak var registry: ResourceRegistry?

    /// The quads workload's code-made texture.
    private var texture: RenderTarget?
    /// The quads workload's layer pass (samples `u_texture`).
    private var layerPass: FieldPass?
    /// The alu workload's pass.
    private var aluPass: FieldPass?
    /// The particles workload's background pass.
    private var clearPass: FieldPass?
    /// The particles workload's renderer.
    private var particleRenderer: ParticleRenderer?
    /// The scaled target (resolution scale below 1.0 only).
    private var scaledTarget: RenderTarget?
    /// The pass that stretches the scaled target over the framebuffer (samples `u_source`).
    private var blitPass: FieldPass?

    /// Turns per layer step of the quads workload: 1 / 64 of a turn.
    static let turnSteps = 64
    /// Frames per unit of phase of the alu workload: 60.
    static let framesPerPhase = 60.0
    /// The constant loop bound of the alu shader: 1,024 (the cap of `CaseLimits.iterations`).
    static let aluLoopBound = 1_024

    /// Builds the workload of `benchmarkCase` on `context`. Validates the case (``WorkloadError/invalidCase(_:)``),
    /// checks the texture size against `context.resources.maxTextureSize` and `textureLimit` before allocating
    /// anything (``WorkloadError/overLimit(field:limit:)``), then compiles and allocates
    /// (``WorkloadError/build(_:)``, leaving nothing allocated).
    init(benchmarkCase: BenchmarkCase, context: RenderContext, textureLimit: Int? = nil) throws(WorkloadError) {
        do {
            try benchmarkCase.validate()
        } catch {
            throw .invalidCase(String(describing: error))
        }
        self.benchmarkCase = benchmarkCase
        self.textureLimit = textureLimit
        self.generation = context.generation
        self.field = benchmarkCase.workload == .particles
            ? ParticleField(count: benchmarkCase.config.particles ?? 0) : nil
        let limit = Self.limit(context, textureLimit)
        if let size = benchmarkCase.config.textureSize, size > limit {
            throw .overLimit(field: "textureSize", limit: limit)
        }
        try build(context)
    }

    /// The largest texture side this workload may allocate on `context`.
    private static func limit(_ context: RenderContext, _ textureLimit: Int?) -> Int {
        min(textureLimit ?? Int.max, context.resources.maxTextureSize)
    }

    // MARK: Building

    /// Makes the GPU objects of the case's workload on `context` (and the scaled target when the scale is below 1).
    /// On a failure everything made is released.
    private func build(_ context: RenderContext) throws(WorkloadError) {
        generation = context.generation
        let registry = context.resources
        self.registry = registry
        do {
            switch benchmarkCase.workload {
            case .quads:
                let size = benchmarkCase.config.textureSize ?? CaseLimits.textureSize.lowerBound
                let target = try registry.makeRenderTarget(width: size, height: size, label: "gbl-quads-texture")
                texture = target
                let texturePass = try FieldPass(registry: registry, fragment: Self.textureFragment, inputs: [],
                                                label: "gbl-quads-texture")
                defer { texturePass.release() }
                try texturePass.run(output: .target(target), inputs: [:])
                layerPass = try FieldPass(registry: registry, fragment: Self.layerFragment, inputs: ["u_texture"],
                                          label: "gbl-quads-layer")
            case .alu:
                aluPass = try FieldPass(registry: registry, fragment: Self.aluFragment, inputs: [], label: "gbl-alu")
            case .particles:
                clearPass = try FieldPass(registry: registry, fragment: Self.clearFragment, inputs: [],
                                          label: "gbl-particles-clear")
                particleRenderer = try ParticleRenderer(registry: registry)
            }
            try prepareScaledTarget(context)
        } catch let error as WorkloadError {
            releaseObjects()
            throw error
        } catch let FieldPassError.compile(message) {
            releaseObjects()
            throw .build(message)
        } catch {
            releaseObjects()
            throw .build(String(describing: error))
        }
    }

    /// Makes (or remakes after a size change) the scaled target and its stretch pass when the resolution scale is
    /// below 1; releases them at scale 1.
    private func prepareScaledTarget(_ context: RenderContext) throws {
        let scale = benchmarkCase.config.resolutionScale
        guard scale < 1 else {
            releaseScaled()
            return
        }
        let limit = Self.limit(context, textureLimit)
        let width = min(limit, max(1, Int((Double(context.pixelWidth) * scale).rounded())))
        let height = min(limit, max(1, Int((Double(context.pixelHeight) * scale).rounded())))
        if let target = scaledTarget, target.width == width, target.height == height,
           target.handle.generation == context.generation {
            return
        }
        if let target = scaledTarget { context.resources.release(target) }
        scaledTarget = nil
        registry = context.resources
        scaledTarget = try context.resources.makeRenderTarget(width: width, height: height, label: "gbl-scaled")
        if blitPass == nil {
            blitPass = try FieldPass(registry: context.resources, fragment: Self.blitFragment, inputs: ["u_source"],
                                     label: "gbl-scaled-blit")
        }
    }

    /// Rebuilds every object when `context` belongs to another generation than the build (a context loss).
    private func rebuildIfStale(_ context: RenderContext) throws(WorkloadError) {
        guard context.generation != generation else { return }
        releaseObjects()
        try build(context)
    }

    // MARK: Drawing

    /// Draws workload frame `n` into `context.framebuffer` (through the scaled target below scale 1). Rebuilds first
    /// after a context loss. Throws when the workload was released, a rebuild fails or a pass refuses to run.
    func draw(frame n: Int, context: RenderContext) throws {
        guard !isReleased else { throw WorkloadError.build("released") }
        try rebuildIfStale(context)
        let screen = FieldPass.Output.framebuffer(name: context.framebuffer, width: context.pixelWidth,
                                                  height: context.pixelHeight)
        if benchmarkCase.config.resolutionScale < 1 {
            try prepareScaledTarget(context)
            guard let target = scaledTarget, let blitPass else { throw WorkloadError.build("scaled target missing") }
            try drawWorkload(frame: n, output: .target(target), width: target.width, height: target.height)
            try blitPass.run(output: screen, inputs: ["u_source": target])
        } else {
            try drawWorkload(frame: n, output: screen, width: context.pixelWidth, height: context.pixelHeight)
        }
    }

    /// Draws frame `n` of the case's workload into `output` of `width` × `height` pixels.
    private func drawWorkload(frame n: Int, output: FieldPass.Output, width: Int, height: Int) throws {
        let aspect = Float(max(1, width)) / Float(max(1, height))
        switch benchmarkCase.workload {
        case .quads:
            guard let layerPass, let texture else { throw WorkloadError.build("quads not built") }
            let layers = benchmarkCase.config.layers ?? 1
            for k in 0..<layers {
                let step = ((k + n) % Self.turnSteps + Self.turnSteps) % Self.turnSteps
                let turn = Float(step) / Float(Self.turnSteps)
                try layerPass.run(output: output, inputs: ["u_texture": texture],
                                  uniforms: ["u_turn": .float(turn), "u_aspect": .float(aspect)])
            }
        case .alu:
            guard let aluPass else { throw WorkloadError.build("alu not built") }
            let iterations = Int32(benchmarkCase.config.iterations ?? 1)
            let phase = Float(Double(n) / Self.framesPerPhase)
            try aluPass.run(output: output, inputs: [:],
                            uniforms: ["u_iterations": .int(iterations), "u_phase": .float(phase),
                                       "u_aspect": .float(aspect)])
        case .particles:
            guard let clearPass, let particleRenderer, let field else {
                throw WorkloadError.build("particles not built")
            }
            // The clear pass binds the output and sets the viewport; the renderer draws into the bound framebuffer.
            try clearPass.run(output: output, inputs: [:])
            let w = Double(max(1, width)), h = Double(max(1, height))
            let metrics = ViewMetrics(size: Vec2(w, h), scale: 1)
            let camera = Camera2D()
            let states = field.states(frame: n, width: w, height: h)
            var instances: [ParticleInstance] = []
            instances.reserveCapacity(states.count)
            for state in states {
                let world = metrics.toWorld(Vec2(state.x, state.y), camera: camera) ?? .zero
                instances.append(ParticleInstance(position: world, size: state.size,
                                                  color: Vec4(state.red, state.green, state.blue, state.alpha)))
            }
            try particleRenderer.draw(instances, camera: camera, metrics: metrics)
        }
    }

    /// The drawable size changed: remakes the scaled target (scale below 1); rebuilds first after a context loss.
    /// A failure is left to the next ``draw(frame:context:)``, which tries again and throws.
    func resize(_ context: RenderContext) {
        guard !isReleased else { return }
        do {
            try rebuildIfStale(context)
            try prepareScaledTarget(context)
        } catch {
            releaseScaled()
        }
    }

    // MARK: Releasing

    /// Releases every GPU object back to the registry (idempotent); the workload draws nothing afterwards.
    func release() {
        guard !isReleased else { return }
        releaseObjects()
        isReleased = true
    }

    /// Releases every object held (objects of an ended context are ignored by the registry).
    private func releaseObjects() {
        if let texture { registry?.release(texture) }
        texture = nil
        layerPass?.release()
        layerPass = nil
        aluPass?.release()
        aluPass = nil
        clearPass?.release()
        clearPass = nil
        particleRenderer?.release()
        particleRenderer = nil
        releaseScaled()
    }

    /// Releases the scaled target and its stretch pass.
    private func releaseScaled() {
        if let scaledTarget { registry?.release(scaledTarget) }
        scaledTarget = nil
        blitPass?.release()
        blitPass = nil
    }

    // MARK: Shaders (GLSL ES 3.00; FieldPass adds the full-screen vertex shader and `in vec2 v_uv`)

    /// The quads texture: a 4 × 4 checker (16 cells) of two colours mixed with VisualCore's value noise.
    static let textureFragment = """
    precision highp float;
    #include "vc/noise.glsl"
    in vec2 v_uv;
    out vec4 color;

    void main() {
        vec2 cell = floor(v_uv * 4.0);
        float checker = mod(cell.x + cell.y, 2.0);
        vec3 base = mix(vec3(0.08, 0.14, 0.32), vec3(0.95, 0.64, 0.22), checker);
        float n = vc_valueNoise(v_uv * 12.0);
        color = vec4(mix(base, vec3(n), 0.35), 1.0);
    }
    """

    /// One quads layer: the texture turned by `u_turn` of a turn about the centre, aspect-correct, repeated.
    static let layerFragment = """
    precision highp float;
    in vec2 v_uv;
    uniform sampler2D u_texture;
    uniform float u_turn;
    uniform float u_aspect;
    out vec4 color;

    void main() {
        float a = 6.28318530718 * u_turn;
        float c = cos(a), s = sin(a);
        vec2 p = (v_uv - 0.5) * vec2(u_aspect, 1.0);
        vec2 r = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
        vec2 uv = fract(r * 1.5 + 0.5);
        color = vec4(texture(u_texture, uv).rgb, 1.0);
    }
    """

    /// The alu stress: `u_iterations` steps (at most 1,024) of a bounded trigonometric recurrence, phase `u_phase`.
    static let aluFragment = """
    precision highp float;
    in vec2 v_uv;
    uniform int u_iterations;
    uniform float u_phase;
    uniform float u_aspect;
    out vec4 color;

    void main() {
        vec2 p = (v_uv - 0.5) * vec2(u_aspect, 1.0) * 3.0;
        vec2 z = p;
        float acc = 0.0;
        for (int i = 0; i < \(aluLoopBound); ++i) {
            if (i >= u_iterations) break;
            z = vec2(sin(z.y * 1.7 + u_phase), cos(z.x * 1.3 - u_phase)) + p * 0.5;
            acc += 0.5 + 0.5 * sin(dot(z, z) + u_phase);
        }
        float t = acc / float(max(u_iterations, 1));
        color = vec4(0.5 + 0.5 * cos(6.28318530718 * (t + vec3(0.0, 0.33, 0.67))), 1.0);
    }
    """

    /// The particles background: a dark vertical gradient.
    static let clearFragment = """
    precision highp float;
    in vec2 v_uv;
    out vec4 color;

    void main() {
        color = vec4(mix(vec3(0.01, 0.02, 0.05), vec3(0.03, 0.05, 0.10), v_uv.y), 1.0);
    }
    """

    /// Stretches the scaled target over the framebuffer.
    static let blitFragment = """
    precision highp float;
    in vec2 v_uv;
    uniform sampler2D u_source;
    out vec4 color;

    void main() {
        color = vec4(texture(u_source, v_uv).rgb, 1.0);
    }
    """
}
