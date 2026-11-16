// GrayScottGPU — feature 118 (A16-P02) T-A16-205 (FR-A16-210; SC-A16-205; clarification Q4; contracts/gpu.md). The
// GPU twin of the CPU reference ``GrayScott``: an RGBA16F `PingPongTarget` at the grid size holds u in red and v in
// green, and one `FieldPass` performs one explicit Euler step per run,
//   u′ = u + Δt (Dᵤ∇²u − uv² + F(1 − u)),   v′ = v + Δt (Dᵥ∇²v + uv² − (F + k)v),
// with `highp` arithmetic, ∇² the five-point stencil (left + right + down + up − 4 · centre), Dᵤ = 0.16 and
// Dᵥ = 0.08, and u′, v′ clamped to 0…1 before they are stored. Neighbours wrap by index: the cell is read with
// `texelFetch` at `(cell + offset + n) % n`, so the registry's CLAMP_TO_EDGE sampling is never relied on. The step
// shader lives in this file (`SimulationShaders.swift` keeps one writer). Storing a colour write in half precision is
// implementation-defined in GLES (round to nearest or toward zero), which is why the fixture
// `GrayScottToleranceTests` compares with the CPU reference rounded both ways.
//
// The type requires half-float render targets (`FloatRenderSupport.detect(in:)`); every call is made with the
// registry's context current on the main thread. Nothing here is drawn on screen: it is the Phase 02 fixture that the
// Phase 03 reaction-diffusion drawing builds on.
import SimulationLabCore
import VisualCoreRendering
import VisualCoreSimulation

/// Why a ``GrayScottGPU`` could not be made.
enum GrayScottGPUError: Error, Equatable, Sendable {
    /// The context cannot render into RGBA16F targets (`FloatRenderSupport` reports no support).
    case floatTargetsUnavailable
    /// The grid size is below 1.
    case invalidGridSize(Int)
    /// The RGBA16F ping-pong pair could not be made (over budget or an incomplete framebuffer); the description of
    /// the underlying error.
    case incompleteTarget(String)
    /// The step program failed to compile or link (its first diagnostic).
    case compile(String)
}

/// Gray-Scott reaction-diffusion stepped on the GPU in an RGBA16F ping-pong pair (u in red, v in green).
@MainActor
final class GrayScottGPU {
    /// The sampler name of the state the step reads.
    nonisolated static let stateInput = "uState"

    /// The step program: one explicit Euler step of the five-point stencil with index wrap, clamped to 0…1.
    nonisolated static let stepFragment = """
    precision highp float;
    precision highp int;
    uniform highp sampler2D uState;
    uniform int uGrid;
    uniform float uFeed;
    uniform float uKill;
    uniform float uTimeStep;
    out vec4 color;
    vec2 cellAt(ivec2 cell) {
        return texelFetch(uState, (cell + ivec2(uGrid)) % uGrid, 0).rg;
    }
    void main() {
        ivec2 cell = ivec2(gl_FragCoord.xy);
        vec2 centre = cellAt(cell);
        vec2 left = cellAt(cell + ivec2(-1, 0));
        vec2 right = cellAt(cell + ivec2(1, 0));
        vec2 down = cellAt(cell + ivec2(0, -1));
        vec2 up = cellAt(cell + ivec2(0, 1));
        vec2 lap = (left + right) + (down + up) - 4.0 * centre;
        float u = centre.x;
        float v = centre.y;
        float uvv = u * v * v;
        float nu = u + uTimeStep * (\(GrayScott.diffusionU) * lap.x - uvv + uFeed * (1.0 - u));
        float nv = v + uTimeStep * (\(GrayScott.diffusionV) * lap.y + uvv - (uFeed + uKill) * v);
        color = vec4(clamp(nu, 0.0, 1.0), clamp(nv, 0.0, 1.0), 0.0, 1.0);
    }
    """

    /// Cells per side.
    let gridSize: Int
    /// The RGBA16F pair; `pair.read` holds the current u, v.
    let pair: PingPongTarget
    /// The step pass.
    let pass: FieldPass
    /// Steps run since creation (one swap of the pair each).
    private(set) var stepCount = 0
    private var released = false

