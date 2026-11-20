// GridGraph — feature 216 (R02-F16) T-R02F16-002 (FR-R02F16-001; clarification Q1). A width × height grid of open and
// blocked cells, node id y·width + x, turned into a unit-cost `RouteGraph`. Neighbour offsets are taken in the fixed
// order (0, −1), (1, 0), (0, 1), (−1, 0) and, for the eight-neighbourhood, (1, −1), (1, 1), (−1, 1), (−1, −1); a
// diagonal move exists only when both orthogonal cells beside it are open (no corner cutting). Blocked cells have no
// edges in or out. The estimates (Manhattan for four neighbours, Chebyshev for eight) never overestimate unit costs.

/// Which neighbours of a grid cell are joined.
public enum GridNeighbourhood: String, Sendable, Codable, CaseIterable {
    /// Up, right, down, left.
    case four
    /// The four plus the diagonals, without corner cutting.
    case eight
}

/// A rectangular grid of open and blocked cells.
public struct GridGraph: Sendable, Equatable {
    /// The largest width or height.
    public static let maxSide = 4_096
    /// The most cells a grid has.
    public static let maxCells = 1_048_576

    /// Cells across.
    public let width: Int
    /// Cells down.
    public let height: Int
    /// Which neighbours are joined.
    public let neighbourhood: GridNeighbourhood
    private let blockedCells: [Bool]

    /// Creates a grid; refuses a side of 0 with ``RouteError/emptyGraph``, a side above ``maxSide`` or more than
    /// ``maxCells`` cells with ``RouteError/graphLimit(_:)``, and a blocked node outside the grid with
    /// ``RouteError/nodeRange(_:)``.
    public init(width: Int, height: Int, neighbourhood: GridNeighbourhood = .four,
                blocked: Set<Int> = []) throws(RouteError) {
        guard width > 0, height > 0 else { throw .emptyGraph }
        guard width <= Self.maxSide, height <= Self.maxSide else { throw .graphLimit("side") }
        guard width * height <= Self.maxCells else { throw .graphLimit("cells") }
        var cells = Array(repeating: false, count: width * height)
        for node in blocked.sorted() {
            guard node >= 0, node < cells.count else { throw .nodeRange(node) }
            cells[node] = true
        }
        self.width = width
        self.height = height
        self.neighbourhood = neighbourhood
        blockedCells = cells
    }

    /// The node of cell (x, y), y·width + x (not checked; use ``isOpen(_:)`` to test a node).
    public func node(x: Int, y: Int) -> Int { y * width + x }

    /// The cell of `node`.
    public func cell(of node: Int) -> (x: Int, y: Int) { (node % width, node / width) }

    /// Whether `node` is a cell of the grid and not blocked.
    public func isOpen(_ node: Int) -> Bool { node >= 0 && node < blockedCells.count && !blockedCells[node] }

    private func isOpen(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height && !blockedCells[y * width + x]
    }

    /// The grid as a unit-cost graph with edges in the fixed offset order (see the file header).
    public func graph() -> RouteGraph {
        // The grid's limits are within the graph's, so no addEdge below can fail.
        guard var graph = try? RouteGraph(nodeCount: width * height) else { preconditionFailure("grid within limits") }
        let orthogonal = [(0, -1), (1, 0), (0, 1), (-1, 0)]
        let diagonal = [(1, -1), (1, 1), (-1, 1), (-1, -1)]
        for y in 0..<height {
            for x in 0..<width where isOpen(x: x, y: y) {
                let from = node(x: x, y: y)
                for (dx, dy) in orthogonal where isOpen(x: x + dx, y: y + dy) {
                    try? graph.addEdge(from: from, to: node(x: x + dx, y: y + dy))
                }
                if neighbourhood == .eight {
                    for (dx, dy) in diagonal
                    where isOpen(x: x + dx, y: y + dy) && isOpen(x: x + dx, y: y) && isOpen(x: x, y: y + dy) {
                        try? graph.addEdge(from: from, to: node(x: x + dx, y: y + dy))
                    }
                }
            }
        }
        return graph
    }

    /// An estimate of the remaining steps to `goal` that never overestimates: Manhattan distance for four neighbours,
    /// Chebyshev distance for eight.
    public func estimate(to goal: Int) -> @Sendable (Int) -> Int {
        let w = width
        let gx = goal % w, gy = goal / w
        let eight = neighbourhood == .eight
        return { node in
            let dx = abs(node % w - gx), dy = abs(node / w - gy)
            return eight ? max(dx, dy) : dx + dy
        }
    }
}
