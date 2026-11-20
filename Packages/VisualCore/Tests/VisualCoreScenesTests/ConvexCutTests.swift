// ConvexCutTests — feature 212 (R02-F12) T-R02F12-003 (FR-R02F12-002, FR-R02F12-003, FR-R02F12-004, FR-R02F12-009;
// SC-R02F12-001, SC-R02F12-003, SC-R02F12-004). The unit cube cut through its centre on three axes and by 100 seeded
// planes; planes that miss; planes through vertices, edges and faces and within the tolerance of them; a sliver side;
// a 1e-3 and a 1e3 cube alike; repeated cuts stay valid; cuts past the limits are refused.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct ConvexCutTests {
    static func unitCube() throws -> ConvexSolid { try ConvexSolid.box(min: Vec3(0, 0, 0), max: Vec3(1, 1, 1)) }

    /// A plane with a seeded normal through a seeded point of `0…scale`³.
    static func seededPlane(_ random: inout SDFTestRandom, scale: Double = 1) throws -> ClipPlane {
        var n = random.point(1)
        while n.length < 1e-3 { n = random.point(1) }
        n = n.normalized
        let q = (Vec3(0.5, 0.5, 0.5) + random.point(0.5)) * scale
        return try ClipPlane(normal: n, offset: n.dot(q))
    }

    /// Checks a part: mesh closed, valid and outward with the part's volume; clean faces; no sliver.
    static func checkPart(_ part: ConvexSolid, parentDiagonal: Double, _ comment: Comment = "") {
        let report = part.mesh().validate(requireClosed: true)
        #expect(report.isValid, "\(report.description) \(comment)")
        if let v = report.summary.volume { #expect(abs(v - part.volume) <= 1e-12 * part.volume, comment) }
        let tol = 1e-9 * parentDiagonal
        #expect(part.volume > tol * parentDiagonal * parentDiagonal, "sliver \(comment)")
        for face in part.faces {
            #expect(face.count >= 3, comment)
            let corners = face.map { part.vertices[$0] }
            #expect(PolygonCleanup.areaVector(corners).length / 2 > 1e-12 * parentDiagonal * parentDiagonal, comment)
            for i in corners.indices {
                for j in corners.indices where j > i {
                    #expect((corners[i] - corners[j]).length > tol, "repeated point \(comment)")
                }
            }
        }
    }

    @Test func centreCutsOnThreeAxes() throws {
        let cube = try Self.unitCube()
        for axis in [Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0, 0, 1)] {
            let r = try cube.cut(by: try ClipPlane(normal: axis, offset: 0.5))
            #expect(abs(r.keptVolume - 0.5) <= 1e-12)
            #expect(abs(r.removedVolume - 0.5) <= 1e-12)
            #expect(abs(r.keptVolume + r.removedVolume - 1) <= 1e-12)
            #expect(r.cap.count == 4)
            #expect(abs(PolygonCleanup.areaVector(r.cap).length / 2 - 1) <= 1e-12)
            #expect(PolygonCleanup.areaVector(r.cap).dot(axis) > 0, "cap counter-clockwise about the normal")
            let kept = try #require(r.kept), removed = try #require(r.removed)
            Self.checkPart(kept, parentDiagonal: cube.diagonal)
            Self.checkPart(removed, parentDiagonal: cube.diagonal)
            #expect(kept.faces.count == 6 && removed.faces.count == 6)
            #expect(kept.contains(Vec3(0.25, 0.25, 0.25)) && !kept.contains(Vec3(0.75, 0.75, 0.75)))
        }
    }

    @Test func hundredSeededPlanesConserveVolume() throws {
        let cube = try Self.unitCube()
        var random = SDFTestRandom(seed: 2_012)
        var worst = 0.0
        for k in 0..<100 {
            let plane = try Self.seededPlane(&random)
            let r = try cube.cut(by: plane)
            let sum = r.keptVolume + r.removedVolume
            worst = max(worst, abs(sum - 1))
            #expect(abs(sum - 1) <= 1e-12, "plane \(k)")
            if let kept = r.kept { Self.checkPart(kept, parentDiagonal: cube.diagonal, "kept \(k)") }
            if let removed = r.removed { Self.checkPart(removed, parentDiagonal: cube.diagonal, "removed \(k)") }
            if r.kept != nil, r.removed != nil {
                #expect(r.cap.count >= 3)
                for p in r.cap { #expect(abs(plane.distance(to: p)) <= cube.tolerance) }
            }
        }
        print("ConvexCutTests worst volume sum error \(worst)")
        // Determinism: the same cuts give identical results.
        var again = SDFTestRandom(seed: 2_012)
        var first = SDFTestRandom(seed: 2_012)
        for _ in 0..<10 {
            #expect(try cube.cut(by: try Self.seededPlane(&first)) == cube.cut(by: try Self.seededPlane(&again)))
        }
    }

    @Test func missingPlanesKeepOrRemoveTheSolidWhole() throws {
        let cube = try Self.unitCube()
        var random = SDFTestRandom(seed: 2_012)
        for _ in 0..<50 {
            let n = random.point(1).normalized
            var top = -Double.infinity, bottom = Double.infinity
            for v in cube.vertices { top = max(top, n.dot(v)); bottom = min(bottom, n.dot(v)) }
            let above = try cube.cut(by: try ClipPlane(normal: n, offset: top + 0.1))
            #expect(above.kept == cube && above.removed == nil && above.cap.isEmpty && above.removedVolume == 0)
            let below = try cube.cut(by: try ClipPlane(normal: n, offset: bottom - 0.1))
            #expect(below.kept == nil && below.removed == cube && below.cap.isEmpty && below.keptVolume == 0)
            // A plane touching the solid at a vertex (within the tolerance) also misses.
            let touch = try cube.cut(by: try ClipPlane(normal: n, offset: top - 0.5 * cube.tolerance))
            #expect(touch.kept == cube && touch.removed == nil)
        }
    }

    @Test func planesThroughVerticesEdgesAndFacesLeaveNoDegenerateFace() throws {
        let cube = try Self.unitCube()
        let eps = cube.tolerance
        var random = SDFTestRandom(seed: 2_012)
        let edges: [(Int, Int)] = [(0, 1), (0, 2), (0, 4), (3, 7), (5, 7), (6, 7), (1, 3), (2, 6), (4, 5), (1, 5),
                                   (2, 3), (4, 6)]
        var split = 0
        for k in 0..<100 {
            var n = random.point(1).normalized
            var through = Vec3.zero
            switch k % 4 {
            case 0:  // through a vertex
                through = cube.vertices[Int(random.next() * 8) % 8]
            case 1:  // along an edge
                let e = edges[Int(random.next() * 12) % 12]
                let a = cube.vertices[e.0], b = cube.vertices[e.1], d = (b - a).normalized
                n = (n - d * n.dot(d)).normalized
                through = a
            case 2:  // containing a face
                let axis = Int(random.next() * 3) % 3
                n = axis == 0 ? Vec3(1, 0, 0) : (axis == 1 ? Vec3(0, 1, 0) : Vec3(0, 0, 1))
                if random.next() < 0.5 { n = -n }
                through = random.next() < 0.5 ? Vec3(0, 0, 0) : Vec3(1, 1, 1)
            default:  // through two opposite vertices (a diagonal plane through four vertices)
                n = Vec3(1, -1, 0).normalized
                through = Vec3(0, 0, 0)
            }
            let shift = [0.0, 0.5 * eps, -0.5 * eps][(k / 4) % 3]
            let plane = try ClipPlane(normal: n, offset: n.dot(through) + shift)
            let r = try cube.cut(by: plane)
            #expect(abs(r.keptVolume + r.removedVolume - 1) <= 1e-12, "fixture \(k)")
            if let kept = r.kept { Self.checkPart(kept, parentDiagonal: cube.diagonal, "kept \(k)") }
            if let removed = r.removed { Self.checkPart(removed, parentDiagonal: cube.diagonal, "removed \(k)") }
            if r.kept != nil, r.removed != nil { split += 1 }
        }
        #expect(split > 20, "most fixtures cut the cube in two")
    }

    @Test func aSliverSideIsEmpty() throws {
        let cube = try Self.unitCube()
        let eps = cube.tolerance
        // A slab of thickness 2ε (volume below ε × diagonal²) is a sliver: nothing is removed.
        let slab = try cube.cut(by: try ClipPlane(normal: Vec3(1, 0, 0), offset: 1 - 2 * eps))
        #expect(slab.removed == nil && slab.kept == cube && slab.cap.isEmpty)
        // A corner cut 3ε deep is a sliver too.
        let n = Vec3(1, 1, 1).normalized
        let corner = try cube.cut(by: try ClipPlane(normal: n, offset: n.dot(Vec3(1, 1, 1)) - 3 * eps))
        #expect(corner.removed == nil && corner.kept == cube)
        let keptSliver = try cube.cut(by: try ClipPlane(normal: Vec3(1, 0, 0), offset: 2 * eps))
        #expect(keptSliver.kept == nil && keptSliver.removed == cube)
    }

    @Test func smallAndLargeCubesBehaveAlike() throws {
        let small = try ConvexSolid.box(min: Vec3(0, 0, 0), max: Vec3(1e-3, 1e-3, 1e-3))
        let large = try ConvexSolid.box(min: Vec3(0, 0, 0), max: Vec3(1e3, 1e3, 1e3))
        var random = SDFTestRandom(seed: 2_012)
        var worst = 0.0
        for k in 0..<100 {
            var n = random.point(1)
            while n.length < 1e-3 { n = random.point(1) }
            n = n.normalized
            let q = Vec3(0.5, 0.5, 0.5) + random.point(0.5)
            let a = try small.cut(by: try ClipPlane(normal: n, offset: n.dot(q * 1e-3)))
            let b = try large.cut(by: try ClipPlane(normal: n, offset: n.dot(q * 1e3)))
            let pairs: [(ConvexSolid?, ConvexSolid?)] = [(a.kept, b.kept), (a.removed, b.removed)]
            for (x, y) in pairs {
                #expect((x == nil) == (y == nil), "plane \(k)")
                guard let x, let y else { continue }
                #expect(x.vertices.count == y.vertices.count && x.faces == y.faces, "plane \(k)")
                guard x.vertices.count == y.vertices.count else { continue }
                for i in x.vertices.indices {
                    let d = (x.vertices[i] * 1e3 - y.vertices[i] * 1e-3).length / 3.0.squareRoot()
                    worst = max(worst, d)
                }
            }
            #expect(abs(a.keptVolume / 1e-9 - b.keptVolume / 1e9) <= 1e-12, "plane \(k)")
        }
        print("ConvexCutTests worst rescaled vertex error \(worst)")
        #expect(worst <= 1e-12)
    }

    @Test func repeatedCutsKeepTheSolidValid() throws {
        var solid = try Self.unitCube()
        var random = SDFTestRandom(seed: 2_012)
        var cuts = 0
        for _ in 0..<200 {
            var n = random.point(1)
            while n.length < 1e-3 { n = random.point(1) }
            n = n.normalized
            var centre = Vec3.zero
            for v in solid.vertices { centre += v }
            centre = centre / Double(solid.vertices.count)
            var top = -Double.infinity
            for v in solid.vertices { top = max(top, n.dot(v)) }
            let h = n.dot(centre) + (0.5 + 0.45 * random.next()) * (top - n.dot(centre))
            let r = try solid.cut(by: try ClipPlane(normal: n, offset: h))
            let kept = try #require(r.kept)
            #expect(kept.volume <= solid.volume)
            #expect(abs(r.keptVolume + r.removedVolume - solid.volume) <= 1e-12, "relative to the unit cube")
            if r.removed != nil { cuts += 1 }
            solid = kept
            #expect(solid.vertices.count <= ConvexSolid.maxVertices && solid.faces.count <= ConvexSolid.maxFaces)
            for face in solid.faces { #expect(face.count <= ConvexSolid.maxCorners) }
        }
        let report = solid.mesh().validate(requireClosed: true)
        #expect(report.isValid, "\(report.description)")
        let data = try JSONEncoder().encode(solid)
        #expect(try JSONDecoder().decode(ConvexSolid.self, from: data) == solid)
        #expect(cuts > 150)
    }

    @Test func cutsPastTheLimitsAreRefused() throws {
        // A prism of 257 vertical planes: its top and bottom would need 257 corners.
        var prism: [ClipPlane] = []
        for k in 0..<257 {
            let a = 2 * Double.pi * Double(k) / 257
            prism.append(try ClipPlane(normal: Vec3(cos(a), sin(a), 0), offset: 1))
        }
        #expect(throws: ConvexSolidError.tooComplex("corners")) {
            _ = try ConvexSolid.bounded(by: prism, min: Vec3(-2, -2, -1), max: Vec3(2, 2, 1))
        }
        // A bipyramid over a 512-vertex ring has exactly 1,024 triangle faces; it is built directly (through the
        // internal validated initialiser, so the test stays well under a second and does not slow the suites that
        // run beside it — a 1,024-plane construction took ~4 s and pushed a timed R02-F05 test past its bound).
        // Cutting at x = 0.99 takes about 23 ring vertices but every triangle keeps its apex, so all 1,024 faces stay
        // (clipped) and the cap is the 1,025th face.
        let ring = 512
        var vertices: [Vec3] = [Vec3(0, 0, 1), Vec3(0, 0, -1)]
        for k in 0..<ring {
            let a = 2 * Double.pi * Double(k) / Double(ring)
            vertices.append(Vec3(cos(a), sin(a), 0))
        }
        var faces: [[Int]] = []
        for k in 0..<ring {
            let i = 2 + k, j = 2 + (k + 1) % ring
            faces.append([0, i, j])
            faces.append([1, j, i])
        }
        let bipyramid = ConvexSolid(validatedVertices: vertices, faces: faces)
        #expect(bipyramid.faces.count == ConvexSolid.maxFaces)
        #expect(bipyramid.mesh().validate(requireClosed: true).isValid)
        #expect(throws: ConvexSolidError.tooComplex("faces")) {
            _ = try bipyramid.cut(by: try ClipPlane(normal: Vec3(1, 0, 0), offset: 0.99))
        }
    }
}
