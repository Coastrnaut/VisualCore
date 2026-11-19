// CurveSplines.swift — feature 208 (R02-F08) T-R02F08-002 (FR-R02F08-001; research R1; spec Clarifications Q1).
// Cubic Bézier chains and centripetal Catmull-Rom splines (alpha 0.5, Barry–Goldman), open or closed, with exact
// positions and first derivatives. Pure and deterministic: every value is a function of the control points only.
import VisualCoreMath

/// A curve made of `segmentCount` parametric segments, each evaluated for a local parameter t in 0…1.
///
/// Segment `i` ends where segment `i + 1` starts; on a closed curve the last segment ends where segment 0 starts.
/// A segment index outside `0..<segmentCount` is clamped into that range; t is used as given (0…1 is the segment).
public protocol ParametricCurve: Sendable {
    /// Number of segments (at least 1).
    var segmentCount: Int { get }
    /// True when the last segment ends at the start of the first.
    var isClosed: Bool { get }
    /// The point of `segment` at local parameter `t`.
    func position(segment: Int, t: Double) -> Vec3
    /// The first derivative d position / d t of `segment` at local parameter `t`.
    func derivative(segment: Int, t: Double) -> Vec3
}

// MARK: - Cubic Bézier chain

/// A chain of cubic Bézier segments sharing their end control points.
///
/// Open: 3n + 1 control points (n ≥ 1), segment i uses points 3i … 3i + 3. Closed: 3n control points (n ≥ 1), and the
/// last segment ends at point 0. Positions and derivatives are the exact Bernstein forms.
public struct CubicBezierChain: ParametricCurve, Equatable {
    /// The control points as given.
    public let points: [Vec3]
    /// True when the chain is a loop.
    public let isClosed: Bool

    /// A chain through `points`.
    ///
    /// - Throws: `.invalidInput` for a non-finite point, or a count that is not 3n + 1 (open) or 3n (closed) with
    ///   n ≥ 1.
    public init(points: [Vec3], closed: Bool) throws(MeshError) {
        guard points.allSatisfy(\.isFinite) else { throw .invalidInput("Bézier chain has a non-finite control point") }
        if closed {
            guard points.count >= 3, points.count % 3 == 0 else {
                throw .invalidInput("a closed Bézier chain needs 3n control points (n ≥ 1), got \(points.count)")
            }
        } else {
            guard points.count >= 4, (points.count - 1) % 3 == 0 else {
                throw .invalidInput("an open Bézier chain needs 3n + 1 control points (n ≥ 1), got \(points.count)")
            }
        }
        self.points = points
        self.isClosed = closed
    }

    /// Number of cubic segments: `points.count / 3` (closed) or `(points.count − 1) / 3` (open).
    public var segmentCount: Int { isClosed ? points.count / 3 : (points.count - 1) / 3 }

    /// The four control points of `segment` (clamped into range).
    public func controlPoints(segment: Int) -> (Vec3, Vec3, Vec3, Vec3) {
        let s = min(max(segment, 0), segmentCount - 1)
        let n = points.count
        return (points[3 * s], points[3 * s + 1], points[3 * s + 2], points[(3 * s + 3) % n])
    }

    /// The Bernstein form (1 − t)³ b0 + 3 (1 − t)² t b1 + 3 (1 − t) t² b2 + t³ b3.
    public func position(segment: Int, t: Double) -> Vec3 {
        let (b0, b1, b2, b3) = controlPoints(segment: segment)
        let s = 1 - t
        return b0 * (s * s * s) + b1 * (3 * s * s * t) + b2 * (3 * s * t * t) + b3 * (t * t * t)
    }

    /// The derivative 3 (1 − t)² (b1 − b0) + 6 (1 − t) t (b2 − b1) + 3 t² (b3 − b2).
    public func derivative(segment: Int, t: Double) -> Vec3 {
        let (b0, b1, b2, b3) = controlPoints(segment: segment)
        let s = 1 - t
        return (b1 - b0) * (3 * s * s) + (b2 - b1) * (6 * s * t) + (b3 - b2) * (3 * t * t)
    }
}

// MARK: - Centripetal Catmull-Rom spline

/// A centripetal Catmull-Rom spline (alpha 0.5) through its points, evaluated by the Barry–Goldman pyramid.
///
/// Consecutive repeated points (within 1e-9 × (1 + largest coordinate magnitude)) are dropped, and for a closed spline
/// a last point equal to the first. Open: segment i runs from point i to point i + 1, and the missing outer neighbours
/// are phantom points reflected through the end points (p₋₁ = 2p₀ − p₁, pₙ = 2pₙ₋₁ − pₙ₋₂). Closed: neighbours wrap
/// around and the last segment returns to point 0. Knot intervals are |pᵢ₊₁ − pᵢ|^0.5, so the spline has no cusps or
/// self-loops within a segment.
public struct CatmullRomSpline: ParametricCurve, Equatable {
    /// The knot exponent: 0.5 (centripetal).
    public static let alpha = 0.5
    /// The interpolated points after dropping repeats.
    public let points: [Vec3]
    /// True when the spline is a loop.
    public let isClosed: Bool

