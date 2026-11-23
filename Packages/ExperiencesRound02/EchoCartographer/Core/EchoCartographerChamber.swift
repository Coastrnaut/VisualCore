// EchoCartographerChamber — feature 401 (R02-G11-01) T-R02G1101-002 (FR-R02G1101-001, 002, 003, 013, 014;
// clarifications Q1, Q2). The grid chamber of Echo Cartographer and the exact physics of a pulse. A chamber is W × H
// cells (W, H 5 … 16); cell (x, y) has the index y · W + x; every cell is open or a wall (a whole unit square, the static
// convex segment the echoes strike) and the border is a wall too. A pulse from a cell sends four rays in the fixed order
// north (−y), east (+x), south (+y), west (−x): a ray steps cell by cell, crossing open cells, until it enters a wall
// cell or leaves the chamber; its travel distance is the number of steps (1 when the neighbour is a wall). Each beacon
// answers with its path length: the fewest side steps through open cells from the emitter (0 on the emitter), found by
// breadth-first search; the echoes are reported sorted, without naming the beacon. Every delay is the round trip at 12
// ticks of 0.008333 s per cell each way, 24 ticks per cell; delays never decide a rule. The player's knowledge of the
// chamber (unknown, open, wall per cell) lives here too: it starts with only the entry open and only grows. Integers
// only; no clock, no random source.
import Foundation

/// A cell of the chamber, column `x` and row `y` (row 0 is the north edge). Ordered by row, then column, which is the
/// cell-index order.
public struct EchoCartographerCell: Sendable, Hashable, Codable, Comparable {
    /// The column, 0 … W − 1 inside the chamber.
    public let x: Int
    /// The row, 0 … H − 1 inside the chamber.
    public let y: Int

    /// The cell at column `x`, row `y` (not checked against a chamber).
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// Row-major order: lower row first, then lower column.
    public static func < (lhs: Self, rhs: Self) -> Bool { (lhs.y, lhs.x) < (rhs.y, rhs.x) }

    /// The larger of the column and row differences (the claim tolerance's measure).
    public func distance(to other: Self) -> Int { max(abs(x - other.x), abs(y - other.y)) }
}

/// The four directions of a pulse's rays, in their fixed order.
public enum EchoCartographerDirection: String, Sendable, Codable, CaseIterable {
    /// Towards row 0.
    case north
    /// Towards higher columns.
    case east
    /// Towards higher rows.
    case south
    /// Towards column 0.
    case west

    /// The column and row change of one step.
    public var step: (dx: Int, dy: Int) {
        switch self {
        case .north: (0, -1)
        case .east: (1, 0)
        case .south: (0, 1)
        case .west: (-1, 0)
        }
    }
}

/// One ray of a pulse: the open cells it crossed, the wall cell it struck (nil when it left the chamber) and its travel
/// distance in steps.
public struct EchoCartographerRay: Sendable, Equatable, Codable {
    /// The ray's direction.
    public let direction: EchoCartographerDirection
    /// The open cells crossed, nearest first (distance − 1 of them).
    public let open: [EchoCartographerCell]
    /// The wall cell struck; nil when the ray reached the border.
    public let wall: EchoCartographerCell?
    /// The steps from the emitter to the struck wall or border, at least 1.
    public let distance: Int

    /// A ray of the given values (not checked).
    public init(direction: EchoCartographerDirection, open: [EchoCartographerCell], wall: EchoCartographerCell?,
                distance: Int) {
        self.direction = direction
        self.open = open
        self.wall = wall
        self.distance = distance
    }

    /// The round-trip delay in ticks: 24 × distance.
    public var delay: Int { distance * EchoCartographerChamber.ticksPerCell }
}

/// The report of one pulse: its four rays and the beacons' echoes (sorted path lengths, unlabelled).
public struct EchoCartographerEcho: Sendable, Equatable, Codable {
    /// The cell the pulse came from.
    public let emitter: EchoCartographerCell
    /// The rays, north, east, south, west.
    public let rays: [EchoCartographerRay]
    /// Each reachable beacon's path length from the emitter, ascending.
    public let beaconDistances: [Int]

    /// A report of the given values (not checked).
    public init(emitter: EchoCartographerCell, rays: [EchoCartographerRay], beaconDistances: [Int]) {
        self.emitter = emitter
        self.rays = rays
        self.beaconDistances = beaconDistances
    }

    /// The round-trip delays of the beacon echoes in ticks, ascending.
    public var beaconDelays: [Int] { beaconDistances.map { $0 * EchoCartographerChamber.ticksPerCell } }
}

/// The grid chamber: its size and its wall cells.
public struct EchoCartographerChamber: Sendable, Hashable, Codable {
    /// The allowed widths and heights.
    public static let sizeRange: ClosedRange<Int> = 5...16
    /// The round-trip delay of one cell of distance, in ticks of 0.008333 s (12 each way).
    public static let ticksPerCell: Int = 24

    /// The number of columns.
    public let width: Int
    /// The number of rows.
    public let height: Int
    /// The wall cells' indices (y · width + x).
    public let walls: Set<Int>

    /// A chamber; refuses a size outside 5 … 16 (`.level("size")`) and a wall index outside the grid
    /// (`.level("walls")`).
    public init(width: Int, height: Int, walls: Set<Int>) throws(EchoCartographerError) {
        guard Self.sizeRange.contains(width), Self.sizeRange.contains(height) else { throw .level("size") }
        guard walls.allSatisfy({ $0 >= 0 && $0 < width * height }) else { throw .level("walls") }
        self.width = width
        self.height = height
        self.walls = walls
    }

    /// The number of cells, W × H.
    public var cellCount: Int { width * height }

