// SDFMarch — feature 211 (R02-F11) T-R02F11-004 (FR-R02F11-004; clarification Q3; research R4, R9; SC-R02F11-002).
// Sphere tracing (Hart 1996) of a signed-distance description along a ray. The conservative mode advances by the
// distance itself (ω = 1). The fast mode over-relaxes by ω = 1.6 with the overlap fallback of Keinert, Schäfer,
// Korndörfer, Ganse and Stamminger, "Enhanced Sphere Tracing" (2014): an over-relaxed step from t₀ (radius r₀, step
// s = ω·r₀) to t₁ (radius r₁) is kept only when the two unbounding spheres overlap, r₀ + |r₁| ≥ s, and r₁ ≥ 0; then the
// whole segment [t₀, t₁] is covered by spheres free of surface, so no surface of a distance bound can be skipped.
// Otherwise the march steps back to t₀ and takes the plain step r₀ (ω = 1 for that step); the next step over-relaxes
// again and is verified the same way. An over-relaxed step pays off only where the surface runs nearly along the ray:
// for a plane at incidence cos θ the overlap holds when cos θ ≤ (2 − ω)/ω = 0.25. An over-relaxed position is never reported as a miss before it is verified, and running
// out of steps is reported as `budgetExhausted`, never as a miss.
import Foundation
import VisualCoreMath

/// Validated settings of a sphere-traced march (see the file header).
public struct SDFMarchOptions: Sendable, Equatable {
    /// How far each step advances.
    public enum Mode: String, Sendable, Codable {
        /// ω = 1: each step advances by the distance bound.
        case conservative
        /// ω = 1.6 with the Keinert et al. (2014) overlap fallback.
        case fast
    }

    /// The step mode.
    public let mode: Mode
    /// The most distance evaluations after the origin, 1…4,096.
    public let maxSteps: Int
    /// The ray length beyond which the march reports a miss; finite and > 0.
    public let maxDistance: Double
    /// The relative hit tolerance: a hit when |d| < tolerance · max(1, t); finite and > 0.
    public let tolerance: Double

    /// Creates validated options; refuses `maxSteps` outside 1…4,096 and a non-finite or non-positive `maxDistance`
    /// or `tolerance`.
    public init(mode: Mode = .conservative, maxSteps: Int = 128, maxDistance: Double = 100,
                tolerance: Double = 1e-7) throws(SDFError) {
        guard (1...4_096).contains(maxSteps) else { throw .nonPositive("maxSteps") }
        guard maxDistance.isFinite else { throw .nonFinite("maxDistance") }
        guard maxDistance > 0 else { throw .nonPositive("maxDistance") }
        guard tolerance.isFinite else { throw .nonFinite("tolerance") }
        guard tolerance > 0 else { throw .nonPositive("tolerance") }
        self.mode = mode
        self.maxSteps = maxSteps
        self.maxDistance = maxDistance
        self.tolerance = tolerance
    }

    /// The defaults: conservative, 128 steps, distance 100, tolerance 1e-7 (research R9).
    public static let standard: SDFMarchOptions = try! SDFMarchOptions()
}

/// The outcome of one march.
public struct SDFMarchResult: Sendable, Equatable {
    /// How the march ended.
    public enum Outcome: String, Sendable {
        /// The ray reached the surface within the tolerance (or started inside).
        case hit
        /// The ray left `maxDistance` without reaching a surface.
        case miss
        /// The step budget ran out before the march decided; not a miss.
        case budgetExhausted
    }

    /// How the march ended.
    public let outcome: Outcome
    /// The ray parameter where the march ended (the hit distance for a hit).
    public let distance: Double
    /// The point `origin + direction · distance`.
    public let point: Vec3
    /// The shape's unit normal at `point` for a hit; (0, 0, 0) otherwise.
    public let normal: Vec3
    /// How many distance evaluations followed the one at the origin.
    public let steps: Int
    /// Whether the origin was inside the shape (distance < 0).
    public let startedInside: Bool

    /// Creates a result from its parts.
    public init(outcome: Outcome, distance: Double, point: Vec3, normal: Vec3, steps: Int, startedInside: Bool) {
        self.outcome = outcome
        self.distance = distance
        self.point = point
        self.normal = normal
        self.steps = steps
        self.startedInside = startedInside
    }
}

/// Sphere tracing of signed-distance descriptions (see the file header).
public enum SDFMarch {
    /// The over-relaxation factor of the fast mode.
    public static let fastRelaxation = 1.6

    /// Marches `ray` through `shape` with `options`.
    ///
    /// An origin inside the shape is a hit at distance 0 with `startedInside` and 0 steps. A hit is reported when
    /// |d| < tolerance · max(1, t), with the shape's normal at the hit point.
    public static func march(_ shape: SDFShape, ray: Ray3, options: SDFMarchOptions = .standard) -> SDFMarchResult {
        let origin = ray.origin, direction = ray.direction
        func at(_ t: Double) -> Vec3 { origin + direction * t }
        func end(_ outcome: SDFMarchResult.Outcome, _ t: Double, _ steps: Int) -> SDFMarchResult {
            let p = at(t)
            return SDFMarchResult(outcome: outcome, distance: t, point: p,
                                  normal: outcome == .hit ? shape.normal(at: p) : .zero, steps: steps,
                                  startedInside: false)
        }

        let d0 = shape.distance(at: origin)
        if d0 < 0 {
            return SDFMarchResult(outcome: .hit, distance: 0, point: origin, normal: shape.normal(at: origin),
                                  steps: 0, startedInside: true)
        }

        let omega = options.mode == .fast ? fastRelaxation : 1
        var t = 0.0, d = d0, steps = 0
        var previousRadius = 0.0, previousStep = 0.0
        var unverified = false  // the current position came from an over-relaxed step not yet checked
        while true {
            if unverified && (d < 0 || previousRadius + d < previousStep) {
                // The spheres do not overlap: back to the previous position and take the plain step (ω = 1).
                t = t - previousStep + previousRadius
                previousStep = previousRadius
                unverified = false
            } else {
                unverified = false
                if t > options.maxDistance { return end(.miss, t, steps) }
                if d < options.tolerance * max(1, t) { return end(.hit, t, steps) }
                previousRadius = d
                previousStep = omega * d
                unverified = omega > 1
                t += previousStep
            }
            if !unverified && t > options.maxDistance { return end(.miss, t, steps) }
            if steps >= options.maxSteps { return end(.budgetExhausted, t, steps) }
            steps += 1
            d = shape.distance(at: at(t))
            if d.isNaN { return end(.budgetExhausted, t, steps) }
        }
    }
}
