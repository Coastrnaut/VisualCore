// WaveKnotKeeperGeometry — feature 321 (R02-G03-01) T-R02G0301-003 (FR-R02G0301-002, 003; clarifications Q2, Q3, Q4;
// research R1, R2). The exact integer geometry of the rope: orientation determinants, closed segment–segment and
// segment–triangle intersection, the sweep test of a move, the xy-projection summary (crossings, writhe, degeneracy),
// simplicity and tension. Every decision uses integer arithmetic only (coordinates −16 … 16, so every determinant is
// far below Int's range); nothing is rounded.
//
// Sweep (Q2): moving point P (neighbours A and B) to P′ sweeps the triangles A-P-P′ and P-P′-B. The move is clear when no
// segment that does not end at P meets either triangle, except that a segment ending at A may touch A-P-P′ at A alone
// and a segment starting at B may touch P-P′-B at B alone. Gates are not considered here; the play applies the gate
// exemption.
//
// Projection (Q3): every pair of non-adjacent segments is compared in the xy-plane. A pair whose projections cross at
// one point interior to both counts one crossing, signed by the right-hand rule: +1 when the cross product of the
// over-strand's direction and the under-strand's direction (xy) is positive, −1 when negative, the over-strand being the
// one with the larger z at the crossing. The projection is degenerate when a non-adjacent pair's projections meet in
// any other way (an endpoint on the other, a collinear overlap) or cross with equal z.
//
// Coplanar cases: two coplanar 3D figures meet exactly when their projections onto all three coordinate planes meet,
// because at least one of those projections is one-to-one on their plane and every projection preserves meeting.
import VisualCoreMath

/// The xy-projection summary of a rope: its crossing count, writhe and whether it is degenerate.
public struct WaveKnotKeeperSummary: Sendable, Hashable {
    /// The number of proper crossings of non-adjacent projected segments.
    public let crossings: Int
    /// The sum of the crossing signs.
    public let writhe: Int
    /// Whether some non-adjacent pair touches, overlaps or crosses at equal z in the projection.
    public let degenerate: Bool

    /// A summary of the given values.
    public init(crossings: Int, writhe: Int, degenerate: Bool) {
        self.crossings = crossings
        self.writhe = writhe
        self.degenerate = degenerate
    }
}

/// The exact integer geometry of Wave Knot Keeper (see the file header).
public enum WaveKnotKeeperGeometry {
    typealias P = WaveKnotKeeperPoint

    // MARK: Primitive determinants

    /// The 3D orientation of `d` against the plane through `a`, `b`, `c`: the determinant of (b − a, c − a, d − a);
    /// positive, negative or zero (coplanar).
    public static func orientation(_ a: WaveKnotKeeperPoint, _ b: WaveKnotKeeperPoint, _ c: WaveKnotKeeperPoint,
                                   _ d: WaveKnotKeeperPoint) -> Int {
        let (ux, uy, uz) = (b.x - a.x, b.y - a.y, b.z - a.z)
        let (vx, vy, vz) = (c.x - a.x, c.y - a.y, c.z - a.z)
        let (wx, wy, wz) = (d.x - a.x, d.y - a.y, d.z - a.z)
        return ux * (vy * wz - vz * wy) - uy * (vx * wz - vz * wx) + uz * (vx * wy - vy * wx)
    }

    /// The 2D cross product of (b − a) and (c − a).
    static func cross2(_ a: (Int, Int), _ b: (Int, Int), _ c: (Int, Int)) -> Int {
        (b.0 - a.0) * (c.1 - a.1) - (b.1 - a.1) * (c.0 - a.0)
    }

    /// Whether `c`, collinear with `a` and `b`, lies in their bounding box (so on the closed segment a–b).
    static func onSegment2(_ a: (Int, Int), _ b: (Int, Int), _ c: (Int, Int)) -> Bool {
        Swift.min(a.0, b.0) <= c.0 && c.0 <= Swift.max(a.0, b.0) && Swift.min(a.1, b.1) <= c.1 && c.1 <= Swift.max(a.1, b.1)
    }

