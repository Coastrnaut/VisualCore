// NocturneGardenBloom — feature 381 (R02-G09-01) T-R02G0901-002 (FR-R02G0901-002, 003, 013; clarifications Q1, Q2,
// Q3). The six bloom kinds as fixed lattice polygons, a planted bloom (kind, anchor cell, size), its shadow cast by the
// sun and the exact cell test, and the five actions.
//
// Outlines: simple, counter-clockwise polygons with integer vertices in a local frame whose origin (0, 0) is the stem's
// foot (a vertex on the bottom edge), the stem rising along +y; at most 16 vertices; x within −1 … 2 and y within 0 … 6
// (at most 3 cells wide and 6 tall at size 1). The outlines are the project's own design.
//
// Casting: a vertex (x, y) of a bloom of size s anchored at (c, r) under sun elevation e (factor e/2) casts the point
// (c + s·x, r + (e/2)·s·y); every coordinate is doubled, (2c + 2s·x, 2r + e·s·y), so all are integers. A bed cell
// (col, row) is dark when its doubled centre (2·col + 1, 2·row + 1) lies inside the cast polygon or on its boundary,
// decided by an exact integer winding-number test with an explicit on-segment check. The doubled coordinates stay below
// 2^10 and every cross product below 2^22, so plain `Int` arithmetic is exact. No floating point.

/// A lattice point (integer coordinates); in a cast polygon the coordinates are doubled.
public struct NocturneGardenLattice: Sendable, Hashable, Codable {
    /// The horizontal coordinate (to the right).
    public let x: Int
    /// The vertical coordinate (upward).
    public let y: Int

    /// The point (x, y).
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// The six bloom kinds, each a fixed outline named in words.
public enum NocturneGardenKind: String, Sendable, CaseIterable, Codable {
    /// A cup of two upright petals on a stem.
    case tulip
    /// A bell: a narrow crown over a flared rim on a stem.
    case bell
    /// A star of five spikes on a stem.
    case star
    /// A frond with leaflets alternating up the stem.
    case fern
    /// A round, full head on a stem.
    case rose
    /// A trumpet flaring straight from the stem to a wide mouth.
    case lily

    /// The kind's position in the case order (tulip 0 … lily 5), used by the canonical order of blooms.
    public var order: Int {
        switch self {
        case .tulip: 0
        case .bell: 1
        case .star: 2
        case .fern: 3
        case .rose: 4
        case .lily: 5
        }
    }

    /// The kind in words: "tulip", "bell", "star", "fern", "rose" or "lily" (FR-R02G0901-013).
    public var name: String { rawValue }

    /// The silhouette in words, for players who cannot tell the outlines apart by sight (FR-R02G0901-013).
    public var shape: String {
        switch self {
        case .tulip: "a cup of two upright petals"
        case .bell: "a bell with a flared rim"
        case .star: "a star of five spikes"
        case .fern: "a frond of alternating leaflets"
        case .rose: "a round full head"
        case .lily: "a trumpet with a wide mouth"
        }
    }

    /// The outline at size 1: a simple counter-clockwise polygon starting at the foot (0, 0).
    public var outline: [NocturneGardenLattice] {
        let points: [(Int, Int)]
        switch self {
        case .tulip:
            points = [(0, 0), (1, 0), (1, 2), (2, 3), (2, 6), (1, 5), (0, 5), (-1, 6), (-1, 3), (0, 2)]
        case .bell:
            points = [(0, 0), (1, 0), (1, 2), (2, 2), (1, 4), (1, 6), (0, 6), (0, 4), (-1, 2), (0, 2)]
        case .star:
            points = [(0, 0), (1, 0), (1, 2), (2, 2), (1, 3), (2, 5), (1, 4), (1, 6), (0, 6), (0, 4), (-1, 5),
                      (0, 3), (-1, 2), (0, 2)]
        case .fern:
            points = [(0, 0), (1, 0), (1, 1), (2, 2), (1, 2), (1, 3), (2, 4), (1, 4), (1, 6), (0, 5), (-1, 5),
                      (0, 4), (0, 3), (-1, 3), (0, 2)]
        case .rose:
            points = [(0, 0), (1, 0), (1, 2), (2, 3), (2, 5), (1, 6), (0, 6), (-1, 5), (-1, 3), (0, 2)]
        case .lily:
            points = [(0, 0), (1, 0), (1, 2), (2, 5), (2, 6), (-1, 6), (-1, 5), (0, 2)]
        }
        return points.map { NocturneGardenLattice(x: $0.0, y: $0.1) }
    }
}

/// A planted bloom: a kind, the anchor cell whose bottom-left corner is the foot, and a size (1 … 3).
public struct NocturneGardenBloom: Sendable, Hashable, Codable, Comparable {
    /// The allowed sizes.
    public static let sizes: ClosedRange<Int> = 1...3
    /// The allowed sun elevations (1 high … 4 low); the shadow factor is e/2.
    public static let elevations: ClosedRange<Int> = 1...4

