// RakeBrush — feature 145 (A20-P01) T-A20-106 (FR-A20-104; clarification Q3). The groove profile of a rake style,
// depth·cos(2π·tines·u/width) for |u| ≤ width/2 (u the signed distance from the stroke's centre line), and the stamp
// that writes it into the reference sand field: every cell whose centre lies in the footprint (one spacing along the
// direction, the rake's width across) takes the profile height, replacing what was there. Pure arithmetic.
//
// Feature 146 (A20-P02) T-A20-203 (FR-A20-202; clarification Q1): the stamp uses the field's own size and visits only
// the footprint rectangle's bounding box widened by one cell (the same cells change as before; fewer are visited).
import Foundation
import VisualCoreMath

/// The groove profile of a rake and its stamp into a ``SandField``.
public enum RakeBrush {
    /// The height of `style`'s profile at the signed across-distance `u` (tray widths) from the centre line, or nil
    /// when `u` lies outside the rake (|u| > width/2).
    public static func height(across u: Double, style: GardenPalette.RakeStyle) -> Double? {
        guard u.isFinite, abs(u) <= style.width / 2 else { return nil }
        return style.depth * cos(2 * Double.pi * Double(style.tines) * u / style.width)
    }

    /// The unit direction of `direction` in tray widths (y scaled by the tray's y scale), or the tray's x axis when
    /// `direction` is zero or not finite.
    public static func unitDirection(_ direction: Vec2) -> Vec2 {
        let scaled = Vec2(direction.x, direction.y * GardenPalette.smallTray.yScale)
        let length = scaled.length
        guard length.isFinite, length > 0 else { return Vec2(1, 0) }
        return scaled / length
    }

    /// Stamps `style` into `field` at `point` (normalized tray coordinates) moving along `direction`.
    ///
    /// The footprint is a rectangle in tray widths centred on `point`: ``StrokeResampler/spacing`` long along the
    /// unit direction and `style.width` across it. Every cell of `field` (of its own size) whose centre lies in it is
    /// set to the profile height at its signed across-distance (replace, not add). Only cells in the rectangle's
    /// axis-aligned bounding box, widened by one cell, are visited.
    public static func stamp(into field: inout SandField, at point: Vec2, direction: Vec2,
                             style: GardenPalette.RakeStyle) {
        guard point.isFinite else { return }
        let tray = GardenPalette.smallTray
        let along = unitDirection(direction)
        let across = Vec2(-along.y, along.x)
        let halfLength = StrokeResampler.spacing / 2
        let halfWidth = style.width / 2
        let centre = Vec2(point.x, point.y * tray.yScale)
        // The half extents of the rotated rectangle along x and y, in tray widths.
        let extentX = abs(along.x) * halfLength + abs(across.x) * halfWidth
        let extentY = abs(along.y) * halfLength + abs(across.y) * halfWidth
        let columns = field.columns
        let rows = field.rows
        let minColumn = max(0, Int(((centre.x - extentX) * Double(columns)).rounded(.down)) - 1)
        let maxColumn = min(columns - 1, Int(((centre.x + extentX) * Double(columns)).rounded(.up)) + 1)
        let minRow = max(0, Int(((point.y - extentY / tray.yScale) * Double(rows)).rounded(.down)) - 1)
        let maxRow = min(rows - 1, Int(((point.y + extentY / tray.yScale) * Double(rows)).rounded(.up)) + 1)
        guard minColumn <= maxColumn, minRow <= maxRow else { return }
        for row in minRow...maxRow {
            for column in minColumn...maxColumn {
                let cell = field.cellCentre(column: column, row: row)
                let offset = Vec2(cell.x, cell.y * tray.yScale) - centre
                guard abs(offset.dot(along)) <= halfLength else { continue }
                let u = offset.dot(across)
                guard let value = height(across: u, style: style) else { continue }
                field[column, row] = Float(value)
            }
        }
    }
}
