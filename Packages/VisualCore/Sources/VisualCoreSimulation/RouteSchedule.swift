// RouteSchedule — feature 216 (R02-F16) T-R02F16-002 (FR-R02F16-003; clarification Q3). Which cells are open at each
// time step t in 0 ..< T, for routes through time. A state (cell, t) outside the schedule is closed. Limits: T 1 … 4,096
// and cells × T ≤ 16,777,216, so the open bits fit in 16 MiB.

/// A state of a route through time: a node at a time step.
public struct TimedState: Sendable, Equatable, Hashable, Codable {
    /// The node.
    public let node: Int
    /// The time step.
    public let time: Int

    /// Creates the state.
    public init(node: Int, time: Int) {
        self.node = node
        self.time = time
    }
}

/// Which cells are open at each time step.
public struct RouteSchedule: Sendable, Equatable {
    /// The most time steps.
    public static let maxSteps = 4_096
    /// The most (cell, time) states.
    public static let maxStates = 16_777_216

    /// The number of cells (equal to the graph's node count when used with a graph).
    public let cellCount: Int
    /// The number of time steps T.
    public let steps: Int
    private let open: [Bool]

    /// Creates a schedule by asking `isOpen` for every cell at every step, time-major; refuses 0 cells or steps with
    /// ``RouteError/emptyGraph`` and sizes beyond the limits with ``RouteError/scheduleLimit``.
    public init(cellCount: Int, steps: Int, isOpen: (_ cell: Int, _ time: Int) -> Bool) throws(RouteError) {
        guard cellCount > 0, steps > 0 else { throw .emptyGraph }
        guard cellCount <= RouteGraph.maxNodes, steps <= Self.maxSteps, cellCount * steps <= Self.maxStates else {
            throw .scheduleLimit
        }
        var bits = [Bool]()
        bits.reserveCapacity(cellCount * steps)
        for t in 0..<steps {
            for cell in 0..<cellCount { bits.append(isOpen(cell, t)) }
        }
        self.cellCount = cellCount
        self.steps = steps
        open = bits
    }

    /// Whether `cell` is open at `time`; false outside 0 ..< ``steps`` or 0 ..< ``cellCount``.
    public func isOpen(_ cell: Int, at time: Int) -> Bool {
        guard cell >= 0, cell < cellCount, time >= 0, time < steps else { return false }
        return open[time * cellCount + cell]
    }
}
