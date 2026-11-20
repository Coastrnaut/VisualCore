// WaveKnotKeeperGeometryTests — feature 321 (R02-G03-01) T-R02G0301-003 (FR-R02G0301-002, 003; SC-R02G0301-003 and the
// sweep refusals of SC-R02G0301-001; clarifications Q2, Q3). The exact integer geometry against independent methods
// written here: the xy-projection summary of 500 seeded ropes equals a brute-force count with exact rational
// parameters (crossings, writhe, degeneracy) and is invariant under translation, cyclic rotation and (for crossings and
// writhe) reversal; known diagrams (one lifted figure-eight crossing with its hand-computed sign, its z-mirror, a
// 7-stick trefoil, three degenerate projections); segment–segment and segment–triangle intersection on constructed
// cases and on 2,000 random small cases against an exact case analysis; the sweep refusals of a move (a piercing
// segment, the neighbour allowance at the shared vertex alone); simplicity; tension. Seed 2_321. Explicit types, plain
// loops, short runs.
import Foundation
import Testing
@testable import WaveKnotKeeperCore

@Suite struct WaveKnotKeeperGeometryTests {
    typealias Point = WaveKnotKeeperPoint
    typealias Geometry = WaveKnotKeeperGeometry

    // MARK: Independent reference (exact integer / rational arithmetic, written differently from the kernel)

