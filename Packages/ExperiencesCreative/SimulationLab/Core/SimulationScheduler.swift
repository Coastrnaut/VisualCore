// SimulationScheduler — feature 117 (A16-P01) T-A16-104 (FR-A16-120; clarification Q4; data-model
// "SimulationScheduler"). Run, pause, single step, reset and speed. The core is stepped by the host at 1/60 s; a
// running scheduler adds speed × base rate × host step to an accumulator (speeds 0.25, 0.5, 1, 2 and 4; base rates
// 10 automaton, 240 reaction-diffusion and 120 wave iterations per second) and runs its whole part, at most 16
// iterations per host step. When more than 16 are due, 16 run and the whole remainder is dropped (the accumulator
// returns to 0), so a long gap never turns into a burst. A paused scheduler runs nothing and keeps no accumulator.
// A whole part is taken with a tolerance of 10⁻⁹ iteration, so rational rates (2.5 / 60 per host step) land on whole
// iterations exactly when expected.
//
// Written as JSON with sorted keys: `{"accumulator": <a>, "kind": "<kind>", "running": <bool>, "speedIndex": <0…4>,
// "stepCount": <n>}`. Decoding throws `SimulationStateRefusal.outOfRange` for an unknown kind, a speed index outside
// 0…4, a negative step count or an accumulator outside 0 ≤ a < 1 (a missing key is a decoding error).

/// The iteration scheduler of one simulation.
public struct SimulationScheduler: Codable, Equatable, Sendable {
    /// The most iterations one host step runs.
    public static let maxIterationsPerHostStep = 16
    /// The speed factors by index.
    public static let speeds: [Double] = [0.25, 0.5, 1, 2, 4]
    /// The default speed index (×1).
    public static let defaultSpeedIndex = 2
    /// The host step of the core, 1/60 s.
    public static let hostStep = 1.0 / 60

    /// The family, which sets the base rate.
    public let kind: SimulationKind
    /// True while running; a paused scheduler runs only single steps.
    public private(set) var running: Bool
    /// The index into `speeds`, 0…4.
    public private(set) var speedIndex: Int
    /// The iterations run since the seeded start.
    public private(set) var stepCount: Int
    /// The fraction of an iteration carried to the next host step, 0 ≤ a < 1.
    public private(set) var accumulator: Double

    /// A scheduler at step 0 with an empty accumulator; `speedIndex` is clamped into 0…4.
    public init(kind: SimulationKind, running: Bool = true, speedIndex: Int = SimulationScheduler.defaultSpeedIndex) {
        self.init(kind: kind, running: running, speedIndex: min(max(speedIndex, 0), Self.speeds.count - 1),
                  stepCount: 0, accumulator: 0)
    }

    /// A scheduler with every field given (no validation).
    init(kind: SimulationKind, running: Bool, speedIndex: Int, stepCount: Int, accumulator: Double) {
        self.kind = kind
        self.running = running
        self.speedIndex = speedIndex
        self.stepCount = stepCount
        self.accumulator = accumulator
    }

    /// The speed factor.
    public var speed: Double { Self.speeds[speedIndex] }

    /// The iterations per second at the current speed.
    public var iterationsPerSecond: Double { kind.baseRate * speed }

    /// Starts running.
    public mutating func run() { running = true }

    /// Pauses and empties the accumulator.
    public mutating func pause() {
        running = false
        accumulator = 0
    }

    /// Sets the speed index; false, with nothing changed, outside 0…4.
    @discardableResult
    public mutating func setSpeed(_ index: Int) -> Bool {
        guard Self.speeds.indices.contains(index) else { return false }
        speedIndex = index
        return true
    }

    /// The iterations to run for a host step of `hostStep` seconds (0 when paused or for a step that is not finite
    /// and positive), at most 16; they are added to `stepCount`.
    public mutating func iterations(forHostStep hostStep: Double) -> Int {
        guard running, hostStep.isFinite, hostStep > 0 else { return 0 }
        let cap = Self.maxIterationsPerHostStep
        accumulator += iterationsPerSecond * hostStep
        let due = min((accumulator + 1e-9).rounded(.down), Double(cap + 1))
        var n = due.isFinite ? Int(due) : cap + 1
        if n > cap {
            n = cap
            accumulator = 0
        } else {
            accumulator = min(max(accumulator - Double(n), 0), 1 - 1e-9)
        }
        stepCount += n
        return n
    }

    /// Accounts for one single step: true (and `stepCount` + 1) while paused; false, with nothing changed, while
    /// running.
    public mutating func singleStep() -> Bool {
        guard !running else { return false }
        stepCount += 1
        return true
    }

    /// Returns to step 0 with an empty accumulator; running and speed are kept.
    public mutating func reset() {
        stepCount = 0
        accumulator = 0
    }

    /// Adds `n` iterations run outside `iterations(forHostStep:)` (for `SimulationModel.step()`).
    mutating func count(_ n: Int) { stepCount += n }

    // MARK: Codec

    private enum CodingKeys: String, CodingKey { case accumulator, kind, running, speedIndex, stepCount }

    /// Writes the JSON of the file header.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(accumulator, forKey: .accumulator)
        try c.encode(kind.rawValue, forKey: .kind)
        try c.encode(running, forKey: .running)
        try c.encode(speedIndex, forKey: .speedIndex)
        try c.encode(stepCount, forKey: .stepCount)
    }

    /// Reads and checks the JSON of the file header.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kindName = try c.decode(String.self, forKey: .kind)
        let running = try c.decode(Bool.self, forKey: .running)
        let speedIndex = try c.decode(Int.self, forKey: .speedIndex)
        let stepCount = try c.decode(Int.self, forKey: .stepCount)
        let accumulator = try c.decode(Double.self, forKey: .accumulator)
        guard let kind = SimulationKind(rawValue: kindName), Self.speeds.indices.contains(speedIndex), stepCount >= 0,
              accumulator.isFinite, accumulator >= 0, accumulator < 1 else {
            throw SimulationStateRefusal.outOfRange
        }
        self.init(kind: kind, running: running, speedIndex: speedIndex, stepCount: stepCount,
                  accumulator: accumulator)
    }
}
