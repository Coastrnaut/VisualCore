// MeshShapeTests — feature 205 (R02-F05) T-R02F05-008 (FR-R02F05-010 to 015; SC-R02F05-001).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

// MARK: - Helpers

/// Signed volume by the divergence theorem, computed here independently of the validator.
private func signedVolume(_ m: Mesh) -> Double {
    stride(from: 0, to: m.indices.count, by: 3).reduce(0.0) { sum, k in
        let a = m.positions[Int(m.indices[k])], b = m.positions[Int(m.indices[k + 1])]
        let c = m.positions[Int(m.indices[k + 2])]
        return sum + a.dot(b.cross(c)) / 6
    }
}

/// `value` is within `tolerance` relative of `expected`.
private func near(_ value: Double?, _ expected: Double, _ tolerance: Double) -> Bool {
    guard let value else { return false }
    return abs(value - expected) <= tolerance * abs(expected)
}

/// Every triangle has area and its geometric normal agrees with the mean of its vertex normals (outward, CCW).
private func facesAgree(_ m: Mesh) -> Bool {
    stride(from: 0, to: m.indices.count, by: 3).allSatisfy { k in
        let (i, j, l) = (Int(m.indices[k]), Int(m.indices[k + 1]), Int(m.indices[k + 2]))
        let face = (m.positions[j] - m.positions[i]).cross(m.positions[l] - m.positions[i])
        return face.length > 1e-14 && face.dot(m.normals[i] + m.normals[j] + m.normals[l]) > 0
    }
}

/// Unit normals and texture coordinates in 0…1.
private func attributesInRange(_ m: Mesh) -> Bool {
    m.normals.allSatisfy { abs($0.length - 1) <= 1e-9 }
        && m.uvs.allSatisfy { $0.x >= 0 && $0.x <= 1 && $0.y >= 0 && $0.y <= 1 }
}

