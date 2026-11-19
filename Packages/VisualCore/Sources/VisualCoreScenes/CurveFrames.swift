// CurveFrames.swift — feature 208 (R02-F08) T-R02F08-003 (FR-R02F08-003; research R3; spec Clarifications Q3).
// Public rotation-minimizing (parallel-transport) frames on curve samples by double reflection (Wang, Jüttler, Zheng
// and Liu 2008), defined through reversals and repeated points and closing exactly on loops.
import Foundation
import VisualCoreMath

/// An orthonormal frame at one curve sample: `binormal` = `tangent` × `normal`.
public struct CurveFrame: Sendable, Equatable {
    /// The sample position.
    public var position: Vec3
    /// The unit tangent along the curve.
    public var tangent: Vec3
    /// The unit normal, orthogonal to the tangent; carried with minimal rotation.
    public var normal: Vec3
    /// The unit binormal `tangent × normal`.
    public var binormal: Vec3

    /// A frame from its parts (taken as given).
    public init(position: Vec3, tangent: Vec3, normal: Vec3, binormal: Vec3) {
        self.position = position; self.tangent = tangent; self.normal = normal; self.binormal = binormal
    }
}

/// Parallel-transport frames along `CurveSamples`.
public enum CurveFrames {
    /// Rotation-minimizing frames along `samples` (clarification Q3).
    ///
    /// The tangents are the samples' tangents. The first normal is `initialNormal` made orthogonal to the first
    /// tangent, or, when it is nil, zero or parallel to that tangent, the world axis least parallel to it,
    /// orthogonalised. Each further normal is carried from the previous by double reflection: first in the plane
    /// normal to the chord, then in the plane normal to the difference of the reflected and the new tangent (skipped
    /// when that difference is shorter than 1e-10, as at a 180° reversal, so the normal is kept and only the tangent
    /// turns). A closed record is carried once more to the first sample; the angle between that frame and the first
    /// is spread linearly by arc length (frame i turns about its tangent by angle × arcLength(i) / length), and one
    /// seam frame (the first sample reached around the loop, equal to the first frame within rounding) is appended.
    ///
    /// - Returns: one frame per sample, plus the seam frame for a closed record.
    /// - Throws: `.invalidInput` when `initialNormal` is not finite.
    public static func parallelTransport(_ samples: CurveSamples,
                                         initialNormal: Vec3? = nil) throws(MeshError) -> [CurveFrame] {
        try transport(samples, initialNormal: initialNormal).frames
    }

    /// The frames of `parallelTransport` and the closing angle spread over a loop (0 for an open record).
    static func transport(_ samples: CurveSamples,
                          initialNormal: Vec3?) throws(MeshError) -> (frames: [CurveFrame], closingAngle: Double) {
        let points = samples.positions, tangents = samples.tangents
        let m = points.count
        var first = leastParallelNormal(tangents[0])
        if let initialNormal {
            guard initialNormal.isFinite else { throw .invalidInput("initial normal is not finite") }
            let o = initialNormal - tangents[0] * tangents[0].dot(initialNormal)
            let size = initialNormal.length
            if size > 0, o.length > 1e-9 * size { first = o.normalized }
        }
        var normals = [first]
        normals.reserveCapacity(m)
        for i in 1..<m {
            normals.append(carry(normals[i - 1], tangents[i - 1], from: points[i - 1], to: points[i],
                                 tangent: tangents[i]))
        }
        func frame(_ i: Int, _ r: Vec3) -> CurveFrame {
            let t = tangents[i]
            return CurveFrame(position: points[i], tangent: t, normal: r, binormal: t.cross(r).normalized)
        }
        guard samples.isClosed else { return ((0..<m).map { frame($0, normals[$0]) }, 0) }

        let t0 = tangents[0]
        let seam = carry(normals[m - 1], tangents[m - 1], from: points[m - 1], to: points[0], tangent: t0)
        let angle = atan2(seam.cross(normals[0]).dot(t0), seam.dot(normals[0]))
        let total = samples.length
        var frames: [CurveFrame] = []
        frames.reserveCapacity(m + 1)
        for i in 0..<m {
            frames.append(frame(i, rotate(normals[i], about: tangents[i], by: angle * samples.arcLengths[i] / total)))
        }
        frames.append(frame(0, rotate(seam, about: t0, by: angle)))
        return (frames, angle)
    }

    /// The world axis least parallel to unit `t` (x before y before z on ties), made orthogonal to `t`.
    static func leastParallelNormal(_ t: Vec3) -> Vec3 {
        let axes = [Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0, 0, 1)]
        var best = axes[0]
        for axis in axes.dropFirst() where abs(axis.dot(t)) < abs(best.dot(t)) { best = axis }
        return (best - t * best.dot(t)).normalized
    }

    /// Carries normal `r` (with tangent `t` at `x0`) to `x1` with tangent `t1` by double reflection.
    static func carry(_ r: Vec3, _ t: Vec3, from x0: Vec3, to x1: Vec3, tangent t1: Vec3) -> Vec3 {
        let v1 = x1 - x0, c1 = v1.dot(v1)
        var r1 = r
        if c1 > 0 {
            let rL = r - v1 * (2 / c1 * v1.dot(r)), tL = t - v1 * (2 / c1 * v1.dot(t))
            let v2 = t1 - tL, c2 = v2.dot(v2)
            r1 = c2 > 1e-20 ? rL - v2 * (2 / c2 * v2.dot(rL)) : rL
        }
        let o = r1 - t1 * t1.dot(r1)
        if o.length > 1e-12 { return o.normalized }
        let kept = r - t1 * t1.dot(r)
        return kept.length > 1e-12 ? kept.normalized : leastParallelNormal(t1)
    }

    /// `r` turned about unit `t` by `theta` (for `r` orthogonal to `t`), normalised.
    static func rotate(_ r: Vec3, about t: Vec3, by theta: Double) -> Vec3 {
        (r * cos(theta) + t.cross(r) * sin(theta)).normalized
    }
}
