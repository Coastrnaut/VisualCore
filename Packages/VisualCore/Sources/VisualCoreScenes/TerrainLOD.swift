// TerrainLOD — feature 218 (R02-F18) T-R02F18-003 (FR-R02F18-001…003; SC-R02F18-001, 002; clarifications Q1, Q2;
// research R1–R3).
//
// The terrain spans x, z in 0 … size as P × P pieces of C × C base cells of size s; piece (column c, row r) starts at
// (c · C · s, r · C · s). Level ℓ samples every 2^ℓ base cells, so a piece has C / 2^ℓ cells of size s · 2^ℓ.
// Selection (clarification Q1): with d the horizontal distance from the viewpoint to a piece's square (0 inside), the
// initial level is clamp(⌊log₂(d / D)⌋ + 1, 0, L − 1) (d < D gives 0). Then passes visit the pieces row by row and lower
// any piece that is more than one level coarser than a 4-neighbour to (finest neighbour level + 1), until a pass changes
// nothing. Budget (clarification Q2, research R3): the total Σ (C / 2^ℓ + 1)² must not exceed the vertex budget; a
// budget the all-coarsest tiling exceeds is refused with the vertices it needs; otherwise the distance per level is
// shrunk in steps, D · 2^(−t/4) for t = 0, 1, 2, …, and the first step whose balanced selection fits is used (in
// implementation, 2026-11-19: coarsening the farthest coarsenable piece first could leave a farther piece finer than a
// nearer one, while every step here is an ordinary selection, so detail still never rises with distance).
// Coordinates (research R2): every grid point is placed and sampled at (global index) · s, the global index being
// column · C + i · 2^ℓ, so a point shared by two pieces has the same coordinates bit for bit whatever s is. Stitching
// (clarification Q2, research R1): on each edge facing a neighbour one level coarser, every odd point becomes the mean
// of its two even neighbours along the edge (all three coordinates), which is the point of the coarser piece's straight
// edge; even points coincide with the coarser piece's points.
import Foundation
import VisualCoreMath

/// One piece of a terrain at its chosen level of detail.
public struct TerrainPiece: Sendable, Equatable {
    /// The piece's column, its index along x (0 … pieces − 1).
    public let column: Int
    /// The piece's row, its index along z (0 … pieces − 1).
    public let row: Int
    /// The level of detail ℓ (0 is the finest); the piece samples every 2^ℓ base cells.
    public let level: Int
    /// For the edges −z, +x, +z and −x in that order: whether the neighbour there exists and is exactly one level
    /// coarser, so that edge is stitched.
    public let coarserNeighbours: [Bool]
    /// x of the piece's first grid column, column · pieceCells · cellSize.
    public let originX: Double
    /// z of the piece's first grid row, row · pieceCells · cellSize.
    public let originZ: Double
    /// The piece's cell size, the base cell size · 2^level.
    public let cellSize: Double
    /// Cells per piece side at this level, pieceCells / 2^level.
    public let cells: Int

    /// The number of vertices of the piece's mesh, (cells + 1)².
    public var vertexCount: Int { (cells + 1) * (cells + 1) }
}

/// Chooses levels of detail for the pieces of a terrain and builds their crack-free meshes.
public enum TerrainLOD {
    /// The pieces of the terrain for a viewpoint, in row-major order (row = z index, then column = x index).
    ///
    /// Levels follow distance (one level per `levelDistance`), 4-neighbours differ by at most one level, and the total
    /// vertex count stays within `vertexBudget` by shrinking the distance per level in quarter-octave steps.
    ///
    /// - Throws: `.viewpoint` when the viewpoint is not finite; `.budget(needed)` when even the all-coarsest tiling
    ///   needs more vertices than the budget allows.
    public static func select(_ settings: TerrainSettings, viewpoint: Vec3) throws(TerrainError) -> [TerrainPiece] {
        guard viewpoint.isFinite else { throw .viewpoint }
        let p = settings.pieces, c = settings.pieceCells, s = settings.cellSize
        let coarsest = settings.levels - 1
        let side = Double(c) * s
        let count = p * p

        // Distances.
        var distance = [Double](repeating: 0, count: count)
        for r in 0..<p {
            for col in 0..<p {
                let minX = Double(col * c) * s, minZ = Double(r * c) * s
                let dx = max(minX - viewpoint.x, 0, viewpoint.x - (minX + side))
                let dz = max(minZ - viewpoint.z, 0, viewpoint.z - (minZ + side))
                distance[r * p + col] = (dx * dx + dz * dz).squareRoot()
            }
        }

        /// Initial levels for the distance per level `perLevel`, then balanced: any piece more than one level
        /// coarser than a neighbour is lowered to (finest neighbour + 1), passes row by row until nothing changes.
        func balancedLevels(_ perLevel: Double) -> [Int] {
            var level = [Int](repeating: 0, count: count)
            for index in 0..<count {
                level[index] = initialLevel(distance: distance[index], levelDistance: perLevel, coarsest: coarsest)
            }
            var changed = true
            while changed {
                changed = false
                for index in 0..<count {
                    let finest = neighbours(of: index, pieces: p).map { level[$0] }.min() ?? level[index]
                    if level[index] > finest + 1 {
                        level[index] = finest + 1
                        changed = true
                    }
                }
            }
            return level
        }

        // Budget: shrink the distance per level in quarter-octave steps until the selection fits.
        func vertices(_ l: Int) -> Int { let n = (c >> l) + 1; return n * n }
        let coarsestTotal = count * vertices(coarsest)
        guard coarsestTotal <= settings.vertexBudget else { throw .budget(coarsestTotal) }
        var step = 0
        var level = balancedLevels(settings.levelDistance)
        while level.reduce(0, { $0 + vertices($1) }) > settings.vertexBudget {
            step += 1
            let perLevel = settings.levelDistance * Foundation.exp2(-Double(step) / 4)
            // Once every piece is coarsest the tiling fits (checked above); a vanishing distance per level makes
            // every piece coarsest, so the loop ends.
            level = perLevel > 0 && perLevel.isNormal ? balancedLevels(perLevel)
                                                      : [Int](repeating: coarsest, count: count)
        }

        // Pieces with their coarser-facing edges.
        var result: [TerrainPiece] = []
        result.reserveCapacity(count)
        for r in 0..<p {
            for col in 0..<p {
                let index = r * p + col
                let own = level[index]
                let around: [(Int, Int)] = [(col, r - 1), (col + 1, r), (col, r + 1), (col - 1, r)]
                var coarser: [Bool] = []
                for (nc, nr) in around {
                    let inside = nc >= 0 && nc < p && nr >= 0 && nr < p
                    coarser.append(inside && level[nr * p + nc] == own + 1)
                }
                result.append(TerrainPiece(column: col, row: r, level: own, coarserNeighbours: coarser,
                                           originX: Double(col * c) * s, originZ: Double(r * c) * s,
                                           cellSize: s * Double(1 << own), cells: c >> own))
            }
        }
        return result
    }

