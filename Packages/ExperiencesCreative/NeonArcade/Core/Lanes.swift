// Lanes — feature 076 (A10-P02) T-A10-202 (FR-A10-201; clarification 1; data-model "Lanes"). The five lanes of the
// Neon Dodge field: lane i (0…4) has its centre at x = 0.9 + 1.8 i (0.9, 2.7, 4.5, 6.3, 8.1), so the lanes split the
// 9-unit field evenly. Lanes place falling objects only; the player still moves freely across the field.
import Foundation

/// The lanes falling objects spawn in.
public enum Lanes {
    /// The number of lanes.
    public static let count = 5
    /// The distance between neighbouring lane centres, in game units.
    public static let spacing = 1.8
    /// The x of lane 0's centre.
    public static let firstCentre = 0.9

    /// The centre x of `lane` (0.9 + 1.8 × lane); lanes outside 0…4 are clamped to the nearest lane.
    public static func centre(_ lane: Int) -> Double {
        firstCentre + spacing * Double(min(max(lane, 0), count - 1))
    }

    /// Every lane centre in lane order.
    public static var centres: [Double] { (0..<count).map(centre) }

    /// True when `lane` names a lane (0…4).
    public static func contains(_ lane: Int) -> Bool { (0..<count).contains(lane) }
}
