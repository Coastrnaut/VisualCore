// LissajousLabyrinthRulesTests — feature 311 (R02-G02-01) T-R02G0201-005 (FR-R02G0201-008). The R02-F23 puzzle contract
// of Lissajous Labyrinth: moves in the documented dial and value order without a no-change or a non-coprime result (checked
// against a brute force), apply refusing out-of-range, no-change, non-coprime and invalid-state moves, isSolved equal to
// the lap verdict for seeded fixtures, and R02-F23's PuzzleValidator certifying a seeded level two phase moves from its
// safe setting. Test data uses explicit types and plain loops (CI type-check rule).
import Testing
@testable import LissajousLabyrinthCore
import VisualCoreSimulation

@Suite("Lissajous Labyrinth rules (R02-F23 contract)")
struct LissajousLabyrinthRulesTests {
    /// The greatest common divisor, written out here so the brute force does not reuse the code under test.
    static func gcd(_ a: Int, _ b: Int) -> Int {
        var x: Int = a
        var y: Int = b
        while y != 0 {
            let r: Int = x % y
            x = y
            y = r
        }
        return x
    }

    /// The brute-force move list: every dial in declaration order, every value of 0 … 20 that is in the dial's range,
    /// differs from the current value and keeps the frequencies coprime.
    static func bruteForceMoves(_ state: LissajousLabyrinthDials) -> [LissajousLabyrinthAction] {
        let dials: [LissajousLabyrinthDial] = [.frequencyA, .frequencyB, .phaseA, .phaseC]
        var result: [LissajousLabyrinthAction] = []
        for dial in dials {
            for value in -2...20 {
                var a: Int = state.frequencyA
                var b: Int = state.frequencyB
                var current: Int = 0
                var lower: Int = 0
                var upper: Int = 15
                switch dial {
                case .frequencyA:
                    current = state.frequencyA
                    a = value
                    lower = 1
                    upper = 9
                case .frequencyB:
                    current = state.frequencyB
                    b = value
                    lower = 1
                    upper = 9
                case .phaseA:
                    current = state.phaseA
                case .phaseC:
                    current = state.phaseC
                }
                if value < lower || value > upper || value == current { continue }
                if gcd(a, b) != 1 { continue }
                result.append(LissajousLabyrinthAction(dial: dial, value: value))
            }
        }
        return result
    }

