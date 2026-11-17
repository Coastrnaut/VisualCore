// SandField — feature 145 (A20-P01) T-A20-106 (FR-A20-104; clarifications Q1, Q3, Q4). The reference sand field of the
// small tray: 160 × 120 heights in units of the deepest groove, zero at rest, rebuilt on the CPU by replaying the rake
// strokes in order (later strokes overwrite earlier ones). The replay is exact and deterministic; it is the reference
// the history compares against within 1e-6 per cell. Pure arithmetic.
import Foundation
import VisualCoreMath

/// The reference sand field: one height per cell, row-major, zero at rest.
public struct SandField: Equatable, Sendable {
    /// The number of columns (160, from the small tray).
    public static let columns = GardenPalette.smallTray.fieldColumns
    /// The number of rows (120, from the small tray).
    public static let rows = GardenPalette.smallTray.fieldRows

    /// The heights, row-major (`row * columns + column`), in units of the deepest groove.
    public private(set) var heights: [Float]

    /// A field at rest: every height zero.
    public init() {
        heights = [Float](repeating: 0, count: SandField.columns * SandField.rows)
    }

    /// The centre of the cell at `column`, `row` in normalized tray coordinates: ((c + 0.5)/160, (r + 0.5)/120).
    public static func cellCentre(column: Int, row: Int) -> Vec2 {
        Vec2((Double(column) + 0.5) / Double(columns), (Double(row) + 0.5) / Double(rows))
    }

    /// The height of the cell at `column`, `row` (both in range).
    public subscript(_ column: Int, _ row: Int) -> Float {
        get { heights[row * SandField.columns + column] }
        set { heights[row * SandField.columns + column] = newValue }
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

    /// The field obtained by raking `strokes` in order into a field at rest.
    public static func replay(_ strokes: [RakeStroke]) -> SandField {
        var field = SandField()
        for stroke in strokes { field.apply(stroke) }
        return field
    }

    /// The largest absolute height difference between this field and `other` over all cells.
    public func maxDifference(_ other: SandField) -> Float {
        var largest: Float = 0
        for index in heights.indices {
            largest = max(largest, abs(heights[index] - other.heights[index]))
        }
        return largest
    }
}
