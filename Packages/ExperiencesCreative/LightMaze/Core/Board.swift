// Board — feature 096 (A13-P01) T-A13-103 (FR-A13-110, FR-A13-112; clarification Q2; data-model "Direction",
// "Orientation", "Tile", "Board"; gap G-BOARD). The Light Maze board: a grid of `width` × `height` unit cells (4…12
// each) with at most one tile per cell. Cell (column c, row r) spans x c…c + 1 and y r…r + 1 in board coordinates,
// x to the east and y to the north, so the board covers 0…width × 0…height.
//
// Tiles: an emitter (with the direction it shines: east, north, west or south), a wall, a mirror and a prism (each with
// an orientation: slash `/` is the cell's diagonal from (c, r) to (c + 1, r + 1), backslash `\` the diagonal from
// (c, r + 1) to (c + 1, r)), and a target. Only mirrors and prisms turn; turning toggles the orientation.
//
// Segments in board coordinates, in this order: a wall is its cell's square (bottom, right, top, left edge), a mirror
// or a prism its diagonal by orientation, a target the square of side 0.6 centred in its cell (from c + 0.2 to c + 0.8,
// same edge order), an emitter its cell's square; after the tiles' segments, in tile order, come the four board edges
// (bottom, right, top, left).
//
// Validation (`problem`), in this order, the first failure naming the reason: `size-out-of-range` (width or height
// outside 4…12), `too-many-tiles` (more than 144), `outside-board` (a tile's cell outside the board), `duplicate-cell`
// (two tiles in one cell), `missing-direction` (an emitter without a direction), `missing-orientation` (a mirror or a
// prism without an orientation), `emitter-count` (not exactly one emitter), `no-target` (no target).
import Foundation
import VisualCoreMath

/// A grid direction a beam can travel along.
public enum Direction: String, Codable, CaseIterable, Sendable {
    /// Toward +x.
    case east
    /// Toward +y.
    case north
    /// Toward −x.
    case west
    /// Toward −y.
    case south

    /// The unit vector of the direction: (1, 0), (0, 1), (−1, 0) or (0, −1).
    public var vector: Vec2 {
        switch self {
        case .east: return Vec2(1, 0)
        case .north: return Vec2(0, 1)
        case .west: return Vec2(-1, 0)
        case .south: return Vec2(0, -1)
        }
    }

    /// The column and row step of the direction.
    public var step: (column: Int, row: Int) {
        switch self {
        case .east: return (1, 0)
        case .north: return (0, 1)
        case .west: return (-1, 0)
        case .south: return (0, -1)
        }
    }

    /// The grid direction nearest to `vector` (the larger component wins; ties go to the x axis), or nil for a zero or
    /// non-finite vector. A reflection about a 45° diagonal yields a grid direction up to rounding; this snaps it back.
    public static func nearest(to vector: Vec2) -> Direction? {
        guard vector.isFinite, vector.length > 0 else { return nil }
        if abs(vector.x) >= abs(vector.y) { return vector.x > 0 ? .east : .west }
        return vector.y > 0 ? .north : .south
    }
}

/// The orientation of a mirror or a prism: which diagonal of its cell it lies on.
public enum Orientation: String, Codable, CaseIterable, Sendable {
    /// `/`: the diagonal from the cell's lower-left corner (c, r) to its upper-right corner (c + 1, r + 1).
    case slash
    /// `\`: the diagonal from the cell's upper-left corner (c, r + 1) to its lower-right corner (c + 1, r).
    case backslash

    /// The other orientation (what a turn gives).
    public var toggled: Orientation { self == .slash ? .backslash : .slash }

    /// The orientation's symbol, "/" or "\".
    public var symbol: String { self == .slash ? "/" : "\\" }
}

/// The kind of a tile.
public enum TileKind: String, Codable, CaseIterable, Sendable {
    /// The light source; it has a direction and blocks beams that come back to it.
    case emitter
    /// A wall; it stops the beam.
    case wall
    /// A two-sided mirror on a diagonal; it reflects the beam.
    case mirror
    /// A target; it stops the beam and is lit when hit from any side.
    case target
    /// A beam splitter on a diagonal; it reflects the beam and lets it pass straight on.
    case prism

    /// True for the kinds that turn (mirror and prism).
    public var isTurnable: Bool { self == .mirror || self == .prism }
}

/// A cell of the board by column (x) and row (y), both from 0.
public struct Cell: Codable, Hashable, Sendable, CustomStringConvertible {
    /// The column, 0 at the west edge.
    public var column: Int
    /// The row, 0 at the south edge.
    public var row: Int

    /// Creates the cell at `column`, `row`.
    public init(_ column: Int, _ row: Int) { self.column = column; self.row = row }

    /// The cell containing the board point `point` (the floor of each coordinate), or nil for a non-finite point.
    public init?(containing point: Vec2) {
        guard point.isFinite, abs(point.x) < 1e9, abs(point.y) < 1e9 else { return nil }
        self.init(Int(point.x.rounded(.down)), Int(point.y.rounded(.down)))
    }