/// A closed shape: valid with `requireClosed`, no boundary edges, positive volume equal to `exact` within 1e-6
/// relative (and to the independently summed volume within 1e-9).
private func expectClosed(_ m: Mesh, exact: Double?, sourceLocation: SourceLocation = #_sourceLocation) {
    let report = m.validate(requireClosed: true)
    #expect(report.isValid, "\(report)", sourceLocation: sourceLocation)
    #expect(report.summary.boundaryEdges == 0, sourceLocation: sourceLocation)
    #expect(report.summary.isClosed, sourceLocation: sourceLocation)
    #expect((report.summary.volume ?? 0) > 0, sourceLocation: sourceLocation)
    #expect(near(report.summary.volume, signedVolume(m), 1e-9), sourceLocation: sourceLocation)
    if let exact { #expect(near(report.summary.volume, exact, 1e-6), sourceLocation: sourceLocation) }
    #expect(facesAgree(m), sourceLocation: sourceLocation)
    #expect(attributesInRange(m), sourceLocation: sourceLocation)
}

/// An open shape: valid without `requireClosed` and exactly `boundary` boundary edges.
private func expectOpen(_ m: Mesh, boundary: Int, sourceLocation: SourceLocation = #_sourceLocation) {
    let report = m.validate(requireClosed: false)
    #expect(report.isValid, "\(report)", sourceLocation: sourceLocation)
    #expect(report.summary.boundaryEdges == boundary, sourceLocation: sourceLocation)
    #expect(!report.summary.isClosed, sourceLocation: sourceLocation)
    #expect(facesAgree(m), sourceLocation: sourceLocation)
    #expect(attributesInRange(m), sourceLocation: sourceLocation)
}

/// The error a build throws, nil when it succeeds.
private func failure(_ body: () throws -> Mesh) -> MeshError? {
    do { _ = try body(); return nil } catch { return error as? MeshError }
}

private func isInvalidInput(_ error: MeshError?) -> Bool {
    if case .some(.invalidInput) = error { return true }
    return false
}

private func isBudget(_ error: MeshError?) -> Bool {
    if case .some(.budget) = error { return true }
    return false
}

/// Area of a regular n-gon of circumradius r: n/2 · r² · sin(2π/n).
private func polygonArea(_ n: Int, _ r: Double) -> Double { Double(n) / 2 * r * r * sin(2 * .pi / Double(n)) }

/// Exact volume of a polygonal profile revolved in n segments: a stack of frusta with regular n-gon cross sections,
/// Σ c · (y₂ − y₁)/3 · (r₁² + r₁r₂ + r₂²) with c = n/2 · sin(2π/n).
private func facetedRevolutionVolume(_ profile: [Vec2], segments n: Int) -> Double {
    let c = Double(n) / 2 * sin(2 * .pi / Double(n))
    return zip(profile, profile.dropFirst()).reduce(0.0) { sum, pair in
        let (p, q) = pair
        return sum + c * (q.y - p.y) / 3 * (p.x * p.x + p.x * q.x + q.x * q.x)
    }
}

/// Semicircle of radius 1 from the south pole to the north pole in `points` samples (poles exactly on the axis).
private func semicircle(_ points: Int) -> [Vec2] {
    (0..<points).map { j in
        if j == 0 { return Vec2(0, -1) }
        if j == points - 1 { return Vec2(0, 1) }
        let theta = -Double.pi / 2 + Double.pi * Double(j) / Double(points - 1)
        return Vec2(cos(theta), sin(theta))
    }
}

/// Star outline with `tips` tips (outer radius 1, inner 0.5), counter-clockwise, 2 · tips points.
private func star(_ tips: Int) -> [Vec2] {
    (0..<(2 * tips)).map { k in
        let angle = Double.pi * Double(k) / Double(tips), r = k % 2 == 0 ? 1.0 : 0.45   // 0.5 with 3 tips makes collinear edges (a triangle)
        return Vec2(r * cos(angle), r * sin(angle))
    }
}

private func helix(_ points: Int) -> [Vec3] {
    (0..<points).map { i in
        let t = 4 * Double.pi * Double(i) / Double(points - 1)
        return Vec3(cos(t), sin(t), 0.3 * t)
    }
}

private func circle(_ points: Int, radius: Double) -> [Vec3] {
    (0..<points).map { i in
        let t = 2 * Double.pi * Double(i) / Double(points)
        return Vec3(radius * cos(t), radius * sin(t), 0)
    }
}

/// Angle between two vectors, accurate for small angles.
private func angle(_ a: Vec3, _ b: Vec3) -> Double { atan2(a.cross(b).length, a.dot(b)) }

private let tiny = MeshBudget(maxVertices: 10, maxIndices: 10)

// MARK: - Surface (FR-R02F05-010)

@Test func surfaceOpenAtThreeResolutions() throws {
    for (c, r) in [(1, 1), (8, 5), (64, 40)] {
        let m = try Mesh.surface(columns: c, rows: r, closedU: false, closedV: false) { u, v in
            Vec3(2 * u - 1, 2 * v - 1, 0.2 * sin(3 * u) * cos(2 * v))
        }
        #expect(m.positions.count == (c + 1) * (r + 1) && m.indices.count == 6 * c * r)
        expectOpen(m, boundary: 2 * (c + r))
    }
}

@Test func surfaceClosedInUIsAnOpenCylinder() throws {
    for (c, r) in [(3, 1), (16, 4), (128, 8)] {
        let m = try Mesh.surface(columns: c, rows: r, closedU: true, closedV: false) { u, v in
            Vec3(cos(2 * .pi * u), sin(2 * .pi * u), v)
        }
        #expect(m.positions.count == c * (r + 1))
        expectOpen(m, boundary: 2 * c)
    }
}

@Test func surfaceClosedTorusAtThreeResolutions() throws {
    let (big, small) = (2.0, 0.5)
    for (c, r) in [(6, 4), (16, 8), (128, 64)] {
        let m = try Mesh.surface(columns: c, rows: r, closedU: true, closedV: true) { u, v in
            let ring = big + small * cos(2 * .pi * v)
            return Vec3(ring * cos(2 * .pi * u), ring * sin(2 * .pi * u), small * sin(2 * .pi * v))
        }
        #expect(m.positions.count == c * r)
        // Pappus for the faceted torus: the r-gon (centroid at distance R) revolved in c planar steps.
        let exact = Double(c) * sin(2 * .pi / Double(c)) * polygonArea(r, small) * big
        expectClosed(m, exact: exact)
        let smooth = 2 * Double.pi * Double.pi * big * small * small
        if c == 128 { #expect(near(m.validate().summary.volume, smooth, 0.01)) }
    }
    // A closed direction is clamped to at least 3.
    let clamped = try Mesh.surface(columns: 1, rows: 1, closedU: true, closedV: true) { u, v in
        Vec3(cos(2 * .pi * u) * (2 + cos(2 * .pi * v)), sin(2 * .pi * u) * (2 + cos(2 * .pi * v)), sin(2 * .pi * v))
    }
    #expect(clamped.positions.count == 9)
}

// MARK: - Revolution (FR-R02F05-011)

@Test func revolutionOfSemicircleAtThreeResolutions() throws {
    for (k, s) in [(5, 6), (17, 24), (65, 128)] {
        let profile = semicircle(k)
        let m = try Mesh.revolution(profile: profile, segments: s)
        #expect(m.positions.count == 2 + (k - 2) * (s + 1))
        #expect(m.indices.count == 2 * 3 * s + 6 * s * (k - 3))
        expectClosed(m, exact: facetedRevolutionVolume(profile, segments: s))
        if s == 128 { #expect(near(m.validate().summary.volume, 4 / 3 * Double.pi, 0.01)) }
    }
}

@Test func revolutionEdgeCases() throws {
    // Clockwise profile (top to bottom) is reversed: same mesh.
    let forward = try Mesh.revolution(profile: semicircle(9), segments: 12)
    let backward = try Mesh.revolution(profile: Array(semicircle(9).reversed()), segments: 12)
    #expect(forward.digest == backward.digest)
    // Profile touching the axis in the middle: one pole vertex there, no degenerate triangles.
    let pinch = [Vec2(0, -1), Vec2(1, -0.5), Vec2(0, 0), Vec2(1, 0.5), Vec2(0, 1)]
    let m = try Mesh.revolution(profile: pinch, segments: 16)
    #expect(m.positions.filter { $0 == Vec3(0, 0, 0) }.count == 1)
    let report = m.validate(requireClosed: true)
    #expect(report.isValid, "\(report)")
    #expect(near(report.summary.volume, facetedRevolutionVolume(pinch, segments: 16), 1e-6))
    // Repeated points are ignored; segments are clamped.
    let repeated = [Vec2(0, -1), Vec2(0, -1)] + semicircle(9).dropFirst() + [Vec2(0, 1)]
    #expect(try Mesh.revolution(profile: repeated, segments: 12).digest == forward.digest)
    #expect(try Mesh.revolution(profile: semicircle(5), segments: 1).digest
            == Mesh.revolution(profile: semicircle(5), segments: 3).digest)
    // Refusals.
    #expect(isInvalidInput(failure { () throws -> Mesh in try Mesh.revolution(profile: [Vec2(1, 0)], segments: 8) }))
    #expect(isInvalidInput(failure { () throws -> Mesh in
        try Mesh.revolution(profile: [Vec2(1, 0), Vec2(1, 0)], segments: 8)
    }))
    #expect(isInvalidInput(failure { () throws -> Mesh in
        try Mesh.revolution(profile: [Vec2(0, 0), Vec2(0, 1)], segments: 8)
    }))
}

