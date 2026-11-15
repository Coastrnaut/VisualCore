// Difficulty — feature 076 (A10-P02) T-A10-202 (FR-A10-203, FR-A10-205; clarification 3; research D2; data-model
// "Difficulty"). A pure function of the wave number: level L = min(wave − 1, 8) (waves below 1 count as wave 1); fall
// speed (3 + 0.2 L) … min(5, 3.6 + 0.2 L) units/s; spawn gap max(20, 40 − 2.5 L) steps rounded down (40, 37, 35, 32,
// 30, 27, 25, 22, 20); orb multiplier 1 + L / 2 with integer division (1, 1, 2, 2, 3, 3, 4, 4, 5). Every value is
// non-decreasing in difficulty from wave to wave and stops at the ceiling (wave 9 on: 4.6…5.0 units/s, gap 20,
// multiplier 5); the fall speed never exceeds 5 units/s, which keeps the capsule speed bound of A10-P01 research D3.
import Foundation

/// The difficulty of one wave.
public struct Difficulty: Equatable, Sendable {
    /// The highest level (reached at wave 9).
    public static let ceilingLevel = 8
    /// The highest fall speed of any wave, in units per second (the capsule bound).
    public static let maxFallSpeed = 5.0
    /// The smallest spawn gap of any wave, in steps.
    public static let minSpawnGap = 20

    /// The wave number this difficulty is for (≥ 1).
    public let wave: Int
    /// The level, 0…``ceilingLevel``.
    public let level: Int
    /// The fall speed range in units per second.
    public let fallSpeed: ClosedRange<Double>
    /// Steps between spawns of the per-gap patterns.
    public let spawnGap: Int
    /// The factor an orb's catalog value is multiplied by when it spawns in this wave.
    public let orbMultiplier: Int

    /// The difficulty of `wave` (values below 1 count as wave 1).
    public init(wave: Int) {
        let wave = max(wave, 1)
        let level = min(wave - 1, Self.ceilingLevel)
        let l = Double(level)
        self.wave = wave
        self.level = level
        let low = 3 + 0.2 * l
        fallSpeed = low...max(low, min(Self.maxFallSpeed, 3.6 + 0.2 * l))
        spawnGap = max(Self.minSpawnGap, Int((40 - 2.5 * l).rounded(.down)))
        orbMultiplier = 1 + level / 2
    }

    /// The difficulty at the ceiling (wave 9 and later).
    public static var ceiling: Difficulty { Difficulty(wave: ceilingLevel + 1) }
}
