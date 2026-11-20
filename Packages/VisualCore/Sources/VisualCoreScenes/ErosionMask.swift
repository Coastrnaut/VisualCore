// ErosionMask — feature 218 (R02-F18) T-R02F18-004 (FR-R02F18-004; SC-R02F18-003; clarification Q3; research R4).
// Three per-point masks of a height field for terrain shading: steepness, flow and wear. Steepness is the sine of the
// slope angle, taken from the field's central-difference normal. Flow is D8 flow accumulation (O'Callaghan and Mark
// 1984): every grid point starts with one unit, and points are visited from highest to lowest, each handing its whole
// accumulated amount to the one neighbour of its 8-neighbourhood with the steepest descent (drop / distance). Because
// a point only ever hands water to a strictly lower point, visiting by descending height makes every inflow complete
// before a point passes its total on. Wear is steepness · flow. Everything is computed in Double with a fixed visiting
// and tie-breaking order, so the masks are bit-identical across runs on one platform (the logarithm comes from the
// platform library, which IEEE 754 does not require to round correctly).
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// Steepness, flow and wear masks of a `HeightField`, one value set per grid point.
///
/// The masks are deterministic functions of the field's heights: the same field gives bit-identical values.
public enum ErosionMask {
    /// Channel index of the steepness mask in the grid returned by `masks(of:)`.
    static let steepnessChannel = 0
    /// Channel index of the flow mask in the grid returned by `masks(of:)`.
    static let flowChannel = 1
    /// Channel index of the wear mask in the grid returned by `masks(of:)`.
    static let wearChannel = 2

    /// The 8 neighbour offsets (column, row) in tie-break order N, NE, E, SE, S, SW, W, NW, where N is row − 1 and E
    /// is column + 1.
    private static let neighbours: [(Int, Int)] = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]

    /// The masks of `field` on its (columns + 1) × (rows + 1) grid points, 3 channels, every value in 0…1.
    ///
    /// Cell (x, y) of the returned grid is grid point (column x, row y); its channels are:
    /// - 0, steepness: |∇h| / √(1 + |∇h|²), the sine of the slope angle, equal to the horizontal length of the unit
    ///   normal from `HeightField.normal(column:row:)` (central differences, using the ring beyond the grid at edges).
    /// - 1, flow: log(1 + a) / log(1 + N), with N the number of grid points and a the D8 accumulation of the point:
    ///   one for the point itself plus everything handed to it. Each point hands its a to the neighbour inside the grid
    ///   with the largest drop / distance (distance `cellSize`, or `cellSize · √2` diagonally), only when that drop is
    ///   positive; ties go to the first neighbour in the order N (row − 1), NE, E, SE, S, SW, W, NW. Points are visited
    ///   by descending height, equal heights by ascending index `row · (columns + 1) + column`. A point without a lower
    ///   neighbour keeps its a. With a single grid point (never the case for a valid field) flow is 0.
    /// - 2, wear: steepness · flow.
    ///
    /// Values are computed in Double and stored as Float.
    public static func masks(of field: HeightField) -> FieldGrid {
        let width = field.columns + 1, depth = field.rows + 1
        let count = width * depth
        var heights: [Double] = []
        heights.reserveCapacity(count)
        for row in 0..<depth {
            for column in 0..<width { heights.append(field.height(column: column, row: row)) }
        }

        // D8 accumulation, visiting from highest to lowest (ties by lower index first).
        let order: [Int] = (0..<count).sorted { a, b in
            heights[a] != heights[b] ? heights[a] > heights[b] : a < b
        }
        var accumulation = [Double](repeating: 1, count: count)
        let straight = field.cellSize, diagonal = field.cellSize * 2.0.squareRoot()
        for index in order {
            let column = index % width, row = index / width
            var best = -1
            var bestSlope = 0.0
            for (dc, dr) in neighbours {
                let c = column + dc, r = row + dr
                guard c >= 0, c < width, r >= 0, r < depth else { continue }
                let target = r * width + c
                let drop = heights[index] - heights[target]
                guard drop > 0 else { continue }
                let slope = drop / (dc != 0 && dr != 0 ? diagonal : straight)
                if slope > bestSlope {
                    bestSlope = slope
                    best = target
                }
            }
            if best >= 0 { accumulation[best] += accumulation[index] }
        }

        var grid = FieldGrid(width: width, height: depth, channels: 3)
        let denominator = count > 1 ? Foundation.log(1 + Double(count)) : 0
        for row in 0..<depth {
            for column in 0..<width {
                let n = field.normal(column: column, row: row)
                let steepness = min(max((n.x * n.x + n.z * n.z).squareRoot(), 0), 1)
                let a = accumulation[row * width + column]
                let flow = denominator > 0 ? min(max(Foundation.log(1 + a) / denominator, 0), 1) : 0
                let base = (row * width + column) * 3
                grid.values[base + steepnessChannel] = Float(steepness)
                grid.values[base + flowChannel] = Float(flow)
                grid.values[base + wearChannel] = Float(steepness * flow)
            }
        }
        return grid
    }
}