    /// Whether the closed 2D segments p–q and r–s meet.
    static func segmentsMeet2(_ p: (Int, Int), _ q: (Int, Int), _ r: (Int, Int), _ s: (Int, Int)) -> Bool {
        let d1 = cross2(r, s, p), d2 = cross2(r, s, q), d3 = cross2(p, q, r), d4 = cross2(p, q, s)
        if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)) { return true }
        if d1 == 0 && onSegment2(r, s, p) { return true }
        if d2 == 0 && onSegment2(r, s, q) { return true }
        if d3 == 0 && onSegment2(p, q, r) { return true }
        if d4 == 0 && onSegment2(p, q, s) { return true }
        return false
    }

    /// Whether the closed 2D segment p–q meets the closed 2D triangle a–b–c (a degenerate triangle is the union of its
    /// edges).
    static func segmentMeetsTriangle2(_ p: (Int, Int), _ q: (Int, Int), _ a: (Int, Int), _ b: (Int, Int),
                                      _ c: (Int, Int)) -> Bool {
        if segmentsMeet2(p, q, a, b) || segmentsMeet2(p, q, b, c) || segmentsMeet2(p, q, c, a) { return true }
        let area = cross2(a, b, c)
        guard area != 0 else { return false }
        // Neither edge is met, so the segment is wholly inside or wholly outside: test one endpoint strictly.
        let s1 = cross2(a, b, p), s2 = cross2(b, c, p), s3 = cross2(c, a, p)
        return area > 0 ? (s1 > 0 && s2 > 0 && s3 > 0) : (s1 < 0 && s2 < 0 && s3 < 0)
    }

    /// The three coordinate-plane projections of a point: (x, y), (y, z), (x, z).
    static func projections(_ p: P) -> [(Int, Int)] { [(p.x, p.y), (p.y, p.z), (p.x, p.z)] }

    // MARK: 3D intersection

    /// Whether the closed segments p–q and r–s meet in space.
    public static func segmentsIntersect(_ p: WaveKnotKeeperPoint, _ q: WaveKnotKeeperPoint, _ r: WaveKnotKeeperPoint,
                                         _ s: WaveKnotKeeperPoint) -> Bool {
        guard orientation(p, q, r, s) == 0 else { return false }
        let pp = projections(p), qq = projections(q), rr = projections(r), ss = projections(s)
        for k in 0..<3 where !segmentsMeet2(pp[k], qq[k], rr[k], ss[k]) { return false }
        return true
    }

    /// Whether the closed segment p–q meets the closed triangle a–b–c (a degenerate triangle is the union of its edges).
    public static func segmentIntersectsTriangle(_ p: WaveKnotKeeperPoint, _ q: WaveKnotKeeperPoint,
                                                 _ a: WaveKnotKeeperPoint, _ b: WaveKnotKeeperPoint,
                                                 _ c: WaveKnotKeeperPoint) -> Bool {
        if isCollinear(a, b, c) {
            return segmentsIntersect(p, q, a, b) || segmentsIntersect(p, q, b, c) || segmentsIntersect(p, q, c, a)
        }
        let d1 = orientation(a, b, c, p), d2 = orientation(a, b, c, q)
        if (d1 > 0 && d2 > 0) || (d1 < 0 && d2 < 0) { return false }
        if d1 == 0 && d2 == 0 {
            let pp = projections(p), qq = projections(q), aa = projections(a), bb = projections(b), cc = projections(c)
            for k in 0..<3 where !segmentMeetsTriangle2(pp[k], qq[k], aa[k], bb[k], cc[k]) { return false }
            return true
        }
        // The segment meets the plane in one point; it lies in the triangle exactly when the line p–q passes on the
        // same side (or on) every edge.
        let e1 = orientation(p, q, a, b), e2 = orientation(p, q, b, c), e3 = orientation(p, q, c, a)
        return (e1 >= 0 && e2 >= 0 && e3 >= 0) || (e1 <= 0 && e2 <= 0 && e3 <= 0)
    }

    /// Whether `a`, `b` and `c` lie on one line (the cross product of b − a and c − a is zero).
    public static func isCollinear(_ a: WaveKnotKeeperPoint, _ b: WaveKnotKeeperPoint, _ c: WaveKnotKeeperPoint) -> Bool {
        let (ux, uy, uz) = (b.x - a.x, b.y - a.y, b.z - a.z)
        let (vx, vy, vz) = (c.x - a.x, c.y - a.y, c.z - a.z)
        return uy * vz - uz * vy == 0 && uz * vx - ux * vz == 0 && ux * vy - uy * vx == 0
    }

    /// Whether the segment from `v` to `w` (w ≠ v) meets the triangle v–x–y only at their shared vertex `v`.
    static func touchesOnlyAtVertex(_ v: P, _ w: P, _ x: P, _ y: P) -> Bool {
        let d = (w.x - v.x, w.y - v.y, w.z - v.z)
        if isCollinear(v, x, y) {
            // The triangle is the segment hull of three collinear points; the segment enters it only along the line.
            guard isCollinear(v, w, x) && isCollinear(v, w, y) else { return true }
            let towardX = d.0 * (x.x - v.x) + d.1 * (x.y - v.y) + d.2 * (x.z - v.z)
            let towardY = d.0 * (y.x - v.x) + d.1 * (y.y - v.y) + d.2 * (y.z - v.z)
            return towardX <= 0 && towardY <= 0
        }
        guard orientation(v, x, y, w) == 0 else { return true }
        // Coplanar: inside the triangle's angle at v means more than v is shared. Use a one-to-one projection.
        let n = (( x.y - v.y) * (y.z - v.z) - (x.z - v.z) * (y.y - v.y),
                 (x.z - v.z) * (y.x - v.x) - (x.x - v.x) * (y.z - v.z),
                 (x.x - v.x) * (y.y - v.y) - (x.y - v.y) * (y.x - v.x))
        let k: Int = abs(n.2) >= abs(n.0) && abs(n.2) >= abs(n.1) ? 0 : (abs(n.0) >= abs(n.1) ? 1 : 2)
        let vv = projections(v)[k], ww = projections(w)[k], xx = projections(x)[k], yy = projections(y)[k]
        let s = cross2(vv, xx, yy)
        let c1 = cross2(vv, xx, ww), c2 = cross2(vv, ww, yy)
        let inside = s > 0 ? (c1 >= 0 && c2 >= 0) : (c1 <= 0 && c2 <= 0)
        return !inside
    }

    // MARK: Moves

    /// Whether moving point `index` of the closed rope `points` to `to` sweeps through no other part of the rope (see the
    /// file header). Ignores gates, bounds and coincidence, which the play checks. A rope of fewer than 4 points or an
    /// index outside the rope is never clear.
    public static func sweepIsClear(_ points: [WaveKnotKeeperPoint], moving index: Int, to: WaveKnotKeeperPoint) -> Bool {
        let n = points.count
        guard n >= 4, points.indices.contains(index) else { return false }
        let a = points[(index - 1 + n) % n], p = points[index], b = points[(index + 1) % n]
        let beforeA = (index - 2 + 2 * n) % n   // segment beforeA … A ends at A
        let afterB = (index + 1) % n            // segment B … next starts at B
        for j in 0..<n {
            if j == (index - 1 + n) % n || j == index { continue }   // the two segments that end at P
            let s = points[j], t = points[(j + 1) % n]
            if j == beforeA {
                // Ends at A: may touch A-P-P′ at A alone; must miss P-P′-B.
                if !touchesOnlyAtVertex(a, s, p, to) { return false }
                if segmentIntersectsTriangle(s, t, p, to, b) { return false }
            } else if j == afterB {
                // Starts at B: may touch P-P′-B at B alone; must miss A-P-P′.
                if !touchesOnlyAtVertex(b, t, p, to) { return false }
                if segmentIntersectsTriangle(s, t, a, p, to) { return false }
            } else {
                if segmentIntersectsTriangle(s, t, a, p, to) || segmentIntersectsTriangle(s, t, p, to, b) { return false }
            }
        }
        return true
    }

    /// Whether the closed rope is simple: no two non-adjacent segments meet and no two adjacent segments overlap beyond
    /// their shared vertex.
    public static func isSimple(_ points: [WaveKnotKeeperPoint]) -> Bool {
        let n = points.count
        guard n >= 4 else { return false }
        for i in 0..<n {
            let a = points[i], b = points[(i + 1) % n], c = points[(i + 2) % n]
            // Adjacent segments a–b and b–c overlap when collinear and folding back.
            if isCollinear(a, b, c) {
                let dot = (a.x - b.x) * (c.x - b.x) + (a.y - b.y) * (c.y - b.y) + (a.z - b.z) * (c.z - b.z)
                if dot > 0 { return false }
            }
            for j in (i + 2)..<(i + n - 1) {
                let jj = j % n
                guard jj > i else { continue }   // each unordered pair once
                if segmentsIntersect(a, b, points[jj], points[(jj + 1) % n]) { return false }
            }
        }
        return true
    }

    // MARK: Projection

    /// The xy-projection summary of the closed rope (see the file header).
    public static func summary(_ points: [WaveKnotKeeperPoint]) -> WaveKnotKeeperSummary {
        let n = points.count
        var crossings = 0
        var writhe = 0
        var degenerate = false
        guard n >= 4 else { return WaveKnotKeeperSummary(crossings: 0, writhe: 0, degenerate: true) }
        for i in 0..<(n - 2) {
            for j in stride(from: i + 2, to: n, by: 1) {
                if i == 0 && j == n - 1 { continue }   // adjacent across the wrap
                let p1 = points[i], q1 = points[(i + 1) % n], p2 = points[j], q2 = points[(j + 1) % n]
                switch crossing(p1, q1, p2, q2) {
                case .none: break
                case .degenerate: degenerate = true
                case .signed(let sign):
                    crossings += 1
                    writhe += sign
                }
            }
        }
        return WaveKnotKeeperSummary(crossings: crossings, writhe: writhe, degenerate: degenerate)
    }

    /// How two segments' xy-projections relate.
    enum Crossing: Equatable {
        /// They do not meet.
        case none
        /// They meet other than at one point interior to both, or cross at equal z.
        case degenerate
        /// They cross properly with this sign.
        case signed(Int)
    }

    /// The projected relation of segments p1–q1 and p2–q2 (see ``Crossing``).
    static func crossing(_ p1: P, _ q1: P, _ p2: P, _ q2: P) -> Crossing {
        let a = (p1.x, p1.y), b = (q1.x, q1.y), c = (p2.x, p2.y), d = (q2.x, q2.y)
        guard segmentsMeet2(a, b, c, d) else { return .none }
        let o1 = cross2(c, d, a), o2 = cross2(c, d, b), o3 = cross2(a, b, c), o4 = cross2(a, b, d)
        let proper = ((o1 > 0 && o2 < 0) || (o1 < 0 && o2 > 0)) && ((o3 > 0 && o4 < 0) || (o3 < 0 && o4 > 0))
        guard proper else { return .degenerate }
        // p1 + t·d1 = p2 + u·d2 with t = tn / den, u = un / den.
        let d1 = (b.0 - a.0, b.1 - a.1), d2 = (d.0 - c.0, d.1 - c.1)
        let den = d1.0 * d2.1 - d1.1 * d2.0
        let w = (c.0 - a.0, c.1 - a.1)
        let tn = w.0 * d2.1 - w.1 * d2.0
        let un = w.0 * d1.1 - w.1 * d1.0
        let z1 = p1.z * den + tn * (q1.z - p1.z)
        let z2 = p2.z * den + un * (q2.z - p2.z)
        let difference = (z1 - z2) * (den > 0 ? 1 : -1)
        guard difference != 0 else { return .degenerate }
        let over = difference > 0 ? d1 : d2
        let under = difference > 0 ? d2 : d1
        let turn = over.0 * under.1 - over.1 * under.0
        return .signed(turn > 0 ? 1 : -1)
    }

    // MARK: Tension

    /// The tension of the closed rope: the sum over its segments of the squared length.
    public static func tension(_ points: [WaveKnotKeeperPoint]) -> Int {
        let n = points.count
        var total = 0
        for i in 0..<n {
            let a = points[i], b = points[(i + 1) % n]
            let dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z
            total += dx * dx + dy * dy + dz * dz
        }
        return total
    }
}
