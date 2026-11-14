// MeshShapes.swift — feature 205 (R02-F05) T-R02F05-009 (FR-R02F05-010 to 015, 050).
// Parametric surface, solid of revolution, extrusion, tube (research D3) and bevelled box (research D6), all built
// through `MeshBuilder`. Every shape winds its triangles counter-clockwise seen from outside, gives unit normals and
// texture coordinates in 0…1, checks its exact vertex and index counts against the budget before building anything
// (research D9: no partial mesh) and is a pure, deterministic function of its description (FR-R02F05-051).
import Foundation
import VisualCoreMath

extension Mesh {
    /// Allowed sides for `tube`; values outside are clamped.
    static let tubeSideRange = 3...256
    /// Allowed bevel segments for `bevelledBox`; values outside are clamped.
    static let bevelSegmentRange = 1...16

    // MARK: - Parametric surface (FR-R02F05-010)

    /// A parametric surface sampled on a grid of `columns` × `rows` quads over u, v in 0…1.
    ///
    /// `point(u, v)` gives the position of each sample. Vertex (i, j) is `point(i / columns, j / rows)` with texture
    /// coordinate (u, v). A closed direction shares its seam: the last column (row) of quads joins back to the first, no
    /// duplicate samples are made and `point` is never called at u = 1 (v = 1), so the mesh is topologically closed in
    /// that direction. The outside is the side `∂point/∂u × ∂point/∂v` points to (a plane `(u, v, 0)` faces +z).
    /// `columns` and `rows` are clamped to `subdivisionRange`, and to at least 3 in a closed direction. Normals are the
    /// area-weighted average of the adjacent triangles. Triangles of (near) zero area, such as those at a pole where
    /// `point` collapses a row to one position, are left out.
    ///
    /// - Throws: `.budget` when `(columns or columns + 1) × (rows or rows + 1)` vertices or `6 · columns · rows`
    ///   indices exceed `budget`; `.invalidInput` when `point` returns a non-finite position.
    public static func surface(columns: Int, rows: Int, closedU: Bool, closedV: Bool, budget: MeshBudget = .default,
                               _ point: (Double, Double) -> Vec3) throws(MeshError) -> Mesh {
        let cols = clampResolution(columns, closed: closedU), rws = clampResolution(rows, closed: closedV)
        let nu = closedU ? cols : cols + 1, nv = closedV ? rws : rws + 1
        try checkBudget(vertices: nu * nv, indices: 6 * cols * rws, budget: budget)

        var draft = ShapeDraft()
        for j in 0..<nv {
            for i in 0..<nu {
                let u = Double(i) / Double(cols), v = Double(j) / Double(rws)
                let p = point(u, v)
                guard p.isFinite else { throw .invalidInput("surface point at u \(u), v \(v) is not finite") }
                draft.positions.append(p); draft.uvs.append(Vec2(u, v))
            }
        }
        func index(_ i: Int, _ j: Int) -> Int { (j % nv) * nu + (i % nu) }
        let degenerate = 1e-12 * squaredDiagonal(draft.positions)
        var accumulated = [Vec3](repeating: .zero, count: draft.positions.count)
        for j in 0..<rws {
            for i in 0..<cols {
                let a = index(i, j), b = index(i + 1, j), c = index(i, j + 1), d = index(i + 1, j + 1)
                for (x, y, z) in [(a, b, d), (a, d, c)] {
                    let face = (draft.positions[y] - draft.positions[x]).cross(draft.positions[z] - draft.positions[x])
                    guard 0.5 * face.length > degenerate else { continue }
                    draft.triangles += [x, y, z]
                    accumulated[x] += face; accumulated[y] += face; accumulated[z] += face
                }
            }
        }
        draft.normals = accumulated.map { $0.length > 0 ? $0.normalized : Vec3(0, 0, 1) }
        return try draft.build(budget: budget)
    }

    // MARK: - Solid of revolution (FR-R02F05-011; research D4)

