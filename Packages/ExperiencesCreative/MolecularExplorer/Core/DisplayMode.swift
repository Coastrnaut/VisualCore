// DisplayMode — feature 111 (A15-P02) T-A15-202 (FR-A15-210; clarification Q2; data-model "DisplayMode";
// contracts/renderer.md). The two display modes of Molecular Explorer:
// - `ballAndStick` (0): atoms at 0.30 × their van der Waals radius, bonds as sticks of radius 0.12 Å;
// - `spaceFilling` (1): atoms at 1.00 × their van der Waals radius, no bonds.
// Display conventions only, never measured sizes ("Display radii, not measured sizes").
import Foundation

/// How a molecule is drawn: ball-and-stick or space-filling.
public enum DisplayMode: Int, Codable, CaseIterable, Sendable {
    /// Small atoms joined by sticks.
    case ballAndStick = 0
    /// Atoms at their van der Waals radius, no sticks.
    case spaceFilling = 1

    /// The radius of a bond stick in ball-and-stick, ångström (thinner than the smallest drawn atom).
    public static let stickRadius = 0.12

    /// The fraction of the van der Waals radius an atom is drawn at (0.30 or 1.00).
    public var atomRadiusFactor: Double {
        switch self {
        case .ballAndStick: return 0.30
        case .spaceFilling: return 1.00
        }
    }

    /// True when bonds are drawn as sticks (ball-and-stick only).
    public var showsBonds: Bool { self == .ballAndStick }

    /// The mode's name in words (`ball-and-stick`, `space-filling`).
    public var name: String {
        switch self {
        case .ballAndStick: return "ball-and-stick"
        case .spaceFilling: return "space-filling"
        }
    }
}
