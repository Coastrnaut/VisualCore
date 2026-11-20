// TerrainLODTests — feature 218 (R02-F18) T-R02F18-003 (FR-R02F18-001…003; SC-R02F18-001, 002).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// A small deterministic generator (SplitMix64) for seeded viewpoints and budgets.
fileprivate struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z: UInt64 = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// A double in lower ..< upper.
    mutating func double(_ lower: Double, _ upper: Double) -> Double {
        let unit: Double = Double(next() >> 11) / Double(UInt64(1) << 53)
        return lower + (upper - lower) * unit
    }
    /// An integer in lower ... upper.
    mutating func int(_ lower: Int, _ upper: Int) -> Int {
        let span: UInt64 = UInt64(upper - lower + 1)
        return lower + Int(next() % span)
    }
}

@Suite struct TerrainLODTests {
    /// The horizontal distance from a viewpoint to a piece's square, computed independently of the source.
    static func distance(_ piece: TerrainPiece, _ settings: TerrainSettings, _ v: Vec3) -> Double {
        let side: Double = Double(settings.pieceCells) * settings.cellSize
        let minX: Double = Double(piece.column * settings.pieceCells) * settings.cellSize
        let minZ: Double = Double(piece.row * settings.pieceCells) * settings.cellSize
        var dx: Double = 0
        if v.x < minX { dx = minX - v.x } else if v.x > minX + side { dx = v.x - (minX + side) }
        var dz: Double = 0
        if v.z < minZ { dz = minZ - v.z } else if v.z > minZ + side { dz = v.z - (minZ + side) }
        return (dx * dx + dz * dz).squareRoot()
    }

    /// The vertex indices of one edge (0 −z, 1 +x, 2 +z, 3 −x) of a piece mesh, in increasing along-edge order.
    static func edge(_ side: Int, cells n: Int) -> [Int] {
        let stride: Int = n + 1
        var result: [Int] = []
        for k in 0...n {
            switch side {
            case 0: result.append(k)
            case 1: result.append(k * stride + n)
            case 2: result.append(n * stride + k)
            default: result.append(k * stride)
            }
        }
        return result
    }

    /// The 8 × 8 terrain of 16-cell pieces used by the seeded tests.
    static func settings(budget: Int, cellSize: Double = 1) throws -> TerrainSettings {
        try TerrainSettings(pieces: 8, pieceCells: 16, cellSize: cellSize, levels: 4, levelDistance: 20,
                            vertexBudget: budget)
    }

    /// A seeded budget: the default for three viewpoints of four, otherwise a tight one above the coarsest tiling.
    fileprivate static func budget(_ random: inout SplitMix, index: Int) -> Int {
        // Coarsest tiling: 64 · (16 / 8 + 1)² = 576 vertices; finest: 64 · 17² = 18,496.
        index % 4 == 3 ? random.int(576, 6_000) : TerrainSettings.defaultVertexBudget
    }

