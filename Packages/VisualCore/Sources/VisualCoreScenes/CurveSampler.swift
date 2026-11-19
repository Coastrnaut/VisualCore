// CurveSampler.swift — feature 208 (R02-F08) T-R02F08-002 (FR-R02F08-002; research R2; spec Clarifications Q2, Q3).
// Adaptive, deterministic sampling of a parametric curve into a polyline within a tolerance, and the sample record
// (positions, unit tangents, cumulative chord arc lengths) that frames, ribbons and tubes are built from.
import VisualCoreMath

/// An ordered polyline sampled from a curve: positions, unit tangents and cumulative arc lengths.
///
/// Built only through `init(positions:closed:)` (or `CurveSampler.sample`), which enforces the collapse and tangent
/// rules of the clarified design: no two consecutive positions coincide, every tangent has unit length and the arc
/// lengths start at 0 and grow by the chord lengths. A closed record does not repeat its first position at the end.
public struct CurveSamples: Sendable, Equatable {
    /// The kept sample positions, in order.
    public let positions: [Vec3]
    /// One unit tangent per position: the normalised sum of the two unit chords at the sample (one chord at an open
    /// end); at a reversal, where that sum is shorter than 1e-6, the chord ahead (behind at an open end).
    public let tangents: [Vec3]
    /// Cumulative chord length from the first position to each position (the first is 0).
    public let arcLengths: [Double]
    /// True when the polyline is a loop (the last position joins back to the first).
    public let isClosed: Bool

    /// The total length: the last arc length, plus the closing chord for a loop.
    public var length: Double {
        guard let last = arcLengths.last, let tail = positions.last, let head = positions.first else { return 0 }
        return isClosed ? last + (head - tail).length : last
    }

    /// A sample record of `positions`.
    ///
    /// Positions closer than 1e-9 × (1 + extent) per component to the previous kept position are dropped, where the
    /// extent is the largest coordinate magnitude of all positions; a closed record also drops a last position equal
    /// to the first. Tangents and arc lengths are then computed from the kept positions.
    ///
    /// - Throws: `.invalidInput` for a non-finite position or fewer than 2 kept positions (3 when `closed`).
    public init(positions: [Vec3], closed: Bool) throws(MeshError) {
        guard positions.allSatisfy(\.isFinite) else { throw .invalidInput("curve samples have a non-finite position") }
        let extent = positions.reduce(0.0) { max($0, abs($1.x), abs($1.y), abs($1.z)) }
        let tolerance = 1e-9 * (1 + extent)
        func same(_ a: Vec3, _ b: Vec3) -> Bool {
            abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance && abs(a.z - b.z) <= tolerance
        }
        var kept: [Vec3] = []
        kept.reserveCapacity(positions.count)
        for p in positions where kept.last.map({ !same($0, p) }) ?? true { kept.append(p) }
        if closed, kept.count > 1, same(kept[0], kept[kept.count - 1]) { kept.removeLast() }
        guard kept.count >= 2 else { throw .invalidInput("curve samples need at least 2 distinct positions") }
        guard !closed || kept.count >= 3 else {
            throw .invalidInput("closed curve samples need at least 3 distinct positions")
        }

        let m = kept.count
        var tangents: [Vec3] = []
        tangents.reserveCapacity(m)
        for i in 0..<m {
            let back: Vec3? = i > 0 ? kept[i] - kept[i - 1] : (closed ? kept[0] - kept[m - 1] : nil)
            let ahead: Vec3? = i + 1 < m ? kept[i + 1] - kept[i] : (closed ? kept[0] - kept[m - 1] : nil)
            switch (back, ahead) {
            case let (b?, a?):
                let sum = b.normalized + a.normalized
                tangents.append(sum.length >= 1e-6 ? sum.normalized : a.normalized)
            case let (nil, a?): tangents.append(a.normalized)
            case let (b?, nil): tangents.append(b.normalized)
            case (nil, nil): tangents.append(Vec3(1, 0, 0))   // unreachable: m ≥ 2
            }
        }
        var arcLengths = [0.0]
        arcLengths.reserveCapacity(m)
        for i in 1..<m { arcLengths.append(arcLengths[i - 1] + (kept[i] - kept[i - 1]).length) }
        self.positions = kept
        self.tangents = tangents
        self.arcLengths = arcLengths
        self.isClosed = closed
    }
}

/// Adaptive sampling of a `ParametricCurve` into `CurveSamples` within a distance tolerance.
public enum CurveSampler {
    /// The largest number of samples ever produced: 65,536.
    public static let maxSamples = 65_536
    /// The deepest subdivision of one segment: intervals at this depth are kept as they are.
    public static let maxDepth = 20

