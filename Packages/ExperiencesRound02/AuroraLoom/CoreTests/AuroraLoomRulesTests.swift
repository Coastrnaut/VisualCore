// AuroraLoomRulesTests — feature 301 (R02-G01-01) T-R02G0101-005 (FR-R02G0101-008; clarification Q5). The R02-F23 puzzle
// contract of Aurora Loom: moves in the documented order without a no-change, apply refusing out-of-range and no-change
// moves, isSolved equal to the win test, and R02-F23's PuzzleValidator certifying a small seeded level two moves from its
// winning steps. Test data uses explicit types and plain loops (CI type-check rule).
import Testing
@testable import AuroraLoomCore
import VisualCoreSimulation

@Suite("Aurora Loom rules (R02-F23 contract)")
struct AuroraLoomRulesTests {
    /// A level two moves from its winning steps: ribbon 0's wave and ribbon 2's phase differ from them. Ribbons turn with
    /// the harmony (ω = Ω = 256, period 16 ticks), so every residual is constant over time; with a tolerance below 16 the
    /// winning steps are the only winning setting (a different (wave, phase) moves a residual by a non-zero multiple of 16
    /// at some gate), so the goal-uniqueness promise holds.
    static func twoMoveLevel(_ random: inout SeededRandom) -> (level: AuroraLoomLevel, winning: AuroraLoomSteps) {
        let wave: Int = random.int(0...15)
        let phase: Int = random.int(0...15)
        let positions: [Int] = [2, 5, 9, 13]
        var gates: [AuroraLoomGate] = []
        for p in positions {
            let target: Int = ((wave * p * 16 + phase * 256) % 4_096 + 4_096) % 4_096
            gates.append(try! AuroraLoomGate(position: p, target: target))
        }
        let ribbons: [AuroraLoomRibbon] = [
            try! AuroraLoomRibbon(wave: (wave + 1) % 16, phase: phase, omega: 256),
            try! AuroraLoomRibbon(wave: wave, phase: phase, omega: 256),
            try! AuroraLoomRibbon(wave: wave, phase: (phase + 1) % 16, omega: 256),
        ]
        let level: AuroraLoomLevel = try! AuroraLoomLevel(id: "rules-two-move", seed: 2_301, band: 1, ribbons: ribbons,
                                                          gates: gates, omega: 256, tolerance: 8, allowance: 8)
        let winning: AuroraLoomSteps = AuroraLoomSteps(wave: [wave, wave, wave], phase: [phase, phase, phase])
        return (level, winning)
    }

    /// The certification budget: solutions of 1 … 2 moves, 90 moves per state, at most 1 + 90 + 8,100 states.
    static func budget() -> FairnessBudget {
        try! FairnessBudget(minLength: 1, maxLength: 2, maxBranching: 90, nodeBudget: 100_000)
    }