    /// Makes the RGBA16F pair (`a16.grayscott.a`, `a16.grayscott.b`) and the step pass for a `gridSize` × `gridSize`
    /// grid. Throws ``GrayScottGPUError/floatTargetsUnavailable`` without half-float render targets,
    /// ``GrayScottGPUError/incompleteTarget(_:)`` when the pair cannot be made and ``GrayScottGPUError/compile(_:)``
    /// when the program fails; nothing stays allocated after a throw.
    init(registry: ResourceRegistry, gridSize: Int) throws {
        guard gridSize >= 1 else { throw GrayScottGPUError.invalidGridSize(gridSize) }
        guard FloatRenderSupport.detect(in: registry).supported else { throw GrayScottGPUError.floatTargetsUnavailable }
        let made: PingPongTarget
        do {
            made = try PingPongTarget(registry: registry, width: gridSize, height: gridSize, format: .rgba16f,
                                      label: "a16.grayscott")
        } catch {
            throw GrayScottGPUError.incompleteTarget(String(describing: error))
        }
        do {
            pass = try FieldPass(registry: registry, fragment: Self.stepFragment, inputs: [Self.stateInput],
                                 label: "a16.grayscott.step")
        } catch {
            made.release()
            if case .compile(let message) = error { throw GrayScottGPUError.compile(message) }
            throw GrayScottGPUError.compile(String(describing: error))
        }
        pair = made
        self.gridSize = gridSize
    }

    /// Uploads `field` (channel 0 = u, channel 1 = v; rows bottom-up) into the read target, rounded to half precision
    /// by GL. Returns false for a field that is not `gridSize` × `gridSize` with at least two channels, a released or
    /// stale pair, or a refused upload. Channels beyond the second are ignored.
    @discardableResult
    func load(_ field: FieldGrid) -> Bool {
        guard !released, pair.isValid, field.width == gridSize, field.height == gridSize, field.channels >= 2 else {
            return false
        }
        var rgba = [Float](repeating: 0, count: gridSize * gridSize * 4)
        for cell in 0..<(gridSize * gridSize) {
            rgba[cell * 4] = field.values[cell * field.channels]
            rgba[cell * 4 + 1] = field.values[cell * field.channels + 1]
            rgba[cell * 4 + 3] = 1
        }
        return pair.read.upload(rgbaFloats: rgba)
    }

    /// Runs `count` steps with feed F, kill k and time step Δt, each reading `pair.read`, drawing into `pair.write`
    /// and swapping. Throws `FieldPassError.stale` once released or after a context recreation, and any other
    /// `FieldPassError` the pass reports; a negative `count` runs nothing.
    func step(feed: Float, kill: Float, timeStep: Float, count: Int) throws {
        guard !released else { throw FieldPassError.stale }
        let uniforms: [String: FieldUniform] = ["uGrid": .int(Int32(gridSize)), "uFeed": .float(feed),
                                                "uKill": .float(kill), "uTimeStep": .float(timeStep)]
        for _ in 0..<max(0, count) {
            try pass.run(pair: pair, input: Self.stateInput, uniforms: uniforms)
            stepCount += 1
        }
    }

    /// The current u, v as a two-channel `gridSize` × `gridSize` grid (rows bottom-up), read with
    /// `readFloatPixels`. When the read fails (released, stale or a GL error) every value is NaN, so no comparison
    /// with a reference can pass by accident.
    func readBack() -> FieldGrid {
        var grid = FieldGrid(width: gridSize, height: gridSize, channels: 2, fill: .nan)
        guard !released else { return grid }
        let rgba = pair.read.readFloatPixels()
        guard rgba.count == gridSize * gridSize * 4 else { return grid }
        for cell in 0..<(gridSize * gridSize) {
            grid.values[cell * 2] = rgba[cell * 4]
            grid.values[cell * 2 + 1] = rgba[cell * 4 + 1]
        }
        return grid
    }

    /// Releases the pair and the pass together (idempotent).
    func release() {
        guard !released else { return }
        released = true
        pair.release()
        pass.release()
    }
}
