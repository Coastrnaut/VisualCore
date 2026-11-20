// PhaseStepper — feature 215 (R02-F15) T-R02F15-004 (FR-R02F15-004; SC-R02F15-003; clarification Q3; research R5, R6).
// Deterministic fixed-step time for orbit phases. The time of tick k is t₀ + Double(k)·Δt, computed directly and never
// accumulated, so k single steps and one jump to k give the same bits and the error does not grow with k. The phase of a
// closed orbit is ((t − tₚ)/P) mod 1 in [0, 1); open orbits have none. Passages of periapsis (tₚ + jP) and apoapsis
// (tₚ + (j + ½)P) are listed for a half-open span [tₐ, t_b): every candidate time is computed by the same expression
// whatever the span, so adjacent spans partition the passages and each appears exactly once. An open orbit has one
// periapsis passage, at tₚ (index 0).
import Foundation

/// A passage of periapsis or apoapsis at a time.
public struct Passage: Sendable, Equatable {
    /// Which apsis is passed.
    public enum Kind: String, Sendable {
        /// Closest approach, at tₚ + jP.
        case periapsis
        /// Farthest point of a closed orbit, at tₚ + (j + ½)P.
        case apoapsis
    }

    /// Which apsis is passed.
    public let kind: Kind
    /// The revolution index j (0 for the passage at or just after tₚ).
    public let index: Int
    /// The time of the passage.
    public let time: Double
}

/// Fixed-step, drift-free time with orbit phases and apsis passages.
public struct PhaseStepper: Sendable, Equatable {
    /// The largest tick.
    public static let maxTick = 1_000_000_000
    /// The most passages one listing returns.
    public static let maxPassages = 1_000_000

    /// The time of tick 0.
    public let startTime: Double
    /// The duration of one tick, finite and positive.
    public let step: Double
    /// The current tick, 0 … ``maxTick``.
    public private(set) var tick: Int

    /// Creates a stepper at `tick`; refuses a start time or step that is not finite (or a step that is not positive)
    /// with ``OrbitError/invalidStep`` and a tick outside 0 … ``maxTick`` with ``OrbitError/tickLimit(_:)``.
    public init(startTime: Double = 0, step: Double, tick: Int = 0) throws(OrbitError) {
        guard startTime.isFinite, step.isFinite, step > 0 else { throw .invalidStep }
        guard (0...Self.maxTick).contains(tick) else { throw .tickLimit(tick) }
        self.startTime = startTime
        self.step = step
        self.tick = tick
    }

    /// The time of the current tick.
    public var time: Double { time(atTick: tick) }

    /// The time of tick `k`, t₀ + Double(k)·Δt.
    public func time(atTick k: Int) -> Double { startTime + Double(k) * step }

    /// Moves `n` ticks (negative moves back); refuses a result outside 0 … ``maxTick`` and leaves the tick unchanged.
    public mutating func advance(by n: Int = 1) throws(OrbitError) {
        let (next, overflow) = tick.addingReportingOverflow(n)
        guard !overflow else { throw .tickLimit(n < 0 ? Int.min : Int.max) }
        try jump(to: next)
    }

    /// Moves to tick `k`; refuses a tick outside 0 … ``maxTick`` and leaves the tick unchanged.
    public mutating func jump(to k: Int) throws(OrbitError) {
        guard (0...Self.maxTick).contains(k) else { throw .tickLimit(k) }
        tick = k
    }

    /// The phase of a closed `orbit` at `time`, ((t − tₚ)/P) mod 1 in [0, 1); nil for an open orbit or a time that is
    /// not finite.
    public static func phase(of orbit: ConicOrbit, at time: Double) -> Double? {
        guard let period = orbit.period, time.isFinite else { return nil }
        let x = (time - orbit.timeOfPeriapsis) / period
        guard x.isFinite else { return nil }
        let f = x - x.rounded(.down)
        return f >= 0 && f < 1 ? f : 0
    }

    /// The apsis passages of `orbit` in [`from`, `to`), in time order. Refuses ends that are not finite or reversed
    /// with ``OrbitError/invalidStep`` and a listing of more than ``maxPassages`` passages with
    /// ``OrbitError/spanLimit(_:)``.
    public static func passages(of orbit: ConicOrbit, from: Double, to: Double) throws(OrbitError) -> [Passage] {
        guard from.isFinite, to.isFinite, from <= to else { throw .invalidStep }
        let tp = orbit.timeOfPeriapsis
        guard let period = orbit.period else {
            return from <= tp && tp < to ? [Passage(kind: .periapsis, index: 0, time: tp)] : []
        }
        let lowRev = ((from - tp) / period).rounded(.down) - 1
        let highRev = ((to - tp) / period).rounded(.down) + 1
        let limit = 9.0e15
        guard abs(lowRev) < limit, abs(highRev) < limit else { throw .spanLimit(Int.max) }
        let estimate = 2 * (highRev - lowRev + 1)
        guard estimate <= Double(maxPassages + 8) else { throw .spanLimit(Int(estimate)) }
        var result: [Passage] = []
        for j in Int(lowRev)...Int(highRev) {
            let peri = tp + Double(j) * period
            if from <= peri && peri < to { result.append(Passage(kind: .periapsis, index: j, time: peri)) }
            let apo = tp + (Double(j) + 0.5) * period
            if from <= apo && apo < to { result.append(Passage(kind: .apoapsis, index: j, time: apo)) }
        }
        guard result.count <= maxPassages else { throw .spanLimit(result.count) }
        return result
    }
}
