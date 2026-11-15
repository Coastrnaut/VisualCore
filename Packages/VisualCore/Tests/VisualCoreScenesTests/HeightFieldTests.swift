// HeightFieldTests — feature 089 (A12-P01) T-A12-102 (FR-A12-101, FR-A12-103; SC-A12-102).
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct HeightFieldTests {
    /// The polynomial of the mesh digest fixture.
    static func polynomial(_ x: Double, _ z: Double) -> Double { 0.25 * x * x - 0.5 * x * z + 0.125 * z * z * z + 0.1 }

    /// A rolling function made of fractal noise, used for the seam test.
    static let rolling = FractalNoise2D(seed: 21, octaves: 4, frequency: 0.6)!

    /// True when creating the field throws `.invalidInput`.
    static func refused(_ columns: Int, _ rows: Int, _ cellSize: Double,
                        height: (Double, Double) -> Double = { _, _ in 0 }) -> Bool {
        do {
            _ = try HeightField(columns: columns, rows: rows, cellSize: cellSize, height: height)
            return false
        } catch {
            if case .invalidInput = error { return true }
            return false
        }
    }

    @Test func refusesInvalidInput() {
        #expect(Self.refused(0, 4, 1))
        #expect(Self.refused(4, 513, 1))
        #expect(Self.refused(513, 4, 1))
        #expect(Self.refused(4, 4, 0))
        #expect(Self.refused(4, 4, -1))
        #expect(Self.refused(4, 4, .infinity))
        #expect(Self.refused(4, 4, .nan))
        #expect(Self.refused(4, 4, 1) { x, _ in x > 2 ? .nan : 0 })
        // A non-finite height in the ring beyond the grid is refused too.
        #expect(Self.refused(4, 4, 1) { x, _ in x < 0 ? .infinity : 0 })
        #expect(throws: Never.self) { try HeightField(columns: 1, rows: 512, cellSize: 1) { _, _ in 0 } }
        #expect(HeightField.countRange == 1...512)
    }

    @Test func gridHeightsEqualTheFunction() throws {
        let field = try HeightField(columns: 6, rows: 5, cellSize: 0.25, originX: 2, originZ: -1,
                                    height: Self.polynomial)
        for j in 0...5 {
            for i in 0...6 {
                let x = 2 + Double(i) * 0.25, z = -1 + Double(j) * 0.25
                #expect(field.height(column: i, row: j) == Self.polynomial(x, z))
            }
        }
        #expect(field.height(column: -3, row: 9) == field.height(column: 0, row: 5))
        #expect(field.height(column: 40, row: -1) == field.height(column: 6, row: 0))
    }

    @Test func bilinearIsExactAtGridPointsAndClampedOutside() throws {
        let field = try HeightField(columns: 4, rows: 3, cellSize: 0.5, originX: -1, originZ: -0.75,
                                    height: Self.polynomial)
        for j in 0...3 {
            for i in 0...4 {
                let x = -1 + Double(i) * 0.5, z = -0.75 + Double(j) * 0.5
                #expect(field.height(atX: x, z: z) == field.height(column: i, row: j))
            }
        }
        #expect(field.height(atX: -50, z: -50) == field.height(column: 0, row: 0))
        #expect(field.height(atX: 50, z: 50) == field.height(column: 4, row: 3))
        #expect(field.height(atX: 50, z: -0.75) == field.height(column: 4, row: 0))
        #expect(field.height(atX: .nan, z: -0.75) == field.height(column: 0, row: 0))
        // Midpoint of a cell edge is the average of its two ends.
        let mid = field.height(atX: -0.75, z: -0.75)
        let expected = 0.5 * field.height(column: 0, row: 0) + 0.5 * field.height(column: 1, row: 0)
        #expect(abs(mid - expected) < 1e-15)
    }

    @Test func flatFieldHasUpNormals() throws {
        let field = try HeightField(columns: 3, rows: 3, cellSize: 0.7) { _, _ in 0.4 }
        for j in 0...3 {
            for i in 0...3 { #expect(field.normal(column: i, row: j) == Vec3(0, 1, 0)) }
        }
    }

    @Test func zSlopeGivesTheAnalyticNormal() throws {
        let slope = 0.5
        let field = try HeightField(columns: 4, rows: 4, cellSize: 0.25) { _, z in slope * z }
        let expected = Vec3(0, 1, -slope).normalized
        for j in 0...4 {
            for i in 0...4 {
                let n = field.normal(column: i, row: j)
                #expect((n - expected).length < 1e-12)
            }
        }
    }

    @Test func fieldsSharingAnEdgeAgreeBitForBit() throws {
        let cell = 0.1875, columns = 8, rows = 6
        let f: (Double, Double) -> Double = { x, z in Self.rolling.value(x: x, y: z) }
        let left = try HeightField(columns: columns, rows: rows, cellSize: cell, height: f)
        let right = try HeightField(columns: columns, rows: rows, cellSize: cell, originX: Double(columns) * cell,
                                    height: f)
        for j in 0...rows {
            #expect(left.height(column: columns, row: j).bitPattern == right.height(column: 0, row: j).bitPattern)
            let a = left.normal(column: columns, row: j), b = right.normal(column: 0, row: j)
            #expect(a.x.bitPattern == b.x.bitPattern && a.y.bitPattern == b.y.bitPattern)
            #expect(a.z.bitPattern == b.z.bitPattern)
        }
    }

    @Test func meshCountsAndCounterClockwiseWinding() throws {
        let columns = 5, rows = 3
        let field = try HeightField(columns: columns, rows: rows, cellSize: 0.5, originX: 1, originZ: 2) { _, _ in 0 }
        let mesh = try field.mesh()
        #expect(mesh.positions.count == (columns + 1) * (rows + 1))
        #expect(mesh.normals.count == mesh.positions.count && mesh.uvs.count == mesh.positions.count)
        #expect(mesh.indices.count == 6 * columns * rows)
        for k in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a = mesh.positions[Int(mesh.indices[k])], b = mesh.positions[Int(mesh.indices[k + 1])]
            let c = mesh.positions[Int(mesh.indices[k + 2])]
            #expect((b - a).cross(c - a).y > 0)
        }
        #expect(mesh.positions[0] == Vec3(1, 0, 2))
        #expect(mesh.positions[mesh.positions.count - 1] == Vec3(3.5, 0, 3.5))
        #expect(mesh.uvs[0] == Vec2(0, 0) && mesh.uvs[mesh.uvs.count - 1] == Vec2(1, 1))
        #expect(mesh.validate().problems.isEmpty)
        let rolling = try HeightField(columns: 6, rows: 4, cellSize: 0.3) { x, z in Self.rolling.value(x: x, y: z) }
        #expect(try rolling.mesh().validate().problems.isEmpty)
    }

    @Test func budgetRefusedBeforeBuilding() throws {
        let field = try HeightField(columns: 10, rows: 10, cellSize: 1) { _, _ in 0 }
        let small = MeshBudget(maxVertices: 120, maxIndices: 10_000)
        #expect(throws: MeshError.budget(vertices: 121, indices: 600, budget: small)) { try field.mesh(budget: small) }
        let fewIndices = MeshBudget(maxVertices: 1_000, maxIndices: 599)
        #expect(throws: MeshError.budget(vertices: 121, indices: 600, budget: fewIndices)) {
            try field.mesh(budget: fewIndices)
        }
        #expect(try field.mesh(budget: MeshBudget(maxVertices: 121, maxIndices: 600)).indices.count == 600)
    }

    @Test func equalInputsGiveEqualFields() throws {
        let a = try HeightField(columns: 3, rows: 2, cellSize: 0.5, height: Self.polynomial)
        let b = try HeightField(columns: 3, rows: 2, cellSize: 0.5, height: Self.polynomial)
        let c = try HeightField(columns: 3, rows: 2, cellSize: 0.5) { x, z in Self.polynomial(x, z) + 1 }
        #expect(a == b)
        #expect(a != c)
    }

    /// Committed digest of a 4 × 3 field (cell 0.5, origin (−1, −0.75)) of the polynomial.
    @Test func meshDigestMatchesCommittedFixture() throws {
        let field = try HeightField(columns: 4, rows: 3, cellSize: 0.5, originX: -1, originZ: -0.75,
                                    height: Self.polynomial)
        #expect(try field.mesh().digest == "2e1e3f3c956e84d579fe6e89360a2ef6c11fc234df7c9f82a2631f6b3b90d34c")
    }

    /// The existing plane generator is untouched by this feature (its digest recorded before the change).
    @Test func planeDigestUnchanged() {
        #expect(Mesh.plane().digest == "32bcb87447701ba3f9b02e11897f98ff6e9c4b6de2347cdd59a3b77b051a0cca")
        let subdivided = "06376fb6b1c16898ac975e3bb6309f2bb75ed93e069f7dcd7dcd527dc094d3fb"
        #expect(Mesh.plane(subdivisions: 4).digest == subdivided)
    }
}