// MARK: - Extrusion (FR-R02F05-012)

@Test func extrusionAtThreeResolutions() throws {
    let depth = 0.7
    for tips in [3, 16, 64] {
        let n = 2 * tips
        let area = Double(tips) * 1 * 0.45 * sin(.pi / Double(tips))   // 2·tips triangles of ½·R·r·sin(π/tips)
        let capped = try Mesh.extrusion(outline: star(tips), depth: depth, caps: true)
        #expect(capped.positions.count == 6 * n && capped.indices.count == 6 * n + 6 * (n - 2))
        expectClosed(capped, exact: area * depth)
        let open = try Mesh.extrusion(outline: star(tips), depth: depth, caps: false)
        #expect(open.positions.count == 4 * n)
        expectOpen(open, boundary: 2 * n)
    }
}

@Test func extrusionEdgeCases() throws {
    let square = [Vec2(0, 0), Vec2(1, 0), Vec2(1, 1), Vec2(0, 1)]
    // Clockwise outline is accepted (reversed); a repeated closing point is ignored.
    let clockwise = try Mesh.extrusion(outline: square.reversed() + [Vec2(0, 1)], depth: 2, caps: true)
    expectClosed(clockwise, exact: 2)
    // Collinear points on an edge stay closed (no T-junctions).
    let collinear = try Mesh.extrusion(outline: [Vec2(0, 0), Vec2(0.5, 0), Vec2(1, 0), Vec2(1, 1), Vec2(0, 1)],
                                       depth: 1, caps: true)
    expectClosed(collinear, exact: 1)
    // Refusals: self-intersecting, too few points, no area, bad depth.
    let bowtie = [Vec2(0, 0), Vec2(1, 1), Vec2(1, 0), Vec2(0, 1)]
    #expect(isInvalidInput(failure { () throws -> Mesh in
        try Mesh.extrusion(outline: bowtie, depth: 1, caps: true)
    }))
    #expect(isInvalidInput(failure { () throws -> Mesh in
        try Mesh.extrusion(outline: [Vec2(0, 0), Vec2(1, 0)], depth: 1, caps: true)
    }))
    #expect(isInvalidInput(failure { () throws -> Mesh in
        try Mesh.extrusion(outline: [Vec2(0, 0), Vec2(1, 0), Vec2(2, 0)], depth: 1, caps: true)
    }))
    #expect(isInvalidInput(failure { () throws -> Mesh in
        try Mesh.extrusion(outline: square, depth: 0, caps: true)
    }))
}

