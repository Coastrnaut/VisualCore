// AuroraLoomSolverTests — feature 302 (R02-G01-02) T-R02G0102-003 (FR-R02G0102-002, 003; SC-R02G0102-002; clarification
// Q2; research R1, R2). The solver against an independent exhaustive check on 500 seeded levels: the setting wins, the
// moves replay through the R02-F23 rules to it, their count is the shortest solution and no setting wins in fewer changes.
// Also determinism, the nil result for a ribbon that cannot win, the tie rules and the work bound. Test data uses
// explicit types and plain loops (CI type-check rule).
import Testing
@testable import AuroraLoomCore
import VisualCoreSimulation

@Suite("Aurora Loom solver")
struct AuroraLoomSolverTests {
    /// The fewest changes to win, found by enumerating every setting of each ribbon with the other ribbons held at
    /// `others`' steps and judging the whole setting with `AuroraLoomHarmony.wins` (after a tick-0 pre-filter, a
    /// necessary condition only); nil when some ribbon cannot win.
    static func exhaustiveShortest(_ level: AuroraLoomLevel, others: AuroraLoomSteps) -> Int? {
        let start: AuroraLoomSteps = level.startSteps
        var total: Int = 0
        for ribbon in 0..<3 {
            var fewest: Int = Int.max
            for wave in 0...15 {
                for phase in 0...15 {
                    var steps: AuroraLoomSteps = others
                    steps.wave[ribbon] = wave
                    steps.phase[ribbon] = phase
                    // Tick 0 failing at any gate is a necessary loss; the full two-period test decides the rest.
                    var tickZero: Bool = true
                    for gate in 0..<4 where abs(AuroraLoomHarmony.residual(ribbon: ribbon, gate: gate, tick: 0,
                                                                          steps: steps, level: level)) > level.tolerance {
                        tickZero = false
                    }
                    guard tickZero, AuroraLoomHarmony.wins(steps, level: level) else { continue }
                    let changes: Int = (wave != start.wave[ribbon] ? 1 : 0) + (phase != start.phase[ribbon] ? 1 : 0)
                    fewest = min(fewest, changes)
                }
            }
            guard fewest != Int.max else { return nil }
            total += fewest
        }
        return total
    }

    @Test("500 seeded levels: the solution wins, replays and is the proven shortest")
    func seededLevels() {
        var random: SeededRandom = SeededRandom(seed: 2_302)
        var solved: Int = 0
        var descents: Int = 0
        for _ in 0..<500 {
            guard let fixture = AuroraLoomFixture.make(&random, offset: random.int(0...1) == 1) else { continue }
            let level: AuroraLoomLevel = fixture.level
            guard let solution = AuroraLoomSolver.solve(level) else {
                Issue.record("no solution for \(level.id)")
                continue
            }
            solved += 1
            if solution.method == .descent { descents += 1 }
            #expect(AuroraLoomHarmony.wins(solution.setting, level: level))
            let rules: AuroraLoomRules = AuroraLoomRules(level: level)
            var state: AuroraLoomSteps = level.startSteps
            for move in solution.moves {
                guard let next = rules.apply(move, to: state) else {
                    Issue.record("refused move \(move) on \(level.id)")
                    break
                }
                state = next
            }
            #expect(state == solution.setting)
            #expect(rules.isSolved(state))
            #expect(solution.moves.count == solution.shortest)
            #expect(solution.winningSettings.count == 3)
            let exhaustive: Int? = Self.exhaustiveShortest(level, others: solution.setting)
            #expect(exhaustive == solution.shortest, "\(level.id) method \(solution.method)")
            #expect(solution.work >= 768)
            #expect(solution.work <= 768 + 3 * AuroraLoomSolver.maxSweeps * 32)
        }
        #expect(solved >= 450)
        #expect(descents > 0)
    }

