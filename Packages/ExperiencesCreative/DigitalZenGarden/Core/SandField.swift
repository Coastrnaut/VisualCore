// SandField — feature 145 (A20-P01) T-A20-106 (FR-A20-104; clarifications Q1, Q3, Q4). The reference sand field of the
// small tray: 160 × 120 heights in units of the deepest groove, zero at rest, rebuilt on the CPU by replaying the rake
// strokes in order (later strokes overwrite earlier ones). The replay is exact and deterministic; it is the reference
// the history compares against within 1e-6 per cell. Pure arithmetic.
//
// Feature 146 (A20-P02) T-A20-203 (FR-A20-202, FR-A20-203; clarification Q1; data-model.md "SandField"): a field has a
// size, `init(columns:rows:)` with columns and rows in 1…1024 ("defaults 160 × 120"); the experience draws a 480 × 360
// field, where the fine rake's tine period is about 5.8 cells. Cell centres are ((c + 0.5)/columns, (r + 0.5)/rows) of
// the field's own size; the static `columns`, `rows`, `cellCentre(column:row:)` and `replay(_:)` keep the A20-P01
// default size, so every A20-P01 behaviour is unchanged at the default.
import Foundation
import VisualCoreMath

/// The reference sand field: one height per cell, row-major, zero at rest.
public struct SandField: Equatable, Sendable {
    /// The number of columns of the default field (160, from the small tray).
    public static let columns = GardenPalette.smallTray.fieldColumns
    /// The number of rows of the default field (120, from the small tray).
    public static let rows = GardenPalette.smallTray.fieldRows
    /// The accepted number of columns and of rows of a field; a size outside it is clamped into it.
    public static let sizeRange: ClosedRange<Int> = 1...1024

    /// The number of columns of this field (1…1024).
    public let columns: Int
    /// The number of rows of this field (1…1024).
    public let rows: Int
    /// The heights, row-major (`row * columns + column`), in units of the deepest groove.
    public private(set) var heights: [Float]

    /// A field at rest of `columns` × `rows` cells (defaults 160 × 120, the small tray's reference field); each
    /// count is clamped into ``sizeRange``.
    public init(columns: Int = SandField.columns, rows: Int = SandField.rows) {
        let width = min(max(columns, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
        let height = min(max(rows, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
        self.columns = width
        self.rows = height
        heights = [Float](repeating: 0, count: width * height)
    }

    /// The centre of the cell at `column`, `row` of the default field in normalized tray coordinates:
    /// ((c + 0.5)/160, (r + 0.5)/120).
    public static func cellCentre(column: Int, row: Int) -> Vec2 {
        Vec2((Double(column) + 0.5) / Double(columns), (Double(row) + 0.5) / Double(rows))
    }

    /// The centre of the cell at `column`, `row` of this field in normalized tray coordinates:
    /// ((c + 0.5)/columns, (r + 0.5)/rows).
    public func cellCentre(column: Int, row: Int) -> Vec2 {
        Vec2((Double(column) + 0.5) / Double(columns), (Double(row) + 0.5) / Double(rows))
    }

    /// The height of the cell at `column`, `row` (both in range).
    public subscript(_ column: Int, _ row: Int) -> Float {
        get { heights[row * columns + column] }
        set { heights[row * columns + column] = newValue }
    }

    /// Rakes `stroke` into the field: each point is stamped along its tangent (the next point minus the previous
    /// one, one-sided at the ends; the tray's x axis for a dab). A stroke with an unknown rake changes nothing (the
    /// document validator refuses it before).
    public mutating func apply(_ stroke: RakeStroke) {
        guard let style = GardenPalette.rake(id: stroke.rake) else { return }
        let points = stroke.points
        guard !points.isEmpty else { return }
        for index in points.indices {
            let direction: Vec2
            if points.count == 1 {
                direction = Vec2(1, 0)
            } else {
                let previous = points[max(index - 1, 0)]
                let next = points[min(index + 1, points.count - 1)]
                direction = next - previous
            }
            RakeBrush.stamp(into: &self, at: points[index], direction: direction, style: style)
        }
    }

    /// The default-size field (160 × 120) obtained by raking `strokes` in order into a field at rest.
    public static func replay(_ strokes: [RakeStroke]) -> SandField {
        replay(strokes, columns: columns, rows: rows)
    }

    /// The `columns` × `rows` field obtained by raking `strokes` in order into a field at rest of that size.
    public static func replay(_ strokes: [RakeStroke], columns: Int, rows: Int) -> SandField {
        var field = SandField(columns: columns, rows: rows)
        for stroke in strokes { field.apply(stroke) }
        return field
    }

    /// The largest absolute height difference between this field and `other` over all cells; infinity when the
    /// two fields differ in size.
    public func maxDifference(_ other: SandField) -> Float {
        guard columns == other.columns, rows == other.rows else { return .infinity }
        var largest: Float = 0
        for index in heights.indices {
            largest = max(largest, abs(heights[index] - other.heights[index]))
        }
        return largest
    }
}