// MARK: - Tube (FR-R02F05-013)

@Test func straightCappedTubeAtThreeResolutions() throws {
    let path = [Vec3(0, 0, -1), Vec3(0, 0, 0), Vec3(0, 0, 1)], radius = 0.25
    for sides in [3, 12, 96] {
        let m = try Mesh.tube(path: path, radius: radius, sides: sides, caps: true, closed: false)
        #expect(m.positions.count == 3 * (sides + 1) + 2 * (sides + 1))
        expectClosed(m, exact: polygonArea(sides, radius) * 2)
        if sides == 96 { #expect(near(m.validate().summary.volume, Double.pi * radius * radius * 2, 0.01)) }
        let open = try Mesh.tube(path: path, radius: radius, sides: sides, caps: false, closed: false)
        expectOpen(open, boundary: 2 * sides)
    }
}

@Test func helixTubeAtThreeResolutions() throws {
    for (points, sides) in [(12, 4), (48, 12), (200, 48)] {
        let m = try Mesh.tube(path: helix(points), radius: 0.2, sides: sides, caps: true, closed: false)
        expectClosed(m, exact: nil)
        let open = try Mesh.tube(path: helix(points), radius: 0.2, sides: sides, caps: false, closed: false)
        expectOpen(open, boundary: 2 * sides)
    }
}

@Test func closedLoopTubeAtThreeResolutions() throws {
    let (big, radius) = (2.0, 0.3)
    for (points, sides) in [(6, 3), (24, 12), (128, 64)] {
        let m = try Mesh.tube(path: circle(points, radius: big), radius: radius, sides: sides, caps: true, closed: true)
        #expect(m.positions.count == (points + 1) * (sides + 1))
        // Pappus for the faceted loop: the sides-gon (centroid on the circle) swept in `points` planar steps.
        expectClosed(m, exact: Double(points) * sin(2 * .pi / Double(points)) * polygonArea(sides, radius) * big)
        let smooth = 2 * Double.pi * Double.pi * big * radius * radius
        if points == 128 { #expect(near(m.validate().summary.volume, smooth, 0.01)) }
        // The seam ring coincides with the first ring.
        let ring = sides + 1, seam = points * ring
        let meets = (0..<ring).allSatisfy { (m.positions[seam + $0] - m.positions[$0]).length <= 1e-9 }
        #expect(meets)
    }
}

@Test func tubeFramesAreRotationMinimizing() {
    let path = helix(100)
    let frames = Mesh.pathFrames(path, closed: false)
    #expect(frames.count == path.count)
    for (t, n, b) in frames {
        #expect(abs(t.length - 1) < 1e-9 && abs(n.length - 1) < 1e-9 && abs(t.dot(n)) < 1e-9)
        #expect((t.cross(n) - b).length < 1e-9)
    }
    for i in 1..<frames.count {
        #expect(angle(frames[i - 1].1, frames[i].1) <= angle(frames[i - 1].0, frames[i].0) + 1e-9)
    }
    // A trefoil knot (residual twist about 2.2 rad): the twist is spread so the seam frame meets the first frame.
    let loop = (0..<60).map { i -> Vec3 in
        let t = 2 * Double.pi * Double(i) / 60
        return Vec3(sin(t) + 2 * sin(2 * t), cos(t) - 2 * cos(2 * t), -sin(3 * t))
    }
    let closed = Mesh.pathFrames(loop, closed: true)
    #expect(closed.count == loop.count + 1)
    #expect((closed[loop.count].1 - closed[0].1).length <= 1e-9)
    #expect((closed[loop.count].0 - closed[0].0).length <= 1e-9)
    let tube = try? Mesh.tube(path: loop, radius: 0.1, sides: 8, caps: false, closed: true)
    #expect(tube.map { $0.validate(requireClosed: true).isValid } == true)
}

@Test func tubeEdgeCases() throws {
    let path = [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(1, 1, 0)]
    let base = try Mesh.tube(path: path, radius: 0.1, sides: 8, caps: true, closed: false)
    let repeated = try Mesh.tube(path: [path[0], path[0], path[1], path[1], path[1], path[2]], radius: 0.1, sides: 8,
                                 caps: true, closed: false)
    #expect(repeated.digest == base.digest)
    #expect(isInvalidInput(failure { () throws -> Mesh in
        try Mesh.tube(path: [Vec3(1, 2, 3), Vec3(1, 2, 3)], radius: 0.1, sides: 8, caps: true, closed: false)
    }))
    #expect(isInvalidInput(failure { () throws -> Mesh in
        try Mesh.tube(path: path, radius: 0, sides: 8, caps: true, closed: false)
    }))
    #expect(try Mesh.tube(path: path, radius: 0.1, sides: 1, caps: false, closed: false).digest
            == Mesh.tube(path: path, radius: 0.1, sides: 3, caps: false, closed: false).digest)
    #expect(try Mesh.tube(path: path, radius: 0.1, sides: 1_000, caps: false, closed: false).positions.count == 3 * 257)
}

