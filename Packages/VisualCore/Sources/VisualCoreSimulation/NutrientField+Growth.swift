// NutrientField+Growth — feature 221 (R02-F21) T-R02F21-004 (FR-R02F21-005; clarification Q4; research R6, R7). The
// growth phase of a frame and the hand-off of the grown network to the route solvers. Candidates are the 4-neighbours of
// network cells inside the grid, outside the network, with viability at least the threshold and at least `cost` quanta
// of the food channel; they are ranked by food (most first), then cell index, and taken in that order up to `perFrame`
// a frame while the network stays within `limit`. Each new cell links to its lowest-index network neighbour and eats
// `cost` from its own cell, counted as eaten. The order is fixed by the network's cell order and a total sort, never by
// set iteration, so two runs from the same state are identical.

extension NutrientField {
    /// Grows the network once (called by ``step(by:)`` once per frame with t > 0) and returns the cells grown and the
    /// quanta of the food channel eaten; (0, 0) without a network or with nowhere viable to go.
    mutating func growthPhase() -> (grown: Int, eaten: Int64) {
        guard var net = network else { return (0, 0) }
        let n = cellCount
        let food = net.foodChannel
        let base = food * n

        // Gather candidates in the network's cell order; `seen` keeps each candidate once.
        var seen = [Bool](repeating: false, count: n)
        var candidates: [Int] = []
        for cell in net.cells {
            for neighbour in neighbours(of: cell) where !seen[neighbour] && !net.contains(neighbour) {
                seen[neighbour] = true
                if viability(at: neighbour) >= net.threshold && amountQ[base + neighbour] >= net.cost {
                    candidates.append(neighbour)
                }
            }
        }
        // Most food first, then the lower index: a total order, so the result does not depend on gathering order.
        candidates.sort { (a: Int, b: Int) -> Bool in
            let fa = amountQ[base + a]
            let fb = amountQ[base + b]
            return fa != fb ? fa > fb : a < b
        }

        var grown = 0
        var eaten: Int64 = 0
        for cell in candidates {
            if grown >= net.perFrame || net.count >= net.limit { break }
            // A candidate's own cell changes only when it is taken, so this holds; kept as a guard.
            guard amountQ[base + cell] >= net.cost else { continue }
            var parent = -1
            for neighbour in neighbours(of: cell) where net.contains(neighbour) {
                if parent < 0 || neighbour < parent { parent = neighbour }
            }
            // Every candidate neighbours a cell that was in the network when the frame began.
            guard parent >= 0 else { continue }
            net.append(cell, parent: parent)
            amountQ[base + cell] -= net.cost
            totalQ[food] -= net.cost
            ledger.accounts[food].eaten += net.cost
            eaten += net.cost
            grown += 1
        }
        network = net
        return (grown, eaten)
    }

    /// The 4-neighbours of `cell` inside the grid, in the order below, left, right, above.
    private func neighbours(of cell: Int) -> [Int] {
        let x = cell % width
        let y = cell / width
        var result: [Int] = []
        result.reserveCapacity(4)
        if y > 0 { result.append(cell - width) }
        if x > 0 { result.append(cell - 1) }
        if x + 1 < width { result.append(cell + 1) }
        if y + 1 < height { result.append(cell + width) }
        return result
    }

    /// The grown network as a `RouteGraph` over every grid cell (node y · width + x, as `GridGraph`) with one undirected
    /// edge of cost 1 between each grown cell and the cell it linked to; a graph without edges when there is no network.
    ///
    /// Each tree of the network is connected, so the existing route solvers find a route between any two of its cells.
    public func networkGraph() -> RouteGraph {
        do {
            var graph = try RouteGraph(nodeCount: cellCount)
            if let net = network {
                for i in 0..<net.count where net.parents[i] >= 0 {
                    try graph.addUndirectedEdge(net.cells[i], net.parents[i], cost: 1)
                }
            }
            return graph
        } catch {
            // At most 262,144 nodes (≤ 1,048,576), at most 2 · 65,536 edges (≤ 4,194,304), cost 1 and cells checked by
            // setNetwork and seed: none of RouteGraph's refusals can be reached.
            preconditionFailure("NutrientField network graph within RouteGraph limits: \(error)")
        }
    }
}
