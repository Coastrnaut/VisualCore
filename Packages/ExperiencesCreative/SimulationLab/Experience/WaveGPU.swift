// WaveGPU — feature 119 (A16-P03) T-A16-303 (FR-A16-301, FR-A16-302; clarifications Q1, Q2; contracts/gpu.md). The GPU
// twin of the CPU reference ``WaveField``: an RGBA16F `PingPongTarget` at the grid size holds the current height uⁿ in
// red and the previous height uⁿ⁻¹ in green, and one `FieldPass` performs one leapfrog step per run,
//   uⁿ⁺¹ = (2uⁿ − uⁿ⁻¹ + C²∇²uⁿ)(1 − γ),
// writing (uⁿ⁺¹, uⁿ), with `highp` arithmetic in the CPU's order and grouping: ∇² is
// (left + right) + (down + up) − 4 · centre, C² arrives as `uCourant2` and 1 − γ as `uKeep`. Every edge cell (x or y
// equal to 0 or n − 1, from `gl_FragCoord`) is written as (0, 0): the CPU result's border is always zero, so the
// stored uⁿ of the next pair is zero there too. Neighbours are read with `texelFetch` without wrap: only interior
// cells read them, and their neighbours are valid indices, so the registry's CLAMP_TO_EDGE sampling is never relied
// on. Storing a colour write in half precision is implementation-defined in GLES (round to nearest or toward zero),
// which is why `FloatFieldToleranceTests` compares with the CPU reference rounded both ways. The step shader lives in
// this file (`SimulationShaders.swift` keeps one writer).
//
// The type requires half-float render targets (`FloatRenderSupport.detect(in:)`); every call is made with the
// registry's context current on the main thread.
// Original work for VisualCore, Copyright (c) 2026 Coastrnaut, MIT License (repository LICENSE); no third-party code.
import SimulationLabCore
import VisualCoreRendering
import VisualCoreSimulation

/// Why a ``WaveGPU`` could not be made.
enum WaveGPUError: Error, Equatable, Sendable {
    /// The context cannot render into RGBA16F targets (`FloatRenderSupport` reports no support).
    case floatTargetsUnavailable
    /// The grid size is below 3 (a field with no interior cell).
    case invalidGridSize(Int)
    /// The RGBA16F ping-pong pair could not be made (over budget or an incomplete framebuffer); the description of
    /// the underlying error.
    case incompleteTarget(String)
    /// The step program failed to compile or link (its first diagnostic).
    case compile(String)
}

/// The leapfrog wave field stepped on the GPU in an RGBA16F ping-pong pair (uⁿ in red, uⁿ⁻¹ in green), with a fixed
/// zero border.
@MainActor
final class WaveGPU {
    /// The sampler name of the state the step reads.
    nonisolated static let stateInput = "uState"

    /// The step program: one leapfrog step of the five-point stencil, zero on the edge cells, no wrap, each height rounded
    /// to the nearest half-float in the shader (`toHalf`) so the store is exact.
    nonisolated static let stepFragment = """
    precision highp float;
    precision highp int;
    uniform highp sampler2D uState;
    uniform int uGrid;
    uniform float uCourant2;
    uniform float uKeep;
    out vec4 color;
    // Rounds x to the nearest half-float (ties to even), as the CPU reference's float16 does, so the RGBA16F
    // store holds it exactly whatever rounding the driver applies to colour writes (feature 119).
    float toHalf(float x) {
        float a = abs(x);
        if (a >= 65520.0) { return x; }
        int e = ((floatBitsToInt(a) >> 23) & 255) - 127;
        float step = a < 6.103515625e-5 ? 5.9604644775390625e-8 : intBitsToFloat((e - 10 + 127) << 23);
        float q = roundEven(a / step) * step;
        return x < 0.0 ? -q : q;
    }
    float heightAt(ivec2 cell) {
        return texelFetch(uState, cell, 0).r;
    }
    void main() {
        ivec2 cell = ivec2(gl_FragCoord.xy);
        if (cell.x <= 0 || cell.y <= 0 || cell.x >= uGrid - 1 || cell.y >= uGrid - 1) {
            color = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }
        vec2 centre = texelFetch(uState, cell, 0).rg;
        float u = centre.x;
        float previous = centre.y;
        float lap = (heightAt(cell + ivec2(-1, 0)) + heightAt(cell + ivec2(1, 0)))
            + (heightAt(cell + ivec2(0, -1)) + heightAt(cell + ivec2(0, 1))) - 4.0 * u;
        float next = (2.0 * u - previous + uCourant2 * lap) * uKeep;
        color = vec4(toHalf(next), u, 0.0, 1.0);
    }
    """

    /// Cells per side.
    let gridSize: Int
    /// The RGBA16F pair; `pair.read` holds the current uⁿ (red) and uⁿ⁻¹ (green).
    let pair: PingPongTarget
    /// The step pass.
    let pass: FieldPass
    /// Steps run since creation (one swap of the pair each).
    private(set) var stepCount = 0
    private var released = false

