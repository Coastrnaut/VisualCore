// SkyModel — feature 218 (R02-F18) T-R02F18-005 (FR-R02F18-005, 006; SC-R02F18-004, 005; clarification Q4; research R5, R6).
// The processor reference of the analytic sky: the colour seen in a view direction for a sun direction and
// `SkyParameters`, with no image. `vc/sky.glsl` (`vc_sky`) computes the same expression in the same order in float;
// this file computes it in Double. With d the unit view direction, s the unit sun direction and e = d.y:
//   day = e ≥ 0 ? mix(horizon, zenith, √e) : mix(horizon, ground, smoothstep(0, 0.1, −e))
//   w   = clamp(1 − |s.y| / 0.25, 0, 1)
//   c   = day + dusk · w · max(d·s, 0)⁴ · (1 − max(e, 0))
//   f   = smoothstep(−0.15, 0.05, s.y)
//   c   = c · mix(night, 1, f)                                  (per channel)
//   c  += sunColour · f · (smoothstep(cos(r + 0.004), cos r, d·s) + g · max(d·s, 0)^k)   when e ≥ −r
//   c   = clamp(c, 0, 1)                                         (per channel, linear RGB)
// r is the disc's angular radius, g and k the glow strength and exponent. smoothstep and mix are GLSL's.
import Foundation
import VisualCoreMath

/// The analytic sky of clarification Q4, evaluated on the processor (the reference for `vc/sky.glsl`).
public enum SkyModel {
    /// The linear RGB colour (each channel 0 … 1) of the sky seen in `direction` with the sun in `sun`.
    /// - Parameters:
    ///   - direction: The view direction (any non-zero finite length; normalised first).
    ///   - sun: The direction towards the sun (any non-zero finite length; normalised first).
    ///   - parameters: The sky settings; validated first.
    /// - Throws: ``SkyError/direction`` for a zero or non-finite vector; ``SkyError/skyParameter(_:)`` for invalid
    ///   parameters.
    public static func colour(direction: Vec3, sun: Vec3, parameters: SkyParameters) throws(SkyError) -> Vec3 {
        guard direction.isFinite, sun.isFinite, direction.length > 0, sun.length > 0 else { throw .direction }
        let p = try parameters.validated()
        let d = direction / direction.length
        let s = sun / sun.length
        guard d.isFinite, s.isFinite else { throw .direction }

        let e = d.y
        let day: Vec3
        if e >= 0 {
            day = mix(p.horizon, p.zenith, e.squareRoot())
        } else {
            day = mix(p.horizon, p.ground, smoothstep(0, 0.1, -e))
        }
        let w = clamp(1 - abs(s.y) / 0.25, 0, 1)
        let ds = d.dot(s)
        let toward = Swift.max(ds, 0)
        let toward2 = toward * toward
        var c = day + p.dusk * (w * (toward2 * toward2) * (1 - Swift.max(e, 0)))
        let f = smoothstep(-0.15, 0.05, s.y)
        c = Vec3(c.x * mix(p.night.x, 1, f), c.y * mix(p.night.y, 1, f), c.z * mix(p.night.z, 1, f))
        let r = p.sunRadius
        if e >= -r {
            let disc = smoothstep(cos(r + 0.004), cos(r), ds)
            c += p.sunColour * (f * (disc + p.glowStrength * pow(toward, p.glowExponent)))
        }
        return Vec3(clamp(c.x, 0, 1), clamp(c.y, 0, 1), clamp(c.z, 0, 1))
    }

    /// GLSL `smoothstep`: t = clamp((x − a) / (b − a), 0, 1); t²(3 − 2t).
    static func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = clamp((x - a) / (b - a), 0, 1)
        return t * t * (3 - 2 * t)
    }

    /// GLSL `mix` of scalars: a + (b − a) t.
    static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    /// GLSL `mix` of vectors: a + (b − a) t.
    static func mix(_ a: Vec3, _ b: Vec3, _ t: Double) -> Vec3 { a + (b - a) * t }

    /// GLSL `clamp`.
    static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double { Swift.min(Swift.max(x, lo), hi) }
}
