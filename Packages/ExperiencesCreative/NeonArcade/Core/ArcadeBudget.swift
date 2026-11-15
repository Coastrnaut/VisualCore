// ArcadeBudget — feature 079 (A10-P05) T-A10-502 (FR-A10-501, FR-A10-502; clarification 1; research D1; data-model
// "ArcadeBudget"). The drawing budget of Neon Arcade's three quality levels, level 0 (the lowest) first:
//   level 0 — glow 1.2 × the object's radius, glow opacity ≤ 0.25, ≤ 48 live particles, no pulse;
//   level 1 — glow 1.4 ×, opacity ≤ 0.30, ≤ 128 particles, pulse;
//   level 2 — glow 1.6 ×, opacity ≤ 0.35, ≤ 256 particles, pulse (the full drawing of A10-P01…P04).
// The glow alpha is min(cap, base + pulse) (the pulse term only on a level that pulses; never below 0); a burst of n
// particles at full drawing becomes max(1, round(n × cap / 256)) particles, at most the cap. The budget is
// presentation only: the game state and its digest never depend on the level.
import Foundation

/// The glow and particle budget of one quality level.
public struct ArcadeBudget: Equatable, Sendable {
    /// The number of quality levels (level 0 the lowest, level 2 the full drawing).
    public static let levels = 3
    /// The particle cap of the full drawing (level 2); bursts are designed for it.
    public static let fullParticleCap = 256

    /// The quality level, 0…``levels`` − 1.
    public let level: Int
    /// A glow's radius as a multiple of its object's radius (1.2, 1.4, 1.6).
    public let glowFactor: Double
    /// The highest glow alpha, the pulse included (0.25, 0.30, 0.35).
    public let glowOpacityCap: Double
    /// The most live particles (48, 128, 256).
    public let particleCap: Int
    /// True when the glow alpha pulses (levels 1 and 2); reduced flashing removes the pulse at every level.
    public let pulse: Bool

    /// The budget of each level, level 0 first.
    static let table: [ArcadeBudget] = [
        ArcadeBudget(level: 0, glowFactor: 1.2, glowOpacityCap: 0.25, particleCap: 48, pulse: false),
        ArcadeBudget(level: 1, glowFactor: 1.4, glowOpacityCap: 0.30, particleCap: 128, pulse: true),
        ArcadeBudget(level: 2, glowFactor: 1.6, glowOpacityCap: 0.35, particleCap: 256, pulse: true),
    ]

    private init(level: Int, glowFactor: Double, glowOpacityCap: Double, particleCap: Int, pulse: Bool) {
        self.level = level; self.glowFactor = glowFactor; self.glowOpacityCap = glowOpacityCap
        self.particleCap = particleCap; self.pulse = pulse
    }

    /// The budget of quality level `level`, clamped to 0…2.
    public static func level(_ level: Int) -> ArcadeBudget { table[min(max(level, 0), levels - 1)] }

    /// Every level's budget, level 0 first.
    public static var all: [ArcadeBudget] { table }

    /// The glow alpha for the presenter's `base` alpha and signed `pulse` offset: min(cap, base + pulse) on a level
    /// that pulses, min(cap, base) on one that does not; never below 0 (a non-finite input counts as 0).
    public func glowAlpha(base: Double, pulse: Double) -> Double {
        let b = base.isFinite ? base : 0
        let p = (self.pulse && pulse.isFinite) ? pulse : 0
        return min(max(b + p, 0), glowOpacityCap)
    }

    /// The particle count of a burst designed as `count` particles at full drawing: max(1, round(count × cap / 256)),
    /// at most the cap; 0 for a count ≤ 0.
    public func burstCount(_ count: Int) -> Int {
        guard count > 0 else { return 0 }
        let scaled = (Double(count) * Double(particleCap) / Double(Self.fullParticleCap)).rounded()
        return min(max(Int(scaled), 1), particleCap)
    }
}