    /// The centre of the cell in board coordinates, (column + 0.5, row + 0.5).
    public var center: Vec2 { Vec2(Double(column) + 0.5, Double(row) + 0.5) }

    /// "(column, row)".
    public var description: String { "(\(column), \(row))" }
}

/// One tile: its kind, its cell and, by kind, its direction (emitter) or orientation (mirror, prism).
public struct Tile: Codable, Equatable, Sendable {
    /// The side of a target's centred square.
    public static let targetSide = 0.6

    /// The kind.
    public var kind: TileKind
    /// The cell.
    public var cell: Cell
    /// The emitter's direction (nil for the other kinds).
    public var direction: Direction?
    /// The mirror's or prism's orientation (nil for the other kinds).
    public var orientation: Orientation?

    /// Creates a tile from all of its fields (no validation; `Board.problem` validates).
    public init(kind: TileKind, cell: Cell, direction: Direction? = nil, orientation: Orientation? = nil) {
        self.kind = kind; self.cell = cell; self.direction = direction; self.orientation = orientation
    }

    /// An emitter at (`column`, `row`) shining toward `direction`.
    public static func emitter(_ column: Int, _ row: Int, _ direction: Direction) -> Tile {
        Tile(kind: .emitter, cell: Cell(column, row), direction: direction)
    }

    /// A wall at (`column`, `row`).
    public static func wall(_ column: Int, _ row: Int) -> Tile { Tile(kind: .wall, cell: Cell(column, row)) }

    /// A mirror at (`column`, `row`) with `orientation`.
    public static func mirror(_ column: Int, _ row: Int, _ orientation: Orientation) -> Tile {
        Tile(kind: .mirror, cell: Cell(column, row), orientation: orientation)
    }

    /// A target at (`column`, `row`).
    public static func target(_ column: Int, _ row: Int) -> Tile { Tile(kind: .target, cell: Cell(column, row)) }

    /// A prism at (`column`, `row`) with `orientation`.
    public static func prism(_ column: Int, _ row: Int, _ orientation: Orientation) -> Tile {
        Tile(kind: .prism, cell: Cell(column, row), orientation: orientation)
    }

    /// The tile's segments in board coordinates (see the file header): four square edges for a wall, a target (side
    /// 0.6, centred) and an emitter, one diagonal for a mirror or a prism (the slash diagonal when the orientation is
    /// missing).
    public var segments: [Segment2] {
        let x = Double(cell.column), y = Double(cell.row)
        switch kind {
        case .wall, .emitter:
            return Self.square(x0: x, y0: y, x1: x + 1, y1: y + 1)
        case .target:
            let inset = (1 - Self.targetSide) / 2
            return Self.square(x0: x + inset, y0: y + inset, x1: x + 1 - inset, y1: y + 1 - inset)
        case .mirror, .prism:
            if orientation == .backslash { return [Segment2(Vec2(x, y + 1), Vec2(x + 1, y))] }
            return [Segment2(Vec2(x, y), Vec2(x + 1, y + 1))]
        }
    }

    private enum CodingKeys: String, CodingKey { case column, direction, kind, orientation, row }

    /// Decodes the flat JSON layout `{"column", "direction"?, "kind", "orientation"?, "row"}` (no validation).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(TileKind.self, forKey: .kind)
        cell = Cell(try c.decode(Int.self, forKey: .column), try c.decode(Int.self, forKey: .row))
        direction = try c.decodeIfPresent(Direction.self, forKey: .direction)
        orientation = try c.decodeIfPresent(Orientation.self, forKey: .orientation)
    }

    /// Encodes the flat JSON layout (direction and orientation only when present).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cell.column, forKey: .column)
        try c.encodeIfPresent(direction, forKey: .direction)
        try c.encode(kind, forKey: .kind)
        try c.encodeIfPresent(orientation, forKey: .orientation)
        try c.encode(cell.row, forKey: .row)
    }

    /// The four edges of the axis-aligned square x0…x1 × y0…y1: bottom, right, top, left.
    static func square(x0: Double, y0: Double, x1: Double, y1: Double) -> [Segment2] {
        [Segment2(Vec2(x0, y0), Vec2(x1, y0)), Segment2(Vec2(x1, y0), Vec2(x1, y1)),
         Segment2(Vec2(x1, y1), Vec2(x0, y1)), Segment2(Vec2(x0, y1), Vec2(x0, y0))]
    }
}

/// Why a board was refused; the raw values are the reason names used in documents and tests.
public enum BoardRefusal: String, Codable, CaseIterable, Error, Sendable {
    /// The width or the height lies outside 4…12.
    case sizeOutOfRange = "size-out-of-range"
    /// More than 144 tiles.
    case tooManyTiles = "too-many-tiles"
    /// A tile's cell lies outside the board.
    case outsideBoard = "outside-board"
    /// Two tiles share a cell.
    case duplicateCell = "duplicate-cell"
    /// An emitter has no direction.
    case missingDirection = "missing-direction"
    /// A mirror or a prism has no orientation.
    case missingOrientation = "missing-orientation"
    /// Not exactly one emitter.
    case emitterCount = "emitter-count"
    /// No target.
    case noTarget = "no-target"
}

