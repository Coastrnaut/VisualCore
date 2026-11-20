// LissajousLabyrinthSolverTests — feature 312 (R02-G02-02) T-R02G0202-003 (FR-R02G0202-002; clarification Q2; research
// R1–R3). The legal setting space; the exact decision against the kernel's verdict (all 14,080 settings of two levels;
// winners, 440 random settings and the admitted losers of twenty more); the shortest solution against a plain
// breadth-first search over legal states; replay of the action list through `Rules.apply` to a setting the kernel
// confirms; the tie rule; determinism; an unsolvable level. Seeded levels (seed 2_312) are built around a random target
// setting so most are solvable. Test data uses explicit types and plain loops (CI type-check rule).
@testable import LissajousLabyrinthCore
import Testing
import VisualCoreSimulation

/// Seeded solver levels: checkpoints on a target lap at increasing ticks, obstacles the target lap clears, a start that
/// changes one to three dials of the target.
private enum SolverLevels {
    /// The suite's seed.
    static let seed: UInt64 = 2_312

    /// The first `count` levels drawn from the suite's seed.
    static func make(_ count: Int) -> [LissajousLabyrinthLevel] {
        var random = SeededRandom(seed: seed)
        var result: [LissajousLabyrinthLevel] = []
        while result.count < count {
            if let level = candidate(&random) { result.append(level) }
        }
        return result
    }

    /// Fifty levels, drawn once.
    static let fifty: [LissajousLabyrinthLevel] = make(50)

    /// Random valid dials.
    static func dials(_ random: inout SeededRandom) -> LissajousLabyrinthDials {
        while true {
            let d = LissajousLabyrinthDials(frequencyA: random.int(1...9), frequencyB: random.int(1...9),
                                            phaseA: random.int(0...15), phaseC: random.int(0...15))
            if d.isValid { return d }
        }
    }

    /// One candidate level, or nil when a draw is refused (a ball out of range, an invalid or winning start).
    static func candidate(_ random: inout SeededRandom) -> LissajousLabyrinthLevel? {
        let amplitudes: [Int] = [random.int(1...4), random.int(1...4), random.int(1...4)]
        let frequencyC: Int = random.int(1...9)
        let target: LissajousLabyrinthDials = dials(&random)
        guard let far = try? LissajousLabyrinthBall(x: 5_000, y: 5_000, z: 5_000, radius: 64),
              let probe = try? LissajousLabyrinthLevel(id: "probe", seed: 0, band: 1, amplitudes: amplitudes,
                                                       frequencyC: frequencyC, start: target, checkpoints: [far],
                                                       obstacles: [], allowance: 12) else { return nil }
        let points: [LissajousLabyrinthPoint] = LissajousLabyrinthLap.samples(target, level: probe)
        let count: Int = random.int(2...4)
        var ticks: [Int] = []
        while ticks.count < count {
            let t: Int = random.int(0...4_095)
            if !ticks.contains(t) { ticks.append(t) }
        }
        ticks.sort()
        var checkpoints: [LissajousLabyrinthBall] = []
        for t in ticks {
            let p: LissajousLabyrinthPoint = points[t]
            guard let ball = try? LissajousLabyrinthBall(x: p.x, y: p.y, z: p.z, radius: random.int(300...600)) else {
                return nil
            }
            checkpoints.append(ball)
        }
        var obstacles: [LissajousLabyrinthBall] = []
        let wanted: Int = random.int(0...4)
        var attempts: Int = 0
        while obstacles.count < wanted && attempts < 40 {
            attempts += 1
            guard let ball = try? LissajousLabyrinthBall(x: random.int(-4_000...4_000), y: random.int(-4_000...4_000),
                                                         z: random.int(-4_000...4_000),
                                                         radius: random.int(64...512)) else { continue }
            var touches: Bool = false
            for n in 0..<LissajousLabyrinthLap.ticks
            where LissajousLabyrinthLap.segmentTouches(points[n], points[(n + 1) % LissajousLabyrinthLap.ticks],
                                                       ball: ball) {
                touches = true
                break
            }
            if !touches { obstacles.append(ball) }
        }
        var start: LissajousLabyrinthDials = target
        let changes: Int = random.int(1...3)
        var dialsToChange: [LissajousLabyrinthDial] = []
        while dialsToChange.count < changes {
            let dial: LissajousLabyrinthDial = LissajousLabyrinthDial.allCases[random.int(0...3)]
            if !dialsToChange.contains(dial) { dialsToChange.append(dial) }
        }
        for dial in dialsToChange {
            var value: Int = start[dial]
            while value == start[dial] { value = random.int(dial.range) }
            start[dial] = value
        }
        guard start.isValid else { return nil }
        return try? LissajousLabyrinthLevel(id: "solver", seed: random.next(), band: random.int(1...5),
                                            amplitudes: amplitudes, frequencyC: frequencyC, start: start,
                                            checkpoints: checkpoints, obstacles: obstacles, allowance: 12)
    }

