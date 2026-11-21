// WaveKnotKeeperSolverTests — feature 322 (R02-G03-02) T-R02G0302-003 (FR-R02G0302-002; SC-R02G0302-002; clarification
// Q2). The breadth-first solver of Wave Knot Keeper: hand-built levels one, two and three moves from a winning rope (the
// one-move level asserted literally, all against an independent search); a level beyond depth 1 refused at depth 1 and
// solved at depth 3; the shortest length against a plain breadth-first search over `WaveKnotKeeperRules` on seeded
// levels; replay of the moves through `WaveKnotKeeperRules.apply` to the reported winning rope; the crossing
// counterexample refused by `WaveKnotKeeperPlay.refusal` with `move("crossing")`; the work bound 1 + 60 + 3,600 = 3,661
// for ropes of at most 10 points; determinism. A level is built backwards: a random simple rope with a non-degenerate
// projection is the goal (the target is its crossing count and writhe) and one to three seeded legal moves scramble it to
// a start that does not win; the tension bound is the largest allowed, so only range, bounds, coincidence and crossing
// refuse a move. Seed 2_322 (`SeededRandom`). Explicit types, plain loops, short runs, no clock.
import Testing
@testable import WaveKnotKeeperCore
import VisualCoreSimulation

/// Seeded solver levels built backwards from a winning rope.
private enum SolverLevels {
    /// The suite's seed.
    static let seed: UInt64 = 2_322

    /// A random simple rope of `count` points in −`spread` … `spread` whose projection is not degenerate.
    static func rope(_ random: inout SeededRandom, count: Int, spread: Int) -> [WaveKnotKeeperPoint] {
        while true {
            var points: [WaveKnotKeeperPoint] = []
            var seen: Set<WaveKnotKeeperPoint> = []
            while points.count < count {
                let p: WaveKnotKeeperPoint = WaveKnotKeeperPoint(x: random.int(-spread...spread),
                                                                 y: random.int(-spread...spread),
                                                                 z: random.int(-spread...spread))
                if seen.insert(p).inserted { points.append(p) }
            }
            if WaveKnotKeeperGeometry.isSimple(points) && !WaveKnotKeeperGeometry.summary(points).degenerate {
                return points
            }
        }
    }

    /// A level `steps` seeded legal moves from a random winning rope of `count` points, or nil when the draw is refused
    /// (the walk stalls, the start already wins, or the level initialiser refuses it).
    static func candidate(_ random: inout SeededRandom, count: Int, steps: Int, index: Int) -> WaveKnotKeeperLevel? {
        let goal: [WaveKnotKeeperPoint] = rope(&random, count: count, spread: random.int(2...4))
        let summary: WaveKnotKeeperSummary = WaveKnotKeeperGeometry.summary(goal)
        guard let target = try? WaveKnotKeeperTarget(crossings: summary.crossings, writhe: summary.writhe) else {
            return nil
        }
        let probe: WaveKnotKeeperFixtures.ProbeLevel = WaveKnotKeeperFixtures.ProbeLevel(gates: [])
        var points: [WaveKnotKeeperPoint] = goal
        var walked: Int = 0
        var attempts: Int = 0
        while walked < steps && attempts < 200 {
            attempts += 1
            let move: WaveKnotKeeperMove = WaveKnotKeeperMove(point: random.int(0...(count - 1)),
                                                              direction: WaveKnotKeeperDirection.allCases[random.int(0...5)])
            guard probe.legal(move, points) else { continue }
            points[move.point] = points[move.point].moved(move.direction)
            walked += 1
        }
        guard walked == steps else { return nil }
        return try? WaveKnotKeeperLevel(id: "solver-\(index)", seed: seed &+ UInt64(index), band: 1, points: points,
                                        gates: [], target: target, tensionBound: 49_152, allowance: 12)
    }

    /// The first `total` levels of `count` points `steps` moves from their goal, drawn from `seed` and `stream`.
    static func make(_ total: Int, count: Int, steps: Int, stream: UInt64) -> [WaveKnotKeeperLevel] {
        var random: SeededRandom = SeededRandom(seed: seed &+ stream &* 7_919)
        var result: [WaveKnotKeeperLevel] = []
        var index: Int = 0
        while result.count < total {
            index += 1
            if let level = candidate(&random, count: count, steps: steps, index: index) { result.append(level) }
        }
        return result
    }

    /// Eight mixed levels: 6 to 8 points, one to three moves from their goal.
    static let mixed: [WaveKnotKeeperLevel] = {
        var result: [WaveKnotKeeperLevel] = []
        var n: Int = 0
        while n < 8 {
            let levels: [WaveKnotKeeperLevel] = make(1, count: 6 + n % 3, steps: 1 + n % 3, stream: UInt64(100 + n))
            result.append(levels[0])
            n += 1
        }
        return result
    }()
}

/// An independent plain breadth-first search over the R02-F23 rules, depth at most `depth`: the number of moves of the
/// shortest solution, or nil when none within `depth` wins.
private func plainShortest(_ level: WaveKnotKeeperLevel, depth: Int) -> Int? {
    let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: level)
    let start: [WaveKnotKeeperPoint] = rules.initialState
    if rules.isSolved(start) { return 0 }
    var visited: Set<[WaveKnotKeeperPoint]> = [start]
    var layer: [[WaveKnotKeeperPoint]] = [start]
    var distance: Int = 0
    while distance < depth && !layer.isEmpty {
        distance += 1
        var nextLayer: [[WaveKnotKeeperPoint]] = []
        for state in layer {
            for move in rules.moves(in: state) {
                guard let child = rules.apply(move, to: state) else { continue }
                if rules.isSolved(child) { return distance }
                if visited.insert(child).inserted { nextLayer.append(child) }
            }
        }
        layer = nextLayer
    }
    return nil
}

