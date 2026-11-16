// SimulationBrush — feature 120 (A16-P04) T-A16-402 (FR-A16-401, SC-A16-401; clarification Q1; data-model "Brush";
// contracts/ui.md). What a tap or drag at cell (x, y) writes into the field, the same on every run:
// - automaton (alive 0/1): a tap toggles the cell, a drag sets it alive;
// - reaction-diffusion (u, v): every cell within radius 2 (dx² + dy² ≤ 4, wrapping) gets u = 0.25 and v = 0.5;
// - wave (height, current and previous): the cell and its four neighbours get height 1 in both fields (no initial
//   velocity); edge cells (index 0 or n − 1) stay 0, and nothing wraps.
// Written values are rounded to the family's storage precision. A cell outside the grid gives nil (nothing changes).
import Foundation
import VisualCoreSimulation

/// How a paint action was made.
public enum PaintMode: Int, Sendable {
    /// A single tap (the automaton toggles the cell).
    case tap = 0
    /// A drag entering a new cell (the automaton sets the cell alive).
    case drag = 1
}

/// The deterministic paint brush of the three families.
public enum SimulationBrush {
    /// The radius of the reaction-diffusion disc, in cells.
    public static let reactionRadius = 2
    /// The u written by the reaction-diffusion brush.
    public static let reactionU: Float = 0.25
    /// The v written by the reaction-diffusion brush.
    public static let reactionV: Float = 0.5
    /// The height written by the wave brush.
    public static let waveHeight: Float = 1

    /// `field` painted at cell (x, y) with `mode` for `kind`, values rounded to `precision`; nil when (x, y) is
    /// outside the grid.
    public static func painted(_ field: SimulationField, kind: SimulationKind, x: Int, y: Int, mode: PaintMode,
                               precision: StoragePrecision) -> SimulationField? {
        let width = field.current.width, height = field.current.height
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        var out = field
        switch kind {
        case .automaton:
            let alive: Float = mode == .tap ? (field.current[x, y, 0] >= 0.5 ? 0 : 1) : 1
            out.current[x, y, 0] = precision.round(alive)
        case .reactionDiffusion:
            let u = precision.round(reactionU), v = precision.round(reactionV)
            for (cx, cy) in cells(kind: kind, x: x, y: y, width: width, height: height) {
                out.current[cx, cy, 0] = u
                if out.current.channels > 1 { out.current[cx, cy, 1] = v }
            }
        case .wave:
            let h = precision.round(waveHeight)
            var previous = field.previous ?? field.current
            for (cx, cy) in cells(kind: kind, x: x, y: y, width: width, height: height) {
                out.current[cx, cy, 0] = h
                previous[cx, cy, 0] = h
            }
            out.previous = previous
        }
        return out
    }

    /// The cells the brush of `kind` writes at (x, y) on a `size` × `size` grid, in row then column order; empty
    /// when (x, y) is outside the grid.
    public static func cells(kind: SimulationKind, x: Int, y: Int, size: Int) -> [(Int, Int)] {
        cells(kind: kind, x: x, y: y, width: size, height: size)
    }

    /// The cells the brush of `kind` writes at (x, y) on a `width` × `height` grid (see `cells(kind:x:y:size:)`).
    static func cells(kind: SimulationKind, x: Int, y: Int, width: Int, height: Int) -> [(Int, Int)] {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return [] }
        switch kind {
        case .automaton:
            return [(x, y)]
        case .reactionDiffusion:
            var out: [(Int, Int)] = []
            var seen = Set<Int>()
            let r = reactionRadius
            for dy in -r...r {
                for dx in -r...r where dx * dx + dy * dy <= r * r {
                    let cx = ((x + dx) % width + width) % width, cy = ((y + dy) % height + height) % height
                    if seen.insert(cy * width + cx).inserted { out.append((cx, cy)) }
                }
            }
            return out
        case .wave:
            let offsets = [(0, -1), (-1, 0), (0, 0), (1, 0), (0, 1)]
            return offsets.compactMap { offset -> (Int, Int)? in
                let cx = x + offset.0, cy = y + offset.1
                guard cx > 0, cx < width - 1, cy > 0, cy < height - 1 else { return nil }
                return (cx, cy)
            }
        }
    }
}