    /// A solid of revolution: `profile` points (x = radius ≥ 0, y = height) revolved around the y axis in `segments`
    /// steps (clamped to `segmentRange`).
    ///
    /// The profile is used in the order that runs counter-clockwise around the region between it and the axis in the
    /// (radius, height) plane (for example from the bottom up along the outside); a profile in the other order is
    /// reversed. Repeated consecutive points are dropped. A point with radius ≤ 1e-9 becomes one pole vertex on the
    /// axis, so no degenerate triangles are made. Rings duplicate their seam vertex (texture u = 0 and u = 1 at the
    /// same position); texture v is the arc-length fraction along the profile. Normals come from the profile tangent.
    ///
    /// - Throws: `.invalidInput` for fewer than 2 distinct points, a non-finite or negative radius, or a profile that
    ///   lies entirely on the axis; `.budget` when the exact counts exceed `budget`.
    public static func revolution(profile: [Vec2], segments: Int,
                                  budget: MeshBudget = .default) throws(MeshError) -> Mesh {
        guard profile.allSatisfy(\.isFinite) else { throw .invalidInput("profile has a non-finite point") }
        guard profile.allSatisfy({ $0.x >= -poleRadius }) else { throw .invalidInput("profile has a negative radius") }
        var points = distinct(profile.map { Vec2($0.x <= poleRadius ? 0 : $0.x, $0.y) })
        guard points.count >= 2 else { throw .invalidInput("profile needs at least 2 distinct points") }
        guard points.contains(where: { $0.x > 0 }) else { throw .invalidInput("profile lies on the axis") }
        // Shoelace area of the profile closed along the axis; negative means clockwise.
        var area = 0.0
        let closedLoop = [Vec2(0, points[0].y)] + points + [Vec2(0, points[points.count - 1].y)]
        for k in closedLoop.indices { area += closedLoop[k].cross(closedLoop[(k + 1) % closedLoop.count]) }
        if area < 0 { points.reverse() }

        let s = min(max(segments, segmentRange.lowerBound), segmentRange.upperBound)
        let isPole = points.map { $0.x == 0 }
        var vertexCount = 0, indexCount = 0
        for j in points.indices {
            vertexCount += isPole[j] ? 1 : s + 1
            if j + 1 < points.count {
                switch (isPole[j], isPole[j + 1]) {
                case (false, false): indexCount += 6 * s
                case (true, true): break
                default: indexCount += 3 * s
                }
            }
        }
        try checkBudget(vertices: vertexCount, indices: indexCount, budget: budget)

        let ring = angleTable(s)
        var lengths = [0.0]
        for j in 1..<points.count { lengths.append(lengths[j - 1] + points[j].distance(to: points[j - 1])) }
        let total = lengths[lengths.count - 1]
        var draft = ShapeDraft()
        var first: [Int] = []
        for j in points.indices {
            let p = points[j]
            let back = j > 0 ? (p - points[j - 1]).normalized : Vec2.zero
            let ahead = j + 1 < points.count ? (points[j + 1] - p).normalized : Vec2.zero
            var tangent = back + ahead
            tangent = tangent.length > 1e-9 ? tangent.normalized : (ahead.length > 0 ? ahead : back)
            let outward = Vec2(tangent.y, -tangent.x)
            let v = total > 0 ? lengths[j] / total : 0
            first.append(draft.positions.count)
            if isPole[j] {
                draft.add(Vec3(0, p.y, 0), Vec3(0, outward.y >= 0 ? 1 : -1, 0), Vec2(0.5, v))
            } else {
                for k in 0...s {
                    let (sine, cosine) = ring[k]
                    draft.add(Vec3(p.x * sine, p.y, p.x * cosine),
                              Vec3(outward.x * sine, outward.y, outward.x * cosine).normalized,
                              Vec2(Double(k) / Double(s), v))
                }
            }
        }
        for j in 0..<(points.count - 1) {
            let lower = first[j], upper = first[j + 1]
            switch (isPole[j], isPole[j + 1]) {
            case (false, false):
                for k in 0..<s {
                    let a = lower + k, b = a + 1, c = upper + k, d = c + 1
                    draft.triangles += [a, b, d, a, d, c]
                }
            case (false, true):
                for k in 0..<s { draft.triangles += [lower + k, lower + k + 1, upper] }
            case (true, false):
                for k in 0..<s { draft.triangles += [lower, upper + k + 1, upper + k] }
            case (true, true):
                break
            }
        }
        return try draft.build(budget: budget)
    }

