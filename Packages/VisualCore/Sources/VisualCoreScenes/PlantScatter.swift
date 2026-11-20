// PlantScatter — feature 219 (R02-F19) T-R02F19-005 (FR-R02F19-005; SC-R02F19-004; clarification Q4; research R5).
// Deterministic dart throwing of plant instances over a rectangle of the x-z plane: seeded candidates are accepted when
// no accepted instance lies strictly closer than the spacing, checked through a background grid of cell size
// spacing/√2; each accepted instance draws its scale, yaw and variant and carries the model matrix T · R_y · S, ready
// for the instanced renderer (`MeshInstance`, feature 209).
//
// Grid storage: when the grid has at most `denseCellLimit` cells it is a dense array holding at most one instance per
// cell (a cell's diagonal equals the spacing, so two points in one half-open cell always conflict). A larger grid (a
// tiny spacing over a large area) would cost memory proportional to the area, so it becomes a dictionary keyed by cell
// that holds only occupied cells; its cell indices are clamped to 2^60, and because clamping can merge far cells each
// dictionary cell keeps a list and every member is compared by true distance. Both storages give the same result.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// One scattered plant: where it stands, its size, turn and mesh variant, and its model matrix.
public struct PlantInstance: Sendable, Equatable {
    /// The position on the ground plane (y = 0).
    public let position: Vec3
    /// The uniform scale factor.
    public let scale: Double
    /// The turn about +y in radians, in [0, 2π).
    public let yaw: Double
    /// The mesh variant index, in 0 ..< variants.
    public let variant: Int
    /// The model matrix T(position) · R_y(yaw) · S(scale), column-major with the translation in `c3`.
    public var model: Mat4

    init(position: Vec3, scale: Double, yaw: Double, variant: Int) {
        self.position = position
        self.scale = scale
        self.yaw = yaw
        self.variant = variant
        self.model = Mat4.translation(position) * PlantScatter.rotationY(yaw) * Mat4.scale(Vec3(scale, scale, scale))
    }
}

/// Deterministic scattering of plant instances with a minimum spacing (dart throwing, clarification Q4).
public enum PlantScatter {
    /// The most instances of one scatter.
    public static let maxCount = 65_536
    /// The most mesh variants.
    static let maxVariants = 64
    /// The largest scale bound.
    static let maxScale = 100.0
    /// Candidates drawn per requested instance.
    static let candidatesPerInstance = 30
    /// The most cells of the dense grid (4 MiB of `Int32`); a larger grid is stored sparsely.
    static let denseCellLimit = 1 << 20
    /// The largest cell index of the sparse grid.
    static let sparseIndexLimit = Double(1 << 60)

    /// Scatters instances over the rectangle `minX < x < maxX`, `minZ < z < maxZ` (y = 0) so that no two are closer
    /// than `spacing` (exactly `spacing` apart is allowed).
    ///
    /// One `SeededRandom(seed:)` stream draws up to 30 · `maxCount` candidates, each as x then z; an accepted candidate
    /// then draws its scale in `scale`, its yaw in [0, 2π) and its variant in 0 ..< `variants`, in that order. The scatter
    /// stops at `maxCount` instances or when the candidates run out, so a spacing larger than the area gives one
    /// instance. Instances are returned in acceptance order; the same arguments always give the same result.
    /// - Parameters:
    ///   - minX: The lower x bound (finite, less than `maxX`).
    ///   - maxX: The upper x bound (finite).
    ///   - minZ: The lower z bound (finite, less than `maxZ`).
    ///   - maxZ: The upper z bound (finite).
    ///   - spacing: The minimum distance between instances (finite, > 0).
    ///   - maxCount: The most instances, 1 … ``maxCount``.
    ///   - scale: The scale range (finite, lower bound > 0, upper bound ≤ 100).
    ///   - variants: The number of mesh variants, 1 … 64.
    ///   - seed: The seed of the random stream.
    /// - Returns: The instances in acceptance order.
    /// - Throws: ``PlantError/scatterArea`` for an empty or non-finite area, ``PlantError/scatterParameter(_:)`` naming
    ///   `spacing`, `maxCount`, `scale` or `variants` for a setting out of range.
    public static func scatter(minX: Double, maxX: Double, minZ: Double, maxZ: Double, spacing: Double, maxCount: Int,
                               scale: ClosedRange<Double>, variants: Int, seed: UInt64) throws(PlantError) -> [PlantInstance] {
        guard minX.isFinite, maxX.isFinite, minZ.isFinite, maxZ.isFinite, minX < maxX, minZ < maxZ else {
            throw .scatterArea
        }
        let width: Double = maxX - minX
        let depth: Double = maxZ - minZ
        guard width.isFinite, depth.isFinite else { throw .scatterArea }
        guard spacing.isFinite, spacing > 0 else { throw .scatterParameter("spacing") }
        guard maxCount >= 1, maxCount <= PlantScatter.maxCount else { throw .scatterParameter("maxCount") }
        guard scale.lowerBound.isFinite, scale.upperBound.isFinite, scale.lowerBound > 0,
              scale.upperBound <= maxScale else { throw .scatterParameter("scale") }
        guard variants >= 1, variants <= maxVariants else { throw .scatterParameter("variants") }

        var random = SeededRandom(seed: seed)
        var grid = Grid(minX: minX, minZ: minZ, width: width, depth: depth, spacing: spacing)
        var instances: [PlantInstance] = []
        instances.reserveCapacity(min(maxCount, 4_096))
        let candidates: Int = candidatesPerInstance * maxCount
        let scaleSpan: Double = scale.upperBound - scale.lowerBound
        var drawn = 0
        while drawn < candidates, instances.count < maxCount {
            drawn += 1
            let x: Double = minX + width * random.double()
            let z: Double = minZ + depth * random.double()
            guard grid.isFree(x: x, z: z, instances: instances) else { continue }
            let s: Double = scale.lowerBound + scaleSpan * random.double()
            let yaw: Double = 2 * Double.pi * random.double()
            let variant: Int = min(Int(random.double() * Double(variants)), variants - 1)
            grid.insert(x: x, z: z, index: instances.count)
            instances.append(PlantInstance(position: Vec3(x, 0, z), scale: s, yaw: yaw, variant: variant))
        }
        return instances
    }