@Suite("Wave Knot Keeper solver (FR-R02G0302-002)")
struct WaveKnotKeeperSolverTests {
    /// A level one move from its goal has shortest solution exactly 1; levels two and three moves away solve within
    /// their walk, and every shortest equals the independent search.
    @Test func handBuiltLevelsOneTwoAndThreeMovesAway() throws {
        var steps: Int = 1
        while steps <= 3 {
            let levels: [WaveKnotKeeperLevel] = SolverLevels.make(2, count: 7, steps: steps, stream: UInt64(steps))
            for level in levels {
                let solution: WaveKnotKeeperSolution = try #require(WaveKnotKeeperSolver.solve(level))
                #expect(solution.shortest == plainShortest(level, depth: 3))
                #expect(solution.shortest >= 1)
                #expect(solution.shortest <= steps)
                #expect(solution.moves.count == solution.shortest)
                if steps == 1 { #expect(solution.shortest == 1) }
            }
            steps += 1
        }
    }

    /// A level whose shortest solution is longer than one move gives nil at depth 1 and a solution at depth 3.
    @Test func depthBoundRefusesThenSolves() throws {
        var found: WaveKnotKeeperLevel?
        var stream: UInt64 = 200
        while found == nil && stream < 260 {
            let level: WaveKnotKeeperLevel = SolverLevels.make(1, count: 7, steps: 3, stream: stream)[0]
            if let shortest = plainShortest(level, depth: 3), shortest >= 2 { found = level }
            stream += 1
        }
        let level: WaveKnotKeeperLevel = try #require(found)
        #expect(WaveKnotKeeperSolver.solve(level, depth: 1) == nil)
        #expect(WaveKnotKeeperSolver.solve(level, depth: 0) == nil)
        let solution: WaveKnotKeeperSolution = try #require(WaveKnotKeeperSolver.solve(level, depth: 3))
        #expect(solution.shortest >= 2)
        #expect(solution.shortest == plainShortest(level, depth: 3))
    }

    /// On eight seeded levels the solver's shortest length equals a plain breadth-first search over the rules.
    @Test func shortestMatchesPlainBreadthFirstSearch() throws {
        #expect(SolverLevels.mixed.count >= 6)
        for level in SolverLevels.mixed {
            let solution: WaveKnotKeeperSolution = try #require(WaveKnotKeeperSolver.solve(level))
            #expect(solution.shortest == plainShortest(level, depth: WaveKnotKeeperSolver.maximumDepth))
        }
    }

    /// The moves replay through `WaveKnotKeeperRules.apply` over legal ropes to `final`, which wins; no earlier rope wins.
    @Test func movesReplayToWinningFinal() throws {
        for level in SolverLevels.mixed {
            let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: level)
            let solution: WaveKnotKeeperSolution = try #require(WaveKnotKeeperSolver.solve(level))
            var rope: [WaveKnotKeeperPoint] = rules.initialState
            for move in solution.moves {
                #expect(!level.wins(rope))
                #expect(rules.moves(in: rope).contains(move))
                rope = try #require(rules.apply(move, to: rope))
                #expect(WaveKnotKeeperGeometry.isSimple(rope))
            }
            #expect(rope == solution.final)
            #expect(level.wins(solution.final))
            #expect(rules.isSolved(solution.final))
        }
    }

    /// Every returned crossing counterexample is refused by the play with `move("crossing")`, and at least one level of
    /// the seeded set returns one.
    @Test func crossingCounterexampleIsRefused() throws {
        var examples: Int = 0
        var levels: [WaveKnotKeeperLevel] = SolverLevels.mixed
        levels.append(contentsOf: SolverLevels.make(4, count: 8, steps: 2, stream: 300))
        for level in levels {
            let solution: WaveKnotKeeperSolution = try #require(WaveKnotKeeperSolver.solve(level))
            guard let crossing = solution.crossing else { continue }
            examples += 1
            #expect(WaveKnotKeeperPlay.refusal(of: crossing.move, points: crossing.points, level: level)
                    == .move("crossing"))
            #expect(WaveKnotKeeperRules(level: level).apply(crossing.move, to: crossing.points) == nil)
        }
        #expect(examples >= 1)
    }

    /// For ropes of at most 10 points the search expands at most 1 + 60 + 3,600 = 3,661 ropes.
    @Test func workIsBounded() throws {
        var levels: [WaveKnotKeeperLevel] = SolverLevels.mixed
        levels.append(contentsOf: SolverLevels.make(2, count: 10, steps: 3, stream: 400))
        for level in levels {
            #expect(level.points.count <= 10)
            let solution: WaveKnotKeeperSolution = try #require(WaveKnotKeeperSolver.solve(level))
            #expect(solution.work >= 1)
            #expect(solution.work <= 3_661)
        }
    }

    /// Solving the same level twice gives equal solutions.
    @Test func solvingIsDeterministic() throws {
        for level in SolverLevels.mixed {
            let first: WaveKnotKeeperSolution? = WaveKnotKeeperSolver.solve(level)
            let second: WaveKnotKeeperSolution? = WaveKnotKeeperSolver.solve(level)
            #expect(first != nil)
            #expect(first == second)
        }
    }
}
