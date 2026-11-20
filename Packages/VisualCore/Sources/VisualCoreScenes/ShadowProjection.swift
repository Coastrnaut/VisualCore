// ShadowProjection — feature 213 (R02-F13) T-R02F13-002 (FR-R02F13-001, FR-R02F13-002, FR-R02F13-006, FR-R02F13-008;
// clarifications Q1, Q2; research R1, R2). Planar projected shadows on the CPU: a light (point or directional), a plane
// with a deterministic right-handed 2D basis, and a projector that maps points, triangles, meshes and convex solids to
// polygons in that basis. Geometry is clipped to the slab between the ground and (for a point light) the light before
// it is projected, so no polygon is ever flipped or infinite. `matrix(light:onto:)` is the equivalent 4 × 4 planar
// projection of J. Blinn, "Me and my (fake) shadow", IEEE Computer Graphics and Applications 8(1), 1988:
// M = (P · l) I − l Pᵀ with the plane P = (n, −h) and the homogeneous light l = (L, 1) or (d, 0).
// Everything is pure Double arithmetic with no randomness, so equal inputs give equal outputs on every run.
import VisualCoreMath

/// A light that casts planar shadows (see the file header).
public enum ShadowLight: Sendable, Equatable {
    /// A point light at a world position.
    case point(Vec3)
    /// A directional light; the vector points from the light into the scene (it should have unit length — use
    /// `directional(towards:)` to build one).
    case directional(Vec3)

    /// A point light at `position`; throws `.nonFinite("position")` for a NaN or infinite component.
    public static func point(at position: Vec3) throws(ShadowError) -> ShadowLight {
        guard position.isFinite else { throw .nonFinite("position") }
        return .point(position)
    }

    /// A directional light shining along `d` (from the light into the scene), normalised. Throws
    /// `.nonFinite("direction")` for a non-finite component and `.zeroDirection` for a zero (or underflowing) vector.
    public static func directional(towards d: Vec3) throws(ShadowError) -> ShadowLight {
        guard d.isFinite else { throw .nonFinite("direction") }
        let length = d.length
        guard length > 0, length.isFinite else { throw .zeroDirection }
        let unit = d / length
        guard unit.isFinite, unit.length > 0 else { throw .zeroDirection }
        return .directional(unit)
    }
}

/// A receiving plane with a deterministic 2D basis (clarification Q1).
///
/// With unit normal n and offset h: the origin is n · h; e is the world axis least aligned with n (the smallest |nᵢ|,
/// ties to x, then y); u = normalised(n × e); v = n × u. The basis is orthonormal and right-handed (u × v = n), so a
/// polygon that is counter-clockwise seen from the side n points to is counter-clockwise in (u, v).
public struct ProjectionPlane: Sendable, Equatable {
    /// The underlying plane n · p = offset (n is the side that receives the shadow).
    public let plane: ClipPlane
    /// The basis origin, n · offset.
    public let origin: Vec3
    /// The first in-plane axis.
    public let u: Vec3
    /// The second in-plane axis (n × u).
    public let v: Vec3

    /// The basis of `plane` as described on the type.
    public init(plane: ClipPlane) {
        self.plane = plane
        let n = plane.normal
        let ax = abs(n.x), ay = abs(n.y), az = abs(n.z)
        let e: Vec3
        if ax <= ay && ax <= az {
            e = Vec3(1, 0, 0)
        } else if ay <= az {
            e = Vec3(0, 1, 0)
        } else {
            e = Vec3(0, 0, 1)
        }
        let u = n.cross(e).normalized
        self.origin = n * plane.offset
        self.u = u
        self.v = n.cross(u)
    }

    /// The plane coordinates ((p − origin) · u, (p − origin) · v) of `p` (the component along n is discarded).
    public func coordinates(of p: Vec3) -> Vec2 {
        let d = p - origin
        return Vec2(d.dot(u), d.dot(v))
    }

    /// The world point origin + q.x u + q.y v on the plane.
    public func point(of q: Vec2) -> Vec3 { origin + u * q.x + v * q.y }
}

/// Planar shadow projection on the CPU (see the file header and clarification Q2).
///
/// A directional light d maps p to p − d (n · p − h)/(n · d); a point light L maps p to
/// L + (p − L)(h − n · L)/(n · (p − L)). Geometry below the ground (n · p < h) or, for a point light, above the slab
/// n · p ≤ n · L − δ with δ = 1e-9 × max(1, |L|, |p|) casts nothing.
public enum ShadowProjector {
    /// The largest number of triangles `project(mesh:light:onto:)` accepts.
    public static let maxTriangles = 1_048_576

    // MARK: - Validation

    /// The light reduced to what the formulas need, after every refusal of clarification Q2.
    private enum Checked {
        case point(Vec3, Double)      // L and n · L
        case directional(Vec3, Double) // unit d and n · d
    }

