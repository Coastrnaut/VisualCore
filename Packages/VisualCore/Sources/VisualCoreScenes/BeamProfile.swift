// BeamProfile — feature 209 (R02-F09) T-R02F09-002 (FR-R02F09-002, FR-R02F09-004; clarification Q2; research R3). The CPU
// reference of a beam's look: the brightness at a point is `falloff(r)` with r the distance from the beam's segment
// divided by half its width; falloff(r) = exp(−4 r²) for r ≤ 1 and 0 beyond (about 1.8% at the edge). A beam whose ends
// coincide is a round point of the beam's width, because the distance to a degenerate segment is the distance to its
// point. Pure; `BeamRenderer` in VisualCoreRendering shades with the same formula.
import Foundation
import VisualCoreMath

/// The cross-section of a beam or point (see the file header).
public enum BeamProfile {
    /// The brightness factor at normalised distance `r` from the centre line: exp(−4 r²) for 0 ≤ r ≤ 1, 0 beyond.
    public static func falloff(_ r: Double) -> Double {
        let x = abs(r)
        return x <= 1 ? exp(-4 * x * x) : 0
    }

    /// The distance from `point` to the segment from `a` to `b`; the distance to `a` when the two coincide.
    public static func distanceToSegment(point: Vec3, a: Vec3, b: Vec3) -> Double {
        let ab = b - a
        let lengthSquared = ab.dot(ab)
        guard lengthSquared > 0 else { return (point - a).length }
        let t = min(max((point - a).dot(ab) / lengthSquared, 0), 1)
        return (point - (a + ab * t)).length
    }

    /// The brightness factor at `point` for a beam from `a` to `b` of `width`: `falloff(distance / (width / 2))`;
    /// 0 for a width that is not positive.
    public static func coverage(point: Vec3, a: Vec3, b: Vec3, width: Double) -> Double {
        guard width > 0 else { return 0 }
        return falloff(distanceToSegment(point: point, a: a, b: b) / (width / 2))
    }
}
