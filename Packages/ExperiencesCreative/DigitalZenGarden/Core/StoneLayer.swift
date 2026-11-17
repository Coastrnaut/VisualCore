// StoneLayer — feature 147 (A20-P03) T-A20-302 (FR-A20-302, FR-A20-306; clarification Q1; data-model.md "StoneLayer";
// gap G-STONES). The stones of a garden rasterized on the CPU into one layer of cells (480 × 360 in the experience,
// the size of the drawn sand field): each cell holds the dome height of the stone that covers its centre and that
// stone's kind index + 1 (0 where no stone lies). The stones are drawn in ascending depth, so a higher stone overwrites
// a lower one where they overlap. The layer depends only on the stones, so the same garden gives the same layer in
// every view (clarification Q5). Each stone visits only the cells of its `StoneShape.bounds` (at most 24 stones of at
// most 0.16 × 2 tray widths). Pure arithmetic.
import Foundation
import VisualCoreMath

/// The stones of a garden rasterized into cells (see the file header).
public struct StoneLayer: Equatable, Sendable {
    /// The number of columns of the drawn layer (480, the drawn sand field's).
    public static let columns = 480
    /// The number of rows of the drawn layer (360, the drawn sand field's).
    public static let rows = 360

    /// The number of columns of this layer (1…1024).
    public let columns: Int
    /// The number of rows of this layer (1…1024).
    public let rows: Int
    /// The dome heights, row-major (`row * columns + column`), 0 where no stone lies.
    public private(set) var heights: [Float]
    /// The kind index + 1 of the stone on top of each cell, row-major; 0 where no stone lies.
    public private(set) var kinds: [UInt8]

    /// An empty layer of `columns` × `rows` cells (defaults 480 × 360), each count clamped into 1…1024.
    public init(columns: Int = StoneLayer.columns, rows: Int = StoneLayer.rows) {
        let width = min(max(columns, SandField.sizeRange.lowerBound), SandField.sizeRange.upperBound)
        let height = min(max(rows, SandField.sizeRange.lowerBound), SandField.sizeRange.upperBound)
        self.columns = width
        self.rows = height
        heights = [Float](repeating: 0, count: width * height)
        kinds = [UInt8](repeating: 0, count: width * height)
    }

    /// The layer of `stones` (any order; drawn in ascending depth) at `columns` × `rows` cells. A stone of an unknown
    /// kind is left out.
    public init(stones: [Stone], columns: Int = StoneLayer.columns, rows: Int = StoneLayer.rows) {
        self.init(columns: columns, rows: rows)
        let ordered = stones.enumerated().sorted { lhs, rhs in
            lhs.element.depth != rhs.element.depth ? lhs.element.depth < rhs.element.depth : lhs.offset < rhs.offset
        }
        for entry in ordered {
            if let shape = StoneShape(stone: entry.element) { draw(shape) }
        }
    }

    /// The centre of the cell at `column`, `row` in normalized tray coordinates: ((c + 0.5)/columns, (r + 0.5)/rows).
    public func cellCentre(column: Int, row: Int) -> Vec2 {
        Vec2((Double(column) + 0.5) / Double(columns), (Double(row) + 0.5) / Double(rows))
    }

    /// The height of the cell at `column`, `row` (both in range).
    public func height(column: Int, row: Int) -> Float { heights[row * columns + column] }

    /// The kind index + 1 of the cell at `column`, `row` (both in range); 0 where no stone lies.
    public func kind(column: Int, row: Int) -> UInt8 { kinds[row * columns + column] }

    /// Whether no cell holds a stone.
    public var isEmpty: Bool { !kinds.contains { $0 != 0 } }

    /// The number of cells that hold a stone.
    public var coveredCount: Int { kinds.reduce(0) { $0 + ($1 == 0 ? 0 : 1) } }

    /// Draws `shape` over the layer: every cell whose centre the shape contains takes its height and kind.
    mutating func draw(_ shape: StoneShape) {
        let box = shape.bounds
        let minColumn = max(0, Int((box.minX * Double(columns)).rounded(.down)) - 1)
        let maxColumn = min(columns - 1, Int((box.maxX * Double(columns)).rounded(.up)) + 1)
        let minRow = max(0, Int((box.minY * Double(rows)).rounded(.down)) - 1)
        let maxRow = min(rows - 1, Int((box.maxY * Double(rows)).rounded(.up)) + 1)
        guard minColumn <= maxColumn, minRow <= maxRow else { return }
        let kind = UInt8(shape.kindIndex + 1)
        for row in minRow...maxRow {
            for column in minColumn...maxColumn {
                let centre = cellCentre(column: column, row: row)
                let d = shape.radialDistance(centre)
                guard d <= 1 else { continue }
                let index = row * columns + column
                heights[index] = Float((1 - d * d).squareRoot() * shape.peak)
                kinds[index] = kind
            }
        }
    }
}
