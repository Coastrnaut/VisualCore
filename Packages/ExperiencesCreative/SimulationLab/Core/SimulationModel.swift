// SimulationModel — feature 117 (A16-P01) T-A16-104 (FR-A16-112, FR-A16-120; clarifications Q1–Q5). The pure,
// GPU-free simulation the experience adapter wraps: a valid spec, its scheduler and the current field (and, for the
// wave, the previous one), rounded to the kind's storage precision after every iteration.
// - `step()` runs exactly one iteration of the family's rule and adds one to the step count, whatever the scheduler
//   says; `singleStep()` does the same only while paused (false, with nothing changed, while running).
// - `advance(hostStep:)` runs the iterations the scheduler grants for one host step (at most 16).
// - `reset()` returns to the seeded start and step 0, keeping running and speed.
// - `digest` is the SHA-256 (hex) of the saved state's JSON, so the same spec, seed and steps give the same digest.
// - Feature 120 (A16-P04) T-A16-402 (FR-A16-401): `paint(x:y:mode:)` applies
//   `SimulationBrush`; the step count is unchanged.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// A running simulation: spec, scheduler and field.
public struct SimulationModel: Equatable, Sendable {
    /// The spec (valid).
    public private(set) var spec: SimulationSpec
    /// The scheduler.
    public private(set) var scheduler: SimulationScheduler
    /// The field.
    public private(set) var field: SimulationField

    /// The seeded start of `spec`, at step 0 with the default speed; throws the spec's refusal.
    public init(spec: SimulationSpec, running: Bool = true) throws(SimulationRefusal) {
        if let refusal = spec.refusal() { throw refusal }
        self.spec = spec
        scheduler = SimulationScheduler(kind: spec.kind, running: running)
        field = Seeding.start(for: spec)
    }

    /// The simulation saved in `state`.
    public init(state: SimulationState) {
        spec = state.spec
        scheduler = state.scheduler
        field = state.field
    }

    /// The saved state (always representable: the model keeps a valid spec and a field of its shape).
    public var state: SimulationState {
        SimulationState(spec: spec, scheduler: scheduler, field: field)!
    }

    /// The SHA-256 (lowercase hex) of `state.encoded()`.
    public var digest: String { StableHash.sha256Hex([UInt8](state.encoded())) }

    /// The storage precision of the field.
    public var precision: StoragePrecision { spec.kind.storagePrecision }

    /// The iterations run since the seeded start.
    public var stepCount: Int { scheduler.stepCount }

    /// True while running.
    public var isRunning: Bool { scheduler.running }

    /// Runs exactly one iteration and adds one to the step count.
    public mutating func step() {
        iterate()
        scheduler.count(1)
    }

    /// One iteration while paused (true); false, with nothing changed, while running.
    @discardableResult
    public mutating func singleStep() -> Bool {
        guard scheduler.singleStep() else { return false }
        iterate()
        return true
    }

    /// Runs the scheduler's iterations for a host step of `hostStep` seconds; returns how many ran (0…16).
    @discardableResult
    public mutating func advance(hostStep: Double = SimulationScheduler.hostStep) -> Int {
        let n = scheduler.iterations(forHostStep: hostStep)
        for _ in 0..<n { iterate() }
        return n
    }

    /// Starts running.
    public mutating func run() { scheduler.run() }

    /// Pauses.
    public mutating func pause() { scheduler.pause() }

    /// Sets the speed index; false, with nothing changed, outside 0…4.
    @discardableResult
    public mutating func setSpeed(_ index: Int) -> Bool { scheduler.setSpeed(index) }

    /// Returns to the seeded start and step 0; running and speed are kept.
    public mutating func reset() {
        field = Seeding.start(for: spec)
        scheduler.reset()
    }

    /// Paints cell (x, y) with the family's brush (`SimulationBrush.painted`), values rounded to `precision`; the
    /// step count is unchanged. False, with nothing changed, outside the grid.
    @discardableResult
    public mutating func paint(x: Int, y: Int, mode: PaintMode) -> Bool {
        guard let painted = SimulationBrush.painted(field, kind: spec.kind, x: x, y: y, mode: mode,
                                                    precision: precision) else { return false }
        field = painted
        return true
    }

    /// One rule iteration of the field (no step count).
    private mutating func iterate() {
        switch spec.kind {
        case .automaton:
            field.current = spec.automatonRule.step(field.current)
        case .reactionDiffusion:
            field.current = GrayScott.step(field.current, spec: spec, precision: precision)
        case .wave:
            let previous = field.previous ?? field.current
            let next = WaveField.step(current: field.current, previous: previous, spec: spec, precision: precision)
            field.previous = field.current
            field.current = next
        }
    }
}