    /// The rotation by `angle` radians about +y, built explicitly (column-major; `Mat4` has only a quaternion rotation,
    /// whose half-angle round trip would add rounding): c0 = (cos, 0, −sin), c1 = +y, c2 = (sin, 0, cos).
    static func rotationY(_ angle: Double) -> Mat4 {
        let c: Double = cos(angle)
        let s: Double = sin(angle)
        return Mat4(Vec4(c, 0, -s, 0), Vec4(0, 1, 0, 0), Vec4(s, 0, c, 0), Vec4(0, 0, 0, 1))
    }

    /// The background grid of cell size spacing/√2 (dense or sparse, see the file header).
    struct Grid {
        struct Cell: Hashable { let column: Int; let row: Int }
        let minX: Double, minZ: Double, cell: Double, spacing: Double
        let columns: Int, rows: Int
        /// Dense storage: the instance index per cell, −1 when empty; empty in sparse mode.
        var dense: [Int32]
        /// Sparse storage: the instance indices per occupied cell.
        var sparse: [Cell: [Int32]]
        let isDense: Bool

        init(minX: Double, minZ: Double, width: Double, depth: Double, spacing: Double) {
            self.minX = minX
            self.minZ = minZ
            self.spacing = spacing
            cell = spacing / 2.0.squareRoot()
            // Two spare columns and rows: a coordinate rounded up to the upper bound still has its own cell.
            let columnsD: Double = (width / cell).rounded(.down) + 2
            let rowsD: Double = (depth / cell).rounded(.down) + 2
            if columnsD * rowsD <= Double(PlantScatter.denseCellLimit) {
                isDense = true
                columns = Int(columnsD)
                rows = Int(rowsD)
                dense = [Int32](repeating: -1, count: columns * rows)
            } else {
                isDense = false
                columns = 0
                rows = 0
                dense = []
            }
            sparse = [:]
        }

        func index(_ offset: Double) -> Int {
            let i: Double = (offset / cell).rounded(.down)
            return Int(Swift.max(0, Swift.min(i, PlantScatter.sparseIndexLimit)))
        }

        func conflicts(_ x: Double, _ z: Double, _ other: Int32, _ instances: [PlantInstance]) -> Bool {
            let p: Vec3 = instances[Int(other)].position
            return hypot(p.x - x, p.z - z) < spacing
        }

        /// Whether no accepted instance lies strictly closer than the spacing to (x, z): the 5 × 5 cells around it.
        func isFree(x: Double, z: Double, instances: [PlantInstance]) -> Bool {
            let column: Int = index(x - minX)
            let row: Int = index(z - minZ)
            for dc in -2...2 {
                for dr in -2...2 {
                    let c: Int = column + dc
                    let r: Int = row + dr
                    if isDense {
                        guard c >= 0, c < columns, r >= 0, r < rows else { continue }
                        let other: Int32 = dense[r * columns + c]
                        if other >= 0, conflicts(x, z, other, instances) { return false }
                    } else if let members = sparse[Cell(column: c, row: r)] {
                        for other in members where conflicts(x, z, other, instances) { return false }
                    }
                }
            }
            return true
        }

        mutating func insert(x: Double, z: Double, index instance: Int) {
            let column: Int = index(x - minX)
            let row: Int = index(z - minZ)
            if isDense {
                dense[Swift.min(row, rows - 1) * columns + Swift.min(column, columns - 1)] = Int32(instance)
            } else {
                sparse[Cell(column: column, row: row), default: []].append(Int32(instance))
            }
        }
    }
}
