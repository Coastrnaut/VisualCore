// AquariumBudget — feature 072 (A09-P05) T-A09-502 (FR-A09-510, FR-A09-520; clarifications 2 and 4; research D4).
// The drawing budget of the aquarium: how many bubbles each vent and how many motes are drawn and how many octaves the
// caustics use. Three quality levels — level 0 (24, 24, 2), level 1 (12, 12, 1), level 2 (6, 6, 0) — and ambient
// drawing (12, 12, 2) combine by taking the smaller value of each component. The budget is presentation only; the
// state never depends on it.
import Foundation

/// The particle and caustics budget of one quality level, optionally combined with ambient drawing.
public struct AquariumBudget: Equatable, Sendable {
    /// The most bubbles one vent draws (0…``WaterEffects/bubblesPerVent``).
    public var bubblesPerVent: Int
    /// The number of motes drawn (0…``WaterEffects/moteCount``).
    public var motes: Int
    /// The caustics octaves: 2 full, 1 one octave, 0 off (the plain fallback).
    public var causticsOctaves: Int

    /// Creates a budget from its three components.
    public init(bubblesPerVent: Int, motes: Int, causticsOctaves: Int) {
        self.bubblesPerVent = bubblesPerVent; self.motes = motes; self.causticsOctaves = causticsOctaves
    }

    /// The number of quality levels (0 most, 2 least).
    public static let levels = 3

    /// The budget of each quality level, level 0 first.
    static let levelBudgets = [
        AquariumBudget(bubblesPerVent: 24, motes: 24, causticsOctaves: 2),
        AquariumBudget(bubblesPerVent: 12, motes: 12, causticsOctaves: 1),
        AquariumBudget(bubblesPerVent: 6, motes: 6, causticsOctaves: 0),
    ]

    /// The budget of ambient drawing: half the bubbles and motes, full caustics.
    public static let ambientBudget = AquariumBudget(bubblesPerVent: 12, motes: 12, causticsOctaves: 2)

    /// The budget of quality level `tier` (clamped to 0…2), combined with ``ambientBudget`` by the component-wise
    /// minimum when `ambient` is true.
    public static func budget(tier: Int, ambient: Bool) -> AquariumBudget {
        let level = levelBudgets[min(max(tier, 0), levels - 1)]
        guard ambient else { return level }
        return AquariumBudget(bubblesPerVent: min(level.bubblesPerVent, ambientBudget.bubblesPerVent),
                              motes: min(level.motes, ambientBudget.motes),
                              causticsOctaves: min(level.causticsOctaves, ambientBudget.causticsOctaves))
    }
}