    // MARK: - Extrusion (FR-R02F05-012; research D5)

    /// A closed `outline` in the XY plane extruded along z from −depth/2 to +depth/2, optionally capped.
    ///
    /// Repeated consecutive points and a closing point equal to the first are dropped; a clockwise outline is
    /// reversed. Each side wall is its own quad with a flat outward normal (vertices split per edge), texture u the
    /// perimeter fraction and v = 0 at the bottom, 1 at the top. Caps are triangulated by ear clipping with normals
    /// ±z and texture coordinates mapped from the outline's bounding box.
    ///
    /// - Throws: `.invalidInput` for fewer than 3 distinct points, a self-intersecting or zero-area outline, a
    ///   non-finite point, or a depth that is not finite and positive; `.budget` when `4n (+ 2n)` vertices or
    ///   `6n (+ 6(n − 2))` indices exceed `budget`.
    public static func extrusion(outline: [Vec2], depth: Double, caps: Bool,
                                 budget: MeshBudget = .default) throws(MeshError) -> Mesh {
        guard outline.allSatisfy(\.isFinite) else { throw .invalidInput("outline has a non-finite point") }
        guard depth.isFinite, depth > 0 else { throw .invalidInput("extrusion depth must be finite and positive") }
        var points = distinct(outline)
        if points.count > 1, nearlyEqual(points[0], points[points.count - 1], scale: scale(points)) {
            points.removeLast()
        }
        guard points.count >= 3 else { throw .invalidInput("outline needs at least 3 distinct points") }
        let n = points.count
        let size = scale(points)
        var area = 0.0
        for k in 0..<n { area += points[k].cross(points[(k + 1) % n]) }
        guard abs(area) > 1e-12 * size * size else { throw .invalidInput("outline has no area") }
        if area < 0 { points.reverse() }
        guard isSimple(points) else { throw .invalidInput("outline intersects itself") }
        try checkBudget(vertices: 4 * n + (caps ? 2 * n : 0), indices: 6 * n + (caps ? 6 * (n - 2) : 0),
                        budget: budget)
        var capTriangles: [(Int, Int, Int)] = []
        if caps {
            guard let triangles = earClip(points) else { throw .invalidInput("outline cannot be triangulated") }
            capTriangles = triangles
        }

        let h = depth / 2
        var perimeter = [0.0]
        for k in 0..<n { perimeter.append(perimeter[k] + points[(k + 1) % n].distance(to: points[k])) }
        var draft = ShapeDraft()
        for k in 0..<n {
            let p = points[k], q = points[(k + 1) % n]
            let e = (q - p).normalized
            let normal = Vec3(e.y, -e.x, 0)
            let u0 = perimeter[k] / perimeter[n], u1 = k + 1 == n ? 1 : perimeter[k + 1] / perimeter[n]
            let base = draft.positions.count
            draft.add(Vec3(p.x, p.y, -h), normal, Vec2(u0, 0))
            draft.add(Vec3(q.x, q.y, -h), normal, Vec2(u1, 0))
            draft.add(Vec3(q.x, q.y, h), normal, Vec2(u1, 1))
            draft.add(Vec3(p.x, p.y, h), normal, Vec2(u0, 1))
            draft.triangles += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
        if caps {
            let lo = Vec2(points.map(\.x).min() ?? 0, points.map(\.y).min() ?? 0)
            let hi = Vec2(points.map(\.x).max() ?? 0, points.map(\.y).max() ?? 0)
            func uv(_ p: Vec2) -> Vec2 { Vec2((p.x - lo.x) / (hi.x - lo.x), (p.y - lo.y) / (hi.y - lo.y)) }
            let top = draft.positions.count
            for p in points { draft.add(Vec3(p.x, p.y, h), Vec3(0, 0, 1), uv(p)) }
            let bottom = draft.positions.count
            for p in points { draft.add(Vec3(p.x, p.y, -h), Vec3(0, 0, -1), uv(p)) }
            for (a, b, c) in capTriangles {
                draft.triangles += [top + a, top + b, top + c]
                draft.triangles += [bottom + a, bottom + c, bottom + b]
            }
        }
        return try draft.build(budget: budget)
    }

    // MARK: - Tube (FR-R02F05-013; research D3)

    /// A tube of `radius` with `sides` sides (clamped 3…256) along `path`.
    ///
    /// Repeated consecutive points are dropped (and, for a closed loop, a last point equal to the first). Cross
    /// sections follow rotation-minimizing frames (`pathFrames`). A closed tube joins its last ring to its first,
    /// with the residual twist spread by arc length so the seam meets; `caps` then has no effect. An open tube with
    /// `caps` gets a fan at each end with normals ∓ the end tangent. Rings duplicate their seam vertex; texture u
    /// is the fraction around, v the arc-length fraction along the path.
    ///
    /// - Throws: `.invalidInput` for fewer than 2 distinct points (3 for a closed loop), a non-finite point or a
    ///   radius that is not finite and positive; `.budget` when the exact counts exceed `budget`.
    public static func tube(path: [Vec3], radius: Double, sides: Int, caps: Bool, closed: Bool,
                            budget: MeshBudget = .default) throws(MeshError) -> Mesh {
        guard path.allSatisfy(\.isFinite) else { throw .invalidInput("tube path has a non-finite point") }
        guard radius.isFinite, radius > 0 else { throw .invalidInput("tube radius must be finite and positive") }
        var points = distinct(path)
        if closed, points.count > 1, nearlyEqual(points[0], points[points.count - 1], scale: scale(points)) {
            points.removeLast()
        }
        guard points.count >= 2 else { throw .invalidInput("tube path needs at least 2 distinct points") }
        guard !closed || points.count >= 3 else { throw .invalidInput("a closed tube needs at least 3 distinct points") }
        let n = min(max(sides, tubeSideRange.lowerBound), tubeSideRange.upperBound)
        let rings = points.count + (closed ? 1 : 0)
        let capped = caps && !closed
        try checkBudget(vertices: rings * (n + 1) + (capped ? 2 * (n + 1) : 0),
                        indices: 6 * n * (rings - 1) + (capped ? 6 * n : 0), budget: budget)

        let frames = pathFrames(points, closed: closed)
        let around = angleTable(n)
        var lengths = [0.0]
        for i in 1..<rings {
            let step: Double = (points[i % points.count] - points[i - 1]).length
            lengths.append(lengths[i - 1] + step)
        }
        let total = lengths[rings - 1]
        var draft = ShapeDraft()
        for i in 0..<rings {
            let seam = closed && i == points.count
            let (_, normal, binormal) = frames[seam ? 0 : i]
            let center = points[i % points.count]
            for k in 0...n {
                let (sine, cosine) = around[k]
                let direction = (normal * cosine + binormal * sine).normalized
                draft.add(center + direction * radius, direction, Vec2(Double(k) / Double(n), lengths[i] / total))
            }
        }
        for i in 0..<(rings - 1) {
            for k in 0..<n {
                let a = i * (n + 1) + k, b = a + 1, c = a + n + 1, d = c + 1
                draft.triangles += [a, b, d, a, d, c]
            }
        }
        if capped {
            for end in [0, points.count - 1] {
                let (tangent, normal, binormal) = frames[end]
                let outward = end == 0 ? -tangent : tangent
                let center = draft.positions.count
                draft.add(points[end], outward, Vec2(0.5, 0.5))
                for k in 0..<n {
                    let (sine, cosine) = around[k]
                    draft.add(points[end] + (normal * cosine + binormal * sine).normalized * radius, outward,
                              Vec2(0.5 + 0.5 * cosine, 0.5 + 0.5 * sine))
                }
                for k in 0..<n {
                    let p = center + 1 + k, q = center + 1 + (k + 1) % n
                    draft.triangles += end == 0 ? [center, q, p] : [center, p, q]
                }
            }
        }
        return try draft.build(budget: budget)
    }

    /// Rotation-minimizing frames (tangent, normal, binormal) along distinct consecutive `points` by double reflection
    /// (Wang, Jüttler, Zheng and Liu 2008).
    ///
    /// Tangents are the normalized sum of the adjacent unit chords (one-sided at open ends). The first normal is the
    /// world axis least parallel to the first tangent, orthogonalized. For `closed`, the frame is carried once more to
    /// the first point, the residual angle between that frame and the first is spread linearly by arc length over the
    /// loop, and one extra seam frame (the first point's, reached around the loop) is appended: `points.count + 1`
    /// frames. Otherwise one frame per point.
    static func pathFrames(_ points: [Vec3], closed: Bool) -> [(Vec3, Vec3, Vec3)] {
        let m = points.count
        guard m >= 2 else { return [] }
        var tangents: [Vec3] = []
        for i in 0..<m {
            let back: Vec3 = i > 0 ? points[i] - points[i - 1] : (closed ? points[0] - points[m - 1] : .zero)
            let ahead: Vec3 = i + 1 < m ? points[i + 1] - points[i] : (closed ? points[0] - points[m - 1] : .zero)
            let sum = back.normalized + ahead.normalized
            tangents.append(sum.length > 1e-9 ? sum.normalized : (ahead.length > 0 ? ahead : back).normalized)
        }
        func leastParallelNormal(_ t: Vec3) -> Vec3 {
            let axes = [Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0, 0, 1)]
            var best = axes[0]
            for axis in axes.dropFirst() where abs(axis.dot(t)) < abs(best.dot(t)) { best = axis }
            return (best - t * best.dot(t)).normalized
        }
        func carry(_ r: Vec3, _ t: Vec3, from x0: Vec3, to x1: Vec3, tangent t1: Vec3) -> Vec3 {
            let v1 = x1 - x0, c1 = v1.dot(v1)
            guard c1 > 0 else { return r }
            let rL = r - v1 * (2 / c1 * v1.dot(r)), tL = t - v1 * (2 / c1 * v1.dot(t))
            let v2 = t1 - tL, c2 = v2.dot(v2)
            let r1 = c2 > 1e-30 ? rL - v2 * (2 / c2 * v2.dot(rL)) : rL
            let o = r1 - t1 * t1.dot(r1)
            return o.length > 1e-12 ? o.normalized : leastParallelNormal(t1)
        }
        var normals = [leastParallelNormal(tangents[0])]
        for i in 1..<m {
            normals.append(carry(normals[i - 1], tangents[i - 1], from: points[i - 1], to: points[i],
                                 tangent: tangents[i]))
        }
        var frames: [(Vec3, Vec3, Vec3)] = []
        if closed {
            let seam = carry(normals[m - 1], tangents[m - 1], from: points[m - 1], to: points[0], tangent: tangents[0])
            let t0 = tangents[0]
            let angle = atan2(seam.cross(normals[0]).dot(t0), seam.dot(normals[0]))
            var lengths = [0.0]
            for i in 1...m {
                let step: Double = (points[i % m] - points[i - 1]).length
                lengths.append(lengths[i - 1] + step)
            }
            let total = lengths[m]
            func rotate(_ r: Vec3, about t: Vec3, by theta: Double) -> Vec3 {
                (r * cos(theta) + t.cross(r) * sin(theta)).normalized
            }
            for i in 0..<m {
                let r = rotate(normals[i], about: tangents[i], by: angle * lengths[i] / total)
                frames.append((tangents[i], r, tangents[i].cross(r)))
            }
            let r = rotate(seam, about: t0, by: angle)
            frames.append((t0, r, t0.cross(r)))
        } else {
            for i in 0..<m { frames.append((tangents[i], normals[i], tangents[i].cross(normals[i]))) }
        }
        return frames
    }

