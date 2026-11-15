// DrawingBudget — feature 086 (A11-P05) T-A11-502 (FR-A11-520; clarification 4; research D3; data-model
// "DrawingBudget"; contract contracts/stability.md). The drawing detail of the three quality levels; presentation only,
// so the world, the tick and every digest are the same at every level (the core stores no level).
//
// | Level | Spring coils | Circle segments | Hatch spacing | Arrowheads |
// |---|---|---|---|---|
// | 0 (fullest) | 8 | 33 | 0.12 m | drawn |
// | 1 | 6 | 24 | 0.2 m | drawn |
// | 2 (lightest) | 4 | 16 | none (static bodies keep their darker fill) | drawn |
//
// The level drawn is `level(tier:lowPower:)`: Low Power Mode draws level 2, otherwise the host's quality tier clamped
// to 0…2 (tier 0 is the fullest).
import Foundation

/// The drawing detail of one quality level (presentation only).
public struct DrawingBudget: Equatable, Sendable {
    /// The zigzag coils of a drawn spring.
    public var coils: Int
    /// The segments of a drawn circle outline.
    public var circleSegments: Int
    /// The spacing in metres of a static body's hatch lines, nil for no hatch.
    public var hatchSpacing: Double?
    /// True when arrows have arrowheads (every level).
    public var arrowheads: Bool

    /// Creates a budget (no validation).
    public init(coils: Int, circleSegments: Int, hatchSpacing: Double?, arrowheads: Bool = true) {
        self.coils = coils; self.circleSegments = circleSegments; self.hatchSpacing = hatchSpacing
        self.arrowheads = arrowheads
    }

    /// The three levels, fullest first.
    public static let levels: [DrawingBudget] = [
        DrawingBudget(coils: 8, circleSegments: 33, hatchSpacing: 0.12),
        DrawingBudget(coils: 6, circleSegments: 24, hatchSpacing: 0.2),
        DrawingBudget(coils: 4, circleSegments: 16, hatchSpacing: nil),
    ]

    /// The number of levels (3).
    public static var count: Int { levels.count }

    /// The level drawn: 2 (the lightest) in Low Power Mode, otherwise `tier` clamped to 0…2.
    public static func level(tier: Int, lowPower: Bool) -> Int {
        lowPower ? count - 1 : min(max(tier, 0), count - 1)
    }

    /// The budget of `level` clamped to 0…2.
    public static func budget(level: Int) -> DrawingBudget {
        levels[min(max(level, 0), count - 1)]
    }
}