    /// The mesh of one piece sampled from `height(x, z)`.
    ///
    /// The mesh has (cells + 1)² vertices in row-major order (row j along z, column i along x): position
    /// ((column · C + i · 2^ℓ) · s, height, (row · C + j · 2^ℓ) · s) on the global grid, the normal of ``HeightField/normal(column:row:)`` and
    /// texture coordinate (i / cells, j / cells); y is up and each cell gives two triangles wound counter-clockwise seen
    /// from +y, as in ``HeightField/mesh(budget:)``. On every edge whose ``TerrainPiece/coarserNeighbours`` flag is set,
    /// each odd point becomes the mean (a + b) / 2 of its two even neighbours along that edge, all three coordinates.
    ///
    /// - Throws: the ``MeshError`` of ``HeightField`` sampling (for example a non-finite height), or `.budget` when the
    ///   mesh exceeds ``MeshBudget/default``.
    public static func mesh(for piece: TerrainPiece,
                            height: (Double, Double) -> Double) throws(MeshError) -> Mesh {
        let n = piece.cells
        let spacing = 1 << piece.level
        let base = piece.cellSize / Double(spacing)   // exact: a division by a power of two
        let firstX = piece.column * n * spacing, firstZ = piece.row * n * spacing
        // HeightField asks for originX + i · cellSize; the sample is taken at the global grid coordinate instead, so
        // neighbouring pieces sample a shared point at exactly the same (x, z).
        let field = try HeightField(columns: n, rows: n, cellSize: piece.cellSize, originX: piece.originX,
                                    originZ: piece.originZ) { x, z in
            let i = Int(((x - piece.originX) / piece.cellSize).rounded())
            let j = Int(((z - piece.originZ) / piece.cellSize).rounded())
            return height(Double(firstX + i * spacing) * base, Double(firstZ + j * spacing) * base)
        }
        var mesh = try field.mesh(budget: .default)
        let stride = n + 1
        for j in 0...n {
            for i in 0...n {
                let v = j * stride + i
                mesh.positions[v].x = Double(firstX + i * spacing) * base
                mesh.positions[v].z = Double(firstZ + j * spacing) * base
            }
        }
        func stitch(_ flagged: Bool, _ at: (Int) -> Int) {
            guard flagged else { return }
            for k in Swift.stride(from: 1, to: n, by: 2) {
                let a = mesh.positions[at(k - 1)], b = mesh.positions[at(k + 1)]
                mesh.positions[at(k)] = Vec3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
            }
        }
        let flags = piece.coarserNeighbours
        stitch(flags[0]) { k in k }                     // −z: row 0
        stitch(flags[1]) { k in k * stride + n }        // +x: column n
        stitch(flags[2]) { k in n * stride + k }        // +z: row n
        stitch(flags[3]) { k in k * stride }            // −x: column 0
        return mesh
    }

    /// clamp(⌊log₂(d / D)⌋ + 1, 0, coarsest), with d < D giving 0.
    static func initialLevel(distance d: Double, levelDistance: Double, coarsest: Int) -> Int {
        let ratio = max(d, 1e-9) / levelDistance
        guard ratio >= 1 else { return 0 }
        guard ratio.isFinite else { return coarsest }  // a distance that overflowed is farther than any level
        let l = Int(log2(ratio).rounded(.down)) + 1
        return min(max(l, 0), coarsest)
    }

    /// The indices of the existing 4-neighbours of a row-major piece index.
    static func neighbours(of index: Int, pieces p: Int) -> [Int] {
        let r = index / p, col = index % p
        var result: [Int] = []
        if r > 0 { result.append(index - p) }
        if col < p - 1 { result.append(index + 1) }
        if r < p - 1 { result.append(index + p) }
        if col > 0 { result.append(index - 1) }
        return result
    }
}
