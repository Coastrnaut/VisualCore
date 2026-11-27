// MyceliumArchitectSolver — feature 512 (R02-G22-02) T-R02G2202-003 (FR-R02G2202-002; clarification Q3; research R3,
// R5). The source's "graph shortest path plus deterministic branching-growth heuristic and target topology check": a
// breadth-first search over arrangements by the number of actions from the start (the shortest path in the graph of
// arrangements), each judged by feature 511's deterministic growth; the first arrangement whose network reaches every
// terminal within the limit (the topology check) ends the search. Within a depth the arrangements are expanded in
// ascending loss (ties keep their discovery order) and the puzzle contract's move order; arrangements already reached
// at any depth are skipped (reachability, never pruning by outcome). Work is counted, never timed.

/// The breadth-first solver of Mycelium Architect.
public enum MyceliumArchitectSolver {
    /// The largest number of arrangements judged per search (a guard, counted).
    public static let workBound = 20_000

    /// The growth loss, zero exactly when the run wins: 16 × the Chebyshev distance from each unreached terminal to
    /// the nearest grown cell, plus the weight above the limit, plus 1 024 for a toxic or starved run.
    public static func loss(_ level: MyceliumArchitectLevel, _ report: MyceliumArchitectReport) -> Int {
        var total: Int = 0
        for (index, terminal) in level.terminals.enumerated() where report.terminalPulses[index] == nil {
            var nearest: Int = Int.max
            for cell in report.grown { nearest = min(nearest, cell.distance(to: terminal)) }
            total += 16 * nearest
        }
        total += max(0, report.totalWeight - level.weightLimit)
        if let failure = report.failure {
            switch failure {
            case .toxic, .starved: total += 1_024
            case .unreached, .overweight: break
            }
        }
        return total
    }

    /// A minimal plan of at most `maxDepth` arrangement actions, or nil when none exists within that depth or the
    /// work bound.
    public static func solve(_ level: MyceliumArchitectLevel, maxDepth: Int) -> MyceliumArchitectSolution? {
        let puzzle = MyceliumArchitectPuzzle(level: level)
        let start = level.start
        let startReport = MyceliumArchitectGrowth.report(level, arrangement: start)
        if startReport.wins { return nil }
        var parents: [MyceliumArchitectArrangement: (MyceliumArchitectArrangement, MyceliumArchitectAction)] = [:]
        var visited: Set<MyceliumArchitectArrangement> = [start]
        var work: Int = 1
        var counts: [Int] = [1]
        var bestLoss: Int = loss(level, startReport)
        var best: MyceliumArchitectArrangement = start
        var bestFailure: MyceliumArchitectFailure? = startReport.failure
        var layer: [(arrangement: MyceliumArchitectArrangement, loss: Int)] = [(start, bestLoss)]
        for depth in 0..<maxDepth {
            let ordered = layer.enumerated().sorted { a, b in
                a.element.loss != b.element.loss ? a.element.loss < b.element.loss : a.offset < b.offset
            }.map(\.element.arrangement)
            var next: [(arrangement: MyceliumArchitectArrangement, loss: Int)] = []
            var nextBest: (Int, MyceliumArchitectArrangement, MyceliumArchitectFailure?)?
            for arrangement in ordered {
                let state = MyceliumArchitectPuzzle.Position(arrangement: arrangement, actionsSpent: depth)
                for move in puzzle.moves(in: state) {
                    guard let after = puzzle.apply(move, to: state) else { continue }
                    let child = after.arrangement
                    if visited.contains(child) { continue }
                    visited.insert(child)
                    work += 1
                    if work > workBound { return nil }
                    parents[child] = (arrangement, move)
                    let report = MyceliumArchitectGrowth.report(level, arrangement: child)
                    if report.wins {
                        var actions: [MyceliumArchitectAction] = [.run]
                        var cursor = child
                        while let (parent, action) = parents[cursor] {
                            actions.insert(action, at: 0)
                            cursor = parent
                        }
                        return MyceliumArchitectSolution(actions: actions, work: work, countsByDepth: counts,
                                                         nearestMissLoss: bestLoss, nearestMiss: best,
                                                         nearestMissFailure: bestFailure)
                    }
                    let childLoss = loss(level, report)
                    next.append((child, childLoss))
                    if nextBest == nil || childLoss < nextBest!.0 { nextBest = (childLoss, child, report.failure) }
                }
            }
            if next.isEmpty { return nil }
            counts.append(next.count)
            if let candidate = nextBest, candidate.0 < bestLoss {
                bestLoss = candidate.0
                best = candidate.1
                bestFailure = candidate.2
            }
            layer = next
        }
        return nil
    }
}