// MARK: - Bevelled box (FR-R02F05-014)

@Test func bevelledBoxAtThreeResolutions() throws {
    let size = Vec3(2, 1.5, 1), r = 0.3
    let (a, b, c) = (size.x - 2 * r, size.y - 2 * r, size.z - 2 * r)
    let edges: Double = Double.pi * r * r * (a + b + c), corners: Double = 4 / 3 * Double.pi * r * r * r
    let smooth: Double = a * b * c + 2 * r * (a * b + b * c + a * c) + edges + corners
    var previous = 0.0
    for segments in [2, 4, 16] {
        let m = try Mesh.bevelledBox(size: size, radius: r, segments: segments)
        expectClosed(m, exact: nil)
        let volume = m.validate().summary.volume ?? 0
        #expect(volume > previous && volume <= smooth)
        previous = volume
        if segments == 16 { #expect(near(volume, smooth, 0.01)) }
    }
}

@Test func bevelledBoxEdgeCases() throws {
    let plain = try Mesh.bevelledBox(size: Vec3(2, 1.5, 1), radius: 0, segments: 8)
    #expect(plain.positions.count == 24 && plain.indices.count == 36)
    expectClosed(plain, exact: 3)
    // Radius 0 at unit size has the positions of `cube()`.
    let unit = try Mesh.bevelledBox(size: Vec3(1, 1, 1), radius: 0, segments: 1)
    #expect(Set(unit.positions) == Set(Mesh.cube().positions))
    // Radius larger than half the smallest side is clamped; the clamped box is still closed.
    let clamped = try Mesh.bevelledBox(size: Vec3(2, 1.5, 1), radius: 5, segments: 4)
    #expect(clamped.digest == (try Mesh.bevelledBox(size: Vec3(2, 1.5, 1), radius: 0.5, segments: 4)).digest)
    expectClosed(clamped, exact: nil)
    // Fully rounded cube: every inner extent is 0 and the result approaches a sphere.
    let round = try Mesh.bevelledBox(size: Vec3(1, 1, 1), radius: 0.5, segments: 3)
    expectClosed(round, exact: nil)
    // Segments are clamped to 1…16.
    #expect(try Mesh.bevelledBox(size: Vec3(1, 1, 1), radius: 0.2, segments: 0).digest
            == Mesh.bevelledBox(size: Vec3(1, 1, 1), radius: 0.2, segments: 1).digest)
    #expect(try Mesh.bevelledBox(size: Vec3(1, 1, 1), radius: 0.2, segments: 99).digest
            == Mesh.bevelledBox(size: Vec3(1, 1, 1), radius: 0.2, segments: 16).digest)
    #expect(isInvalidInput(failure { () throws -> Mesh in
        try Mesh.bevelledBox(size: Vec3(1, 0, 1), radius: 0.1, segments: 2)
    }))
}