    /// An integer 3-vector.
    struct V3: Equatable {
        let x: Int
        let y: Int
        let z: Int
        init(_ x: Int, _ y: Int, _ z: Int) { self.x = x; self.y = y; self.z = z }
        init(_ p: Point) { x = p.x; y = p.y; z = p.z }
        static func - (l: V3, r: V3) -> V3 { V3(l.x - r.x, l.y - r.y, l.z - r.z) }
        static func + (l: V3, r: V3) -> V3 { V3(l.x + r.x, l.y + r.y, l.z + r.z) }
        static func * (k: Int, v: V3) -> V3 { V3(k * v.x, k * v.y, k * v.z) }
        func dot(_ o: V3) -> Int { x * o.x + y * o.y + z * o.z }
        func cross(_ o: V3) -> V3 { V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x) }
        var isZero: Bool { x == 0 && y == 0 && z == 0 }
    }

    /// Whether 2D point c lies on the closed 2D segment a–b (collinear, and between by the dot-product test).
    static func onSegment2D(_ ax: Int, _ ay: Int, _ bx: Int, _ by: Int, _ cx: Int, _ cy: Int) -> Bool {
        let cross: Int = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
        guard cross == 0 else { return false }
        return (cx - ax) * (cx - bx) + (cy - ay) * (cy - by) <= 0
    }

    /// The reference relation of two projected segments: 0 none, 1 degenerate, 2 + sign proper crossing (+1 or −1).
    /// Solves p1 + t·(q1 − p1) = p2 + u·(q2 − p2) with t = tn/den, u = un/den (den > 0); a meeting that is not at a single
    /// point interior to both, or a crossing at equal interpolated z, is degenerate.
    static func referenceRelation(_ p1: Point, _ q1: Point, _ p2: Point, _ q2: Point) -> (kind: Int, sign: Int) {
        let rx: Int = q1.x - p1.x, ry: Int = q1.y - p1.y
        let sx: Int = q2.x - p2.x, sy: Int = q2.y - p2.y
        var den: Int = rx * sy - ry * sx
        if den == 0 {
            // Parallel or a zero-length projection: they meet exactly when an endpoint of one lies on the other.
            let touches: Bool = onSegment2D(p1.x, p1.y, q1.x, q1.y, p2.x, p2.y)
                || onSegment2D(p1.x, p1.y, q1.x, q1.y, q2.x, q2.y)
                || onSegment2D(p2.x, p2.y, q2.x, q2.y, p1.x, p1.y)
                || onSegment2D(p2.x, p2.y, q2.x, q2.y, q1.x, q1.y)
            return (touches ? 1 : 0, 0)
        }
        let wx: Int = p2.x - p1.x, wy: Int = p2.y - p1.y
        var tn: Int = wx * sy - wy * sx
        var un: Int = wx * ry - wy * rx
        if den < 0 { den = -den; tn = -tn; un = -un }
        if tn < 0 || tn > den || un < 0 || un > den { return (0, 0) }
        if tn == 0 || tn == den || un == 0 || un == den { return (1, 0) }
        // z at the crossing, both scaled by den.
        let z1: Int = p1.z * (den - tn) + q1.z * tn
        let z2: Int = p2.z * (den - un) + q2.z * un
        if z1 == z2 { return (1, 0) }
        let overX: Int = z1 > z2 ? rx : sx, overY: Int = z1 > z2 ? ry : sy
        let underX: Int = z1 > z2 ? sx : rx, underY: Int = z1 > z2 ? sy : ry
        let turn: Int = overX * underY - overY * underX
        return (2, turn > 0 ? 1 : -1)
    }

    /// The reference summary: every unordered pair of non-adjacent segments of the closed rope.
    static func referenceSummary(_ points: [Point]) -> WaveKnotKeeperSummary {
        let n: Int = points.count
        var crossings: Int = 0
        var writhe: Int = 0
        var degenerate: Bool = false
        for i in 0..<n {
            for j in 0..<n {
                if j <= i { continue }
                let adjacent: Bool = j == (i + 1) % n || i == (j + 1) % n
                if adjacent { continue }
                let r: (kind: Int, sign: Int) = referenceRelation(points[i], points[(i + 1) % n],
                                                                  points[j], points[(j + 1) % n])
                if r.kind == 1 { degenerate = true }
                if r.kind == 2 { crossings += 1; writhe += r.sign }
            }
        }
        return WaveKnotKeeperSummary(crossings: crossings, writhe: writhe, degenerate: degenerate)
    }

    /// Reference: whether point x lies on the closed segment a–b in space.
    static func refPointOnSegment(_ x: V3, _ a: V3, _ b: V3) -> Bool {
        let d: V3 = b - a
        if d.isZero { return x == a }
        guard (x - a).cross(d).isZero else { return false }
        let k: Int = (x - a).dot(d)
        return k >= 0 && k <= d.dot(d)
    }

    /// Reference: whether the closed segments p–q and r–s meet in space (exact case analysis with rational parameters).
    static func refSegments(_ p: V3, _ q: V3, _ r: V3, _ s: V3) -> Bool {
        let d1: V3 = q - p, d2: V3 = s - r
        if d1.isZero { return refPointOnSegment(p, r, s) }
        if d2.isZero { return refPointOnSegment(r, p, q) }
        let n: V3 = d1.cross(d2)
        let w: V3 = r - p
        if n.isZero {
            // Parallel: they meet only when collinear and their parameter intervals along d1 overlap.
            guard w.cross(d1).isZero else { return false }
            let len: Int = d1.dot(d1)
            let tr: Int = w.dot(d1), ts: Int = (s - p).dot(d1)
            let lo: Int = min(tr, ts), hi: Int = max(tr, ts)
            return hi >= 0 && lo <= len
        }
        guard w.dot(n) == 0 else { return false }   // skew
        let nn: Int = n.dot(n)
        let tn: Int = w.cross(d2).dot(n)   // t = tn / nn
        let un: Int = w.cross(d1).dot(n)   // u = un / nn
        return tn >= 0 && tn <= nn && un >= 0 && un <= nn
    }

    /// Reference: whether the scaled point xs / k (k > 0) lies in the closed non-degenerate triangle a–b–c with normal n.
    static func refInTriangle(_ xs: V3, _ k: Int, _ a: V3, _ b: V3, _ c: V3, _ n: V3) -> Bool {
        let corners: [V3] = [a, b, c]
        for e in 0..<3 {
            let from: V3 = corners[e], to: V3 = corners[(e + 1) % 3]
            let side: Int = (to - from).cross(xs - k * from).dot(n)
            if side < 0 { return false }
        }
        return true
    }

    /// Reference: whether the closed segment p–q meets the closed triangle a–b–c (degenerate: the union of its edges).
    static func refSegmentTriangle(_ p: V3, _ q: V3, _ a: V3, _ b: V3, _ c: V3) -> Bool {
        let n: V3 = (b - a).cross(c - a)
        if n.isZero { return refSegments(p, q, a, b) || refSegments(p, q, b, c) || refSegments(p, q, c, a) }
        let dp: Int = (p - a).dot(n), dq: Int = (q - a).dot(n)
        if (dp > 0 && dq > 0) || (dp < 0 && dq < 0) { return false }
        if dp == 0 && dq == 0 {
            if refInTriangle(p, 1, a, b, c, n) || refInTriangle(q, 1, a, b, c, n) { return true }
            return refSegments(p, q, a, b) || refSegments(p, q, b, c) || refSegments(p, q, c, a)
        }
        // One point on the plane: x = p + t (q − p) with t = dp / (dp − dq); scale by k = dp − dq made positive.
        var k: Int = dp - dq
        var t: Int = dp
        if k < 0 { k = -k; t = -t }
        let xs: V3 = (k - t) * p + t * q
        return refInTriangle(xs, k, a, b, c, n)
    }

    // MARK: Helpers

    static func randomRope(_ random: inout WaveKnotKeeperRandom, count: Int, spread: Int) -> [Point] {
        var points: [Point] = []
        for _ in 0..<count {
            points.append(Point(x: random.int(-spread...spread), y: random.int(-spread...spread),
                                z: random.int(-spread...spread)))
        }
        return points
    }

    static func randomPoint(_ random: inout WaveKnotKeeperRandom, flat: Bool) -> Point {
        Point(x: random.int(-3...3), y: random.int(-3...3), z: flat ? 0 : random.int(-3...3))
    }

    static func mirrored(_ points: [Point]) -> [Point] {
        var result: [Point] = []
        for p in points { result.append(Point(x: p.x, y: p.y, z: -p.z)) }
        return result
    }

    /// A figure-eight in the xy-plane: segment 0 (0→1) crosses segment 2 (2→3) at (0, 0); point 1 is lifted to z = 2,
    /// so segment 0 is at z = 1 at the crossing and passes over segment 2 (z = 0).
    static let figureEight: [Point] = [Point(x: -2, y: -1, z: 0), Point(x: 2, y: 1, z: 2), Point(x: 2, y: -1, z: 0),
                                       Point(x: -2, y: 1, z: 0)]

    /// A 7-stick trefoil: the (2, 3) torus knot (2 + cos 3t)(cos 2t, sin 2t) with depth 3 sin 3t, sampled at 7 points
    /// (phase 0.05), scaled by 2 and rounded to the lattice. Its projection has three alternating crossings.
    static let trefoil: [Point] = [Point(x: 6, y: 1, z: 0), Point(x: -1, y: 2, z: 1), Point(x: -5, y: -3, z: -2),
                                   Point(x: 2, y: -2, z: 3), Point(x: 2, y: 3, z: -3), Point(x: -5, y: 2, z: 3),
                                   Point(x: 0, y: -2, z: -2)]

    // MARK: 1. Summary against the reference

    @Test func summaryMatchesTheReferenceOn500SeededRopes() {
        var crossingTotal: Int = 0
        var degenerateCount: Int = 0
        for offset in 0..<500 {
            var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: 2_321 &+ UInt64(offset))
            let count: Int = random.int(6...16)
            let rope: [Point] = Self.randomRope(&random, count: count, spread: 10)
            let summary: WaveKnotKeeperSummary = Geometry.summary(rope)
            let reference: WaveKnotKeeperSummary = Self.referenceSummary(rope)
            #expect(summary == reference, "rope \(offset): \(rope)")
            crossingTotal += summary.crossings
            if summary.degenerate { degenerateCount += 1 }

            // Translation by a vector that keeps every coordinate in −16 … 16.
            let shift: Point = Point(x: random.int(-6...6), y: random.int(-6...6), z: random.int(-6...6))
            var moved: [Point] = []
            for p in rope { moved.append(Point(x: p.x + shift.x, y: p.y + shift.y, z: p.z + shift.z)) }
            #expect(Geometry.summary(moved) == summary, "translated rope \(offset)")

            // Cyclic rotation of the point list.
            let k: Int = random.int(1...(count - 1))
            var rotated: [Point] = []
            for i in 0..<count { rotated.append(rope[(i + k) % count]) }
            #expect(Geometry.summary(rotated) == summary, "rotated rope \(offset)")

            // Reversal flips both strands of every crossing, so every sign (and the degeneracy) stays.
            var reversed: [Point] = []
            for i in 0..<count { reversed.append(rope[count - 1 - i]) }
            let back: WaveKnotKeeperSummary = Geometry.summary(reversed)
            #expect(back.crossings == summary.crossings && back.writhe == summary.writhe, "reversed rope \(offset)")
            #expect(back.degenerate == summary.degenerate, "reversed rope \(offset)")
        }
        // The sample exercises both crossings and degeneracy.
        #expect(crossingTotal > 500)
        #expect(degenerateCount > 0 && degenerateCount < 500)
    }

    // MARK: 2. Known diagrams

    @Test func oneLiftedCrossingAndItsMirror() {
        // Over-strand: segment 0, direction (2,1) − (−2,−1) = (4, 2), z = 1 at (0, 0). Under-strand: segment 2, direction
        // (−2,1) − (2,−1) = (−4, 2), z = 0. cross(over, under) = 4·2 − 2·(−4) = 16 > 0, so the sign is +1.
        let summary: WaveKnotKeeperSummary = Geometry.summary(Self.figureEight)
        #expect(summary == WaveKnotKeeperSummary(crossings: 1, writhe: 1, degenerate: false))
        #expect(Geometry.isSimple(Self.figureEight))
        // z → −z exchanges over and under: cross((−4, 2), (4, 2)) = −16, so the sign is −1.
        let mirror: WaveKnotKeeperSummary = Geometry.summary(Self.mirrored(Self.figureEight))
        #expect(mirror == WaveKnotKeeperSummary(crossings: 1, writhe: -1, degenerate: false))
        #expect(Self.referenceSummary(Self.figureEight) == summary)
    }

    @Test func aSevenStickTrefoil() {
        let summary: WaveKnotKeeperSummary = Geometry.summary(Self.trefoil)
        #expect(summary.crossings == 3 && abs(summary.writhe) == 3 && !summary.degenerate)
        #expect(summary == Self.referenceSummary(Self.trefoil))
        #expect(Geometry.isSimple(Self.trefoil))
        let mirror: WaveKnotKeeperSummary = Geometry.summary(Self.mirrored(Self.trefoil))
        #expect(mirror.crossings == 3 && mirror.writhe == -summary.writhe && !mirror.degenerate)
    }

    @Test func degenerateProjections() {
        // A vertex of segment 2–3 projects onto the interior of segment 0–1 (the point (2, 0), lifted in z).
        let touching: [Point] = [Point(x: 0, y: 0, z: 0), Point(x: 4, y: 0, z: 0), Point(x: 4, y: 4, z: 0),
                                 Point(x: 2, y: 0, z: 3), Point(x: 0, y: 4, z: 0)]
        #expect(Geometry.summary(touching).degenerate)
        #expect(Self.referenceSummary(touching).degenerate)
        // Segment 2–3 projects onto a collinear overlap with segment 0–1, at another height.
        let overlapping: [Point] = [Point(x: 0, y: 0, z: 0), Point(x: 6, y: 0, z: 0), Point(x: 6, y: 4, z: 0),
                                    Point(x: 5, y: 0, z: 2), Point(x: 1, y: 0, z: 2), Point(x: 0, y: 4, z: 0)]
        #expect(Geometry.summary(overlapping).degenerate)
        #expect(Self.referenceSummary(overlapping).degenerate)
        // The figure-eight flat: segments 0 and 2 cross at (0, 0) both at z = 0.
        var flat: [Point] = Self.figureEight
        flat[1] = Point(x: 2, y: 1, z: 0)
        #expect(Geometry.summary(flat).degenerate)
        #expect(!Geometry.isSimple(flat))
        // Equal z at the crossing without the strands lying flat: z = 1 on both (segment 0 from z 0 to 2, segment 2
        // from z 2 to 0).
        let level: [Point] = [Point(x: -2, y: -1, z: 0), Point(x: 2, y: 1, z: 2), Point(x: 2, y: -1, z: 2),
                              Point(x: -2, y: 1, z: 0)]
        #expect(Geometry.summary(level).degenerate)
        #expect(!Geometry.isSimple(level))
    }

    // MARK: 3. Intersection primitives

    @Test func segmentTriangleConstructedCases() {
        let a: Point = Point(x: 0, y: 0, z: 0), b: Point = Point(x: 4, y: 0, z: 0), c: Point = Point(x: 0, y: 4, z: 0)
        // Piercing the interior.
        #expect(Geometry.segmentIntersectsTriangle(Point(x: 1, y: 1, z: -1), Point(x: 1, y: 1, z: 1), a, b, c))
        // Stopping short of the plane.
        #expect(!Geometry.segmentIntersectsTriangle(Point(x: 1, y: 1, z: 1), Point(x: 1, y: 1, z: 2), a, b, c))
        // Touching an edge (through (2, 0, 0)) and ending on an edge.
        #expect(Geometry.segmentIntersectsTriangle(Point(x: 2, y: -1, z: 1), Point(x: 2, y: 1, z: -1), a, b, c))
        #expect(Geometry.segmentIntersectsTriangle(Point(x: 2, y: 2, z: 0), Point(x: 2, y: 2, z: 3), a, b, c))
        // Passing just outside an edge.
        #expect(!Geometry.segmentIntersectsTriangle(Point(x: 3, y: 2, z: 1), Point(x: 3, y: 2, z: -1), a, b, c))
        // Touching a vertex.
        #expect(Geometry.segmentIntersectsTriangle(Point(x: -1, y: -1, z: 1), Point(x: 1, y: 1, z: -1), a, b, c))
        #expect(Geometry.segmentIntersectsTriangle(Point(x: 4, y: 0, z: 0), Point(x: 5, y: 3, z: 2), a, b, c))
        // Coplanar crossing, coplanar inside, coplanar touching a vertex from outside, coplanar disjoint.
        #expect(Geometry.segmentIntersectsTriangle(Point(x: 2, y: -1, z: 0), Point(x: 2, y: 5, z: 0), a, b, c))
        #expect(Geometry.segmentIntersectsTriangle(Point(x: 1, y: 1, z: 0), Point(x: 2, y: 1, z: 0), a, b, c))
        #expect(Geometry.segmentIntersectsTriangle(Point(x: 4, y: 0, z: 0), Point(x: 6, y: 0, z: 0), a, b, c))
        #expect(!Geometry.segmentIntersectsTriangle(Point(x: 5, y: 5, z: 0), Point(x: 6, y: 1, z: 0), a, b, c))
        // Parallel off the plane.
        #expect(!Geometry.segmentIntersectsTriangle(Point(x: 1, y: 1, z: 1), Point(x: 3, y: 0, z: 1), a, b, c))
        // A degenerate (collinear) triangle is the segment (0,0,0)–(4,4,4).
        let d: Point = Point(x: 2, y: 2, z: 2), e: Point = Point(x: 4, y: 4, z: 4)
        #expect(Geometry.segmentIntersectsTriangle(Point(x: 2, y: 0, z: 2), Point(x: 2, y: 4, z: 2), a, d, e))
        #expect(Geometry.segmentIntersectsTriangle(Point(x: 0, y: 4, z: 0), Point(x: 4, y: 0, z: 4), a, d, e))
        #expect(!Geometry.segmentIntersectsTriangle(Point(x: 0, y: 1, z: 0), Point(x: 4, y: 5, z: 4), a, d, e))
        #expect(!Geometry.segmentIntersectsTriangle(Point(x: 5, y: 5, z: 5), Point(x: 6, y: 6, z: 6), a, d, e))
    }

    @Test func segmentSegmentConstructedCases() {
        let p: Point = Point(x: 0, y: 0, z: 0), q: Point = Point(x: 4, y: 0, z: 0)
        // Crossing at an interior point; skew; parallel apart; collinear overlap; collinear apart; endpoint touch.
        #expect(Geometry.segmentsIntersect(p, q, Point(x: 2, y: -1, z: 0), Point(x: 2, y: 1, z: 0)))
        #expect(!Geometry.segmentsIntersect(p, q, Point(x: 2, y: -1, z: 1), Point(x: 2, y: 1, z: 1)))
        #expect(!Geometry.segmentsIntersect(p, q, Point(x: 0, y: 1, z: 0), Point(x: 4, y: 1, z: 0)))
        #expect(Geometry.segmentsIntersect(p, q, Point(x: 3, y: 0, z: 0), Point(x: 6, y: 0, z: 0)))
        #expect(!Geometry.segmentsIntersect(p, q, Point(x: 5, y: 0, z: 0), Point(x: 6, y: 0, z: 0)))
        #expect(Geometry.segmentsIntersect(p, q, Point(x: 4, y: 0, z: 0), Point(x: 4, y: 3, z: 5)))
        // Coplanar, lines meet outside both segments.
        #expect(!Geometry.segmentsIntersect(p, q, Point(x: 6, y: 1, z: 0), Point(x: 7, y: 3, z: 0)))
    }

    @Test func primitivesMatchTheReferenceOn2000RandomCases() {
        var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: 2_321)
        var segmentHits: Int = 0
        var triangleHits: Int = 0
        for index in 0..<2_000 {
            // A third of the cases lie in the plane z = 0, to exercise the coplanar branches.
            let flat: Bool = index % 3 == 0
            let p: Point = Self.randomPoint(&random, flat: flat), q: Point = Self.randomPoint(&random, flat: flat)
            let r: Point = Self.randomPoint(&random, flat: flat), s: Point = Self.randomPoint(&random, flat: flat)
            let t: Point = Self.randomPoint(&random, flat: flat)
            let segment: Bool = Geometry.segmentsIntersect(p, q, r, s)
            #expect(segment == Self.refSegments(V3(p), V3(q), V3(r), V3(s)), "segments \(p) \(q) \(r) \(s)")
            let triangle: Bool = Geometry.segmentIntersectsTriangle(p, q, r, s, t)
            #expect(triangle == Self.refSegmentTriangle(V3(p), V3(q), V3(r), V3(s), V3(t)),
                    "segment \(p) \(q) triangle \(r) \(s) \(t)")
            if segment { segmentHits += 1 }
            if triangle { triangleHits += 1 }
        }
        #expect(segmentHits > 50 && segmentHits < 1_950)
        #expect(triangleHits > 50 && triangleHits < 1_950)
    }

    // MARK: 4. Sweep, simplicity, tension

    /// A rope whose point 1 (P = (4, 4, 0), neighbours A = (0, 0, 0) and B = (8, 0, 0)) is moved; points 4 and 5 are
    /// given. The swept triangles lie in the planes x = y (A-P-P′) and x + y = 8 (P-P′-B).
    static func sweepRope(_ x: Point, _ y: Point) -> [Point] {
        [Point(x: 0, y: 0, z: 0), Point(x: 4, y: 4, z: 0), Point(x: 8, y: 0, z: 0), Point(x: 8, y: -6, z: 0), x, y]
    }

    @Test func sweepRefusesAPiercingSegment() {
        // A unit move of P to (4, 4, 1). Segment 4–5 from (4, 2, 0) to (2, 4, 1) passes (3, 3, 1/2), inside A-P-P′
        // (s = 3/4 along A-P, height 1/2 ≤ 3/4); every other segment misses both triangles (segment 5–0 meets x = y
        // only at A).
        let pierced: [Point] = Self.sweepRope(Point(x: 4, y: 2, z: 0), Point(x: 2, y: 4, z: 1))
        let to: Point = pierced[1].moved(.plusZ)
        #expect(!Geometry.sweepIsClear(pierced, moving: 1, to: to))
        // The same strand lifted to z = 3 is above both triangles (height ≤ 1): clear. Segment 5–0 still touches
        // A-P-P′ at A alone, and segment 2–3 touches P-P′-B at B alone: both are allowed.
        let lifted: [Point] = Self.sweepRope(Point(x: 4, y: 2, z: 3), Point(x: 2, y: 4, z: 3))
        #expect(Geometry.sweepIsClear(lifted, moving: 1, to: to))
        // The reverse move from the lifted end is clear too (the same triangles).
        var after: [Point] = lifted
        after[1] = to
        #expect(Geometry.sweepIsClear(after, moving: 1, to: lifted[1]))
        // A rope that is too short or an index outside it is never clear.
        #expect(!Geometry.sweepIsClear(Array(lifted.prefix(3)), moving: 1, to: to))
        #expect(!Geometry.sweepIsClear(lifted, moving: 6, to: to))
    }

    @Test func sweepNeighbourAllowanceIsTheSharedVertexAlone() {
        // A long move of P to (4, 4, 4) (the sweep test takes any target). Segment 5–0 ends at A = (0, 0, 0).
        let to: Point = Point(x: 4, y: 4, z: 4)
        // Allowed: Y = (6, 0, 5) is off the plane x = y, so segment Y–A meets A-P-P′ at A only; with X = (6, 1, 5) no
        // other segment meets either triangle.
        let allowed: [Point] = Self.sweepRope(Point(x: 6, y: 1, z: 5), Point(x: 6, y: 0, z: 5))
        #expect(Geometry.touchesOnlyAtVertex(allowed[0], allowed[5], allowed[1], to))
        #expect(Geometry.sweepIsClear(allowed, moving: 1, to: to))
        // Refused: Y = (3, 3, 1) lies inside A-P-P′ (s = 3/4, height 1 ≤ 3), so segment Y–A lies in the swept triangle
        // beyond A. (The preceding segment from X = (6, 0, 5) necessarily touches the triangle at Y as well, so the
        // neighbour rule itself is pinned by touchesOnlyAtVertex.)
        let refused: [Point] = Self.sweepRope(Point(x: 6, y: 0, z: 5), Point(x: 3, y: 3, z: 1))
        #expect(!Geometry.touchesOnlyAtVertex(refused[0], refused[5], refused[1], to))
        #expect(!Geometry.sweepIsClear(refused, moving: 1, to: to))
        // On the B side: segment B–C with C = (8, −6, 0) touches P-P′-B at B alone; turning C into the plane x + y = 8
        // inside the triangle (C = (6, 2, 1)) is refused by the same rule.
        #expect(Geometry.touchesOnlyAtVertex(allowed[2], allowed[3], allowed[1], to))
        var bSide: [Point] = allowed
        bSide[3] = Point(x: 6, y: 2, z: 1)
        #expect(!Geometry.touchesOnlyAtVertex(bSide[2], bSide[3], bSide[1], to))
        #expect(!Geometry.sweepIsClear(bSide, moving: 1, to: to))
    }

    @Test func simplicity() {
        let hexagon: [Point] = [Point(x: 4, y: 0, z: 0), Point(x: 2, y: 4, z: 1), Point(x: -2, y: 4, z: 0),
                                Point(x: -4, y: 0, z: 1), Point(x: -2, y: -4, z: 0), Point(x: 2, y: -4, z: 1)]
        #expect(Geometry.isSimple(hexagon))
        #expect(Geometry.isSimple(Self.figureEight) && Geometry.isSimple(Self.trefoil))
        // Two non-adjacent segments crossing in space.
        var crossed: [Point] = Self.figureEight
        crossed[1] = Point(x: 2, y: 1, z: 0)
        #expect(!Geometry.isSimple(crossed))
        // A vertex lying on a non-adjacent segment.
        let touching: [Point] = [Point(x: 0, y: 0, z: 0), Point(x: 4, y: 0, z: 0), Point(x: 4, y: 4, z: 0),
                                 Point(x: 2, y: 0, z: 0), Point(x: 0, y: 4, z: 0)]
        #expect(!Geometry.isSimple(touching))
        // Adjacent segments folding back along one line; straight-through collinear points are fine.
        let folded: [Point] = [Point(x: 0, y: 0, z: 0), Point(x: 4, y: 0, z: 0), Point(x: 2, y: 0, z: 0),
                               Point(x: 2, y: 3, z: 0)]
        #expect(!Geometry.isSimple(folded))
        let straight: [Point] = [Point(x: 0, y: 0, z: 0), Point(x: 2, y: 0, z: 0), Point(x: 4, y: 0, z: 0),
                                 Point(x: 2, y: 3, z: 0)]
        #expect(Geometry.isSimple(straight))
        // Fewer than four points is never simple.
        #expect(!Geometry.isSimple(Array(hexagon.prefix(3))))
        // Simple fixture ropes are simple by construction; check a few against the summary rule too.
        var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: 2_321)
        for _ in 0..<20 {
            let rope: [Point] = WaveKnotKeeperFixtures.rope(&random, count: 8, spread: 6)
            #expect(Geometry.isSimple(rope) && !Geometry.summary(rope).degenerate)
        }
    }

    @Test func tensionIsTheSumOfSquaredLengths() {
        var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: 2_321 &+ 9_000)
        for _ in 0..<100 {
            let count: Int = random.int(4...16)
            let rope: [Point] = Self.randomRope(&random, count: count, spread: 16)
            var expected: Int = 0
            for i in 0..<count {
                let next: Point = i == count - 1 ? rope[0] : rope[i + 1]
                let d: V3 = V3(next) - V3(rope[i])
                expected += d.dot(d)
            }
            #expect(Geometry.tension(rope) == expected)
        }
        #expect(Geometry.tension(Self.figureEight) == 24 + 8 + 20 + 4)
    }
}