    @Test func seededViewpointsKeepTheRules() throws {
        var random: SplitMix = SplitMix(seed: 2_018)
        for index in 0..<200 {
            let budget: Int = Self.budget(&random, index: index)
            let settings: TerrainSettings = try Self.settings(budget: budget)
            let viewpoint: Vec3 = Vec3(random.double(-64, 192), random.double(0, 40), random.double(-64, 192))
            let pieces: [TerrainPiece] = try TerrainLOD.select(settings, viewpoint: viewpoint)
            let again: [TerrainPiece] = try TerrainLOD.select(settings, viewpoint: viewpoint)
            #expect(pieces == again)
            #expect(pieces.count == 64)

            var total: Int = 0
            var distances: [Double] = []
            for (k, piece) in pieces.enumerated() {
                #expect(piece.row == k / 8 && piece.column == k % 8)
                #expect(piece.level >= 0 && piece.level < 4)
                #expect(piece.cells == 16 >> piece.level)
                #expect(piece.cellSize == Double(1 << piece.level))
                #expect(piece.vertexCount == (piece.cells + 1) * (piece.cells + 1))
                total += piece.vertexCount
                distances.append(Self.distance(piece, settings, viewpoint))
            }
            #expect(total <= budget)

            // Neighbours within one level, and the coarser-neighbour flags match the levels.
            for piece in pieces {
                let around: [(Int, Int)] = [(piece.column, piece.row - 1), (piece.column + 1, piece.row),
                                            (piece.column, piece.row + 1), (piece.column - 1, piece.row)]
                for (side, (c, r)) in around.enumerated() {
                    if c < 0 || c >= 8 || r < 0 || r >= 8 {
                        #expect(piece.coarserNeighbours[side] == false)
                        continue
                    }
                    let other: TerrainPiece = pieces[r * 8 + c]
                    #expect(abs(other.level - piece.level) <= 1)
                    #expect(piece.coarserNeighbours[side] == (other.level == piece.level + 1))
                }
            }

            // Detail never rises with distance except where the one-level rule refines a farther piece next to a
            // finer one: every pair (a nearer, b farther, a coarser) has b below its own distance level. A binding
            // budget gives the selection of the first distance per level D · 2^(−t/4) whose total fits (clarification
            // Q2 as amended in implementation), found here by trying t = 0, 1, 2, … with the default budget.
            let free: TerrainSettings = try Self.settings(budget: TerrainSettings.defaultVertexBudget)
            let unbound: [TerrainPiece] = try TerrainLOD.select(free, viewpoint: viewpoint)
            var expected: [TerrainPiece] = unbound
            var perLevel: Double = 20
            var step: Int = 0
            while Self.total(expected) > budget && step < 400 {
                step += 1
                perLevel = 20 * exp2(-Double(step) / 4)
                let scaled: TerrainSettings = try TerrainSettings(pieces: 8, pieceCells: 16, cellSize: 1, levels: 4,
                                                                  levelDistance: perLevel)
                expected = try TerrainLOD.select(scaled, viewpoint: viewpoint)
            }
            for k in 0..<64 {
                #expect(pieces[k].level == expected[k].level, "viewpoint \(index) piece \(k)")
                #expect(pieces[k].level >= unbound[k].level)
            }
            #expect(Self.unexplainedInversions(pieces, distances, perLevel: perLevel) == 0, "viewpoint \(index)")
            if budget == TerrainSettings.defaultVertexBudget { #expect(Self.inversions(pieces, distances) == 0) }
        }
    }

    /// Inversions (a strictly nearer than b but coarser) where b is not below its own distance level, that is, not
    /// explained by the one-level rule refining b.
    static func unexplainedInversions(_ pieces: [TerrainPiece], _ distances: [Double], perLevel: Double) -> Int {
        var count: Int = 0
        for a in 0..<pieces.count {
            for b in 0..<pieces.count where distances[a] < distances[b] && pieces[a].level > pieces[b].level {
                let own: Int = TerrainLOD.initialLevel(distance: distances[b], levelDistance: perLevel, coarsest: 3)
                if pieces[b].level >= own { count += 1 }
            }
        }
        return count
    }

    /// The total vertex count of a selection.
    static func total(_ pieces: [TerrainPiece]) -> Int {
        var sum: Int = 0
        for piece in pieces { sum += piece.vertexCount }
        return sum
    }

    /// The pairs (a, b) with a strictly nearer than b but coarser.
    static func inversions(_ pieces: [TerrainPiece], _ distances: [Double]) -> Int {
        var count: Int = 0
        for a in 0..<pieces.count {
            for b in 0..<pieces.count where distances[a] < distances[b] && pieces[a].level > pieces[b].level {
                count += 1
            }
        }
        return count
    }

    @Test func seededSelectionsHaveCrackFreeEdges() throws {
        var random: SplitMix = SplitMix(seed: 2_018 ^ 0x5EED)
        for index in 0..<50 {
            let noise: GradientNoise2D = GradientNoise2D(seed: UInt64(2_018 + index))
            let height: (Double, Double) -> Double = { x, z in 6 * noise.value(x: x * 0.07, y: z * 0.07) }
            let budget: Int = Self.budget(&random, index: index)
            let settings: TerrainSettings = try Self.settings(budget: budget, cellSize: 0.1)
            let viewpoint: Vec3 = Vec3(random.double(-32, 96), 10, random.double(-32, 96))
            let pieces: [TerrainPiece] = try TerrainLOD.select(settings, viewpoint: viewpoint)
            var meshes: [Mesh] = []
            for piece in pieces { meshes.append(try TerrainLOD.mesh(for: piece, height: height)) }

            for r in 0..<8 {
                for c in 0..<8 {
                    let a: Int = r * 8 + c
                    // +x neighbour (shared edge: a's side 1, b's side 3) and +z neighbour (a's side 2, b's side 0).
                    var pairs: [(Int, Int, Int)] = []
                    if c < 7 { pairs.append((a + 1, 1, 3)) }
                    if r < 7 { pairs.append((a + 8, 2, 0)) }
                    for (b, sideA, sideB) in pairs {
                        let fine: Int = pieces[a].level <= pieces[b].level ? a : b
                        let coarse: Int = fine == a ? b : a
                        let fineSide: Int = fine == a ? sideA : sideB
                        let coarseSide: Int = fine == a ? sideB : sideA
                        let fineEdge: [Int] = Self.edge(fineSide, cells: pieces[fine].cells)
                        let coarseEdge: [Int] = Self.edge(coarseSide, cells: pieces[coarse].cells)
                        let finePositions: [Vec3] = meshes[fine].positions
                        let coarsePositions: [Vec3] = meshes[coarse].positions
                        if pieces[fine].level == pieces[coarse].level {
                            for k in 0..<fineEdge.count {
                                #expect(finePositions[fineEdge[k]] == coarsePositions[coarseEdge[k]])
                            }
                            continue
                        }
                        #expect(fineEdge.count == 2 * coarseEdge.count - 1)
                        for k in 0..<fineEdge.count {
                            let point: Vec3 = finePositions[fineEdge[k]]
                            if k % 2 == 0 {
                                #expect(point == coarsePositions[coarseEdge[k / 2]], "selection \(index)")
                            } else {
                                let p: Vec3 = coarsePositions[coarseEdge[k / 2]]
                                let q: Vec3 = coarsePositions[coarseEdge[k / 2 + 1]]
                                let mean: Vec3 = Vec3((p.x + q.x) / 2, (p.y + q.y) / 2, (p.z + q.z) / 2)
                                #expect(point == mean, "selection \(index)")
                            }
                        }
                    }
                }
            }
        }
    }

    @Test func pieceMeshesEqualAHeightFieldAwayFromStitchedPoints() throws {
        let noise: GradientNoise2D = GradientNoise2D(seed: 2_018)
        let height: (Double, Double) -> Double = { x, z in 4 * noise.value(x: x * 0.1, y: z * 0.1) }
        let settings: TerrainSettings = try Self.settings(budget: TerrainSettings.defaultVertexBudget)
        let pieces: [TerrainPiece] = try TerrainLOD.select(settings, viewpoint: Vec3(10, 5, 10))
        var stitchedPieces: Int = 0
        for piece in pieces {
            let mesh: Mesh = try TerrainLOD.mesh(for: piece, height: height)
            let field: HeightField = try HeightField(columns: piece.cells, rows: piece.cells, cellSize: piece.cellSize,
                                                     originX: piece.originX, originZ: piece.originZ, height: height)
            let reference: Mesh = try field.mesh()
            #expect(mesh.positions.count == piece.vertexCount)
            #expect(mesh.indices == reference.indices)
            #expect(mesh.normals == reference.normals)
            #expect(mesh.uvs == reference.uvs)
            var stitched: Set<Int> = []
            for side in 0..<4 where piece.coarserNeighbours[side] {
                let edge: [Int] = Self.edge(side, cells: piece.cells)
                for k in Swift.stride(from: 1, to: edge.count - 1, by: 2) { stitched.insert(edge[k]) }
            }
            if !stitched.isEmpty { stitchedPieces += 1 }
            for v in 0..<mesh.positions.count {
                let p: Vec3 = mesh.positions[v], q: Vec3 = reference.positions[v]
                #expect(p.x == q.x && p.z == q.z)
                if !stitched.contains(v) { #expect(p.y == q.y) }
            }
            // Counter-clockwise seen from +y: every triangle's normal points up.
            for t in 0..<(mesh.indices.count / 3) {
                let a: Vec3 = mesh.positions[Int(mesh.indices[3 * t])]
                let b: Vec3 = mesh.positions[Int(mesh.indices[3 * t + 1])]
                let c: Vec3 = mesh.positions[Int(mesh.indices[3 * t + 2])]
                let u: Vec3 = b - a, w: Vec3 = c - a
                let upward: Double = u.z * w.x - u.x * w.z
                #expect(upward > 0)
            }
        }
        #expect(stitchedPieces > 0)
    }

    @Test func onePieceTerrainIsOneFinePiece() throws {
        let settings: TerrainSettings = try TerrainSettings(pieces: 1, pieceCells: 8, cellSize: 1, levels: 3,
                                                            levelDistance: 4)
        let pieces: [TerrainPiece] = try TerrainLOD.select(settings, viewpoint: Vec3(4, 3, 4))
        #expect(pieces.count == 1)
        #expect(pieces[0].level == 0 && pieces[0].cells == 8 && pieces[0].cellSize == 1)
        #expect(pieces[0].coarserNeighbours == [false, false, false, false])
        #expect(pieces[0].vertexCount == 81)
    }

    @Test func farViewpointGivesAllCoarsest() throws {
        let settings: TerrainSettings = try Self.settings(budget: TerrainSettings.defaultVertexBudget)
        let viewpoints: [Vec3] = [Vec3(1e6, 0, -1e6), Vec3(-5_000, 100, 64), Vec3(1e300, 0, 1e300)]
        for viewpoint in viewpoints {
            let pieces: [TerrainPiece] = try TerrainLOD.select(settings, viewpoint: viewpoint)
            for piece in pieces {
                #expect(piece.level == 3 && piece.cells == 2)
                #expect(piece.coarserNeighbours == [false, false, false, false])
            }
        }
    }

    @Test func budgetBelowTheCoarsestTilingIsRefused() throws {
        let settings: TerrainSettings = try Self.settings(budget: 575)
        #expect(throws: TerrainError.budget(576)) {
            _ = try TerrainLOD.select(settings, viewpoint: Vec3(0, 0, 0))
        }
        // Exactly the coarsest tiling fits and gives every piece the coarsest level.
        let exact: TerrainSettings = try Self.settings(budget: 576)
        let pieces: [TerrainPiece] = try TerrainLOD.select(exact, viewpoint: Vec3(64, 0, 64))
        for piece in pieces { #expect(piece.level == 3) }
        #expect(TerrainError.budget(576).reasonCode == "r2-f18.budget")
    }

    @Test func nonFiniteViewpointIsRefused() throws {
        let settings: TerrainSettings = try Self.settings(budget: TerrainSettings.defaultVertexBudget)
        let viewpoints: [Vec3] = [Vec3(.nan, 0, 0), Vec3(0, .infinity, 0), Vec3(0, 0, -.infinity)]
        for viewpoint in viewpoints {
            #expect(throws: TerrainError.viewpoint) { _ = try TerrainLOD.select(settings, viewpoint: viewpoint) }
        }
    }

    @Test func initialLevelFollowsDistance() {
        #expect(TerrainLOD.initialLevel(distance: 0, levelDistance: 20, coarsest: 3) == 0)
        #expect(TerrainLOD.initialLevel(distance: 19.999, levelDistance: 20, coarsest: 3) == 0)
        #expect(TerrainLOD.initialLevel(distance: 20, levelDistance: 20, coarsest: 3) == 1)
        #expect(TerrainLOD.initialLevel(distance: 39.9, levelDistance: 20, coarsest: 3) == 1)
        #expect(TerrainLOD.initialLevel(distance: 40, levelDistance: 20, coarsest: 3) == 2)
        #expect(TerrainLOD.initialLevel(distance: 80, levelDistance: 20, coarsest: 3) == 3)
        #expect(TerrainLOD.initialLevel(distance: 1e9, levelDistance: 20, coarsest: 3) == 3)
    }

    @Test func nonFiniteHeightIsRefusedByTheMesh() throws {
        let settings: TerrainSettings = try Self.settings(budget: TerrainSettings.defaultVertexBudget)
        let pieces: [TerrainPiece] = try TerrainLOD.select(settings, viewpoint: Vec3(0, 0, 0))
        #expect(throws: MeshError.self) {
            _ = try TerrainLOD.mesh(for: pieces[0], height: { _, _ in .nan })
        }
    }
}
