// ConvexSolidTests — feature 212 (R02-F12) T-R02F12-003 (FR-R02F12-001, FR-R02F12-003, FR-R02F12-008, FR-R02F12-009).
// Box volume and faces; a box bounded by planes gives a tetrahedron and an octahedron; a mesh cube is accepted, a
// non-convex and an open mesh are refused; `mesh()` validates closed with the solid's volume; the stored form round
// trips and is re-validated; `contains`.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct ConvexSolidTests {
    static func plane(_ n: Vec3, _ h: Double) throws -> ClipPlane { try ClipPlane(normal: n, offset: h) }

    static func tetrahedron() throws -> ConvexSolid {
        let planes = [try plane(Vec3(-1, 0, 0), 0), try plane(Vec3(0, -1, 0), 0), try plane(Vec3(0, 0, -1), 0),
                      try plane(Vec3(1, 1, 1), 1 / 3.0.squareRoot())]
        return try ConvexSolid.bounded(by: planes, min: Vec3(0, 0, 0), max: Vec3(1, 1, 1))
    }

    static func octahedron() throws -> ConvexSolid {
        var planes: [ClipPlane] = []
        for i in 0..<8 {
            let n = Vec3(i & 1 == 0 ? 1 : -1, i & 2 == 0 ? 1 : -1, i & 4 == 0 ? 1 : -1)
            planes.append(try plane(n, 1 / 3.0.squareRoot()))
        }
        return try ConvexSolid.bounded(by: planes, min: Vec3(-1, -1, -1), max: Vec3(1, 1, 1))
    }

    /// An L-shaped prism (closed, consistently wound, not convex).
    static func lPrism() -> Mesh {
        let outline = [(1.0, 1.0), (1.0, 2.0), (0.0, 2.0), (0.0, 0.0), (2.0, 0.0), (2.0, 1.0)]
        var m = Mesh(positions: [], normals: [], uvs: [], indices: [])
        for z in [0.0, 1.0] {
            for (x, y) in outline {
                m.positions.append(Vec3(x, y, z)); m.normals.append(Vec3(0, 0, 1)); m.uvs.append(Vec2(0, 0))
            }
        }
        let n = UInt32(outline.count)
        for k in UInt32(1)..<(n - 1) {
            m.indices += [n, n + k, n + k + 1]  // top, counter-clockwise from +z
            m.indices += [0, k + 1, k]  // bottom, reversed
        }
        for a in UInt32(0)..<n {
            let b = (a + 1) % n
            m.indices += [a, b, b + n, a, b + n, a + n]
        }
        return m
    }

    @Test func boxHasUnitVolumeAndSixQuads() throws {
        let box = try ConvexSolid.box(min: Vec3(0, 0, 0), max: Vec3(1, 1, 1))
        #expect(box.vertices.count == 8)
        #expect(box.faces.count == 6)
        for face in box.faces { #expect(face.count == 4) }
        #expect(abs(box.volume - 1) <= 1e-12)
        #expect(abs(box.diagonal - 3.0.squareRoot()) <= 1e-12)
        #expect(abs(box.tolerance - 1e-9 * 3.0.squareRoot()) <= 1e-21)
        #expect(throws: ConvexSolidError.empty) { _ = try ConvexSolid.box(min: Vec3(0, 0, 0), max: Vec3(1, 0, 1)) }
        #expect(throws: ConvexSolidError.nonFinite("max")) {
            _ = try ConvexSolid.box(min: Vec3(0, 0, 0), max: Vec3(1, .infinity, 1))
        }
    }

    @Test func boundedByPlanesGivesTetrahedronAndOctahedron() throws {
        let tetra = try Self.tetrahedron()
        #expect(tetra.vertices.count == 4)
        #expect(tetra.faces.count == 4)
        #expect(abs(tetra.volume - 1 / 6.0) <= 1e-12)
        let octa = try Self.octahedron()
        #expect(octa.vertices.count == 6)
        #expect(octa.faces.count == 8)
        for face in octa.faces { #expect(face.count == 3) }
        #expect(abs(octa.volume - 4 / 3.0) <= 1e-12)
        let away = try Self.plane(Vec3(1, 0, 0), -5)
        #expect(throws: ConvexSolidError.empty) {
            _ = try ConvexSolid.bounded(by: [away], min: Vec3(0, 0, 0), max: Vec3(1, 1, 1))
        }
    }

    @Test func meshCubeIsAcceptedAndBadMeshesAreRefused() throws {
        let cube = try ConvexSolid(mesh: .cube())
        #expect(cube.faces.count == 6)
        #expect(cube.vertices.count == 8)
        #expect(abs(cube.volume - 1) <= 1e-12)
        #expect(throws: ConvexSolidError.notConvex) { _ = try ConvexSolid(mesh: Self.lPrism()) }
        var open = Mesh.cube()
        open.indices.removeLast(3)
        #expect(throws: ConvexSolidError.notClosed) { _ = try ConvexSolid(mesh: open) }
        var inverted = Mesh.cube()
        for t in 0..<inverted.triangleCount { inverted.indices.swapAt(3 * t + 1, 3 * t + 2) }
        #expect(throws: ConvexSolidError.notConvex) { _ = try ConvexSolid(mesh: inverted) }
        // A subdivided-free sphere-like convex mesh: the octahedron's own mesh reads back as the same polyhedron.
        let octa = try Self.octahedron()
        let again = try ConvexSolid(mesh: octa.mesh())
        #expect(again.faces.count == 8)
        #expect(abs(again.volume - octa.volume) <= 1e-12)
    }

    @Test func meshValidatesClosedWithTheSolidsVolume() throws {
        let solids = [try ConvexSolid.box(min: Vec3(-1, 0, 2), max: Vec3(0.5, 3, 2.25)), try Self.tetrahedron(),
                      try Self.octahedron()]
        for solid in solids {
            let report = solid.mesh().validate(requireClosed: true)
            #expect(report.isValid, "\(report.description)")
            let volume = try #require(report.summary.volume)
            #expect(abs(volume - solid.volume) <= 1e-12 * solid.volume)
        }
    }

    @Test func storedFormRoundTripsAndIsRevalidated() throws {
        let octa = try Self.octahedron()
        let data = try JSONEncoder().encode(octa)
        let back = try JSONDecoder().decode(ConvexSolid.self, from: data)
        #expect(back == octa)
        let box = try ConvexSolid.box(min: Vec3(0, 0, 0), max: Vec3(1, 1, 1))
        func refusal(_ vertices: [Vec3], _ faces: [[Int]]) throws -> ConvexSolidError? {
            struct Stored: Encodable { var vertices: [Vec3]; var faces: [[Int]] }
            let data = try JSONEncoder().encode(Stored(vertices: vertices, faces: faces))
            do {
                _ = try JSONDecoder().decode(ConvexSolid.self, from: data)
                return nil
            } catch let DecodingError.dataCorrupted(context) {
                return context.underlyingError as? ConvexSolidError
            }
        }
        var faces = box.faces
        faces[0][0] = 99
        #expect(try refusal(box.vertices, faces) == .malformed("index"))
        #expect(try refusal(box.vertices, Array(box.faces.dropLast())) == .notClosed)
        var dented = box.vertices
        dented[7] = Vec3(0.6, 0.6, 0.6)
        #expect(try refusal(dented, box.faces) == .notConvex)
        var reversed = box.faces
        for i in reversed.indices { reversed[i].reverse() }
        #expect(try refusal(box.vertices, reversed) == .notConvex)
    }

    @Test func containsUsesTheTolerance() throws {
        let tetra = try Self.tetrahedron()
        #expect(tetra.contains(Vec3(0.1, 0.1, 0.1)))
        #expect(tetra.contains(Vec3(0, 0, 0)))
        #expect(tetra.contains(Vec3(-0.5 * tetra.tolerance, 0.2, 0.2)))
        #expect(!tetra.contains(Vec3(-2 * tetra.tolerance, 0.2, 0.2)))
        #expect(!tetra.contains(Vec3(0.5, 0.5, 0.5)))
    }
}