    /// Whether `cell` lies inside the grid.
    public func isInside(_ cell: EchoCartographerCell) -> Bool {
        cell.x >= 0 && cell.x < width && cell.y >= 0 && cell.y < height
    }

    /// Whether `cell` is a wall; every cell outside the grid counts as a wall (the border).
    public func isWall(_ cell: EchoCartographerCell) -> Bool {
        !isInside(cell) || walls.contains(index(cell))
    }

    /// Whether `cell` is an open cell inside the grid.
    public func isOpen(_ cell: EchoCartographerCell) -> Bool { !isWall(cell) }

    /// The index of a cell inside the grid, y · width + x.
    public func index(_ cell: EchoCartographerCell) -> Int { cell.y * width + cell.x }

    /// The cell of an index 0 … W × H − 1.
    public func cell(_ index: Int) -> EchoCartographerCell {
        EchoCartographerCell(x: index % width, y: index / width)
    }

    /// The ray from `from` in `direction`: the open cells it crosses until it enters a wall cell (reported) or leaves
    /// the grid (no wall), and the number of steps taken.
    public func ray(from: EchoCartographerCell, _ direction: EchoCartographerDirection) -> EchoCartographerRay {
        let (dx, dy) = direction.step
        var open: [EchoCartographerCell] = []
        var steps: Int = 0
        var current: EchoCartographerCell = from
        while true {
            current = EchoCartographerCell(x: current.x + dx, y: current.y + dy)
            steps += 1
            if !isInside(current) {
                return EchoCartographerRay(direction: direction, open: open, wall: nil, distance: steps)
            }
            if walls.contains(index(current)) {
                return EchoCartographerRay(direction: direction, open: open, wall: current, distance: steps)
            }
            open.append(current)
        }
    }

    /// The path length of every cell from `from`: the fewest side steps through open cells (breadth-first search,
    /// neighbours in the order north, east, south, west), indexed by cell index; nil for walls and unreachable cells,
    /// and for every cell when `from` is not open.
    public func pathLengths(from: EchoCartographerCell) -> [Int?] {
        var lengths: [Int?] = Array(repeating: nil, count: cellCount)
        guard isOpen(from) else { return lengths }
        let start: Int = index(from)
        lengths[start] = 0
        var queue: [Int] = [start]
        var head: Int = 0
        while head < queue.count {
            let here: Int = queue[head]
            head += 1
            let cell: EchoCartographerCell = self.cell(here)
            let next: Int = (lengths[here] ?? 0) + 1
            for direction in EchoCartographerDirection.allCases {
                let (dx, dy) = direction.step
                let neighbour = EchoCartographerCell(x: cell.x + dx, y: cell.y + dy)
                guard isOpen(neighbour) else { continue }
                let n: Int = index(neighbour)
                if lengths[n] == nil {
                    lengths[n] = next
                    queue.append(n)
                }
            }
        }
        return lengths
    }

    /// The report of a pulse from `from` with the beacons at `beacons`: the four rays and the reachable beacons' path
    /// lengths, ascending.
    public func echo(from: EchoCartographerCell, beacons: [EchoCartographerCell]) -> EchoCartographerEcho {
        let rays: [EchoCartographerRay] = EchoCartographerDirection.allCases.map { ray(from: from, $0) }
        let lengths: [Int?] = pathLengths(from: from)
        var distances: [Int] = []
        for beacon in beacons where isInside(beacon) {
            if let length = lengths[index(beacon)] { distances.append(length) }
        }
        return EchoCartographerEcho(emitter: from, rays: rays, beaconDistances: distances.sorted())
    }
}

/// What the player knows of one cell.
public enum EchoCartographerKnown: String, Sendable, Codable {
    /// Not yet revealed.
    case unknown
    /// Revealed open (crossed by a ray, the entry, or a located beacon's cell).
    case open
    /// Revealed wall (struck by a ray).
    case wall
}

/// What the player knows of the chamber, per cell index. It starts with only the entry open and only grows.
public struct EchoCartographerKnowledge: Sendable, Hashable, Codable {
    /// The knowledge per cell index.
    public private(set) var cells: [EchoCartographerKnown]
    /// The chamber's width (to index cells).
    public let width: Int

    /// The opening knowledge of `chamber`: only `entry` known open.
    public init(chamber: EchoCartographerChamber, entry: EchoCartographerCell) {
        width = chamber.width
        var cells: [EchoCartographerKnown] = Array(repeating: .unknown, count: chamber.cellCount)
        if chamber.isInside(entry) { cells[chamber.index(entry)] = .open }
        self.cells = cells
    }

    /// The knowledge of the cell with index `index`.
    public subscript(_ index: Int) -> EchoCartographerKnown { cells[index] }

    /// The knowledge of `cell` (`.wall` outside the grid, whose border is known to every player).
    public subscript(_ cell: EchoCartographerCell) -> EchoCartographerKnown {
        guard cell.x >= 0, cell.x < width, cell.y >= 0, cell.y < cells.count / width else { return .wall }
        return cells[cell.y * width + cell.x]
    }

    /// The number of cells known open and known wall.
    public var revealed: (open: Int, wall: Int) {
        (cells.filter { $0 == .open }.count, cells.filter { $0 == .wall }.count)
    }

    /// Adds what `echo` revealed: every ray's open cells become known open, every struck wall known wall.
    public mutating func reveal(_ echo: EchoCartographerEcho) {
        for ray in echo.rays {
            for cell in ray.open { cells[cell.y * width + cell.x] = .open }
            if let wall = ray.wall { cells[wall.y * width + wall.x] = .wall }
        }
    }

    /// Marks `cell` (inside the grid) known open, as a located beacon's cell.
    public mutating func markOpen(_ cell: EchoCartographerCell) {
        cells[cell.y * width + cell.x] = .open
    }
}