    // MARK: - Bevelled box (FR-R02F05-014; research D6)

    /// A box of `size` centred on the origin whose edges and corners are rounded with `radius`.
    ///
    /// `radius` is clamped to 0…min(size)/2 (non-finite → 0) and `segments` to 1…16. Radius 0 gives a plain box like
    /// `cube()` scaled: 24 vertices with flat normals, 36 indices. Otherwise each face is a grid whose lines include the
    /// inner box (half-extents size/2 − radius) and `segments` steps across each bevel, spaced so the bevel angle
    /// advances evenly; every grid point p moves to `inner + radius · normalize(p − inner)`, where inner is p clamped
    /// to the inner box, and its normal is that direction. Faces share their edge positions exactly, so the mesh is
    /// closed after welding by position. Texture coordinates run 0…1 across each face.
    ///
    /// - Throws: `.invalidInput` when a size component is not finite and positive; `.budget` when the exact counts
    ///   exceed `budget`.
    public static func bevelledBox(size: Vec3, radius: Double, segments: Int,
                                   budget: MeshBudget = .default) throws(MeshError) -> Mesh {
        guard size.isFinite, size.x > 0, size.y > 0, size.z > 0 else {
            throw .invalidInput("box size must be finite and positive")
        }
        let half = size * 0.5
        let smallest = min(size.x, size.y, size.z)
        let r = radius.isFinite ? min(max(radius, 0), smallest / 2) : 0
        let s = min(max(segments, bevelSegmentRange.lowerBound), bevelSegmentRange.upperBound)
        func innerExtent(_ h: Double) -> Double { let i = h - r; return i > 1e-12 * smallest ? i : 0 }
        let inner = Vec3(innerExtent(half.x), innerExtent(half.y), innerExtent(half.z))
        func coordinates(_ h: Double, _ i: Double) -> [Double] {
            guard r > 0 else { return [-h, h] }
            func step(_ j: Int) -> Double { j == s ? h : i + r * tan(.pi / 4 * Double(j) / Double(s)) }
            var c = stride(from: s, through: 1, by: -1).map { -step($0) }
            c.append(-i)
            if i > 0 { c.append(i) }
            c += (1...s).map(step)
            return c
        }
        func along(_ axis: Vec3, _ v: Vec3) -> Double { abs(axis.x) * v.x + abs(axis.y) * v.y + abs(axis.z) * v.z }
        let faces: [(n: Vec3, u: Vec3, v: Vec3)] = [
            (Vec3(1, 0, 0), Vec3(0, 0, -1), Vec3(0, 1, 0)), (Vec3(-1, 0, 0), Vec3(0, 0, 1), Vec3(0, 1, 0)),
            (Vec3(0, 1, 0), Vec3(1, 0, 0), Vec3(0, 0, -1)), (Vec3(0, -1, 0), Vec3(1, 0, 0), Vec3(0, 0, 1)),
            (Vec3(0, 0, 1), Vec3(1, 0, 0), Vec3(0, 1, 0)), (Vec3(0, 0, -1), Vec3(-1, 0, 0), Vec3(0, 1, 0)),
        ]
        let grids = faces.map { face in
            (coordinates(along(face.u, half), along(face.u, inner)),
             coordinates(along(face.v, half), along(face.v, inner)))
        }
        var vertexCount = 0, indexCount = 0
        for (us, vs) in grids {
            vertexCount += us.count * vs.count
            indexCount += 6 * (us.count - 1) * (vs.count - 1)
        }
        try checkBudget(vertices: vertexCount, indices: indexCount, budget: budget)

        var draft = ShapeDraft()
        for (face, (us, vs)) in zip(faces, grids) {
            let hn = along(face.n, half), hu = along(face.u, half), hv = along(face.v, half)
            let base = draft.positions.count
            for b in vs {
                for a in us {
                    let p = face.n * hn + face.u * a + face.v * b
                    let uv = Vec2((a + hu) / (2 * hu), (b + hv) / (2 * hv))
                    if r > 0 {
                        let q = Vec3(min(max(p.x, -inner.x), inner.x), min(max(p.y, -inner.y), inner.y),
                                     min(max(p.z, -inner.z), inner.z))
                        let direction = (p - q).normalized
                        draft.add(q + direction * r, direction, uv)
                    } else {
                        draft.add(p, face.n, uv)
                    }
                }
            }
            let row = us.count
            for j in 0..<(vs.count - 1) {
                for i in 0..<(us.count - 1) {
                    let a = base + j * row + i, b = a + 1, c = a + row, d = c + 1
                    draft.triangles += [a, b, d, a, d, c]
                }
            }
        }
        return try draft.build(budget: budget)
    }
}

