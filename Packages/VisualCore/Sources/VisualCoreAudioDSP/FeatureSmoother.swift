// FeatureSmoother — feature 048 (A06-P02) T-A06-203; FR-A06-204, SC-A06-204.
// Research D5; contract specs/048-ml-p02-feature-analysis/contracts/api.md.
import Foundation

/// A frame-rate independent one-pole smoother with separate attack and release time constants.
///
/// Each ``update(target:elapsed:)`` moves ``value`` towards the target by the coefficient `1 − exp(−Δt/τ)`, where
/// `τ` is ``attack`` while the target is above the current value and ``release`` otherwise, and `Δt` is the actual
/// elapsed time of the update. A step therefore reaches `1 − 1/e` (about 63 %) of its height after ``attack``
/// seconds and decays to `1/e` (about 37 %) after ``release`` seconds, whatever the update rate.
///
/// Non-finite targets are treated as 0; negative or non-finite elapsed times are treated as 0 and leave the value
/// unchanged. The struct is a plain value and allocates nothing.
public struct FeatureSmoother: Sendable, Equatable {
    /// Smallest time constant in seconds; smaller or non-finite inputs are clamped to it.
    public static let minimumTimeConstant: Double = 1e-6

    /// Attack time constant in seconds, used while the target is above ``value``.
    public let attack: Double
    /// Release time constant in seconds, used while the target is at or below ``value``.
    public let release: Double
    /// The current smoothed value; starts at 0.
    public private(set) var value: Float = 0

    /// Creates a smoother at value 0.
    ///
    /// - Parameters:
    ///   - attack: rise time constant in seconds; clamped to at least ``minimumTimeConstant``.
    ///   - release: fall time constant in seconds; clamped to at least ``minimumTimeConstant``.
    public init(attack: Double, release: Double) {
        self.attack = Self.clampedTimeConstant(attack)
        self.release = Self.clampedTimeConstant(release)
    }

    /// Moves ``value`` towards `target` over `elapsed` seconds and returns the new value.
    ///
    /// - Parameters:
    ///   - target: the value to approach; a non-finite target is treated as 0.
    ///   - elapsed: seconds since the previous update; negative or non-finite values are treated as 0.
    /// - Returns: the updated ``value``.
    @discardableResult
    public mutating func update(target: Float, elapsed: Double) -> Float {
        let goal: Float = target.isFinite ? target : 0
        let dt = elapsed.isFinite ? max(elapsed, 0) : 0
        guard dt > 0 else { return value }
        let tau = goal > value ? attack : release
        let coefficient = Float(1 - exp(-dt / tau))
        value += (goal - value) * coefficient
        if !value.isFinite { value = 0 }
        return value
    }

    /// Returns ``value`` to 0.
    public mutating func reset() {
        value = 0
    }

    private static func clampedTimeConstant(_ seconds: Double) -> Double {
        guard seconds.isFinite else { return minimumTimeConstant }
        return max(seconds, minimumTimeConstant)
    }
}