    /// The shortest solution by a plain breadth-first search over legal states that judges a state by membership in
    /// `winning`; nil when nothing reachable wins.
    static func plainShortest(_ level: LissajousLabyrinthLevel, winning: Set<LissajousLabyrinthDials>) -> Int? {
        let rules = LissajousLabyrinthRules(level: level)
        var seen: Set<LissajousLabyrinthDials> = [level.start]
        var frontier: [LissajousLabyrinthDials] = [level.start]
        var depth: Int = 0
        while !frontier.isEmpty {
            for state in frontier where winning.contains(state) { return depth }
            var next: [LissajousLabyrinthDials] = []
            for state in frontier {
                for move in rules.moves(in: state) {
                    guard let reached = rules.apply(move, to: state) else { continue }
                    if seen.insert(reached).inserted { next.append(reached) }
                }
            }
            frontier = next
            depth += 1
        }
        return nil
    }

    /// The states first reached at `depth` from the start.
    static func layer(_ level: LissajousLabyrinthLevel, depth: Int) -> Set<LissajousLabyrinthDials> {
        let rules = LissajousLabyrinthRules(level: level)
        var seen: Set<LissajousLabyrinthDials> = [level.start]
        var frontier: [LissajousLabyrinthDials] = [level.start]
        for _ in 0..<depth {
            var next: [LissajousLabyrinthDials] = []
            for state in frontier {
                for move in rules.moves(in: state) {
                    guard let reached = rules.apply(move, to: state) else { continue }
                    if seen.insert(reached).inserted { next.append(reached) }
                }
            }
            frontier = next
        }
        return Set(frontier)
    }
}

@Suite struct LissajousLabyrinthSolverTests {
    @Test func legalSettingsAreTheOrderedCoprimeSpace() {
        let settings: [LissajousLabyrinthDials] = LissajousLabyrinthSolver.legalSettings()
        #expect(settings.count == 14_080)
        var unique: Set<LissajousLabyrinthDials> = []
        for dials in settings {
            #expect(dials.isValid)
            unique.insert(dials)
        }
        #expect(unique.count == settings.count)
        for i in 1..<settings.count {
            let p: LissajousLabyrinthDials = settings[i - 1], q: LissajousLabyrinthDials = settings[i]
            let lp: [Int] = [p.frequencyA, p.frequencyB, p.phaseA, p.phaseC]
            let lq: [Int] = [q.frequencyA, q.frequencyB, q.phaseA, q.phaseC]
            #expect(lp.lexicographicallyPrecedes(lq))
        }
        // Every valid setting is listed (9 × 9 × 16 × 16 candidates).
        var valid: Int = 0
        for a in 1...9 {
            for b in 1...9 {
                for phaseA in 0...15 {
                    for phaseC in 0...15 {
                        let d = LissajousLabyrinthDials(frequencyA: a, frequencyB: b, phaseA: phaseA, phaseC: phaseC)
                        if d.isValid { valid += 1 }
                    }
                }
            }
        }
        #expect(valid == 14_080)
    }

