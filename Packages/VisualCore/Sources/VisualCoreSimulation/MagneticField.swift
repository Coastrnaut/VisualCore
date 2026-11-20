// MagneticField — feature 220 (R02-F20) T-R02F20-002 (FR-R02F20-003; SC-R02F20-003; clarification Q4; research R3,
// R4). A uniform field B along z, which only turns a charge's velocity (an exact rotation by −q · B · h per step, so
// speed is kept), and softened point poles: a pole at c of strength s and softening ε pulls a charge q at p with
// F = s · q · (c − p) / (|c − p|² + ε²)^{3/2} (positive s · q attracts), whose length is at most
// |s · q| · 2 / (3√3 · ε²), reached at |c − p| = ε / √2.
import Foundation
import VisualCoreMath

/// A softened magnetic pole that attracts or repels charged agents.
public struct MagneticPole: Sendable, Equatable, Codable {
    /// The largest allowed strength magnitude.
    public static let maxStrength = 1_000.0
    /// The smallest allowed softening.
    public static let minSoftening = 1e-6

    /// Where the pole is.
    public let position: Vec2
    /// The strength s; with a charge q, positive s · q attracts and negative s · q repels.
    public let strength: Double
    /// The softening ε, which keeps the force finite on the pole.
    public let softening: Double

    /// A pole at `position` with `strength` and `softening`.
    ///
    /// - Throws: `.field("position")` for a non-finite position, `.field("strength")` unless finite with
    ///   |s| ≤ 1,000, `.field("softening")` unless finite and ≥ 1e-6.
    public init(position: Vec2, strength: Double, softening: Double = 0.1) throws(SwarmError) {
        guard position.isFinite else { throw .field("position") }
        guard strength.isFinite, abs(strength) <= Self.maxStrength else { throw .field("strength") }
        guard softening.isFinite, softening >= Self.minSoftening else { throw .field("softening") }
        self.position = position
        self.strength = strength
        self.softening = softening
    }

    private enum CodingKeys: String, CodingKey { case position, strength, softening }

    /// Decodes a pole and checks it with the same rules as ``init(position:strength:softening:)``.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(position: c.decode(Vec2.self, forKey: .position),
                          strength: c.decode(Double.self, forKey: .strength),
                          softening: c.decode(Double.self, forKey: .softening))
        } catch let error as SwarmError {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode))
        }
    }

    /// The force on a charge `charge` at `position`; `.zero` for a non-finite position or charge.
    public func force(at position: Vec2, charge: Double) -> Vec2 {
        guard position.isFinite, charge.isFinite else { return .zero }
        let offset = self.position - position
        let soft = offset.x * offset.x + offset.y * offset.y + softening * softening
        let denominator = soft * soft.squareRoot()
        guard denominator.isFinite, denominator > 0 else { return .zero }
        let result = offset * (strength * charge / denominator)
        return result.isFinite ? result : .zero
    }

    /// The largest force this pole can exert on `charge`, |s · q| · 2 / (3√3 · ε²).
    public func forceBound(charge: Double) -> Double {
        abs(strength * charge) * 2 / (3 * 3.0.squareRoot() * softening * softening)
    }
}

/// A uniform magnetic field along z plus softened poles, acting on charged agents.
public struct MagneticField: Sendable, Equatable, Codable {
    /// The largest number of poles.
    public static let maxPoles = 64
    /// The largest allowed uniform field magnitude.
    public static let maxUniform = 100.0
    /// No field and no poles.
    public static let none = MagneticField(checkedUniform: 0, poles: [])

    /// The uniform field B along z; a charge q moving at v turns at angular rate −q · B.
    public let uniform: Double
    /// The poles.
    public let poles: [MagneticPole]

    /// A field with uniform strength `uniform` and `poles`.
    ///
    /// - Throws: `.field("uniform")` unless finite with |B| ≤ 100; `.field("poles")` for more than 64 poles.
    public init(uniform: Double = 0, poles: [MagneticPole] = []) throws(SwarmError) {
        guard uniform.isFinite, abs(uniform) <= Self.maxUniform else { throw .field("uniform") }
        guard poles.count <= Self.maxPoles else { throw .field("poles") }
        self.init(checkedUniform: uniform, poles: poles)
    }

    private init(checkedUniform: Double, poles: [MagneticPole]) {
        self.uniform = checkedUniform
        self.poles = poles
    }

    private enum CodingKeys: String, CodingKey { case uniform, poles }

    /// Decodes a field and checks it with the same rules as ``init(uniform:poles:)``.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(uniform: c.decode(Double.self, forKey: .uniform),
                          poles: c.decode([MagneticPole].self, forKey: .poles))
        } catch let error as SwarmError {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode))
        }
    }

    /// The summed pole force on a charge `charge` at `position`, in pole order; `.zero` without poles or for a
    /// non-finite position or charge. Its length never exceeds ``poleForceBound(charge:)``.
    public func poleForce(at position: Vec2, charge: Double) -> Vec2 {
        guard !poles.isEmpty, position.isFinite, charge.isFinite, charge != 0 else { return .zero }
        var total = Vec2.zero
        for pole in poles { total += pole.force(at: position, charge: charge) }
        return total
    }

    /// The sum over the poles of |s · q| · 2 / (3√3 · ε²), an upper bound of ``poleForce(at:charge:)``.
    public func poleForceBound(charge: Double) -> Double {
        poles.reduce(0) { $0 + $1.forceBound(charge: charge) }
    }

    /// `velocity` turned by the exact angle −charge · uniform · step, which keeps its length to rounding; unchanged
    /// when the angle is zero or not finite.
    public func turned(_ velocity: Vec2, charge: Double, step: Double) -> Vec2 {
        let angle = -charge * uniform * step
        guard angle.isFinite, angle != 0 else { return velocity }
        let c = Foundation.cos(angle), s = Foundation.sin(angle)
        return Vec2(velocity.x * c - velocity.y * s, velocity.x * s + velocity.y * c)
    }
}