    /// The kind.
    public let kind: NocturneGardenKind
    /// The anchor column (0 at the left of the bed).
    public let column: Int
    /// The anchor row (0 at the ground row, counted upward).
    public let row: Int
    /// The size: the outline's scale, 1 … 3.
    public let size: Int

    /// A bloom; the ranges are checked by the play, not here.
    public init(kind: NocturneGardenKind, column: Int, row: Int, size: Int) {
        self.kind = kind
        self.column = column
        self.row = row
        self.size = size
    }

    /// The canonical order: row, then column, then kind (case order), then size.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.row != rhs.row { return lhs.row < rhs.row }
        if lhs.column != rhs.column { return lhs.column < rhs.column }
        if lhs.kind != rhs.kind { return lhs.kind.order < rhs.kind.order }
        return lhs.size < rhs.size
    }

    /// The cast polygon under sun `elevation` in doubled coordinates: (2c + 2s·x, 2r + e·s·y) for every outline
    /// vertex (x, y).
    public func castPolygon(elevation: Int) -> [NocturneGardenLattice] {
        Self.cast(kind.outline, column: column, row: row, size: size, elevation: elevation)
    }

    /// The row-major indices (row · width + column) of the bed cells this bloom darkens under sun `elevation`.
    public func cells(elevation: Int, width: Int, height: Int) -> Set<Int> {
        Self.cells(of: castPolygon(elevation: elevation), width: width, height: height)
    }

    /// Casts `outline` for a bloom of `size` anchored at (`column`, `row`) under sun `elevation`, in doubled
    /// coordinates.
    public static func cast(_ outline: [NocturneGardenLattice], column: Int, row: Int, size: Int,
                            elevation: Int) -> [NocturneGardenLattice] {
        outline.map { NocturneGardenLattice(x: 2 * column + 2 * size * $0.x, y: 2 * row + elevation * size * $0.y) }
    }

