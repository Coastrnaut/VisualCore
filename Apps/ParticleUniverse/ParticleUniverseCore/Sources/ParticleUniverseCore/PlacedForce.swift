// PlacedForce.swift — the one force a person places in the sandbox (feature 034 A04-P02 T-A04-206; FR-A04-204; US1;
// spec clarification 3; data model). Runtime only in this phase (saving scenes is Phase 04).
import VisualCoreMath
import VisualCoreSimulation

/// The kinds of force a person can place.
public enum PlacedForceKind: String, CaseIterable, Sendable, Codable {
    case attractor, repulsor, gravityWell, wind, vortex

    /// Short title for menus and labels.
    public var title: String {
        switch self {
        case .attractor: "Attractor"
        case .repulsor: "Repulsor"
        case .gravityWell: "Gravity well"
        case .wind: "Wind"
        case .vortex: "Vortex"
        }
    }

    /// What the force does, for VoiceOver.
    public var spokenDescription: String {
        switch self {
        case .attractor: "pulls nearby particles toward it"
        case .repulsor: "pushes nearby particles away"
        case .gravityWell: "a softened gravity well that pulls particles in from far away"
        case .wind: "blows every particle in one direction"
        case .vortex: "turns nearby particles counter-clockwise around it"
        }
    }
}

/// One placed force: kind, world position and a strength multiplier.
public struct PlacedForce: Equatable, Sendable {
    /// Half the side of the world square (−500…500 on each axis).
    public static let worldHalfExtent = 500.0
    /// Allowed strength multipliers.
    public static let strengthRange: ClosedRange<Double> = 0.1...2

    /// The kind of force.
    public var kind: PlacedForceKind
    /// World position, always inside the world square.
    public private(set) var position: Vec2
    /// Strength multiplier, 0.1…2 (default 1).
    public private(set) var strength: Double

    /// Creates a force; the position is clamped into the world square (non-finite components become 0) and the
    /// strength into 0.1…2 (non-finite becomes 1).
    public init(kind: PlacedForceKind, position: Vec2, strength: Double = 1) {
        self.kind = kind
        self.position = Self.clampPosition(Vec2(position.x.isFinite ? position.x : 0, position.y.isFinite ? position.y : 0))
        self.strength = strength.isFinite ? min(max(strength, Self.strengthRange.lowerBound), Self.strengthRange.upperBound) : 1
    }

    /// The nearest point inside the world square.
    public static func clampPosition(_ p: Vec2) -> Vec2 {
        let h = worldHalfExtent
        return Vec2(min(max(p.x, -h), h), min(max(p.y, -h), h))
    }

    /// Moves to `p` (clamped into the world square); a non-finite point is ignored.
    public mutating func move(to p: Vec2) {
        guard p.isFinite else { return }
        position = Self.clampPosition(p)
    }

    /// Moves by `delta`, clamped into the world square.
    public mutating func nudge(by delta: Vec2) { move(to: position + delta) }

    /// Sets the strength multiplier (clamped to 0.1…2); a non-finite value is ignored.
    public mutating func setStrength(_ s: Double) {
        guard s.isFinite else { return }
        strength = min(max(s, Self.strengthRange.lowerBound), Self.strengthRange.upperBound)
    }

    /// The direction wind blows: from the world center toward the position, or +x exactly at the center.
    public var windDirection: Vec2 { position == .zero ? Vec2(1, 0) : position.normalized }

    /// The VisualCore force with the clarified defaults scaled by `strength`.
    public var particleForce: ParticleForce {
        switch kind {
        case .attractor: .attractor(point: position, strength: 300 * strength, radius: 300)
        case .repulsor: .repulsor(point: position, strength: 400 * strength, radius: 250)
        case .gravityWell: .gravityWell(point: position, strength: 2_000_000 * strength, softening: 40)
        case .wind: .wind(velocity: windDirection * (120 * strength), rate: 0.8)
        case .vortex: .vortex(point: position, strength: 250 * strength, radius: 300)
        }
    }
}
