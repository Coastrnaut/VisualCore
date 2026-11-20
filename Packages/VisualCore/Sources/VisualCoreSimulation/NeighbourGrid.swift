// NeighbourGrid — feature 220 (R02-F20) T-R02F20-003 (FR-R02F20-001, 002; clarification Q2; research R1, R2). A hashed
// uniform grid over a fixed set of agents that answers the same neighbour query as `NeighbourSearch`, list for list and
// in the same order, while scanning only the cells near the asking agent. Cells are integer pairs
// (⌊x / cellSize⌋, ⌊y / cellSize⌋) clamped to ±2^40, so far agents never overflow; only finite agents are bucketed.
// A query scans the cells within w = ⌈radius / cellSize⌉ + 1 of its own cell (the extra ring absorbs rounding of the
// divisions), or every finite agent once when that window would cover more cells than are occupied; distances, the
// radius test, the sort and the limit are the same expressions as `NeighbourSearch`.
import Foundation
import VisualCoreMath

/// A uniform hashed grid that finds the neighbours of an agent exactly as ``NeighbourSearch`` does, but faster.
public struct NeighbourGrid: Sendable {
    /// The largest number of agents a grid accepts.
    public static let maxAgents = 65_536
    /// The largest cell coordinate magnitude; cell indices are clamped to ±2^40.
    static let cellLimit = 1_099_511_627_776.0

    /// The side length of a cell in world units.
    public let cellSize: Double

    /// An integer cell coordinate.
    struct Cell: Hashable, Sendable {
        /// Column and row.
        var x: Int, y: Int
    }

    /// The agents the grid was built from, in their original order.
    let agents: [SteeringAgent]
    /// For each occupied cell, the start and count of its agents in ``ordered``.
    let buckets: [Cell: (start: Int, count: Int)]
    /// Finite agent indices grouped by cell, ascending inside each cell.
    let ordered: [Int]
    /// The indices of every finite agent, ascending.
    let finite: [Int]

    /// Builds a grid over `agents` with square cells of side `cellSize`.
    ///
    /// - Throws: `.agentLimit(count)` for more than 65,536 agents, `.parameter("cellSize")` unless `cellSize` is finite
    ///   and greater than 0.
    public init(agents: [SteeringAgent], cellSize: Double) throws(SwarmError) {
        guard agents.count <= Self.maxAgents else { throw .agentLimit(agents.count) }
        guard cellSize.isFinite, cellSize > 0 else { throw .parameter("cellSize") }
        self.cellSize = cellSize
        self.agents = agents
        var cellOf: [Cell] = []
        var finite: [Int] = []
        cellOf.reserveCapacity(agents.count)
        finite.reserveCapacity(agents.count)
        var counts: [Cell: Int] = [:]
        for (i, agent) in agents.enumerated() where agent.position.isFinite {
            let cell = Self.cell(of: agent.position, cellSize: cellSize)
            finite.append(i)
            cellOf.append(cell)
            counts[cell, default: 0] += 1
        }
        var buckets: [Cell: (start: Int, count: Int)] = [:]
        buckets.reserveCapacity(counts.count)
        var next = 0
        for (cell, count) in counts {
            buckets[cell] = (next, 0)
            next += count
        }
        var ordered = [Int](repeating: 0, count: finite.count)
        for k in 0..<finite.count {
            let cell = cellOf[k]
            let slot = buckets[cell]!
            ordered[slot.start + slot.count] = finite[k]
            buckets[cell] = (slot.start, slot.count + 1)
        }
        self.buckets = buckets
        self.ordered = ordered
        self.finite = finite
    }

    /// The clamped cell holding a finite position.
    static func cell(of p: Vec2, cellSize: Double) -> Cell {
        func index(_ v: Double) -> Int {
            let f = (v / cellSize).rounded(.down)
            return Int(Swift.min(Swift.max(f, -cellLimit), cellLimit))
        }
        return Cell(x: index(p.x), y: index(p.y))
    }

    /// The indices of at most `limit` agents within `radius` of agent `index`, nearest first, ties by index.
    ///
    /// Equal to `NeighbourSearch.neighbours(of: index, in: agents, radius: radius, limit: limit)` for the agents the
    /// grid was built from. Agent `index` itself and agents with a non-finite position are never returned. Returns `[]`
    /// for an out-of-range `index`, a negative or non-finite `radius`, a `limit` of 0 or less, or a non-finite
    /// position of agent `index`.
    public func neighbours(of index: Int, radius: Double, limit: Int) -> [Int] {
        guard agents.indices.contains(index), radius.isFinite, radius >= 0, limit > 0 else { return [] }
        let own = agents[index].position
        guard own.isFinite else { return [] }
        var found: [(distance: Double, index: Int)] = []

        let w = (radius / cellSize).rounded(.up) + 1
        let side = 2 * w + 1
        if !side.isFinite || side * side > Double(buckets.count) {
            for j in finite where j != index {
                let d = own.distance(to: agents[j].position)
                if d <= radius { found.append((d, j)) }
            }
        } else {
            let span = Int(w)
            let centre = Self.cell(of: own, cellSize: cellSize)
            for cy in (centre.y - span)...(centre.y + span) {
                for cx in (centre.x - span)...(centre.x + span) {
                    guard let slot = buckets[Cell(x: cx, y: cy)] else { continue }
                    for k in slot.start..<(slot.start + slot.count) {
                        let j = ordered[k]
                        if j == index { continue }
                        let d = own.distance(to: agents[j].position)
                        if d <= radius { found.append((d, j)) }
                    }
                }
            }
        }
        found.sort { $0.distance != $1.distance ? $0.distance < $1.distance : $0.index < $1.index }
        return found.prefix(limit).map(\.index)
    }
}