// MARK: - Shared helpers

/// Radius at or below which a revolution profile point lies on the axis.
private let poleRadius = 1e-9

/// Vertices and triangles collected before they go through `MeshBuilder`.
private struct ShapeDraft {
    var positions: [Vec3] = []
    var normals: [Vec3] = []
    var uvs: [Vec2] = []
    var triangles: [Int] = []

    mutating func add(_ position: Vec3, _ normal: Vec3, _ uv: Vec2) {
        positions.append(position); normals.append(normal); uvs.append(uv)
    }

    /// Feeds the draft through a builder with `budget` (equal vertices weld, indices follow insertion order).
    func build(budget: MeshBudget) throws(MeshError) -> Mesh {
        var builder = MeshBuilder(budget: budget)
        var map: [UInt32] = []
        map.reserveCapacity(positions.count)
        for i in positions.indices {
            let index = try builder.vertex(positions[i], normal: normals[i], uv: uvs[i])
            map.append(index)
        }
        var k = 0
        while k + 2 < triangles.count {
            try builder.triangle(map[triangles[k]], map[triangles[k + 1]], map[triangles[k + 2]])
            k += 3
        }
        return builder.build()
    }
}

extension Mesh {
    /// Throws `.budget` when `vertices` or `indices` exceed `budget`.
    fileprivate static func checkBudget(vertices: Int, indices: Int, budget: MeshBudget) throws(MeshError) {
        if vertices > budget.maxVertices || indices > budget.maxIndices {
            throw .budget(vertices: vertices, indices: indices, budget: budget)
        }
    }

