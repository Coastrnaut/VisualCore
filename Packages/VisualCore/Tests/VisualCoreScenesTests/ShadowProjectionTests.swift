// ShadowProjectionTests — feature 213 (R02-F13) T-R02F13-002 (FR-R02F13-001, FR-R02F13-002, FR-R02F13-006,
// FR-R02F13-008; SC-R02F13-001; clarifications Q1, Q2). A unit cube lit straight down casts its rotated unit square
// within 1e-12 over 100 seeded rotations about y; a point light scales by the similar triangles h/(h − s); geometry above
// the light or below the ground casts nothing; a triangle crossing the light's slab is clipped, never flipped; parallel,
// on-plane and below-plane lights are refused with their reason codes; the Blinn matrix maps 100 seeded points like
// `project` within 1e-12 relative; the plane basis is orthonormal with u × v = n for 100 seeded normals. Seeds come from
// the local LCG `SDFTestRandom` with seed 2_013.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct ShadowProjectionTests {
    static func ground() throws -> ProjectionPlane { ProjectionPlane(plane: try ClipPlane(normal: Vec3(0, 1, 0), offset: 0)) }

    /// The unit cube [−0.5, 0.5] × [0, 1] × [−0.5, 0.5] turned by `angle` about y.
    static func cube(angle: Double) throws -> ConvexSolid {
        let c = cos(angle), s = sin(angle)
        var mesh = try ConvexSolid.box(min: Vec3(-0.5, 0, -0.5), max: Vec3(0.5, 1, 0.5)).mesh()
        mesh.positions = mesh.positions.map { Vec3(c * $0.x + s * $0.z, $0.y, -s * $0.x + c * $0.z) }
        return try ConvexSolid(mesh: mesh)
    }

    /// The square of half-size `half` turned by `angle` about y, in the plane basis.
    static func square(angle: Double, half: Double, plane: ProjectionPlane) -> [Vec2] {
        let c = cos(angle), s = sin(angle)
        return [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)].map { x, z in
            plane.coordinates(of: Vec3(c * x * half + s * z * half, 0, -s * x * half + c * z * half))
        }
    }

    /// True when `hull` has four corners matching `expected` within `tolerance`, in any rotation.
    static func matches(_ hull: [Vec2], _ expected: [Vec2], _ tolerance: Double) -> Bool {
        guard hull.count == expected.count else { return false }
        return expected.allSatisfy { e in hull.contains { ($0 - e).length <= tolerance } }
    }

    @Test func cubeStraightDownCastsTheRotatedUnitSquare() throws {
        let plane = try Self.ground()
        let light = try ShadowLight.directional(towards: Vec3(0, -3, 0))
        #expect(light == .directional(Vec3(0, -1, 0)))
        var random = SDFTestRandom(seed: 2_013)
        var worst = 0.0
        for _ in 0..<100 {
            let angle = random.next() * 2 * Double.pi
            let hull = try ShadowProjector.outline(of: Self.cube(angle: angle), light: light, onto: plane)
            #expect(Self.matches(hull, Self.square(angle: angle, half: 0.5, plane: plane), 1e-12))
            worst = max(worst, abs(ConvexHull2D.area(hull) - 1))
            #expect(ConvexHull2D.area(hull) > 0)
        }
        #expect(worst <= 1e-12)
    }

    @Test func pointLightFollowsSimilarTriangles() throws {
        let plane = try Self.ground()
        let light = try ShadowLight.point(at: Vec3(0, 4, 0))
        // A point at height s and distance r lands at r · h / (h − s).
        let q = try #require(try ShadowProjector.project(Vec3(0.5, 1, 0), light: light, onto: plane))
        #expect(abs((plane.point(of: q) - Vec3(0.5 * 4 / 3, 0, 0)).length) <= 1e-12)
        var random = SDFTestRandom(seed: 2_013)
        for _ in 0..<100 {
            let angle = random.next() * 2 * Double.pi
            let hull = try ShadowProjector.outline(of: Self.cube(angle: angle), light: light, onto: plane)
            #expect(Self.matches(hull, Self.square(angle: angle, half: 0.5 * 4 / 3, plane: plane), 1e-12))
            #expect(abs(ConvexHull2D.area(hull) - 16.0 / 9) <= 1e-12)
        }
    }

    @Test func geometryAboveTheLightOrBelowTheGroundCastsNothing() throws {
        let plane = try Self.ground()
        let point = ShadowLight.point(Vec3(0, 2, 0))
        let down = ShadowLight.directional(Vec3(0, -1, 0))
        #expect(try ShadowProjector.project(Vec3(1, 3, 0), light: point, onto: plane) == nil)
        #expect(try ShadowProjector.project(Vec3(1, 2, 0), light: point, onto: plane) == nil)
        #expect(try ShadowProjector.project(Vec3(1, -1, 0), light: point, onto: plane) == nil)
        #expect(try ShadowProjector.project(Vec3(1, -1, 0), light: down, onto: plane) == nil)
        #expect(try ShadowProjector.projectTriangle(Vec3(0, 3, 0), Vec3(1, 3, 0), Vec3(0, 3, 1), light: point,
                                                    onto: plane).isEmpty)
        #expect(try ShadowProjector.projectTriangle(Vec3(0, -1, 0), Vec3(1, -1, 0), Vec3(0, -1, 1), light: down,
                                                    onto: plane).isEmpty)
        let below = try ConvexSolid.box(min: Vec3(-1, -3, -1), max: Vec3(1, -1, 1))
        #expect(try ShadowProjector.outline(of: below, light: down, onto: plane).isEmpty)
        #expect(try ShadowProjector.project(mesh: below.mesh(), light: point, onto: plane).isEmpty)
    }

    @Test func triangleCrossingTheLightSlabIsClippedNotFlipped() throws {
        let plane = try Self.ground()
        let light = ShadowLight.point(Vec3(0, 2, 0))
        let a = Vec3(-1, 1, 0.2), b = Vec3(1, 1, 0.2), c = Vec3(0, 3, 0.5)
        let polygon = try ShadowProjector.projectTriangle(a, b, c, light: light, onto: plane)
        #expect(polygon.count >= 3 && polygon.count <= 5)
        let area = ConvexHull2D.area(polygon)
        #expect(area.isFinite && area > 0)
        // δ = 1e-9 × max(1, |L|, max|corner|); a clipped corner at offset r lands within r · 2 / δ of the light's foot.
        let delta = 1e-9 * max(1, 2, c.length)
        for q in polygon {
            #expect(q.isFinite)
            let w = plane.point(of: q)
            #expect(abs(w.y) <= 1e-9)
            #expect(w.z >= 0.2 - 1e-9) // a flipped projection of the corner above the light would land at z < 0
            #expect(w.length <= 1.2 * 2 / delta)
        }
    }

    @Test func meshShadowsAndTriangleLimit() throws {
        let plane = try Self.ground()
        let mesh = try ConvexSolid.box(min: Vec3(-0.5, 0, -0.5), max: Vec3(0.5, 1, 0.5)).mesh()
        let polygons = try ShadowProjector.project(mesh: mesh, light: .directional(Vec3(0, -1, 0)), onto: plane)
        // Top and bottom quads cast (side faces are edge-on and dropped); every polygon is counter-clockwise.
        #expect(abs(polygons.map(ConvexHull2D.area).reduce(0, +) - 2) <= 1e-12)
        #expect(polygons.allSatisfy { ConvexHull2D.area($0) > 0 })
        var huge = Mesh(positions: [Vec3(0, 1, 0)], normals: [Vec3(0, 1, 0)], uvs: [Vec2(0, 0)], indices: [])
        huge.indices = [UInt32](repeating: 0, count: 3 * (ShadowProjector.maxTriangles + 1))
        #expect(throws: ShadowError.tooManyTriangles(ShadowProjector.maxTriangles + 1)) {
            try ShadowProjector.project(mesh: huge, light: .directional(Vec3(0, -1, 0)), onto: plane)
        }
    }

    @Test func invalidLightsAndPointsAreRefusedWithReasonCodes() throws {
        let plane = try Self.ground()
        let p = Vec3(0, 1, 0)
        let cases: [(ShadowLight, ShadowError, String)] = [
            (.directional(Vec3(1, 0, 0)), .parallelLight, "r2-f13.parallel-light"),
            (.directional(Vec3(0, 1, 0)), .lightBelowPlane, "r2-f13.light-below-plane"),
            (.point(Vec3(3, 0, 0)), .lightOnPlane, "r2-f13.light-on-plane"),
            (.point(Vec3(0, -1, 0)), .lightBelowPlane, "r2-f13.light-below-plane"),
            (.directional(Vec3(0, 0, 0)), .zeroDirection, "r2-f13.zero-direction"),
        ]
        for (light, error, code) in cases {
            #expect(error.reasonCode == code)
            #expect(throws: error) { try ShadowProjector.project(p, light: light, onto: plane) }
            #expect(throws: error) { try ShadowProjector.matrix(light: light, onto: plane) }
            #expect(throws: error) { try ShadowProjector.projectTriangle(p, p, p, light: light, onto: plane) }
        }
        #expect(throws: ShadowError.zeroDirection) { try ShadowLight.directional(towards: .zero) }
        #expect(throws: ShadowError.nonFinite("direction")) { try ShadowLight.directional(towards: Vec3(.nan, -1, 0)) }
        #expect(throws: ShadowError.nonFinite("position")) { try ShadowLight.point(at: Vec3(0, .infinity, 0)) }
        #expect(throws: ShadowError.nonFinite("point")) {
            try ShadowProjector.project(Vec3(.nan, 1, 0), light: .directional(Vec3(0, -1, 0)), onto: plane)
        }
        let codes = [ShadowError.nonFinite("x"), .maskSize(width: 0, height: 1), .mismatchedMasks, .tooManyTriangles(1),
                     .newerSchema(2), .malformed("x")].map(\.reasonCode)
        #expect(codes == ["r2-f13.non-finite", "r2-f13.mask-size", "r2-f13.mismatched-masks",
                          "r2-f13.too-many-triangles", "r2-f13.newer-schema", "r2-f13.malformed"])
    }

    @Test func matrixMapsSeededPointsLikeProject() throws {
        var random = SDFTestRandom(seed: 2_013)
        var worst = 0.0
        var compared = 0
        for i in 0..<100 {
            var n = random.point(1)
            while n.length < 0.1 { n = random.point(1) }
            let clip = try ClipPlane(normal: n, offset: (random.next() * 2 - 1) * 2)
            let plane = ProjectionPlane(plane: clip)
            let unit = clip.normal, h = clip.offset
            let p0 = random.point(3), t = random.next() * 0.8
            let light: ShadowLight
            let p: Vec3
            if i.isMultiple(of: 2) {
                let lift = 1 + random.next() * 3
                let r = random.point(1)
                light = .point(plane.origin + unit * lift + r - unit * unit.dot(r))
                guard case .point(let l) = light else { continue }
                p = p0 - unit * (unit.dot(p0) - h) + unit * (t * (unit.dot(l) - h))
            } else {
                var d = random.point(1)
                while unit.dot(d.normalized) > -0.2 { d = random.point(1) }
                light = try ShadowLight.directional(towards: d)
                p = p0 - unit * (unit.dot(p0) - h) + unit * (t * 3)
            }
            let projected = try #require(try ShadowProjector.project(p, light: light, onto: plane))
            let expected = plane.point(of: projected)
            let mapped = try ShadowProjector.matrix(light: light, onto: plane).applyPoint(p)
            let error = (mapped - expected).length / max(1, expected.length)
            worst = max(worst, error)
            compared += 1
        }
        #expect(compared == 100)
        #expect(worst <= 1e-12)
    }

    @Test func basisIsOrthonormalAndRightHandedForSeededNormals() throws {
        let up = try Self.ground()
        #expect(up.u == Vec3(0, 0, -1) && up.v == Vec3(-1, 0, 0)) // e = x (tie of x and z goes to x)
        let tilted = ProjectionPlane(plane: try ClipPlane(normal: Vec3(1, 1, 0), offset: 1))
        #expect((tilted.u - Vec3(1, -1, 0) / 2.0.squareRoot()).length <= 1e-15) // e = z, the least aligned axis
        #expect(ProjectionPlane(plane: try ClipPlane(normal: Vec3(0, 0, 1), offset: 0)).u == Vec3(0, 1, 0)) // e = x
        #expect(ProjectionPlane(plane: try ClipPlane(normal: Vec3(1, 0, 0), offset: 0)).u == Vec3(0, 0, 1)) // e = y
        var random = SDFTestRandom(seed: 2_013)
        for _ in 0..<100 {
            var n = random.point(1)
            while n.length < 0.1 { n = random.point(1) }
            let plane = ProjectionPlane(plane: try ClipPlane(normal: n, offset: (random.next() * 2 - 1) * 3))
            let normal = plane.plane.normal
            #expect(abs(plane.u.length - 1) <= 1e-12 && abs(plane.v.length - 1) <= 1e-12)
            #expect(abs(plane.u.dot(plane.v)) <= 1e-12 && abs(plane.u.dot(normal)) <= 1e-12)
            #expect((plane.u.cross(plane.v) - normal).length <= 1e-12)
            #expect(abs(plane.plane.distance(to: plane.origin)) <= 1e-12)
            let q = Vec2(random.next() * 4 - 2, random.next() * 4 - 2)
            #expect((plane.coordinates(of: plane.point(of: q)) - q).length <= 1e-12)
        }
    }
}