    /// The row-major indices of the bed cells whose doubled centre lies inside `polygon` (doubled coordinates) or on
    /// its boundary; only the cells of the polygon's bounding box clipped to the bed are tested.
    public static func cells(of polygon: [NocturneGardenLattice], width: Int, height: Int) -> Set<Int> {
        guard width > 0, height > 0, let first = polygon.first else { return [] }
        var minX: Int = first.x
        var maxX: Int = first.x
        var minY: Int = first.y
        var maxY: Int = first.y
        for point in polygon {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        let loColumn: Int = max(0, -floorHalf(1 - minX))
        let hiColumn: Int = min(width - 1, floorHalf(maxX - 1))
        let loRow: Int = max(0, -floorHalf(1 - minY))
        let hiRow: Int = min(height - 1, floorHalf(maxY - 1))
        // A centre 2·k + 1 lies in lo … hi exactly when ⌈(lo − 1)/2⌉ ≤ k ≤ ⌊(hi − 1)/2⌋.
        guard loColumn <= hiColumn, loRow <= hiRow else { return [] }
        var result: Set<Int> = []
        for row in loRow...hiRow {
            for column in loColumn...hiColumn
            where contains(polygon, NocturneGardenLattice(x: 2 * column + 1, y: 2 * row + 1)) {
                result.insert(row * width + column)
            }
        }
        return result
    }

    /// Whether `point` lies inside `polygon` or on its boundary: an explicit on-segment check, then the exact integer
    /// winding number (non-zero is inside).
    public static func contains(_ polygon: [NocturneGardenLattice], _ point: NocturneGardenLattice) -> Bool {
        let count: Int = polygon.count
        guard count >= 3 else { return false }
        var winding: Int = 0
        for index in 0..<count {
            let a: NocturneGardenLattice = polygon[index]
            let b: NocturneGardenLattice = polygon[(index + 1) % count]
            let cross: Int = (b.x - a.x) * (point.y - a.y) - (point.x - a.x) * (b.y - a.y)
            if cross == 0, min(a.x, b.x) <= point.x, point.x <= max(a.x, b.x), min(a.y, b.y) <= point.y,
               point.y <= max(a.y, b.y) {
                return true
            }
            if a.y <= point.y {
                if b.y > point.y, cross > 0 { winding += 1 }
            } else if b.y <= point.y, cross < 0 {
                winding -= 1
            }
        }
        return winding != 0
    }

    /// ⌊v / 2⌋ for any sign.
    static func floorHalf(_ value: Int) -> Int {
        value >= 0 ? value / 2 : -((1 - value) / 2)
    }
}

/// A player action; each accepted one spends one move. Bloom numbers are 0-based indices into the blooms in canonical
/// order.
public enum NocturneGardenAction: Sendable, Hashable, Codable {
    /// Plant a bloom (kind, column, row, size).
    case plant(NocturneGardenKind, Int, Int, Int)
    /// Move bloom `bloom` to (column, row).
    case move(Int, Int, Int)
    /// Resize bloom `bloom` to `size`.
    case resize(Int, Int)
    /// Remove bloom `bloom` (it returns to the supply).
    case remove(Int)
    /// Set the sun elevation.
    case sun(Int)

    /// The stable stored keys.
    private enum Keys: String, CodingKey { case op, kind, bloom, column, row, size, elevation }

    /// Decodes `{"op": "plant" | "move" | "resize" | "remove" | "sun", …operands}`.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let op: String = try c.decode(String.self, forKey: .op)
        switch op {
        case "plant":
            self = .plant(try c.decode(NocturneGardenKind.self, forKey: .kind), try c.decode(Int.self, forKey: .column),
                          try c.decode(Int.self, forKey: .row), try c.decode(Int.self, forKey: .size))
        case "move":
            self = .move(try c.decode(Int.self, forKey: .bloom), try c.decode(Int.self, forKey: .column),
                         try c.decode(Int.self, forKey: .row))
        case "resize":
            self = .resize(try c.decode(Int.self, forKey: .bloom), try c.decode(Int.self, forKey: .size))
        case "remove":
            self = .remove(try c.decode(Int.self, forKey: .bloom))
        case "sun":
            self = .sun(try c.decode(Int.self, forKey: .elevation))
        default:
            throw DecodingError.dataCorruptedError(forKey: .op, in: c, debugDescription: "unknown action \(op)")
        }
    }

    /// Encodes `{"op": …, …operands}` with named operands.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case let .plant(kind, column, row, size):
            try c.encode("plant", forKey: .op)
            try c.encode(kind, forKey: .kind)
            try c.encode(column, forKey: .column)
            try c.encode(row, forKey: .row)
            try c.encode(size, forKey: .size)
        case let .move(bloom, column, row):
            try c.encode("move", forKey: .op)
            try c.encode(bloom, forKey: .bloom)
            try c.encode(column, forKey: .column)
            try c.encode(row, forKey: .row)
        case let .resize(bloom, size):
            try c.encode("resize", forKey: .op)
            try c.encode(bloom, forKey: .bloom)
            try c.encode(size, forKey: .size)
        case let .remove(bloom):
            try c.encode("remove", forKey: .op)
            try c.encode(bloom, forKey: .bloom)
        case let .sun(elevation):
            try c.encode("sun", forKey: .op)
            try c.encode(elevation, forKey: .elevation)
        }
    }
}