/// Who owns a segment of the board's geometry.
public enum SegmentOwner: Equatable, Hashable, Sendable {
    /// The tile at this index of `Board.tiles`.
    case tile(Int)
    /// One of the four board edges.
    case boardEdge
}

/// The segments of a board with the owner of each, in the order of the file header.
public struct BoardGeometry: Equatable, Sendable {
    /// Every segment: the tiles' segments in tile order, then the four board edges.
    public let segments: [Segment2]
    /// The owner of each segment (same indices as ``segments``).
    public let owners: [SegmentOwner]
    /// The indices in ``segments`` of each tile's segments (same indices as `Board.tiles`).
    public let tileSegments: [[Int]]
}

/// A Light Maze board: its size in cells and its tiles.
public struct Board: Codable, Equatable, Sendable {
    /// The allowed widths and heights in cells.
    public static let sizeRange: ClosedRange<Int> = 4...12
    /// The most tiles a board may hold (one per cell of the largest board).
    public static let maxTiles = 144

    /// The width in cells, 4…12.
    public var width: Int
    /// The height in cells, 4…12.
    public var height: Int
    /// The tiles in board order (the order of the level data).
    public var tiles: [Tile]

    /// Creates a board from its fields (no validation; ``problem`` validates).
    public init(width: Int, height: Int, tiles: [Tile]) {
        self.width = width; self.height = height; self.tiles = tiles
    }

    /// A board from its fields, or the reason it is refused (see the file header).
    public static func validated(width: Int, height: Int, tiles: [Tile]) -> Result<Board, BoardRefusal> {
        let board = Board(width: width, height: height, tiles: tiles)
        if let problem = board.problem { return .failure(problem) }
        return .success(board)
    }

    /// The board's first problem in the order of the file header, or nil when it is valid.
    public var problem: BoardRefusal? {
        guard Self.sizeRange.contains(width), Self.sizeRange.contains(height) else { return .sizeOutOfRange }
        guard tiles.count <= Self.maxTiles else { return .tooManyTiles }
        guard tiles.allSatisfy({ contains($0.cell) }) else { return .outsideBoard }
        guard Set(tiles.map(\.cell)).count == tiles.count else { return .duplicateCell }
        guard tiles.allSatisfy({ $0.kind != .emitter || $0.direction != nil }) else { return .missingDirection }
        guard tiles.allSatisfy({ !$0.kind.isTurnable || $0.orientation != nil }) else { return .missingOrientation }
        guard tiles.filter({ $0.kind == .emitter }).count == 1 else { return .emitterCount }
        guard tiles.contains(where: { $0.kind == .target }) else { return .noTarget }
        return nil
    }

    /// True when the board has no problem.
    public var isValid: Bool { problem == nil }

    /// True when `cell` lies on the board.
    public func contains(_ cell: Cell) -> Bool {
        (0..<width).contains(cell.column) && (0..<height).contains(cell.row)
    }

    /// The index of the tile in `cell`, if any (the first one when a damaged board repeats a cell).
    public func tileIndex(at cell: Cell) -> Int? { tiles.firstIndex { $0.cell == cell } }

    /// The index of the (first) emitter, if any.
    public var emitterIndex: Int? { tiles.firstIndex { $0.kind == .emitter } }

    /// The cells of the targets in tile order.
    public var targetCells: [Cell] { tiles.filter { $0.kind == .target }.map(\.cell) }

    /// The indices in ``tiles`` of the turnable tiles (mirrors and prisms) in tile order.
    public var turnableIndices: [Int] { tiles.indices.filter { tiles[$0].kind.isTurnable } }

    /// The orientations of the turnable tiles in tile order (slash for a missing one).
    public var orientations: [Orientation] { turnableIndices.map { tiles[$0].orientation ?? .slash } }

    /// This board with the turnable tiles set to `orientations` (in tile order), or nil when the count differs from
    /// the number of turnable tiles.
    public func applying(_ orientations: [Orientation]) -> Board? {
        let indices = turnableIndices
        guard orientations.count == indices.count else { return nil }
        var board = self
        for (position, index) in indices.enumerated() { board.tiles[index].orientation = orientations[position] }
        return board
    }

    /// The four board edges: bottom, right, top, left.
    public var edges: [Segment2] {
        Tile.square(x0: 0, y0: 0, x1: Double(width), y1: Double(height))
    }

    /// Every segment with its owner (see the file header for the order).
    public var geometry: BoardGeometry {
        var segments: [Segment2] = []
        var owners: [SegmentOwner] = []
        var tileSegments: [[Int]] = []
        for (index, tile) in tiles.enumerated() {
            var own: [Int] = []
            for segment in tile.segments {
                own.append(segments.count)
                segments.append(segment)
                owners.append(.tile(index))
            }
            tileSegments.append(own)
        }
        for edge in edges {
            segments.append(edge)
            owners.append(.boardEdge)
        }
        return BoardGeometry(segments: segments, owners: owners, tileSegments: tileSegments)
    }
}