    /// The obstacle prefilter's cube: 3·h² < r² ≤ 3·(h + 1)² over the whole radius range.
    @Test func innerCubeIsTheLargestStrictlyInside() {
        for radius in LissajousLabyrinthBall.radiusRange {
            let h: Int = LissajousLabyrinthSolver.innerHalf(radius)
            #expect(3 * h * h < radius * radius)
            #expect(3 * (h + 1) * (h + 1) >= radius * radius)
        }
    }

    /// The level of the exhaustive cross-check: level 9 (three obstacles, more than a thousand winning settings), so
    /// one level covers both contact and many winners and the suite stays short (owner's short-test rule).
    static let exhaustiveLevels: [Int] = [9, 9]

    /// The exhaustive levels have what they are chosen for.
    @Test func exhaustiveLevelsHaveObstaclesAndManyWinners() {
        let withObstacles: LissajousLabyrinthLevel = SolverLevels.fifty[Self.exhaustiveLevels[0]]
        #expect(Self.exhaustiveLevels[0] == Self.exhaustiveLevels[1])
        let manyWinners: LissajousLabyrinthLevel = SolverLevels.fifty[Self.exhaustiveLevels[1]]
        #expect(withObstacles.obstacles.count >= 3)
        #expect(LissajousLabyrinthSolver.winningSettings(manyWinners).settings.count >= 500)
    }

