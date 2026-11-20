// PolygonCleanup — feature 212 (R02-F12) T-R02F12-002 (FR-R02F12-004, FR-R02F12-006; clarification Q3). Cleans a planar
// 3D polygon before it becomes a face: removes points within `tolerance` of the previous point (cyclically), removes
// corners within `tolerance` of the line through their neighbours (repeating until none is left), and orients the
// result counter-clockwise seen from the side `normal` points to. Fewer than three corners left is a degenerate polygon.
import VisualCoreMath

/// Cleanup of planar 3D polygons (see the file header).
public enum PolygonCleanup {
    /// The cleaned corners of `points`, counter-clockwise about `normal`; throws `.degeneratePolygon` when fewer than
    /// three corners remain and `.nonFinite` for a non-finite point, normal or tolerance.
    public static func clean(_ points: [Vec3], normal: Vec3, tolerance: Double) throws(ConvexSolidError) -> [Vec3] {
        guard tolerance.isFinite, tolerance >= 0 else { throw .nonFinite("tolerance") }
        guard normal.x.isFinite, normal.y.isFinite, normal.z.isFinite else { throw .nonFinite("normal") }
        for p in points where !(p.x.isFinite && p.y.isFinite && p.z.isFinite) { throw .nonFinite("point") }
        var corners: [Vec3] = []
        for p in points where corners.last.map({ ($0 - p).length > tolerance }) ?? true { corners.append(p) }
        while corners.count > 1, (corners[0] - corners[corners.count - 1]).length <= tolerance { corners.removeLast() }
        var changed = true
        while changed, corners.count >= 3 {
            changed = false
            for i in corners.indices {
                let a = corners[(i + corners.count - 1) % corners.count], b = corners[i]
                let c = corners[(i + 1) % corners.count]
                if distance(b, toLineThrough: a, c) <= tolerance {
                    corners.remove(at: i)
                    changed = true
                    break
                }
            }
        }
        guard corners.count >= 3 else { throw .degeneratePolygon }
        if areaVector(corners).dot(normal) < 0 { corners.reverse() }
        return corners
    }

    /// Twice the vector area of a closed polygon (Newell's method): its direction is the polygon's normal by the
    /// right-hand rule, its length twice the area.
    public static func areaVector(_ corners: [Vec3]) -> Vec3 {
        var sum = Vec3.zero
        for i in corners.indices {
            let a = corners[i], b = corners[(i + 1) % corners.count]
            sum += Vec3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
        }
        return sum
    }

    private static func distance(_ p: Vec3, toLineThrough a: Vec3, _ c: Vec3) -> Double {
        let d = c - a
        let l = d.length
        guard l > 0 else { return (p - a).length }
        return (p - a).cross(d).length / l
    }
}
