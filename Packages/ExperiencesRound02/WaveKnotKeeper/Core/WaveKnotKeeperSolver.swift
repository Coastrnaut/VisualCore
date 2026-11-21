// WaveKnotKeeperSolver — feature 322 (R02-G03-02) T-R02G0302-002 (types and search) with T-R02G0302-003 (tests)
// (FR-R02G0302-002; clarification Q2). The shortest solution of a level: a breadth-first search from the start over
// legal ropes (the kernel's `WaveKnotKeeperRules.moves` and `apply`), ropes compared by their points, to the first
// winning rope, depth at most ``WaveKnotKeeperSolver/maximumDepth``; at each depth the moves are tried in the rules'
// order, so the result is the first shortest sequence in that order. The work is the number of ropes expanded (at most
// 1 + 60 + 3,600 = 3,661 for a rope of 10 points). On the way the search records the first explored rope, in search
// order, that has a move the rules refuse with `r02-g03.move("crossing")`: the crossing counterexample of the witness;
// when the search wins before meeting one, the ropes discovered so far are scanned in search order. Feature 325
// (R02-G03-05) T-R02G0305-002 adds the search from a given rope (`solve(_:from:depth:)`), used by the hints.

/// A rope and a move on it that the rules refuse because a strand would pass through another outside a gate.
public struct WaveKnotKeeperCrossingExample: Sendable, Equatable, Hashable, Codable {
    /// The rope's control points.
    public let points: [WaveKnotKeeperPoint]
    /// The refused move.
    public let move: WaveKnotKeeperMove

    /// An example of the given values (not checked).
    public init(points: [WaveKnotKeeperPoint], move: WaveKnotKeeperMove) {
        self.points = points
        self.move = move
    }
}

/// The solver's result for one level.
public struct WaveKnotKeeperSolution: Sendable, Equatable, Hashable {
    /// The number of moves of the shortest solution.
    public let shortest: Int
    /// The first shortest move sequence in the rules' order.
    public let moves: [WaveKnotKeeperMove]
    /// The winning rope the moves reach.
    public let final: [WaveKnotKeeperPoint]
    /// The ropes expanded.
    public let work: Int
    /// The first explored rope with a crossing refusal, or nil when the search met none.
    public let crossing: WaveKnotKeeperCrossingExample?

    /// A solution of the given values (not checked).
    public init(shortest: Int, moves: [WaveKnotKeeperMove], final: [WaveKnotKeeperPoint], work: Int,
                crossing: WaveKnotKeeperCrossingExample?) {
        self.shortest = shortest
        self.moves = moves
        self.final = final
        self.work = work
        self.crossing = crossing
    }
}

/// The breadth-first solver of Wave Knot Keeper levels.
public enum WaveKnotKeeperSolver {
    /// The deepest search (the largest band range of the shortest solution).
    public static let maximumDepth = 3

    /// The shortest solution of `level` within `depth` moves, or nil when no legal rope within `depth` moves wins.
    /// The search from the level's start: ``solve(_:from:depth:)`` with `from: level.points`.
    public static func solve(_ level: WaveKnotKeeperLevel, depth: Int = maximumDepth) -> WaveKnotKeeperSolution? {
        solve(level, from: level.points, depth: depth)
    }

    /// The shortest solution of `level` from the rope `points` within `depth` moves, or nil when no legal rope within
    /// `depth` moves of `points` wins (feature 325, T-R02G0305-002; clarification Q1). The same certified breadth-first
    /// search as ``solve(_:depth:)`` — the same moves in the rules' order, the same tie rule — started from `points`
    /// instead of the level's start, so a hint follows the certified solution's order. `points` is not validated; it
    /// should be a rope reached by legal moves (a play's current rope).
    public static func solve(_ level: WaveKnotKeeperLevel, from points: [WaveKnotKeeperPoint],
                             depth: Int = maximumDepth) -> WaveKnotKeeperSolution? {
        let start: [WaveKnotKeeperPoint] = points
        guard depth >= 0 else { return nil }
        // Each node: its rope, its parent's index and the move that reached it (none for the start).
        var ropes: [[WaveKnotKeeperPoint]] = [start]
        var parents: [Int] = [-1]
        var reached: [WaveKnotKeeperMove?] = [nil]
        var seen: Set<[WaveKnotKeeperPoint]> = [start]
        var crossing: WaveKnotKeeperCrossingExample?
        var work = 0
        if level.wins(start) {
            return WaveKnotKeeperSolution(shortest: 0, moves: [], final: start, work: 0, crossing: nil)
        }
        var frontier: [Int] = [0]
        for _ in 0..<depth {
            var next: [Int] = []
            for node in frontier {
                let rope = ropes[node]
                work += 1
                for point in rope.indices {
                    for direction in WaveKnotKeeperDirection.allCases {
                        let move = WaveKnotKeeperMove(point: point, direction: direction)
                        if let refusal = WaveKnotKeeperPlay.refusal(of: move, points: rope, level: level) {
                            if crossing == nil, refusal == .move("crossing") {
                                crossing = WaveKnotKeeperCrossingExample(points: rope, move: move)
                            }
                            continue
                        }
                        var child = rope
                        child[point] = rope[point].moved(direction)
                        guard seen.insert(child).inserted else { continue }
                        ropes.append(child)
                        parents.append(node)
                        reached.append(move)
                        let index = ropes.count - 1
                        if level.wins(child) {
                            var moves: [WaveKnotKeeperMove] = []
                            var walk = index
                            while let step = reached[walk] {
                                moves.append(step)
                                walk = parents[walk]
                            }
                            moves.reverse()
                            let example = crossing ?? firstCrossing(in: ropes, level: level)
                            return WaveKnotKeeperSolution(shortest: moves.count, moves: moves, final: child, work: work,
                                                          crossing: example)
                        }
                        next.append(index)
                    }
                }
            }
            frontier = next
        }
        return nil
    }

    /// The first rope of `ropes`, in order, with a move the rules refuse as `move("crossing")`, and that move; nil when
    /// none has one. Used when the search wins before it met a crossing refusal: the ropes discovered so far are
    /// scanned in search order.
    static func firstCrossing(in ropes: [[WaveKnotKeeperPoint]],
                              level: WaveKnotKeeperLevel) -> WaveKnotKeeperCrossingExample? {
        for rope in ropes {
            for point in rope.indices {
                for direction in WaveKnotKeeperDirection.allCases {
                    let move = WaveKnotKeeperMove(point: point, direction: direction)
                    if WaveKnotKeeperPlay.refusal(of: move, points: rope, level: level) == .move("crossing") {
                        return WaveKnotKeeperCrossingExample(points: rope, move: move)
                    }
                }
            }
        }
        return nil
    }
}
