// RailFlight — feature 054 (A07-P01) T-A07-102 (FR-A07-102, FR-A07-104; gap G-CAMERARAIL; research D3).
// Deterministic travel along a rail: speed eases toward a target with clamped acceleration; time steps are capped.
import Foundation

/// The flight state along a rail: travelled distance and a speed that approaches the target speed within
/// ``ComfortLimits`` (trapezoidal profile). The same start state, limits and time steps give the same states.
public struct RailFlight: Sendable, Equatable, Codable {
    /// Largest time step applied by one ``advance(by:limits:)`` call, seconds (longer steps are capped).
    public static let maxStep = 0.1
    /// Sway period along the rail, world units.
    public static let swayPeriod = 40.0

    /// Travelled distance along the rail, world units (the rail wraps it).
    public var distance: Double
    /// Current speed, world units per second.
    public var speed: Double
    /// Requested speed; the effective target is clamped to [0, `maxSpeed`].
    public var targetSpeed: Double
    /// When true the flight eases to a stop (effective target 0) while keeping `targetSpeed`.
    public var paused: Bool

    /// Creates a flight state.
    public init(distance: Double = 0, speed: Double = 0, targetSpeed: Double = 0, paused: Bool = false) {
        self.distance = distance
        self.speed = speed
        self.targetSpeed = targetSpeed
        self.paused = paused
    }

    /// Advances by `dt` seconds: a NaN, infinite, zero or negative `dt` changes nothing; `dt` is capped at
    /// ``maxStep``; speed moves toward the effective target by at most `maxAcceleration · dt` (an over-limit speed
    /// decelerates at that rate, never jumps); distance grows by the average speed of the step times `dt`.
    ///
    /// - Parameters:
    ///   - dt: Elapsed time in seconds.
    ///   - limits: The comfort limits in force.
    public mutating func advance(by dt: Double, limits: ComfortLimits) {
        guard dt.isFinite, dt > 0 else { return }
        let step = min(dt, Self.maxStep)
        let requested = targetSpeed.isFinite ? targetSpeed : 0
        let target = paused ? 0 : max(0, min(requested, limits.maxSpeed))
        let maxChange = max(0, limits.maxAcceleration) * step
        let newSpeed = speed + min(max(target - speed, -maxChange), maxChange)
        distance += (speed + newSpeed) / 2 * step
        speed = newSpeed
    }

    /// Lateral sway offset, `swayAmplitude · sin(2π · distance ÷ 40)` world units (0 under reduced motion).
    ///
    /// - Parameter limits: The comfort limits in force.
    public func sway(limits: ComfortLimits) -> Double {
        limits.swayAmplitude * sin(2 * .pi * distance / Self.swayPeriod)
    }
}