    /// The exact decision equals the kernel's verdict on every one of the 14,080 settings of the exhaustive level
    /// (eight cases, 1,760 settings each), and the solver's winning set on that eighth is the decision's.
    @Test(arguments: 0..<1, 0..<8) func exactDecisionMatchesTheKernelExhaustively(_ which: Int, _ part: Int) {
        let number: Int = Self.exhaustiveLevels[which]
        let level: LissajousLabyrinthLevel = SolverLevels.fifty[number]
        let tables = LissajousLabyrinthSolver.tables(level)
        let legal: [LissajousLabyrinthDials] = LissajousLabyrinthSolver.legalSettings()
        let size: Int = 14_080 / 8
        let range: Range<Int> = (part * size)..<((part + 1) * size)
        var kernelWinners: [LissajousLabyrinthDials] = []
        for i in range {
            let dials: LissajousLabyrinthDials = legal[i]
            let kernel: Bool = LissajousLabyrinthLap.verdict(dials, level: level) == .won
            #expect(LissajousLabyrinthSolver.wins(dials, level: level, tables: tables) == kernel,
                    "level \(number), \(dials)")
            if kernel { kernelWinners.append(dials) }
        }
        #expect(LissajousLabyrinthSolver.winningSettings(level, in: range).settings == kernelWinners)
    }

    /// Levels 10 … 29: every winning setting wins by the kernel; on 440 seeded-random legal settings and on every
    /// setting the prefilters admitted but the decision rejected (when at most 500) the decision equals the kernel.
    @Test(arguments: 10..<30) func exactDecisionMatchesTheKernelOnSamples(_ number: Int) {
        let level: LissajousLabyrinthLevel = SolverLevels.fifty[number]
        let tables = LissajousLabyrinthSolver.tables(level)
        let decided = LissajousLabyrinthSolver.winningSettings(level)
        for dials in decided.settings {
            #expect(LissajousLabyrinthLap.verdict(dials, level: level) == .won, "level \(number), \(dials)")
        }
        let admitted: [LissajousLabyrinthDials] = LissajousLabyrinthSolver.admitted(level)
        #expect(admitted.count == decided.work)
        let winners: Set<LissajousLabyrinthDials> = Set(decided.settings)
        var losers: [LissajousLabyrinthDials] = []
        for dials in admitted where !winners.contains(dials) { losers.append(dials) }
        if losers.count <= 500 {
            for dials in losers {
                #expect(LissajousLabyrinthLap.verdict(dials, level: level) != .won, "level \(number), \(dials)")
            }
        }
        let legal: [LissajousLabyrinthDials] = LissajousLabyrinthSolver.legalSettings()
        var random = SeededRandom(seed: SolverLevels.seed &+ UInt64(number))
        for _ in 0..<440 {
            let dials: LissajousLabyrinthDials = legal[random.int(0...(legal.count - 1))]
            let kernel: Bool = LissajousLabyrinthLap.verdict(dials, level: level) == .won
            #expect(LissajousLabyrinthSolver.wins(dials, level: level, tables: tables) == kernel,
                    "level \(number), \(dials)")
            #expect(winners.contains(dials) == kernel, "level \(number), \(dials)")
        }
    }

    /// The shortest solution equals a plain breadth-first search's; the actions replay legally to a setting the kernel
    /// confirms.
    @Test(arguments: 0..<10) func shortestMatchesPlainSearchAndReplays(_ number: Int) {
        let level: LissajousLabyrinthLevel = SolverLevels.fifty[number]
        let decided = LissajousLabyrinthSolver.winningSettings(level)
        let expected: Int? = SolverLevels.plainShortest(level, winning: Set(decided.settings))
        let solution: LissajousLabyrinthSolution? = LissajousLabyrinthSolver.solve(level)
        #expect(solution?.shortest == expected, "level \(number)")
        guard let solution else { return }
        #expect(solution.shortest == solution.actions.count)
        #expect(solution.winningSettings == decided.settings.count)
        #expect(solution.work == decided.work)
        let rules = LissajousLabyrinthRules(level: level)
        var state: LissajousLabyrinthDials = level.start
        for action in solution.actions {
            guard let next = rules.apply(action, to: state) else {
                Issue.record("illegal action \(action) on level \(number)")
                return
            }
            state = next
        }
        #expect(state == solution.setting)
        #expect(LissajousLabyrinthLap.verdict(state, level: level) == .won)
    }

    /// Ties: the chosen setting is the smallest (a, b, φ, ψ) winning setting first reached at the shortest depth.
    @Test(arguments: [4, 6]) func tieBreaksBySmallestWinningSetting(_ number: Int) {
        let level: LissajousLabyrinthLevel = SolverLevels.fifty[number]
        guard let solution = LissajousLabyrinthSolver.solve(level) else {
            Issue.record("level \(number) has no solution")
            return
        }
        let winners: Set<LissajousLabyrinthDials> = Set(LissajousLabyrinthSolver.winningSettings(level).settings)
        let layer: Set<LissajousLabyrinthDials> = SolverLevels.layer(level, depth: solution.shortest)
        var smallest: LissajousLabyrinthDials? = nil
        for state in LissajousLabyrinthSolver.legalSettings() where layer.contains(state) && winners.contains(state) {
            smallest = state
            break
        }
        #expect(smallest == solution.setting)
    }

    @Test func solvingIsDeterministic() {
        for number in [1, 4, 8] {
            let level: LissajousLabyrinthLevel = SolverLevels.fifty[number]
            #expect(LissajousLabyrinthSolver.solve(level) == LissajousLabyrinthSolver.solve(level))
        }
    }

    /// A checkpoint outside the reachable box (|coordinate| ≤ 4 · 1,024) makes every setting lose: nil, and no exact
    /// decision is spent.
    @Test func unreachableCheckpointHasNoSolution() throws {
        let far = try LissajousLabyrinthBall(x: 5_000, y: 5_000, z: 5_000, radius: 64)
        let start = LissajousLabyrinthDials(frequencyA: 3, frequencyB: 2, phaseA: 4, phaseC: 0)
        let level = try LissajousLabyrinthLevel(id: "unreachable", seed: 1, band: 1, amplitudes: [4, 4, 4],
                                                frequencyC: 5, start: start, checkpoints: [far], obstacles: [],
                                                allowance: 12)
        #expect(LissajousLabyrinthSolver.solve(level) == nil)
        let decided = LissajousLabyrinthSolver.winningSettings(level)
        #expect(decided.settings.isEmpty)
        #expect(decided.work == 0)
    }
}
