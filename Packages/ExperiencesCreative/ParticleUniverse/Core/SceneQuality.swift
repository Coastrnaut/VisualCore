// SceneQuality.swift — the sandbox's quality tiers and particle budget (feature 034 A04-P02 T-A04-210; FR-A04-205; US3;
// spec clarification 2). Composition only: VisualCore's QualityPolicy decides the tier and ParticleBudget turns it into
// the live limit; this type fixes Particle Universe's choices (four tiers, best tier 1 under Low Power Mode).
import VisualCoreDiagnostics

/// Decides the quality tier once per frame and returns the effective particle limit.
public struct SceneQuality: Sendable, Equatable {
    /// Number of tiers.
    public static let tierCount = 4
    /// Best tier allowed while Low Power Mode is on.
    public static let lowPowerCeiling = 1

    /// The tier policy (2 s decision interval, 10 s calm period).
    public private(set) var policy = QualityPolicy(tierCount: SceneQuality.tierCount, lowPowerCeiling: SceneQuality.lowPowerCeiling)
    /// The budget mapping tiers to shares of the requested limit.
    public let budget: ParticleBudget
    /// The last effective limit (0 before the first update).
    public private(set) var effectiveLimit = 0

    /// Creates the controller with `budget` (default `.standard`).
    public init(budget: ParticleBudget = .standard) { self.budget = budget }

    /// The current tier (0 = best).
    public var tier: Int { policy.tier }

    /// Decides the tier for `conditions` at monotonic time `now` (seconds) and returns the effective limit for
    /// `requested`.
    @discardableResult
    public mutating func update(conditions: DeviceConditions, now: Double, requested: Int) -> Int {
        let tier = policy.decide(thermal: conditions.thermal, lowPower: conditions.lowPower, now: now)
        effectiveLimit = budget.limit(requested: requested, tier: tier)
        return effectiveLimit
    }

    /// Back to the best tier (a new screen).
    public mutating func reset() {
        policy.reset()
        effectiveLimit = 0
    }
}