    /// Samples `curve` so the polyline stays within `tolerance` of it (clarification Q2).
    ///
    /// Each segment is first tested for straightness: its cubic control polygon (end points, and end points ± end
    /// derivatives / 3, which are the exact control points of a cubic Bézier or Catmull-Rom segment) lies within
    /// `tolerance` of the chord, so by the convex-hull property the whole segment does, and only its two end points
    /// are kept. Any other segment is split at least once at t = 0.5. An interval [a, b] is then kept when the curve
    /// at the 5 interior parameters a + k (b − a) / 6 (k = 1 … 5) lies within `tolerance` of the chord between its
    /// end points, or when it is `maxDepth` (20) halvings deep; otherwise it is split at its midpoint. The end points
    /// of the kept intervals, in order, go to `CurveSamples(positions:closed:)` (collapses dropped, tangents and
    /// cumulative chord arc lengths computed). A closed curve does not repeat its first sample.
    ///
    /// - Parameter budget: the most samples allowed, clamped to 2 … `maxSamples`.
    /// - Throws: `.invalidInput` for a tolerance that is not finite and positive, a non-finite curve point or a curve
    ///   that collapses (see `CurveSamples`); `.budget(vertices: count, indices: 0, budget:)` as soon as more than
    ///   `budget` samples would be produced (the reported budget has `maxVertices` = the clamped budget).
    public static func sample(_ curve: some ParametricCurve, tolerance: Double,
                              budget: Int = maxSamples) throws(MeshError) -> CurveSamples {
        guard tolerance.isFinite, tolerance > 0 else {
            throw .invalidInput("sampling tolerance must be finite and positive")
        }
        let limit = min(max(budget, 2), maxSamples)
        let segments = curve.segmentCount
        guard segments >= 1 else { throw .invalidInput("curve has no segments") }
        // A closed curve's final end point repeats its first sample and is removed below, so it may pass the limit.
        let rawLimit = limit + (curve.isClosed ? 1 : 0)
        var points: [Vec3] = []

        func append(_ p: Vec3) throws(MeshError) {
            guard p.isFinite else { throw .invalidInput("curve point is not finite") }
            points.append(p)
            if points.count > rawLimit {
                throw .budget(vertices: points.count, indices: 0, budget: MeshBudget(maxVertices: limit, maxIndices: 0))
            }
        }
        func flat(_ segment: Int, _ a: Double, _ b: Double, _ pa: Vec3, _ pb: Vec3) -> Bool {
            for k in 1...5 {
                let p = curve.position(segment: segment, t: a + (b - a) * Double(k) / 6)
                guard p.isFinite, distance(p, toSegment: pa, pb) <= tolerance else { return false }
            }
            return true
        }
        func subdivide(_ segment: Int, _ a: Double, _ b: Double, _ pa: Vec3, _ pb: Vec3,
                       depth: Int) throws(MeshError) {
            if depth >= maxDepth || flat(segment, a, b, pa, pb) {
                try append(pb)
                return
            }
            let m = 0.5 * (a + b)
            let pm = curve.position(segment: segment, t: m)
            guard pm.isFinite else { throw .invalidInput("curve point is not finite") }
            try subdivide(segment, a, m, pa, pm, depth: depth + 1)
            try subdivide(segment, m, b, pm, pb, depth: depth + 1)
        }

        for segment in 0..<segments {
            let p0 = curve.position(segment: segment, t: 0), p1 = curve.position(segment: segment, t: 1)
            if segment == 0 { try append(p0) }
            let b1 = p0 + curve.derivative(segment: segment, t: 0) / 3
            let b2 = p1 - curve.derivative(segment: segment, t: 1) / 3
            if b1.isFinite, b2.isFinite, distance(b1, toSegment: p0, p1) <= tolerance,
               distance(b2, toSegment: p0, p1) <= tolerance {
                try append(p1)
            } else {
                let pm = curve.position(segment: segment, t: 0.5)
                guard pm.isFinite else { throw .invalidInput("curve point is not finite") }
                try subdivide(segment, 0, 0.5, p0, pm, depth: 1)
                try subdivide(segment, 0.5, 1, pm, p1, depth: 1)
            }
        }
        if curve.isClosed, points.count > 1 { points.removeLast() }
        return try CurveSamples(positions: points, closed: curve.isClosed)
    }

    /// Distance from `p` to the segment `a`–`b` (to `a` when the segment has no length).
    static func distance(_ p: Vec3, toSegment a: Vec3, _ b: Vec3) -> Double {
        let ab = b - a, c = ab.dot(ab)
        guard c > 0 else { return (p - a).length }
        let s = min(max((p - a).dot(ab) / c, 0), 1)
        return (p - (a + ab * s)).length
    }
}