    @Test("rules id is the documented slug")
    func rulesID() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
        let rules: AuroraLoomRules = AuroraLoomRules(level: fixture.level)
        #expect(rules.rulesID == "r02-g01-aurora-loom")
    }

    @Test("moves: 90 single-control changes in ribbon, control, step order, never a no-change")
    func movesOrder() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
        let rules: AuroraLoomRules = AuroraLoomRules(level: fixture.level)
        for _ in 0..<20 {
            var wave: [Int] = []
            var phase: [Int] = []
            for _ in 0..<3 {
                wave.append(random.int(0...15))
                phase.append(random.int(0...15))
            }
            let state: AuroraLoomSteps = AuroraLoomSteps(wave: wave, phase: phase)
            let moves: [AuroraLoomMove] = rules.moves(in: state)
            #expect(moves.count == 90)
            var expected: [AuroraLoomMove] = []
            for ribbon in 0..<3 {
                for control in [AuroraLoomControl.wave, AuroraLoomControl.phase] {
                    let current: Int = control == .wave ? wave[ribbon] : phase[ribbon]
                    for step in 0...15 where step != current {
                        expected.append(AuroraLoomMove(ribbon: ribbon, control: control, step: step))
                    }
                }
            }
            #expect(moves == expected)
            for move in moves {
                let current: Int = move.control == .wave ? wave[move.ribbon] : phase[move.ribbon]
                #expect(move.step != current)
            }
            #expect(Set(moves).count == 90)
        }
    }

    @Test("apply refuses out-of-range and no-change moves and otherwise changes exactly one value")
    func applyRules() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
        let rules: AuroraLoomRules = AuroraLoomRules(level: fixture.level)
        let state: AuroraLoomSteps = fixture.level.startSteps
        let refused: [AuroraLoomMove] = [
            AuroraLoomMove(ribbon: -1, control: .wave, step: 0),
            AuroraLoomMove(ribbon: 3, control: .phase, step: 0),
            AuroraLoomMove(ribbon: 0, control: .wave, step: -1),
            AuroraLoomMove(ribbon: 1, control: .wave, step: 16),
            AuroraLoomMove(ribbon: 2, control: .phase, step: 16),
            AuroraLoomMove(ribbon: 0, control: .wave, step: state.wave[0]),
            AuroraLoomMove(ribbon: 1, control: .phase, step: state.phase[1]),
            AuroraLoomMove(ribbon: 2, control: .wave, step: state.wave[2]),
        ]
        for move in refused {
            #expect(rules.apply(move, to: state) == nil)
        }
        for move in rules.moves(in: state) {
            guard let next = rules.apply(move, to: state) else {
                Issue.record("a listed move was refused: \(move)")
                continue
            }
            var changes: Int = 0
            for r in 0..<3 {
                if next.wave[r] != state.wave[r] { changes += 1 }
                if next.phase[r] != state.phase[r] { changes += 1 }
            }
            #expect(changes == 1)
            let value: Int = move.control == .wave ? next.wave[move.ribbon] : next.phase[move.ribbon]
            #expect(value == move.step)
        }
    }

    @Test("isSolved equals AuroraLoomHarmony.wins over seeded states")
    func isSolvedEqualsWins() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        var solvedSeen: Int = 0
        for index in 0..<12 {
            let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random, offset: index % 2 == 1)
            let rules: AuroraLoomRules = AuroraLoomRules(level: fixture.level)
            var states: [AuroraLoomSteps] = [fixture.winning, fixture.level.startSteps]
            for _ in 0..<10 {
                var wave: [Int] = []
                var phase: [Int] = []
                for _ in 0..<3 {
                    wave.append(random.int(0...15))
                    phase.append(random.int(0...15))
                }
                states.append(AuroraLoomSteps(wave: wave, phase: phase))
            }
            for state in states {
                let solved: Bool = rules.isSolved(state)
                #expect(solved == AuroraLoomHarmony.wins(state, level: fixture.level))
                if solved { solvedSeen += 1 }
            }
            #expect(!rules.isSolved(fixture.level.startSteps))
        }
        #expect(solvedSeen >= 12)
    }

    @Test("PuzzleValidator certifies a two-move level with the goal promise and without a promise")
    func certifies() throws {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        let made: (level: AuroraLoomLevel, winning: AuroraLoomSteps) = Self.twoMoveLevel(&random)
        let rules: AuroraLoomRules = AuroraLoomRules(level: made.level)
        let solution: [AuroraLoomMove] = [
            AuroraLoomMove(ribbon: 0, control: .wave, step: made.winning.wave[0]),
            AuroraLoomMove(ribbon: 2, control: .phase, step: made.winning.phase[2]),
        ]
        for uniqueness in [PuzzleUniqueness.goal, PuzzleUniqueness.none] {
            let puzzle: PuzzleLevel<AuroraLoomRules> =
                try PuzzleLevel(rulesID: rules.rulesID, start: made.level.startSteps, solution: solution,
                                uniqueness: uniqueness, budget: Self.budget(), seed: 2_301)
            let certificate: PuzzleCertificate = PuzzleValidator.certify(puzzle, rules: rules)
            #expect(certificate.verdict == .valid)
            #expect(certificate.shortest == 2)
            #expect(certificate.solvedStates == 1)
            #expect(certificate.maxBranching == 90)
            #expect(certificate.explored <= 1 + 90 + 8_100)
        }
        // The two moves commute, so two shortest solutions exist and the stronger solution promise does not hold.
        let strict: PuzzleLevel<AuroraLoomRules> =
            try PuzzleLevel(rulesID: rules.rulesID, start: made.level.startSteps, solution: solution,
                            uniqueness: .solution, budget: Self.budget(), seed: 2_301)
        let strictCertificate: PuzzleCertificate = PuzzleValidator.certify(strict, rules: rules)
        #expect(strictCertificate.verdict == .notUnique)
        #expect(strictCertificate.shortestPaths == 2)
    }

    @Test("PuzzleValidator refuses other rules and an illegal move")
    func refusals() throws {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        let made: (level: AuroraLoomLevel, winning: AuroraLoomSteps) = Self.twoMoveLevel(&random)
        let rules: AuroraLoomRules = AuroraLoomRules(level: made.level)
        let solution: [AuroraLoomMove] = [
            AuroraLoomMove(ribbon: 0, control: .wave, step: made.winning.wave[0]),
            AuroraLoomMove(ribbon: 2, control: .phase, step: made.winning.phase[2]),
        ]
        let wrong: PuzzleLevel<AuroraLoomRules> =
            try PuzzleLevel(rulesID: "r02-g02-other", start: made.level.startSteps, solution: solution,
                            uniqueness: .goal, budget: Self.budget())
        #expect(PuzzleValidator.certify(wrong, rules: rules).verdict == .wrongRules)

        let illegalSolution: [AuroraLoomMove] = [
            AuroraLoomMove(ribbon: 0, control: .wave, step: 16),
            AuroraLoomMove(ribbon: 2, control: .phase, step: made.winning.phase[2]),
        ]
        let illegal: PuzzleLevel<AuroraLoomRules> =
            try PuzzleLevel(rulesID: rules.rulesID, start: made.level.startSteps, solution: illegalSolution,
                            uniqueness: .goal, budget: Self.budget())
        #expect(PuzzleValidator.certify(illegal, rules: rules).verdict == .illegalMove(0))
    }
}