    /// Validates `light` against `plane`: non-finite (`.nonFinite("light")`), zero direction, a directional light
    /// parallel to the plane (|n · d| < 1e-9) or pointing away from it (n · d ≥ 0), a point light on the plane
    /// (|n · L − h| ≤ 1e-9 × max(1, |L|)) or below it.
    private static func check(_ light: ShadowLight, _ plane: ProjectionPlane) throws(ShadowError) -> Checked {
        let n = plane.plane.normal, h = plane.plane.offset
        switch light {
        case .directional(let raw):
            guard raw.isFinite else { throw .nonFinite("light") }
            let length = raw.length
            guard length > 0, length.isFinite else { throw .zeroDirection }
            let d = raw / length
            let nd = n.dot(d)
            guard abs(nd) >= 1e-9 else { throw .parallelLight }
            guard nd < 0 else { throw .lightBelowPlane }
            return .directional(d, nd)
        case .point(let l):
            guard l.isFinite else { throw .nonFinite("light") }
            let nl = n.dot(l)
            let s = nl - h
            let tolerance = 1e-9 * Swift.max(1, l.length)
            guard abs(s) > tolerance else { throw .lightOnPlane }
            guard s > 0 else { throw .lightBelowPlane }
            return .point(l, nl)
        }
    }

    /// The slab tolerance δ = 1e-9 × max(1, |L|, `extent`).
    private static func slab(_ l: Vec3, _ extent: Double) -> Double { 1e-9 * Swift.max(1, l.length, extent) }

    /// The closed-form projection of a point already known to cast (no slab test).
    private static func map(_ p: Vec3, _ light: Checked, _ plane: ProjectionPlane) -> Vec2 {
        let n = plane.plane.normal, h = plane.plane.offset
        let world: Vec3
        switch light {
        case .directional(let d, let nd):
            world = p - d * ((n.dot(p) - h) / nd)
        case .point(let l, let nl):
            world = l + (p - l) * ((h - nl) / (n.dot(p) - nl))
        }
        return plane.coordinates(of: world)
    }

    // MARK: - Points and triangles

    /// The shadow of `p` in the plane basis, or nil when `p` casts none: below the plane (n · p < h − δ with
    /// δ = 1e-9 × max(1, |p|)) or, for a point light, above the light's slab (n · p > n · L − δ with
    /// δ = 1e-9 × max(1, |L|, |p|)). Throws `.nonFinite("point")` and every light refusal.
    public static func project(_ p: Vec3, light: ShadowLight, onto plane: ProjectionPlane) throws(ShadowError) -> Vec2? {
        guard p.isFinite else { throw .nonFinite("point") }
        let checked = try check(light, plane)
        let n = plane.plane.normal, h = plane.plane.offset
        let np = n.dot(p)
        guard np >= h - 1e-9 * Swift.max(1, p.length) else { return nil }
        if case .point(let l, let nl) = checked, np > nl - slab(l, p.length) { return nil }
        let q = map(p, checked, plane)
        return q.isFinite ? q : nil
    }

    /// The shadow of triangle (a, b, c): the triangle clipped (Sutherland–Hodgman) to n · p ≥ h and, for a point light,
    /// to n · p ≤ n · L − δ, then projected corner by corner. Returns 0 or 3…5 corners, wound counter-clockwise in the
    /// plane basis; empty when nothing casts, when a corner would not be finite, or when the projected area is at most
    /// 1e-12 × s² with s = max(1, the diagonal of the projected corners' bounding box) (an edge-on face).
    public static func projectTriangle(_ a: Vec3, _ b: Vec3, _ c: Vec3, light: ShadowLight,
                                       onto plane: ProjectionPlane) throws(ShadowError) -> [Vec2] {
        guard a.isFinite, b.isFinite, c.isFinite else { throw .nonFinite("point") }
        return projectChecked([a, b, c], try check(light, plane), plane)
    }

    /// Clips and projects one convex polygon with a validated light (shared by triangles, meshes and solids).
    private static func projectChecked(_ corners: [Vec3], _ light: Checked, _ plane: ProjectionPlane) -> [Vec2] {
        let n = plane.plane.normal, h = plane.plane.offset
        var polygon = clip(corners) { n.dot($0) - h }
        if case .point(let l, let nl) = light {
            var extent = 0.0
            for p in corners { extent = Swift.max(extent, p.length) }
            let top = nl - slab(l, extent)
            polygon = clip(polygon) { top - n.dot($0) }
        }
        guard polygon.count >= 3 else { return [] }
        var out: [Vec2] = []
        out.reserveCapacity(polygon.count)
        for p in polygon {
            let q = map(p, light, plane)
            guard q.isFinite else { return [] }
            if let last = out.last, last == q { continue }
            out.append(q)
        }
        if out.count >= 2, out[0] == out[out.count - 1] { out.removeLast() }
        guard out.count >= 3 else { return [] }
        var lo = out[0], hi = out[0]
        for q in out {
            lo = Vec2(Swift.min(lo.x, q.x), Swift.min(lo.y, q.y))
            hi = Vec2(Swift.max(hi.x, q.x), Swift.max(hi.y, q.y))
        }
        let s = Swift.max(1, (hi - lo).length)
        let area = ConvexHull2D.area(out)
        guard area.isFinite, abs(area) > 1e-12 * s * s else { return [] }
        return area < 0 ? out.reversed() : out
    }