    /// A level whose start is the fixture's safe setting with both phases turned half a turn, so two phase moves win it;
    /// nil when that start happens to win.
    static func twoPhaseLevel(_ fixture: LissajousLabyrinthFixture) -> LissajousLabyrinthLevel? {
        let safe: LissajousLabyrinthDials = fixture.safe
        let start: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: safe.frequencyA,
                                                                     frequencyB: safe.frequencyB,
                                                                     phaseA: (safe.phaseA + 8) % 16,
                                                                     phaseC: (safe.phaseC + 8) % 16)
        let level: LissajousLabyrinthLevel? =
            try? LissajousLabyrinthLevel(id: "rules-two-phase", seed: 2_315, band: fixture.level.band,
                                         amplitudes: fixture.level.amplitudes, frequencyC: fixture.level.frequencyC,
                                         start: start, checkpoints: fixture.level.checkpoints,
                                         obstacles: fixture.level.obstacles, allowance: fixture.level.allowance)
        return level
    }

    /// The certification budget: solutions of 1 … 2 moves, at most 46 moves per state, at most 1 + 46 + 46 · 46 states.
    static func budget() -> FairnessBudget {
        try! FairnessBudget(minLength: 1, maxLength: 2, maxBranching: 46, nodeBudget: 2_200)
    }

    /// The first seeded fixture (seed 2,315) whose two-phase level has no one-move win: the certification search then
    /// finds the safe setting at depth 2.
    static func certifiedLevel() -> (level: LissajousLabyrinthLevel, safe: LissajousLabyrinthDials)? {
        var random: SeededRandom = SeededRandom(seed: 2_315)
        for _ in 0..<20 {
            let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
            guard let level = twoPhaseLevel(fixture) else { continue }
            let rules: LissajousLabyrinthRules = LissajousLabyrinthRules(level: level)
            var oneMoveWin: Bool = false
            for move in rules.moves(in: level.start) {
                if let next = rules.apply(move, to: level.start), rules.isSolved(next) {
                    oneMoveWin = true
                    break
                }
            }
            if !oneMoveWin { return (level, fixture.safe) }
        }
        return nil
    }

    @Test("rules id is the documented slug")
    func rulesID() {
        var random: SeededRandom = SeededRandom(seed: 2_315)
        let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
        let rules: LissajousLabyrinthRules = LissajousLabyrinthRules(level: fixture.level)
        #expect(rules.rulesID == "r02-g02-lissajous-labyrinth")
    }

    @Test("moves: every valid single-dial change in dial, value order, equal to a brute force")
    func movesOrder() {
        var random: SeededRandom = SeededRandom(seed: 2_315)
        let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
        let rules: LissajousLabyrinthRules = LissajousLabyrinthRules(level: fixture.level)
        var states: [LissajousLabyrinthDials] = [
            LissajousLabyrinthDials(frequencyA: 1, frequencyB: 1, phaseA: 0, phaseC: 0),
            LissajousLabyrinthDials(frequencyA: 6, frequencyB: 1, phaseA: 15, phaseC: 7),
            LissajousLabyrinthDials(frequencyA: 9, frequencyB: 8, phaseA: 3, phaseC: 15),
            fixture.level.start,
            fixture.safe,
        ]
        for _ in 0..<40 {
            states.append(LissajousLabyrinthFixture.dials(&random))
        }
        for state in states {
            let moves: [LissajousLabyrinthAction] = rules.moves(in: state)
            let expected: [LissajousLabyrinthAction] = Self.bruteForceMoves(state)
            #expect(moves == expected)
            #expect(Set(moves).count == moves.count)
            #expect(moves.count <= 46)
            for move in moves {
                #expect(move.value != state[move.dial])
            }
        }
        // Hand-counted: (1, 1) offers 8 + 8 + 15 + 15; (6, 1) offers a ∈ {2 … 9} (8) and b ∈ {5, 7} (2), plus 30.
        #expect(rules.moves(in: states[0]).count == 46)
        #expect(rules.moves(in: states[1]).count == 40)
        // The first ten moves of (6, 1): frequencyA ascending without 6, then frequencyB ∈ {5, 7}.
        let firstOfSix: [LissajousLabyrinthAction] = Array(rules.moves(in: states[1]).prefix(10))
        var expectedFirst: [LissajousLabyrinthAction] = []
        for value in [1, 2, 3, 4, 5, 7, 8, 9] {
            expectedFirst.append(LissajousLabyrinthAction(dial: .frequencyA, value: value))
        }
        expectedFirst.append(LissajousLabyrinthAction(dial: .frequencyB, value: 5))
        expectedFirst.append(LissajousLabyrinthAction(dial: .frequencyB, value: 7))
        #expect(firstOfSix == expectedFirst)
        // Invalid states offer nothing.
        let invalid: [LissajousLabyrinthDials] = [
            LissajousLabyrinthDials(frequencyA: 2, frequencyB: 4, phaseA: 0, phaseC: 0),
            LissajousLabyrinthDials(frequencyA: 0, frequencyB: 1, phaseA: 0, phaseC: 0),
            LissajousLabyrinthDials(frequencyA: 1, frequencyB: 10, phaseA: 0, phaseC: 0),
            LissajousLabyrinthDials(frequencyA: 1, frequencyB: 1, phaseA: 16, phaseC: 0),
            LissajousLabyrinthDials(frequencyA: 1, frequencyB: 1, phaseA: 0, phaseC: -1),
        ]
        for state in invalid {
            #expect(rules.moves(in: state).isEmpty)
        }
    }

    @Test("apply refuses out-of-range, no-change, non-coprime and invalid-state moves and otherwise changes one dial")
    func applyRules() {
        var random: SeededRandom = SeededRandom(seed: 2_315)
        let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
        let rules: LissajousLabyrinthRules = LissajousLabyrinthRules(level: fixture.level)
        let state: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 6, frequencyB: 1, phaseA: 4, phaseC: 9)
        let refused: [LissajousLabyrinthAction] = [
            LissajousLabyrinthAction(dial: .frequencyA, value: 0),
            LissajousLabyrinthAction(dial: .frequencyA, value: 10),
            LissajousLabyrinthAction(dial: .frequencyB, value: 0),
            LissajousLabyrinthAction(dial: .frequencyB, value: 10),
            LissajousLabyrinthAction(dial: .phaseA, value: -1),
            LissajousLabyrinthAction(dial: .phaseA, value: 16),
            LissajousLabyrinthAction(dial: .phaseC, value: 16),
            LissajousLabyrinthAction(dial: .frequencyA, value: 6),
            LissajousLabyrinthAction(dial: .frequencyB, value: 1),
            LissajousLabyrinthAction(dial: .phaseA, value: 4),
            LissajousLabyrinthAction(dial: .phaseC, value: 9),
            LissajousLabyrinthAction(dial: .frequencyB, value: 2),
            LissajousLabyrinthAction(dial: .frequencyB, value: 3),
            LissajousLabyrinthAction(dial: .frequencyB, value: 4),
            LissajousLabyrinthAction(dial: .frequencyB, value: 6),
            LissajousLabyrinthAction(dial: .frequencyB, value: 8),
            LissajousLabyrinthAction(dial: .frequencyB, value: 9),
        ]
        for move in refused {
            #expect(rules.apply(move, to: state) == nil)
        }
        let invalid: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 2, frequencyB: 4, phaseA: 0, phaseC: 0)
        #expect(rules.apply(LissajousLabyrinthAction(dial: .frequencyB, value: 3), to: invalid) == nil)
        #expect(rules.apply(LissajousLabyrinthAction(dial: .phaseA, value: 1), to: invalid) == nil)
        let starts: [LissajousLabyrinthDials] = [state, fixture.level.start, fixture.safe]
        for start in starts {
            for move in rules.moves(in: start) {
                guard let next = rules.apply(move, to: start) else {
                    Issue.record("a listed move was refused: \(move)")
                    continue
                }
                var changes: Int = 0
                for dial in LissajousLabyrinthDial.allCases where next[dial] != start[dial] {
                    changes += 1
                }
                #expect(changes == 1)
                #expect(next[move.dial] == move.value)
                #expect(next.isValid)
            }
        }
    }

    @Test("isSolved equals the lap verdict for 100 seeded fixtures at start and safe dials")
    func isSolvedEqualsVerdict() {
        var random: SeededRandom = SeededRandom(seed: 2_315)
        var safeSolved: Int = 0
        for _ in 0..<100 {
            let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
            let rules: LissajousLabyrinthRules = LissajousLabyrinthRules(level: fixture.level)
            let states: [LissajousLabyrinthDials] = [fixture.level.start, fixture.safe]
            for state in states {
                let won: Bool = LissajousLabyrinthLap.verdict(state, level: fixture.level) == .won
                #expect(rules.isSolved(state) == won)
            }
            #expect(!rules.isSolved(fixture.level.start))
            if rules.isSolved(fixture.safe) { safeSolved += 1 }
        }
        #expect(safeSolved == 100)
    }

    @Test("PuzzleValidator certifies a seeded level two phase moves from its safe setting")
    func certifies() throws {
        guard let made = Self.certifiedLevel() else {
            Issue.record("no seeded fixture without a one-move win")
            return
        }
        let rules: LissajousLabyrinthRules = LissajousLabyrinthRules(level: made.level)
        let solution: [LissajousLabyrinthAction] = [
            LissajousLabyrinthAction(dial: .phaseA, value: made.safe.phaseA),
            LissajousLabyrinthAction(dial: .phaseC, value: made.safe.phaseC),
        ]
        let puzzle: PuzzleLevel<LissajousLabyrinthRules> =
            try PuzzleLevel(rulesID: rules.rulesID, start: made.level.start, solution: solution, uniqueness: .none,
                            budget: Self.budget(), seed: 2_315)
        let certificate: PuzzleCertificate = PuzzleValidator.certify(puzzle, rules: rules)
        #expect(certificate.verdict == .valid)
        #expect(certificate.shortest == 2)
        #expect(certificate.solvedStates >= 1)
        #expect(certificate.maxBranching <= 46)
        #expect(certificate.explored <= 1 + 46 + 46 * 46)
        // The two phase moves commute, so two shortest solutions reach the safe setting and the solution promise fails.
        let strict: PuzzleLevel<LissajousLabyrinthRules> =
            try PuzzleLevel(rulesID: rules.rulesID, start: made.level.start, solution: solution, uniqueness: .solution,
                            budget: Self.budget(), seed: 2_315)
        let strictCertificate: PuzzleCertificate = PuzzleValidator.certify(strict, rules: rules)
        #expect(strictCertificate.verdict == .notUnique)
        #expect(strictCertificate.shortestPaths == 2)
    }

    @Test("PuzzleValidator refuses other rules and an illegal move")
    func refusals() throws {
        var random: SeededRandom = SeededRandom(seed: 2_315)
        let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
        let rules: LissajousLabyrinthRules = LissajousLabyrinthRules(level: fixture.level)
        let start: LissajousLabyrinthDials = fixture.level.start
        let solution: [LissajousLabyrinthAction] = [
            LissajousLabyrinthAction(dial: .phaseA, value: (start.phaseA + 1) % 16),
        ]
        let wrong: PuzzleLevel<LissajousLabyrinthRules> =
            try PuzzleLevel(rulesID: "r02-g01-other", start: start, solution: solution, uniqueness: .none,
                            budget: Self.budget())
        #expect(PuzzleValidator.certify(wrong, rules: rules).verdict == .wrongRules)

        let illegalSolutions: [[LissajousLabyrinthAction]] = [
            [LissajousLabyrinthAction(dial: .frequencyA, value: 10)],
            [LissajousLabyrinthAction(dial: .phaseC, value: start.phaseC)],
            [LissajousLabyrinthAction(dial: .phaseA, value: (start.phaseA + 1) % 16),
             LissajousLabyrinthAction(dial: .phaseA, value: 16)],
        ]
        let indices: [Int] = [0, 0, 1]
        for (i, illegalSolution) in illegalSolutions.enumerated() {
            let illegal: PuzzleLevel<LissajousLabyrinthRules> =
                try PuzzleLevel(rulesID: rules.rulesID, start: start, solution: illegalSolution, uniqueness: .none,
                                budget: Self.budget())
            #expect(PuzzleValidator.certify(illegal, rules: rules).verdict == .illegalMove(indices[i]))
        }
    }
}
