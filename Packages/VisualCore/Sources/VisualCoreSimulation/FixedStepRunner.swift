// FixedStepRunner.swift — deterministic fixed-step advancing with pause/resume and replayable control streams
// (feature 033 A04-P01 T-A04-103; G-SIMSTEP; FR-A04-103, FR-A04-104; research R5).

/// A simulation that advances in fixed steps and can fingerprint its state (for replay checks).
public protocol FixedStepSimulation {
    /// Advances the state by `dt` seconds.
    mutating func step(_ dt: Double)
    /// A fingerprint of the state; equal states give equal checksums.
    func checksum() -> UInt64
}

extension ParticleSystem: FixedStepSimulation {}

/// Commands to apply at given step indices (0 = before the first step). Entries keep their insertion order within a
/// step; entries with a negative step are dropped.
public struct ControlStream<Command> {
    /// One command and the step index before which it applies.
    public struct Entry {
        /// Steps completed when the command applies.
        public let step: Int
        /// The command.
        public let command: Command
        /// Creates an entry applying `command` before step `step`.
        public init(step: Int, command: Command) { self.step = step; self.command = command }
    }

    /// Entries sorted by step (stable).
    public let entries: [Entry]

    /// Creates a stream from `(step, command)` pairs in any order.
    public init(_ entries: [(step: Int, command: Command)] = []) {
        self.entries = entries.enumerated().filter { $0.element.step >= 0 }
            .sorted { $0.element.step != $1.element.step ? $0.element.step < $1.element.step : $0.offset < $1.offset }
            .map { Entry(step: $0.element.step, command: $0.element.command) }
    }

    /// The commands that apply at `step`, in insertion order.
    public func commands(at step: Int) -> [Command] { entries.filter { $0.step == step }.map(\.command) }
}

extension ControlStream: Sendable where Command: Sendable {}
extension ControlStream.Entry: Sendable where Command: Sendable {}

/// Runs a `FixedStepSimulation` with a `FixedStepClock`: fixed steps, a per-frame step cap, pause and resume without
/// catch-up, and a control stream applied by step index, so a replay gives the same state however frames are split.
public struct FixedStepRunner<Simulation: FixedStepSimulation, Command> {
    /// The simulation being advanced.
    public private(set) var simulation: Simulation
    /// Steps completed so far.
    public private(set) var stepIndex = 0
    /// Whether frames are currently ignored (`advance(frame:)` runs no step).
    public private(set) var isPaused = false
    /// The clock turning frame times into steps (its counters report dropped time and invalid frames).
    public private(set) var clock: FixedStepClock
    /// The commands to apply during the run.
    public let stream: ControlStream<Command>
    private let apply: @Sendable (inout Simulation, Command) -> Void
    private var nextEntry = 0

    /// Creates a runner; `apply` performs one command on the simulation just before the step it is scheduled for.
    public init(simulation: Simulation, clock: FixedStepClock = FixedStepClock(), stream: ControlStream<Command> = ControlStream(),
                apply: @escaping @Sendable (inout Simulation, Command) -> Void) {
        self.simulation = simulation; self.clock = clock; self.stream = stream; self.apply = apply
    }

    /// Adds a frame's elapsed time and runs the resulting steps (none while paused); returns the number of steps run.
    @discardableResult
    public mutating func advance(frame dt: Double) -> Int {
        guard !isPaused else { return 0 }
        let n = clock.advance(by: dt)
        for _ in 0..<n { stepNow() }
        return n
    }

    /// Runs one step whether or not the runner is paused (a "Step" control).
    public mutating func stepOnce() { stepNow() }

    /// Runs `steps` steps directly, without the clock (replays and tests).
    public mutating func run(steps: Int) { for _ in 0..<max(steps, 0) { stepNow() } }

    /// Stops advancing on frames.
    public mutating func pause() { isPaused = true }

    /// Advances on frames again, discarding any time accumulated before the pause (no catch-up).
    public mutating func resume() {
        isPaused = false
        clock.resetAccumulator()
    }

    /// Edits the simulation directly (for example a live drag); such edits are not part of the control stream.
    public mutating func mutate(_ body: (inout Simulation) -> Void) { body(&simulation) }

    private mutating func stepNow() {
        while nextEntry < stream.entries.count, stream.entries[nextEntry].step <= stepIndex {
            apply(&simulation, stream.entries[nextEntry].command)
            nextEntry += 1
        }
        simulation.step(clock.step)
        stepIndex += 1
    }
}

extension FixedStepRunner: Sendable where Simulation: Sendable, Command: Sendable {}
