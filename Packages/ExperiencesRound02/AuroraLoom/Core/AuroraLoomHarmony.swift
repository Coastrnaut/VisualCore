// AuroraLoomHarmony — feature 301 (R02-G01-01) T-R02G0101-002 (FR-R02G0101-002, 003; clarifications Q1, Q2; research
// R2, R3). The exact phase model. A phase is a count of 1/4,096 turn modulo 4,096. Ribbon r at the gate at s sixteenths
// and tick n has phase wave_r · s · 16 + phase_r · 256 + ω_r · n; the target harmony at that gate is Θ + Ω · n. The
// residual is their difference wrapped into −2,048 … 2,047. A setting wins when every residual of every ribbon at every
// gate stays within the tolerance (inclusive) for the ticks 0 … 2P − 1, P = 4,096 / Ω (two complete periods).

/// The three ribbons' wave and phase steps (each 0 … 15).
public struct AuroraLoomSteps: Sendable, Equatable, Hashable, Codable {
    /// Wave steps of ribbons 0, 1, 2.
    public var wave: [Int]
    /// Phase steps of ribbons 0, 1, 2.
    public var phase: [Int]

    /// Steps of the given values (not checked; the level and the play check them).
    public init(wave: [Int], phase: [Int]) {
        self.wave = wave
        self.phase = phase
    }
}

/// The largest residual of a setting: where it is and how large.
public struct AuroraLoomMismatch: Sendable, Equatable, Codable {
    /// The ribbon (0 … 2).
    public let ribbon: Int
    /// The gate (0 … 3).
    public let gate: Int
    /// The tick (0 … 2P − 1).
    public let tick: Int
    /// The signed residual in 1/4,096 turn.
    public let residual: Int

    /// A mismatch of the given values.
    public init(ribbon: Int, gate: Int, tick: Int, residual: Int) {
        self.ribbon = ribbon
        self.gate = gate
        self.tick = tick
        self.residual = residual
    }
}

/// The exact phase model of Aurora Loom.
public enum AuroraLoomHarmony {
    /// Units per turn.
    public static let unitsPerTurn = 4_096

    /// The phase of `ribbon` at `gate` and `tick`, 0 … 4,095.
    public static func phase(ribbon: Int, gate: Int, tick: Int, steps: AuroraLoomSteps, level: AuroraLoomLevel) -> Int {
        let position = level.gates[gate].position
        let raw = steps.wave[ribbon] * position * 16 + steps.phase[ribbon] * 256 + level.ribbons[ribbon].omega * tick
        return wrapPositive(raw)
    }

    /// The target harmony at `gate` and `tick`, 0 … 4,095.
    public static func target(gate: Int, tick: Int, level: AuroraLoomLevel) -> Int {
        wrapPositive(level.gates[gate].target + level.omega * tick)
    }

    /// The signed residual (ribbon phase − target) wrapped into −2,048 … 2,047.
    public static func residual(ribbon: Int, gate: Int, tick: Int, steps: AuroraLoomSteps, level: AuroraLoomLevel) -> Int {
        signed(phase(ribbon: ribbon, gate: gate, tick: tick, steps: steps, level: level)
               - target(gate: gate, tick: tick, level: level))
    }

    /// Whether every residual stays within the tolerance for the two periods.
    public static func wins(_ steps: AuroraLoomSteps, level: AuroraLoomLevel) -> Bool {
        let ticks = 2 * level.period
        for r in 0..<3 {
            for g in 0..<4 {
                for n in 0..<ticks
                where abs(residual(ribbon: r, gate: g, tick: n, steps: steps, level: level)) > level.tolerance {
                    return false
                }
            }
        }
        return true
    }

    /// The largest |residual| over the two periods; ties go to the lowest ribbon, then gate, then tick.
    public static func worst(_ steps: AuroraLoomSteps, level: AuroraLoomLevel) -> AuroraLoomMismatch {
        let ticks = 2 * level.period
        var best = AuroraLoomMismatch(ribbon: 0, gate: 0, tick: 0,
                                      residual: residual(ribbon: 0, gate: 0, tick: 0, steps: steps, level: level))
        for r in 0..<3 {
            for g in 0..<4 {
                for n in 0..<ticks {
                    let value = residual(ribbon: r, gate: g, tick: n, steps: steps, level: level)
                    if abs(value) > abs(best.residual) {
                        best = AuroraLoomMismatch(ribbon: r, gate: g, tick: n, residual: value)
                    }
                }
            }
        }
        return best
    }

    /// `value` modulo 4,096 in 0 … 4,095.
    static func wrapPositive(_ value: Int) -> Int {
        let m = value % unitsPerTurn
        return m < 0 ? m + unitsPerTurn : m
    }

    /// `value` modulo 4,096 in −2,048 … 2,047.
    static func signed(_ value: Int) -> Int {
        wrapPositive(value + unitsPerTurn / 2) - unitsPerTurn / 2
    }
}