    /// A spline through `points`.
    ///
    /// - Throws: `.invalidInput` for a non-finite point, fewer than 2 distinct points (open) or fewer than 3 (closed).
    public init(points: [Vec3], closed: Bool) throws(MeshError) {
        guard points.allSatisfy(\.isFinite) else { throw .invalidInput("Catmull-Rom spline has a non-finite point") }
        let scale = points.reduce(0.0) { max($0, abs($1.x), abs($1.y), abs($1.z)) }
        let tolerance = 1e-9 * (1 + scale)
        func same(_ a: Vec3, _ b: Vec3) -> Bool {
            abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance && abs(a.z - b.z) <= tolerance
        }
        var kept: [Vec3] = []
        for p in points where kept.last.map({ !same($0, p) }) ?? true { kept.append(p) }
        if closed, kept.count > 1, same(kept[0], kept[kept.count - 1]) { kept.removeLast() }
        guard kept.count >= 2 else { throw .invalidInput("a Catmull-Rom spline needs at least 2 distinct points") }
        guard !closed || kept.count >= 3 else {
            throw .invalidInput("a closed Catmull-Rom spline needs at least 3 distinct points")
        }
        self.points = kept
        self.isClosed = closed
    }

    /// Number of segments: `points.count` (closed) or `points.count − 1` (open).
    public var segmentCount: Int { isClosed ? points.count : points.count - 1 }

    /// The four points P0 … P3 around `segment` (clamped into range), phantom points at open ends.
    public func neighbourhood(segment: Int) -> (Vec3, Vec3, Vec3, Vec3) {
        let s = min(max(segment, 0), segmentCount - 1)
        let n = points.count
        if isClosed {
            return (points[(s + n - 1) % n], points[s], points[(s + 1) % n], points[(s + 2) % n])
        }
        let p1 = points[s], p2 = points[s + 1]
        let p0 = s > 0 ? points[s - 1] : p1 * 2 - p2
        let p3 = s + 2 < n ? points[s + 2] : p2 * 2 - p1
        return (p0, p1, p2, p3)
    }

    /// The point of `segment` at `t`: the Barry–Goldman pyramid at knot u = t₁ + t (t₂ − t₁).
    public func position(segment: Int, t: Double) -> Vec3 { evaluate(segment: segment, t: t).position }

    /// d position / d t: the derivative of the pyramid with respect to u, times (t₂ − t₁).
    public func derivative(segment: Int, t: Double) -> Vec3 { evaluate(segment: segment, t: t).derivative }

    private func evaluate(segment: Int, t: Double) -> (position: Vec3, derivative: Vec3) {
        let (p0, p1, p2, p3) = neighbourhood(segment: segment)
        func knot(_ a: Vec3, _ b: Vec3) -> Double { (b - a).length.squareRoot() }   // |b − a|^alpha, alpha = 0.5
        let t0 = 0.0, t1 = t0 + knot(p0, p1), t2 = t1 + knot(p1, p2), t3 = t2 + knot(p2, p3)
        let u = t1 + t * (t2 - t1)
        func lerp(_ a: Vec3, _ b: Vec3, _ ta: Double, _ tb: Double) -> Vec3 {
            a * ((tb - u) / (tb - ta)) + b * ((u - ta) / (tb - ta))
        }
        let a1 = lerp(p0, p1, t0, t1), a2 = lerp(p1, p2, t1, t2), a3 = lerp(p2, p3, t2, t3)
        let b1 = lerp(a1, a2, t0, t2), b2 = lerp(a2, a3, t1, t3)
        let c = lerp(b1, b2, t1, t2)
        let da1 = (p1 - p0) / (t1 - t0), da2 = (p2 - p1) / (t2 - t1), da3 = (p3 - p2) / (t3 - t2)
        let db1 = (a2 - a1) / (t2 - t0) + da1 * ((t2 - u) / (t2 - t0)) + da2 * ((u - t0) / (t2 - t0))
        let db2 = (a3 - a2) / (t3 - t1) + da2 * ((t3 - u) / (t3 - t1)) + da3 * ((u - t1) / (t3 - t1))
        let dc = (b2 - b1) / (t2 - t1) + db1 * ((t2 - u) / (t2 - t1)) + db2 * ((u - t1) / (t2 - t1))
        return (c, dc * (t2 - t1))
    }
}