    /// The target holding the current state (the pair's read target), for the display pass.
    var current: RenderTarget { pair.read }

    /// Makes the RGBA16F pair (`a16.wave.a`, `a16.wave.b`) and the step pass for a `gridSize` × `gridSize` grid.
    /// Throws ``WaveGPUError/floatTargetsUnavailable`` without half-float render targets,
    /// ``WaveGPUError/invalidGridSize(_:)`` below 3 cells per side, ``WaveGPUError/incompleteTarget(_:)`` when the pair
    /// cannot be made and ``WaveGPUError/compile(_:)`` when the program fails; nothing stays allocated after a throw.
    init(registry: ResourceRegistry, gridSize: Int) throws {
        guard gridSize >= 3 else { throw WaveGPUError.invalidGridSize(gridSize) }
        guard FloatRenderSupport.detect(in: registry).supported else { throw WaveGPUError.floatTargetsUnavailable }
        let made: PingPongTarget
        do {
            made = try PingPongTarget(registry: registry, width: gridSize, height: gridSize, format: .rgba16f,
                                      label: "a16.wave")
        } catch {
            throw WaveGPUError.incompleteTarget(String(describing: error))
        }
        do {
            pass = try FieldPass(registry: registry, fragment: Self.stepFragment, inputs: [Self.stateInput],
                                 label: "a16.wave.step")
        } catch {
            made.release()
            if case .compile(let message) = error { throw WaveGPUError.compile(message) }
            throw WaveGPUError.compile(String(describing: error))
        }
        pair = made
        self.gridSize = gridSize
    }

    /// Uploads `field` into the read target: channel 0 of `current` (uⁿ) into red and channel 0 of `previous`
    /// (uⁿ⁻¹, or `current` when there is none) into green, rows bottom-up, rounded to half precision by GL. Returns
    /// false for grids that are not `gridSize` × `gridSize` with at least one channel, a released or stale pair, or
    /// a refused upload. Channels beyond the first are ignored.
    @discardableResult
    func load(_ field: SimulationField) -> Bool {
        let now = field.current
        let before = field.previous ?? field.current
        guard !released, pair.isValid, now.width == gridSize, now.height == gridSize, now.channels >= 1,
              before.width == gridSize, before.height == gridSize, before.channels >= 1 else {
            return false
        }
        var rgba = [Float](repeating: 0, count: gridSize * gridSize * 4)
        for cell in 0..<(gridSize * gridSize) {
            rgba[cell * 4] = now.values[cell * now.channels]
            rgba[cell * 4 + 1] = before.values[cell * before.channels]
            rgba[cell * 4 + 3] = 1
        }
        return pair.read.upload(rgbaFloats: rgba)
    }

    /// Runs `count` steps with Courant number `courant` (C = c · Δt) and damping `damping` (γ), each reading
    /// `pair.read`, drawing into `pair.write` and swapping. C² and 1 − γ are formed in `Double` and rounded to
    /// `Float` once, as ``WaveField`` does. Throws `FieldPassError.stale` once released or after a context
    /// recreation, and any other `FieldPassError` the pass reports; a negative `count` runs nothing.
    func step(courant: Float, damping: Float, count: Int) throws {
        guard !released else { throw FieldPassError.stale }
        let c = Double(courant)
        let uniforms: [String: FieldUniform] = ["uGrid": .int(Int32(gridSize)), "uCourant2": .float(Float(c * c)),
                                                "uKeep": .float(Float(1 - Double(damping)))]
        for _ in 0..<max(0, count) {
            try pass.run(pair: pair, input: Self.stateInput, uniforms: uniforms)
            stepCount += 1
        }
    }

    /// The current state read with `readFloatPixels`: red as the one-channel `current` (uⁿ) and green as the
    /// one-channel `previous` (uⁿ⁻¹), `gridSize` × `gridSize`, rows bottom-up. When the read fails (released, stale
    /// or a GL error) every value is NaN, so no comparison with a reference can pass by accident.
    func readBack() -> SimulationField {
        var now = FieldGrid(width: gridSize, height: gridSize, channels: 1, fill: .nan)
        var before = FieldGrid(width: gridSize, height: gridSize, channels: 1, fill: .nan)
        guard !released else { return SimulationField(current: now, previous: before) }
        let rgba = pair.read.readFloatPixels()
        guard rgba.count == gridSize * gridSize * 4 else { return SimulationField(current: now, previous: before) }
        for cell in 0..<(gridSize * gridSize) {
            now.values[cell] = rgba[cell * 4]
            before.values[cell] = rgba[cell * 4 + 1]
        }
        return SimulationField(current: now, previous: before)
    }

    /// Releases the pair and the pass together (idempotent).
    func release() {
        guard !released else { return }
        released = true
        pair.release()
        pass.release()
    }
}
