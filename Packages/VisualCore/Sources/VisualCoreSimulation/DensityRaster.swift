// DensityRaster — feature 220 (R02-F20) T-R02F20-004 (FR-R02F20-004; SC-R02F20-004; clarification Q5; research R6).
// A density picture of a swarm: each agent with a finite position inside the closed rectangle spreads weight 1
// bilinearly over the four cells whose centres surround it (cell centres at (i + ½, j + ½) in cell units), with cell
// indices clamped to the grid so weight past an edge folds onto the edge cells. The total therefore equals the
// in-area agent count. Non-finite and outside agents are skipped. `fieldGrid()` hands the cells to the existing
// field passes as a one-channel `FieldGrid` in the same row-major, bottom-row-first order.
import Foundation
import VisualCoreMath

/// A width × height grid of agent density over a rectangle.
public struct DensityRaster: Sendable, Equatable {
    /// The largest allowed side, in cells.
    public static let maxSide = 1_024
    /// The largest allowed number of cells.
    public static let maxCells = 1_048_576

    /// Cells per row (1 … 1,024).
    public let width: Int
    /// Rows (1 … 1,024).
    public let height: Int
    /// The rectangle the raster covers; cell (i, j) covers the i-th column and j-th row of an even split of it, with
    /// row 0 at `minY`.
    public let bounds: SteeringBounds
    /// `width · height` density values, row-major: cell (x, y) is at index `y · width + x`, y = 0 the row at `minY`.
    public private(set) var cells: [Double]

    /// An empty raster of `width` × `height` cells over `bounds`.
    ///
    /// - Throws: `.rasterSize` unless each side is 1 … 1,024 and `width · height` ≤ 1,048,576; `.bounds` unless
    ///   `bounds.isValid`.
    public init(width: Int, height: Int, bounds: SteeringBounds) throws(SwarmError) {
        guard (1...Self.maxSide).contains(width), (1...Self.maxSide).contains(height),
              width * height <= Self.maxCells else { throw .rasterSize }
        guard bounds.isValid else { throw .bounds }
        self.width = width
        self.height = height
        self.bounds = bounds
        cells = Array(repeating: 0, count: width * height)
    }

    /// Sets every cell to 0.
    public mutating func clear() {
        for index in cells.indices { cells[index] = 0 }
    }

    /// Adds the bilinear weight of every agent whose position is finite and inside the closed rectangle
    /// (minX ≤ x ≤ maxX, minY ≤ y ≤ maxY); each such agent adds a total of 1. Other agents are skipped.
    public mutating func splat(_ agents: [SteeringAgent]) {
        for agent in agents {
            let p = agent.position
            guard p.isFinite, p.x >= bounds.minX, p.x <= bounds.maxX, p.y >= bounds.minY, p.y <= bounds.maxY else {
                continue
            }
            let (x0, x1, fx) = Self.split(p.x, min: bounds.minX, max: bounds.maxX, count: width)
            let (y0, y1, fy) = Self.split(p.y, min: bounds.minY, max: bounds.maxY, count: height)
            let gx = 1 - fx
            let gy = 1 - fy
            cells[y0 * width + x0] += gx * gy
            cells[y0 * width + x1] += fx * gy
            cells[y1 * width + x0] += gx * fy
            cells[y1 * width + x1] += fx * fy
        }
    }

    /// A raster of `width` × `height` cells over `bounds` with `agents` splatted into it.
    ///
    /// - Throws: the refusals of ``init(width:height:bounds:)``.
    public static func of(_ agents: [SteeringAgent], bounds: SteeringBounds, width: Int,
                          height: Int) throws(SwarmError) -> DensityRaster {
        var raster = try DensityRaster(width: width, height: height, bounds: bounds)
        raster.splat(agents)
        return raster
    }

    /// A raster of `width` × `height` cells over the swarm's bounds with its agents splatted into it.
    ///
    /// - Throws: `.rasterSize` for a size outside the limits (the swarm's bounds are always valid).
    public static func of(_ swarm: Swarm, width: Int, height: Int) throws(SwarmError) -> DensityRaster {
        try of(swarm.agents, bounds: swarm.bounds, width: width, height: height)
    }

    /// The sum of all cells: the number of in-area agents splatted since the last ``clear()``.
    public var total: Double {
        var sum = 0.0
        for value in cells { sum += value }
        return sum
    }

    /// The cells as a one-channel `FieldGrid` of the same size and order (cell (x, y) at `y · width + x`, y = 0 the
    /// bottom row at `minY`, which is `FieldGrid`'s GL order), each value converted to `Float`.
    public func fieldGrid() -> FieldGrid {
        var values: [Float] = []
        values.reserveCapacity(cells.count)
        for value in cells { values.append(Float(value)) }
        guard let grid = FieldGrid(width: width, height: height, channels: 1, values: values) else {
            preconditionFailure("DensityRaster sizes are always valid FieldGrid sizes")
        }
        return grid
    }

    /// The two clamped cell indices around coordinate `v` on an axis of `count` cells over `min … max`, and the
    /// weight of the upper one. `v` lies in `min … max`.
    private static func split(_ v: Double, min lower: Double, max upper: Double,
                              count: Int) -> (Int, Int, Double) {
        var t = (v - lower) / (upper - lower)
        if !t.isFinite { t = (v / 2 - lower / 2) / (upper / 2 - lower / 2) }   // spans past Double.greatestFiniteMagnitude
        if !t.isFinite { t = 0.5 }
        t = Swift.min(Swift.max(t, 0), 1)
        let u = t * Double(count) - 0.5
        let base = u.rounded(.down)
        let fraction = Swift.min(Swift.max(u - base, 0), 1)
        let i = Int(base)
        let i0 = Swift.min(Swift.max(i, 0), count - 1)
        let i1 = Swift.min(Swift.max(i + 1, 0), count - 1)
        return (i0, i1, fraction)
    }
}