    @Test("solving twice gives equal solutions")
    func deterministic() {
        var random: SeededRandom = SeededRandom(seed: 2_303)
        for _ in 0..<20 {
            let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random, offset: true)
            #expect(AuroraLoomSolver.solve(fixture.level) == AuroraLoomSolver.solve(fixture.level))
        }
    }

    @Test("a ribbon that drifts against the harmony cannot win, so there is no solution")
    func drifterHasNoSolution() throws {
        let gates: [AuroraLoomGate] = [try AuroraLoomGate(position: 2, target: 0),
                                       try AuroraLoomGate(position: 5, target: 0),
                                       try AuroraLoomGate(position: 9, target: 0),
                                       try AuroraLoomGate(position: 13, target: 0)]
        // Ribbon 1 turns at 128 while the harmony turns at 256: its residual sweeps every 128 units over two periods.
        let ribbons: [AuroraLoomRibbon] = [try AuroraLoomRibbon(wave: 3, phase: 4, omega: 256),
                                           try AuroraLoomRibbon(wave: 0, phase: 0, omega: 128),
                                           try AuroraLoomRibbon(wave: 5, phase: 1, omega: 256)]
        let level: AuroraLoomLevel = try AuroraLoomLevel(id: "solver-drifter", seed: 1, band: 1, ribbons: ribbons,
                                                         gates: gates, omega: 256, tolerance: 64, allowance: 8)
        #expect(!AuroraLoomHarmony.wins(level.startSteps, level: level))
        #expect(AuroraLoomSolver.solve(level) == nil)
        #expect(Self.exhaustiveShortest(level, others: level.startSteps) == nil)
    }

    @Test("ties go to the lower (wave, phase); moves by ribbon, wave before phase")
    func tieRules() throws {
        // Every gate targets 0 and every ribbon turns with the harmony, so residuals are constant over time. Gate positions 1 … 4: wave w at phase 0 gives residual 16 · w · s, at most 64 · w; tolerance 100 lets w = 0 and
        // w = 1 win (≤ 64) but not w = 2 (128). Phase changes move every residual by 256, so phase 0 is required.
        let gates: [AuroraLoomGate] = [try AuroraLoomGate(position: 1, target: 0),
                                       try AuroraLoomGate(position: 2, target: 0),
                                       try AuroraLoomGate(position: 3, target: 0),
                                       try AuroraLoomGate(position: 4, target: 0)]
        let ribbons: [AuroraLoomRibbon] = [try AuroraLoomRibbon(wave: 2, phase: 0, omega: 256),
                                           try AuroraLoomRibbon(wave: 0, phase: 0, omega: 256),
                                           try AuroraLoomRibbon(wave: 5, phase: 3, omega: 256)]
        let level: AuroraLoomLevel = try AuroraLoomLevel(id: "solver-ties", seed: 2, band: 1, ribbons: ribbons,
                                                         gates: gates, omega: 256, tolerance: 100, allowance: 8)
        let solution: AuroraLoomSolution = try #require(AuroraLoomSolver.solve(level))
        // Ribbon 0: (0, 0) and (1, 0) each take one change; (0, 0) is lower. Ribbon 1 already wins. Ribbon 2: wave 5 and
        // phase 3 both lose, so two changes to (0, 0) — (1, 0) ties on changes but is higher.
        #expect(solution.setting == AuroraLoomSteps(wave: [0, 0, 0], phase: [0, 0, 0]))
        #expect(solution.shortest == 3)
        let expected: [AuroraLoomMove] = [AuroraLoomMove(ribbon: 0, control: .wave, step: 0),
                                          AuroraLoomMove(ribbon: 2, control: .wave, step: 0),
                                          AuroraLoomMove(ribbon: 2, control: .phase, step: 0)]
        #expect(solution.moves == expected)
        #expect(solution.winningSettings == [2, 2, 2])
    }

    @Test("work is the descent evaluations plus the 768 grid evaluations")
    func workBound() {
        var random: SeededRandom = SeededRandom(seed: 2_304)
        for _ in 0..<20 {
            let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
            guard let solution = AuroraLoomSolver.solve(fixture.level) else {
                Issue.record("no solution")
                continue
            }
            #expect(solution.work >= 768 + 3 * 32)   // at least one sweep per ribbon
            #expect(solution.work <= 768 + 3 * AuroraLoomSolver.maxSweeps * 32)
            #expect((solution.work - 768) % 32 == 0)
        }
    }
}