    /// Sutherland–Hodgman clip of a convex polygon to the half-space `f(p) ≥ 0`.
    private static func clip(_ polygon: [Vec3], _ f: (Vec3) -> Double) -> [Vec3] {
        guard !polygon.isEmpty else { return [] }
        var out: [Vec3] = []
        out.reserveCapacity(polygon.count + 2)
        var prev = polygon[polygon.count - 1]
        var fPrev = f(prev)
        for cur in polygon {
            let fCur = f(cur)
            if fCur >= 0 {
                if fPrev < 0 { out.append(prev + (cur - prev) * (fPrev / (fPrev - fCur))) }
                out.append(cur)
            } else if fPrev >= 0 {
                out.append(prev + (cur - prev) * (fPrev / (fPrev - fCur)))
            }
            prev = cur
            fPrev = fCur
        }
        return out
    }

    // MARK: - Meshes and solids

    /// One shadow polygon per triangle of `mesh` that casts one (triangles that cast nothing are skipped), in triangle
    /// order. Throws `.tooManyTriangles` above `maxTriangles`, `.malformed("index")` for an index outside the
    /// positions, `.nonFinite("point")` and every light refusal.
    public static func project(mesh: Mesh, light: ShadowLight, onto plane: ProjectionPlane) throws(ShadowError) -> [[Vec2]] {
        let count = mesh.indices.count / 3
        guard count <= maxTriangles else { throw .tooManyTriangles(count) }
        let checked = try check(light, plane)
        var result: [[Vec2]] = []
        for t in 0..<count {
            var corners: [Vec3] = []
            corners.reserveCapacity(3)
            for k in 0..<3 {
                let i = Int(mesh.indices[3 * t + k])
                guard i < mesh.positions.count else { throw .malformed("index") }
                let p = mesh.positions[i]
                guard p.isFinite else { throw .nonFinite("point") }
                corners.append(p)
            }
            let polygon = projectChecked(corners, checked, plane)
            if !polygon.isEmpty { result.append(polygon) }
        }
        return result
    }

    /// The shadow outline of a convex solid: the convex hull (`ConvexHull2D.hull`) of the slab-clipped projections of
    /// all its faces, counter-clockwise in the plane basis; empty when the solid casts nothing. Throws every light
    /// refusal.
    public static func outline(of solid: ConvexSolid, light: ShadowLight, onto plane: ProjectionPlane) throws(ShadowError) -> [Vec2] {
        let checked = try check(light, plane)
        var points: [Vec2] = []
        for face in solid.faces where face.count >= 3 {
            let p0 = solid.vertices[face[0]]
            for k in 1..<(face.count - 1) {
                points += projectChecked([p0, solid.vertices[face[k]], solid.vertices[face[k + 1]]], checked, plane)
            }
        }
        return ConvexHull2D.hull(points)
    }

    // MARK: - Matrix

    /// The 4 × 4 planar projection (Blinn 1988) M = (P · l) I − l Pᵀ with P = (n, −h) and l = (L, 1) for a point light
    /// or (d, 0) for a directional one. For every point p that casts, `matrix.applyPoint(p)` equals
    /// `plane.point(of: project(p)!)` up to rounding. Throws every light refusal.
    public static func matrix(light: ShadowLight, onto plane: ProjectionPlane) throws(ShadowError) -> Mat4 {
        let checked = try check(light, plane)
        let n = plane.plane.normal, h = plane.plane.offset
        let l: Vec4
        switch checked {
        case .point(let p, _): l = Vec4(p, 1)
        case .directional(let d, _): l = Vec4(d, 0)
        }
        let pl = Vec4(n, -h)
        let dot = pl.dot(l)
        // Column j of M is dot · e_j − l · P_j.
        func column(_ j: Int, _ pj: Double) -> Vec4 {
            var c = Vec4(-l.x * pj, -l.y * pj, -l.z * pj, -l.w * pj)
            switch j {
            case 0: c.x += dot
            case 1: c.y += dot
            case 2: c.z += dot
            default: c.w += dot
            }
            return c
        }
        return Mat4(column(0, pl.x), column(1, pl.y), column(2, pl.z), column(3, pl.w))
    }
}
