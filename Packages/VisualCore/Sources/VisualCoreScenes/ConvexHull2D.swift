// ConvexHull2D — feature 213 (R02-F13) T-R02F13-002 (FR-R02F13-002, FR-R02F13-008; research R3). The convex hull of 2D
// points by A. M. Andrew's monotone chain ("Another efficient algorithm for convex hulls in two dimensions", Information
// Processing Letters 9(5), 1979) with a lexicographic sort, so the result is deterministic; and the signed shoelace area.
import VisualCoreMath

/// Planar convex hull and polygon area (see the file header).
public enum ConvexHull2D {
    /// The convex hull of `points`, counter-clockwise, starting at the lexicographically smallest corner (x, then y).
    ///
    /// Non-finite points are ignored. A point is dropped as collinear when the turn it makes has cross product at most
    /// 1e-12 × s², where s is the diagonal of the points' bounding box. When fewer than three non-collinear points remain
    /// (no points, one distinct point, or all points on one line) the result is empty: a degenerate hull has no area
    /// and casts no shadow.
    public static func hull(_ points: [Vec2]) -> [Vec2] {
        let finite = points.filter(\.isFinite)
        guard finite.count >= 3 else { return [] }
        let sorted = finite.sorted { $0.x < $1.x || ($0.x == $1.x && $0.y < $1.y) }
        var lo = sorted[0], hi = sorted[0]
        for p in sorted {
            lo = Vec2(Swift.min(lo.x, p.x), Swift.min(lo.y, p.y))
            hi = Vec2(Swift.max(hi.x, p.x), Swift.max(hi.y, p.y))
        }
        let extent = (hi - lo).length
        guard extent > 0 else { return [] }
        let eps = 1e-12 * extent * extent

        func turn(_ o: Vec2, _ a: Vec2, _ b: Vec2) -> Double { (a - o).cross(b - o) }

        var lower: [Vec2] = []
        for p in sorted {
            while lower.count >= 2, turn(lower[lower.count - 2], lower[lower.count - 1], p) <= eps { lower.removeLast() }
            lower.append(p)
        }
        var upper: [Vec2] = []
        for p in sorted.reversed() {
            while upper.count >= 2, turn(upper[upper.count - 2], upper[upper.count - 1], p) <= eps { upper.removeLast() }
            upper.append(p)
        }
        lower.removeLast()
        upper.removeLast()
        let hull = lower + upper
        return hull.count >= 3 ? hull : []
    }

    /// The signed area of a closed polygon by the shoelace formula: positive when counter-clockwise, negative when
    /// clockwise, 0 for fewer than three corners.
    public static func area(_ polygon: [Vec2]) -> Double {
        guard polygon.count >= 3 else { return 0 }
        var sum = 0.0
        var prev = polygon[polygon.count - 1]
        for p in polygon {
            sum += prev.cross(p)
            prev = p
        }
        return sum / 2
    }
}