    /// `value` clamped to `subdivisionRange`, and to at least 3 for a closed direction.
    fileprivate static func clampResolution(_ value: Int, closed: Bool) -> Int {
        min(max(value, closed ? max(3, subdivisionRange.lowerBound) : subdivisionRange.lowerBound),
            subdivisionRange.upperBound)
    }

    /// (sin, cos) of 2πk/n for k in 0…n, with entry n equal to entry 0 so seams match exactly.
    fileprivate static func angleTable(_ n: Int) -> [(Double, Double)] {
        var table = (0..<n).map { k -> (Double, Double) in
            let angle = 2 * Double.pi * Double(k) / Double(n)
            return (sin(angle), cos(angle))
        }
        table.append(table[0])
        return table
    }

    fileprivate static func squaredDiagonal(_ points: [Vec3]) -> Double {
        guard let first = points.first else { return 0 }
        var lo = first, hi = first
        for p in points {
            lo = Vec3(min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z))
            hi = Vec3(max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z))
        }
        let d = hi - lo
        return d.dot(d)
    }

    fileprivate static func scale(_ points: [Vec2]) -> Double {
        points.reduce(0) { max($0, abs($1.x), abs($1.y)) }
    }

    fileprivate static func scale(_ points: [Vec3]) -> Double {
        points.reduce(0) { max($0, abs($1.x), abs($1.y), abs($1.z)) }
    }

    /// Equal within the weld tolerance 1e-9 × (1 + scale) per component.
    fileprivate static func nearlyEqual(_ a: Vec2, _ b: Vec2, scale: Double) -> Bool {
        let t = 1e-9 * (1 + scale)
        return abs(a.x - b.x) <= t && abs(a.y - b.y) <= t
    }

    fileprivate static func nearlyEqual(_ a: Vec3, _ b: Vec3, scale: Double) -> Bool {
        let t = 1e-9 * (1 + scale)
        return abs(a.x - b.x) <= t && abs(a.y - b.y) <= t && abs(a.z - b.z) <= t
    }

    /// `points` without consecutive repeats (within the weld tolerance).
    fileprivate static func distinct(_ points: [Vec2]) -> [Vec2] {
        let s = scale(points)
        var result: [Vec2] = []
        for p in points {
            if let last = result.last, nearlyEqual(last, p, scale: s) { continue }
            result.append(p)
        }
        return result
    }

    fileprivate static func distinct(_ points: [Vec3]) -> [Vec3] {
        let s = scale(points)
        var result: [Vec3] = []
        for p in points {
            if let last = result.last, nearlyEqual(last, p, scale: s) { continue }
            result.append(p)
        }
        return result
    }

    /// True when no two edges of the closed polygon touch, apart from neighbours sharing their common corner (and
    /// neighbours folding back onto each other count as touching).
    fileprivate static func isSimple(_ p: [Vec2]) -> Bool {
        let n = p.count
        func orient(_ a: Vec2, _ b: Vec2, _ c: Vec2) -> Double { (b - a).cross(c - a) }
        func onSegment(_ a: Vec2, _ b: Vec2, _ c: Vec2) -> Bool {
            min(a.x, b.x) <= c.x && c.x <= max(a.x, b.x) && min(a.y, b.y) <= c.y && c.y <= max(a.y, b.y)
        }
        func touch(_ a: Vec2, _ b: Vec2, _ c: Vec2, _ d: Vec2) -> Bool {
            let o1 = orient(a, b, c), o2 = orient(a, b, d), o3 = orient(c, d, a), o4 = orient(c, d, b)
            if ((o1 > 0 && o2 < 0) || (o1 < 0 && o2 > 0)) && ((o3 > 0 && o4 < 0) || (o3 < 0 && o4 > 0)) { return true }
            return (o1 == 0 && onSegment(a, b, c)) || (o2 == 0 && onSegment(a, b, d))
                || (o3 == 0 && onSegment(c, d, a)) || (o4 == 0 && onSegment(c, d, b))
        }
        for i in 0..<n {
            let a = p[i], b = p[(i + 1) % n], c = p[(i + 2) % n]
            if orient(a, b, c) == 0 && (b - a).dot(c - b) < 0 { return false }   // folds back on itself
            for j in stride(from: i + 2, to: n, by: 1) where !(i == 0 && j == n - 1) {
                if touch(a, b, p[j], p[(j + 1) % n]) { return false }
            }
        }
        return true
    }

    /// Ear clipping of a simple counter-clockwise polygon into `n − 2` counter-clockwise triangles of corner indices;
    /// nil when no ear is found (numerically unusable outline).
    fileprivate static func earClip(_ p: [Vec2]) -> [(Int, Int, Int)]? {
        let size = scale(p)
        let convex = 1e-12 * size * size
        func orient(_ a: Vec2, _ b: Vec2, _ c: Vec2) -> Double { (b - a).cross(c - a) }
        var remaining = Array(p.indices)
        var triangles: [(Int, Int, Int)] = []
        var start = 0
        while remaining.count > 3 {
            let count = remaining.count
            var clipped = false
            for step in 0..<count {
                let s = (start + step) % count
                let i0 = remaining[(s + count - 1) % count], i1 = remaining[s], i2 = remaining[(s + 1) % count]
                let a = p[i0], b = p[i1], c = p[i2]
                guard orient(a, b, c) > convex else { continue }
                let blocked = remaining.contains { k in
                    k != i0 && k != i1 && k != i2
                        && orient(a, b, p[k]) >= 0 && orient(b, c, p[k]) >= 0 && orient(c, a, p[k]) >= 0
                }
                guard !blocked else { continue }
                triangles.append((i0, i1, i2))
                remaining.remove(at: s)
                start = s % remaining.count
                clipped = true
                break
            }
            if !clipped { return nil }
        }
        triangles.append((remaining[0], remaining[1], remaining[2]))
        return triangles
    }
}
