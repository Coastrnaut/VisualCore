// ParticleForceFields.swift — bounded force fields for ParticleSystem (feature 034 A04-P02 T-A04-202; gap G-FIELDS;
// FR-A04-201, FR-A04-202; research R1, R2). Every force has a clamp and a documented bound on its acceleration, and is
// finite at every finite position, including exactly at its center (softened or zero there).
import Foundation
import VisualCoreMath

extension ParticleForce {
    /// Largest strength magnitude of a repulsor or vortex after `clamped()` (units/s²).
    public static let strengthLimit = 10_000.0
    /// Largest gravity-well strength after `clamped()` (units³/s²); the well's strength is never negative.
    public static let gravityWellStrengthLimit = 1e9
    /// Allowed repulsor and vortex radii (world units).
    public static let radiusRange: ClosedRange<Double> = 1...2_000
    /// Allowed gravity-well softening lengths (world units).
    public static let softeningRange: ClosedRange<Double> = 1...500
    /// Allowed wind rates (per second).
    public static let rateRange: ClosedRange<Double> = 0...10
    /// Largest wind speed after `clamped()` (world units per second); faster winds keep their direction.
    public static let maxWindSpeed = 2_000.0
    /// Largest gravity component, attractor strength and drag of the original cases after `clamped()` — far beyond any
    /// existing scene (A01 uses gravity ±400 and drag ≤ 2), so their results are unchanged (research R1).
    public static let legacyLimit = 1e6
    /// Largest coordinate of a force center after `clamped()` (world units).
    public static let maxCoordinate = 1e12

    /// The force with every parameter made safe to step.
    ///
    /// - New fields (repulsor, gravity well, wind, vortex) are clamped to the published ranges; non-finite values become
    ///   0 before clamping.
    /// - The original cases keep every value inside their wide ranges unchanged (so existing scenes step
    ///   bit-identically): gravity components, attractor strength ±`legacyLimit`, drag 0…`legacyLimit`, attractor
    ///   radius 0…`maxCoordinate`.
    /// - Centers are clamped to ±`maxCoordinate` per axis. Clamping is idempotent.
    public func clamped() -> ParticleForce {
        func f(_ v: Double) -> Double { v.isFinite ? v : 0 }
        func clamp(_ v: Double, _ r: ClosedRange<Double>) -> Double { min(max(f(v), r.lowerBound), r.upperBound) }
        let coordinate = -Self.maxCoordinate...Self.maxCoordinate, legacy = -Self.legacyLimit...Self.legacyLimit
        func p(_ v: Vec2) -> Vec2 { Vec2(clamp(v.x, coordinate), clamp(v.y, coordinate)) }
        switch self {
        case .gravity(let g): return .gravity(Vec2(clamp(g.x, legacy), clamp(g.y, legacy)))
        case .drag(let k): return .drag(clamp(k, 0...Self.legacyLimit))
        case .attractor(let c, let s, let r):
            return .attractor(point: p(c), strength: clamp(s, legacy), radius: clamp(r, 0...Self.maxCoordinate))
        case .repulsor(let c, let s, let r):
            return .repulsor(point: p(c), strength: clamp(s, -Self.strengthLimit...Self.strengthLimit), radius: clamp(r, Self.radiusRange))
        case .vortex(let c, let s, let r):
            return .vortex(point: p(c), strength: clamp(s, -Self.strengthLimit...Self.strengthLimit), radius: clamp(r, Self.radiusRange))
        case .gravityWell(let c, let s, let e):
            return .gravityWell(point: p(c), strength: clamp(s, 0...Self.gravityWellStrengthLimit), softening: clamp(e, Self.softeningRange))
        case .wind(let w, let rate):
            var v = Vec2(f(w.x), f(w.y))
            let m = max(abs(v.x), abs(v.y))
            if m > 0, (v / m).length * m > Self.maxWindSpeed {
                // Scale through the largest component (no overflow) to just under the limit, so a second clamp keeps it.
                v = (v / m).normalized * (Self.maxWindSpeed * (1 - 1e-12))
            }
            return .wind(velocity: v, rate: clamp(rate, Self.rateRange))
        }
    }

    /// The largest acceleration magnitude this force can produce for a particle moving at `speed` (units/s; only drag
    /// and wind depend on it). Valid for clamped forces; tests compare `acceleration(at:velocity:)` against it.
    ///
    /// Gravity |g|; drag k·speed; attractor, repulsor and vortex |strength|; gravity well 2s/(3√3·ε²); wind
    /// rate·(|w| + speed).
    public func bound(speed: Double = 0) -> Double {
        let v = speed.isFinite ? abs(speed) : 0
        switch self {
        case .gravity(let g): return g.length
        case .drag(let k): return abs(k) * v
        case .attractor(_, let s, _), .repulsor(_, let s, _), .vortex(_, let s, _): return abs(s)
        case .gravityWell(_, let s, let e): return 2 * abs(s) / (3 * 3.0.squareRoot() * e * e)
        case .wind(let w, let rate): return abs(rate) * (w.length + v)
        }
    }

    /// The acceleration this force gives a particle at `position` moving with `velocity` (no clamping; call
    /// `clamped()` first for untrusted values). Point forces give 0 exactly at their center, where the direction is
    /// undefined.
    public func acceleration(at position: Vec2, velocity: Vec2) -> Vec2 {
        switch self {
        case .gravity(let g): return Vec2(0 + g.x, 0 + g.y)
        case .drag(let k): return Vec2(0 - k * velocity.x, 0 - k * velocity.y)
        case .attractor(let c, let s, let r):
            let dx = c.x - position.x, dy = c.y - position.y, d = (dx * dx + dy * dy).squareRoot()
            return d > 1e-9 && d <= r ? Vec2(0 + s * dx / d, 0 + s * dy / d) : .zero
        case .repulsor(let c, let s, let r):
            let dx = position.x - c.x, dy = position.y - c.y, d = (dx * dx + dy * dy).squareRoot()
            guard d > 1e-9, d < r else { return .zero }
            let k = s * min(max(1 - d / r, 0), 1) / d
            return Vec2(k * dx, k * dy)
        case .vortex(let c, let s, let r):
            let ox = position.x - c.x, oy = position.y - c.y, d = (ox * ox + oy * oy).squareRoot()
            guard d > 1e-9, d < r else { return .zero }
            let k = s * min(max(1 - d / r, 0), 1) / d
            return Vec2(-k * oy, k * ox)
        case .gravityWell(let c, let s, let e):
            let dx = c.x - position.x, dy = c.y - position.y
            let q = dx * dx + dy * dy + e * e
            guard q > 0, q.isFinite else { return .zero }
            let k = s / (q * q.squareRoot())
            return Vec2(k * dx, k * dy)
        case .wind(let w, let rate):
            return Vec2(rate * (w.x - velocity.x), rate * (w.y - velocity.y))
        }
    }
}
