// AutomatonGPU — feature 118 (A16-P02) T-A16-202 (FR-A16-201, FR-A16-203; clarification Q3; contracts/gpu.md). The GPU
// mirror of the CPU reference ``AutomatonRule``: an RGBA8 `PingPongTarget` at the grid size holds the cells (alive =
// red 255, dead = 0), and one `FieldPass` (`SimulationShaders.automatonStep`) runs one generation per run, reading
// `pair.read` with `texelFetch` thresholded at 0.5, wrapping neighbours by index modulo the grid size and drawing
// into `pair.write` before the pair swaps, so no step samples the texture it writes.
//
// The rule is passed as two 9-bit integer masks (`int` uniforms `uBirth` and `uSurvival`): bit k is set when a
// neighbour count of k is in the birth or survival set (``AutomatonGPU/mask(_:)``); Life B3/S23 is birth 0b1000 = 8 and
// survival 0b1100 = 12. Every value the pass writes is exactly 0 or 1, which RGBA8 stores without rounding, so the GPU
// field equals the CPU reference after any number of steps (``AutomatonParityTests``).
//
// The pair and the pass are made together and released together; a compile failure or a pair that cannot be made
// throws and leaves nothing allocated. Every call is made with the registry's context current on the main thread.
import SimulationLabCore
import VisualCoreRendering
import VisualCoreSimulation

/// Why an ``AutomatonGPU`` could not be made.
enum AutomatonGPUError: Error, Equatable, Sendable {
    /// The grid size is below 1.
    case invalidGridSize(Int)
    /// The RGBA8 ping-pong pair could not be made (over budget or an incomplete framebuffer); the description of the
    /// underlying error.
    case incompleteTarget(String)
    /// The step program failed to compile or link (its first diagnostic).
    case compile(String)
}

/// A two-state cellular automaton stepped on the GPU in an RGBA8 ping-pong pair (alive in red).
@MainActor
final class AutomatonGPU {
    /// The sampler name of the field the step reads.
    nonisolated static let fieldInput = "uField"
    /// The label of the step pass (as reported to `FieldPass.runObserver`).
    nonisolated static let stepLabel = "a16.automaton.step"

    /// Cells per side.
    let gridSize: Int
    /// The RGBA8 pair; `pair.read` holds the current cells.
    let pair: PingPongTarget
    /// The step pass.
    let pass: FieldPass
    /// Steps run since creation (one swap of the pair each).
    private(set) var stepCount = 0
    /// Loads since creation.
    private(set) var loadCount = 0
    /// True after ``release()``.
    private(set) var released = false

    /// Makes the RGBA8 pair (`a16.automaton.a`, `a16.automaton.b`) and the step pass compiled from `stepFragment`
    /// (default ``SimulationShaders/automatonStep``; a test seam injects an invalid source) for a `gridSize` ×
    /// `gridSize` grid. Throws ``AutomatonGPUError/invalidGridSize(_:)`` below 1,
    /// ``AutomatonGPUError/incompleteTarget(_:)`` when the pair cannot be made and ``AutomatonGPUError/compile(_:)``
    /// when the program fails; nothing stays allocated after a throw.
    init(registry: ResourceRegistry, gridSize: Int, stepFragment: String = SimulationShaders.automatonStep) throws {
        guard gridSize >= 1 else { throw AutomatonGPUError.invalidGridSize(gridSize) }
        let made: PingPongTarget
        do {
            made = try PingPongTarget(registry: registry, width: gridSize, height: gridSize, format: .rgba8,
                                      label: "a16.automaton")
        } catch {
            throw AutomatonGPUError.incompleteTarget(String(describing: error))
        }
        do {
            pass = try FieldPass(registry: registry, fragment: stepFragment, inputs: [Self.fieldInput],
                                 label: Self.stepLabel)
        } catch {
            made.release()
            if case .compile(let message) = error { throw AutomatonGPUError.compile(message) }
            throw AutomatonGPUError.compile(String(describing: error))
        }
        pair = made
        self.gridSize = gridSize
    }

    /// The 9-bit mask of the neighbour counts in `counts`: bit k set for every k in 0…8 (others are ignored).
    nonisolated static func mask(_ counts: Set<Int>) -> Int32 {
        var bits: Int32 = 0
        for k in counts where (0...8).contains(k) { bits |= Int32(1) << Int32(k) }
        return bits
    }

    /// The target the display pass samples: the current cells (`pair.read`).
    var current: RenderTarget { pair.read }

    /// True while the pair and the pass are usable (not released, no context recreation since they were made).
    var isValid: Bool { !released && pair.isValid }

    /// Uploads channel 0 of `field` (alive when at least 0.5; rows bottom-up) into the read target as red 255 or 0,
    /// green and blue 0, alpha 255. Returns false for a field that is not `gridSize` × `gridSize`, a released or stale
    /// pair, or a refused upload.
    @discardableResult
    func load(_ field: FieldGrid) -> Bool {
        guard isValid, field.width == gridSize, field.height == gridSize else { return false }
        let cells = gridSize * gridSize
        var rgba = [Float](repeating: 0, count: cells * 4)
        for cell in 0..<cells {
            if field.values[cell * field.channels] >= 0.5 { rgba[cell * 4] = 1 }
            rgba[cell * 4 + 3] = 1
        }
        guard pair.read.upload(rgbaFloats: rgba) else { return false }
        loadCount += 1
        return true
    }

    /// Runs `count` generations of `rule`, each reading `pair.read`, drawing into `pair.write` and swapping. Throws
    /// `FieldPassError.stale` once released or after a context recreation, and any other `FieldPassError` the pass
    /// reports; a count of 0 or below runs nothing.
    func step(rule: AutomatonRule, count: Int) throws {
        guard !released else { throw FieldPassError.stale }
        let uniforms: [String: FieldUniform] = ["uGrid": .int(Int32(gridSize)), "uBirth": .int(Self.mask(rule.birth)),
                                                "uSurvival": .int(Self.mask(rule.survival))]
        var done = 0
        while done < count {
            try pass.run(pair: pair, input: Self.fieldInput, uniforms: uniforms)
            stepCount += 1
            done += 1
        }
    }

    /// The current cells as a one-channel `gridSize` × `gridSize` grid (rows bottom-up): 1 where red is at least 128,
    /// else 0. When the read fails (released, stale or a GL error) every value is NaN, so no comparison with a
    /// reference can pass by accident.
    func readBack() -> FieldGrid {
        var grid = FieldGrid(width: gridSize, height: gridSize, channels: 1, fill: .nan)
        guard isValid else { return grid }
        let rgba = pair.read.readPixels()
        guard rgba.count == gridSize * gridSize * 4 else { return grid }
        for cell in 0..<(gridSize * gridSize) {
            grid.values[cell] = rgba[cell * 4] >= 128 ? 1 : 0
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