// MARK: - Budget and determinism (FR-R02F05-050, 051)

@Test func tinyBudgetRefusesEveryShape() {
    #expect(isBudget(failure { () throws -> Mesh in
        try Mesh.surface(columns: 4, rows: 4, closedU: false, closedV: false, budget: tiny) { u, v in Vec3(u, v, 0) }
    }))
    #expect(failure { () throws -> Mesh in try Mesh.revolution(profile: semicircle(5), segments: 6, budget: tiny) }
            == MeshError.budget(vertices: 2 + 3 * 7, indices: 2 * 3 * 6 + 6 * 6 * 2, budget: tiny))
    #expect(isBudget(failure { () throws -> Mesh in
        try Mesh.extrusion(outline: star(5), depth: 1, caps: true, budget: tiny)
    }))
    #expect(isBudget(failure { () throws -> Mesh in
        try Mesh.tube(path: helix(10), radius: 0.1, sides: 8, caps: true, closed: false, budget: tiny)
    }))
    #expect(isBudget(failure { () throws -> Mesh in
        try Mesh.bevelledBox(size: Vec3(1, 1, 1), radius: 0.2, segments: 4, budget: tiny)
    }))
}

@Test func sameDescriptionGivesSameDigest() throws {
    func torus() throws(MeshError) -> Mesh {
        try Mesh.surface(columns: 12, rows: 8, closedU: true, closedV: true) { u, v in
            Vec3((2 + cos(2 * .pi * v)) * cos(2 * .pi * u), (2 + cos(2 * .pi * v)) * sin(2 * .pi * u), sin(2 * .pi * v))
        }
    }
    let builds: [() throws -> Mesh] = [
        torus,
        { () throws -> Mesh in try Mesh.revolution(profile: semicircle(9), segments: 16) },
        { () throws -> Mesh in try Mesh.extrusion(outline: star(7), depth: 0.5, caps: true) },
        { () throws -> Mesh in try Mesh.tube(path: helix(30), radius: 0.2, sides: 10, caps: true, closed: false) },
        { () throws -> Mesh in try Mesh.bevelledBox(size: Vec3(2, 1, 1), radius: 0.2, segments: 4) },
    ]
    for build in builds {
        let first = try build(), second = try build()
        #expect(first.digest == second.digest && first == second)
        #expect(first.digest.count == 64)
    }
}
