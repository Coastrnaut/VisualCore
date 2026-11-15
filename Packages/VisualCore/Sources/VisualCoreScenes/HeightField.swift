// HeightField.swift — feature 089 (A12-P01) T-A12-102 (FR-A12-101, FR-A12-103; research D2).
// A regular grid of heights sampled from a function of (x, z), with one extra ring of samples so that normals at the
// edge come from the function, not from the triangles: two fields that share an edge and are sampled from the same
// function agree there bit for bit. Builds an indexed mesh with y up, wound counter-clockwise seen from +y.
import VisualCoreMath

/// Heights on a regular grid of `columns` × `rows` cells in the x–z plane, with normals and a mesh.
///
/// Grid point (column i, row j) lies at x = `originX + i · cellSize`, z = `originZ + j · cellSize` and has the height
/// `height(x, z)` given at creation. Rows run along z. The field also keeps the samples one cell beyond every edge
/// (i = −1 and `columns + 1`, j = −1 and `rows + 1`), which `normal(column:row:)` uses for its central differences.
/// The struct holds only the sampled values (no closure), so it is `Sendable` and `Equatable`.
public struct HeightField: Sendable, Equatable {
    /// Allowed `columns` and `rows`: 1…512.
    public static let countRange: ClosedRange<Int> = 1...512

    /// Number of cells along x.
    public let columns: Int
    /// Number of cells along z.
    public let rows: Int
    /// Edge length of one square cell, finite and positive.
    public let cellSize: Double
    /// x of grid column 0.
    public let originX: Double
    /// z of grid row 0.
    public let originZ: Double

    /// Row-major samples of (columns + 3) × (rows + 3) points, row index j + 1 and column index i + 1 for grid point
    /// (i, j) with i in −1…columns + 1 and j in −1…rows + 1.
    private let samples: [Double]

    /// Throws MeshError.invalidInput for counts outside countRange, a non-positive or non-finite cell size, or a
    /// non-finite height.
    ///
    /// A non-finite origin is refused with `.invalidInput` too. `height` is called once for every grid point and for
    /// every point of the ring one cell beyond the grid, in row-major order, with (x, z) as described on the type.
    public init(columns: Int, rows: Int, cellSize: Double, originX: Double = 0, originZ: Double = 0,
                height: (Double, Double) -> Double) throws(MeshError) {
        guard Self.countRange.contains(columns) else { throw .invalidInput("columns \(columns) outside 1…512") }
        guard Self.countRange.contains(rows) else { throw .invalidInput("rows \(rows) outside 1…512") }
        guard cellSize.isFinite, cellSize > 0 else { throw .invalidInput("cell size \(cellSize) is not positive") }
        guard originX.isFinite, originZ.isFinite else { throw .invalidInput("origin is not finite") }
        var samples: [Double] = []
        samples.reserveCapacity((columns + 3) * (rows + 3))
        for j in -1...(rows + 1) {
            let z = originZ + Double(j) * cellSize
            for i in -1...(columns + 1) {
                let x = originX + Double(i) * cellSize
                let h = height(x, z)
                guard h.isFinite else { throw .invalidInput("height at x \(x), z \(z) is not finite") }
                samples.append(h)
            }
        }
        self.columns = columns
        self.rows = rows
        self.cellSize = cellSize
        self.originX = originX
        self.originZ = originZ
        self.samples = samples
    }

    /// The stored sample at (i, j) with i in −1…columns + 1 and j in −1…rows + 1.
    private func sample(_ i: Int, _ j: Int) -> Double { samples[(j + 1) * (columns + 3) + (i + 1)] }

    /// The grid height at (column, row); indices outside the grid are clamped to it.
    public func height(column: Int, row: Int) -> Double {
        sample(min(max(column, 0), columns), min(max(row, 0), rows))
    }

    /// The height at (x, z), interpolated bilinearly between the four surrounding grid points.
    ///
    /// Points outside the grid are clamped to its edge; a NaN coordinate is treated as the origin's coordinate. The
    /// value at a grid point's exact coordinates is that grid point's height.
    public func height(atX x: Double, z: Double) -> Double {
        func cell(_ value: Double, _ origin: Double, _ count: Int) -> (Int, Double) {
            var u = (value - origin) / cellSize
            if u.isNaN { u = 0 }
            u = min(max(u, 0), Double(count))
            let index = min(Int(u.rounded(.down)), count - 1)
            return (index, u - Double(index))
        }
        let (i, s) = cell(x, originX, columns), (j, t) = cell(z, originZ, rows)
        let bottom = sample(i, j) * (1 - s) + sample(i + 1, j) * s
        let top = sample(i, j + 1) * (1 - s) + sample(i + 1, j + 1) * s
        return bottom * (1 - t) + top * t
    }

    /// The unit normal at grid point (column, row) from the field including the ring one cell beyond the grid.
    ///
    /// The normal is `normalize(h(i − 1, j) − h(i + 1, j), 2 · cellSize, h(i, j − 1) − h(i, j + 1))`; indices outside
    /// the grid are clamped to it. Normalising uses a square root, which IEEE 754 rounds correctly, so the result is
    /// still bit-identical on every device.
    public func normal(column: Int, row: Int) -> Vec3 {
        let i = min(max(column, 0), columns), j = min(max(row, 0), rows)
        return Vec3(sample(i - 1, j) - sample(i + 1, j), 2 * cellSize, sample(i, j - 1) - sample(i, j + 1)).normalized
    }

    /// The field as a mesh: (columns + 1)(rows + 1) vertices and 6 · columns · rows indices.
    ///
    /// Vertex (i, j) has index `j · (columns + 1) + i`, position (x, height, z), the normal of `normal(column:row:)`
    /// and texture coordinate (i / columns, j / rows). Each cell gives two triangles wound counter-clockwise seen from
    /// +y.
    ///
    /// - Throws: `.budget` when the vertex or index count exceeds `budget`, checked before anything is built.
    public func mesh(budget: MeshBudget = .default) throws(MeshError) -> Mesh {
        let vertices = (columns + 1) * (rows + 1), indices = 6 * columns * rows
        if vertices > budget.maxVertices || indices > budget.maxIndices {
            throw .budget(vertices: vertices, indices: indices, budget: budget)
        }
        var mesh = Mesh(positions: [], normals: [], uvs: [], indices: [])
        mesh.positions.reserveCapacity(vertices)
        mesh.normals.reserveCapacity(vertices)
        mesh.uvs.reserveCapacity(vertices)
        mesh.indices.reserveCapacity(indices)
        for j in 0...rows {
            let z = originZ + Double(j) * cellSize
            for i in 0...columns {
                let x = originX + Double(i) * cellSize
                mesh.positions.append(Vec3(x, sample(i, j), z))
                mesh.normals.append(normal(column: i, row: j))
                mesh.uvs.append(Vec2(Double(i) / Double(columns), Double(j) / Double(rows)))
            }
        }
        let stride = UInt32(columns + 1)
        for j in 0..<UInt32(rows) {
            for i in 0..<UInt32(columns) {
                let a = j * stride + i, b = a + 1, c = a + stride, d = c + 1
                mesh.indices += [a, d, b, a, c, d]
            }
        }
        return mesh
    }
}
