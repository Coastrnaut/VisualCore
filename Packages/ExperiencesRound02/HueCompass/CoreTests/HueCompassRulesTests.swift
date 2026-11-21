// HueCompassRulesTests — feature 331 (R02-G04-01) T-R02G0401-005 (FR-R02G0401-009). The R02-F23 puzzle contract of Hue
// Compass: the rules id and the initial position (the level's start, nothing spent, playing); the 27 moves in their fixed
// order (turn +1, turn −1, probe, select at the current bearing for bands 0 … 23); ended positions offer and accept
// nothing, and unlisted moves are refused; the rules agree with HueCompassPlay (bearing, spent, won and failed) after every
// step of 200 seeded random walks; each fixture's known solution, its turn written as single steps, solves through the
// rules; and R02-F23's PuzzleValidator certifies a hand-made level two moves from its goal (uniqueness `solution`) and
// refuses other rules and an illegal move. Fixtures seed 2_331. Explicit types, plain loops, short runs.
import Testing
@testable import HueCompassCore
import VisualCoreSimulation

@Suite("Hue Compass rules (R02-F23 contract)")
struct HueCompassRulesTests {
    typealias Position = HueCompassRules.Position

    /// A playing play of `level` (begun, the tutorial dismissed when it has one).
    static func playing(_ level: HueCompassLevel) throws -> HueCompassPlay {
        var play: HueCompassPlay = HueCompassPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The rules' outcome for a play stage.
    static func outcome(of stage: HueCompassStage) -> Position.Outcome? {
        switch stage {
        case .playing: .playing
        case .won: .won
        case .failed: .failed
        default: nil
        }
    }

    /// A fixture's known solution with its turn written as single ±1 steps, the only turns the rules list.
    static func singleStepSolution(_ solution: [HueCompassAction]) -> [HueCompassAction] {
        var result: [HueCompassAction] = []
        for action in solution {
            if case .turn(let steps) = action {
                let unit: Int = steps > 0 ? 1 : -1
                var left: Int = steps
                while left != 0 {
                    result.append(.turn(unit))
                    left -= unit
                }
            } else {
                result.append(action)
            }
        }
        return result
    }

    /// A hand-made level two moves from its goal: start 11, target 10, both tolerances 0, allowance 2.
    static func twoMoveLevel() throws -> HueCompassLevel {
        try HueCompassLevel(id: "rules-two-move", seed: 2_331, band: 1, offset: 5, fog: Array(repeating: 1, count: 96),
                            target: 10, start: 11, bearingTolerance: 0, bandTolerance: 0, allowance: 2)
    }

    @Test("rules id is the documented slug and the initial state is the level's start, nothing spent, playing")
    func conformance() {
        for index in 0..<20 {
            let fixture: HueCompassFixture = HueCompassFixtures.fixture(index, tutorial: index % 2 == 1)
            let rules: HueCompassRules = HueCompassRules(level: fixture.level)
            #expect(rules.rulesID == "r02-g04-hue-compass")
            #expect(rules.level == fixture.level)
            let start: Position = rules.initialState
            #expect(start == Position(bearing: fixture.level.start, spent: 0, outcome: .playing))
            #expect(!rules.isSolved(start))
        }
    }

    @Test("moves: turn +1, turn −1, probe, then select at the current bearing for bands 0 … 23 (27 moves)")
    func movesOrder() {
        let fixture: HueCompassFixture = HueCompassFixtures.fixture(0)
        let rules: HueCompassRules = HueCompassRules(level: fixture.level)
        for bearing in 0..<96 {
            for spent in 0..<fixture.level.allowance {
                let state: Position = Position(bearing: bearing, spent: spent, outcome: .playing)
                let moves: [HueCompassAction] = rules.moves(in: state)
                #expect(moves.count == 27)
                #expect(Set(moves).count == 27)
                #expect(moves[0] == .turn(1))
                #expect(moves[1] == .turn(-1))
                #expect(moves[2] == .probe)
                var band: Int = 0
                while band < 24 {
                    #expect(moves[3 + band] == .select(bearing: bearing, band: band))
                    band += 1
                }
            }
        }
    }

    @Test("ended positions offer and accept nothing; unlisted moves are refused")
    func endedAndUnlisted() throws {
        let fixture: HueCompassFixture = HueCompassFixtures.fixture(4)
        let rules: HueCompassRules = HueCompassRules(level: fixture.level)
        let candidates: [HueCompassAction] = [.turn(1), .turn(-1), .probe,
                                              .select(bearing: fixture.level.target, band: fixture.level.targetBand)]
        let outcomes: [Position.Outcome] = [.won, .failed]
        for outcome in outcomes {
            let ended: Position = Position(bearing: fixture.level.target, spent: 1, outcome: outcome)
            #expect(rules.moves(in: ended).isEmpty)
            for move in candidates {
                #expect(rules.apply(move, to: ended) == nil)
            }
        }
        #expect(rules.isSolved(Position(bearing: 0, spent: 1, outcome: .won)))
        #expect(!rules.isSolved(Position(bearing: 0, spent: 1, outcome: .failed)))

        let start: Position = rules.initialState
        let other: Int = (start.bearing + 1) % 96
        let unlisted: [HueCompassAction] = [.turn(0), .turn(2), .turn(-2), .turn(48), .turn(-48), .turn(49),
                                            .select(bearing: other, band: 0), .select(bearing: start.bearing, band: -1),
                                            .select(bearing: start.bearing, band: 24), .select(bearing: -1, band: 0)]
        let listed: Set<HueCompassAction> = Set(rules.moves(in: start))
        for move in unlisted {
            #expect(!listed.contains(move))
            #expect(rules.apply(move, to: start) == nil)
        }
        // Listed moves: turns wrap and spend nothing; a probe spends one unit.
        let down: Position = try #require(rules.apply(.turn(-1), to: Position(bearing: 0, spent: 0, outcome: .playing)))
        #expect(down == Position(bearing: 95, spent: 0, outcome: .playing))
        let up: Position = try #require(rules.apply(.turn(1), to: Position(bearing: 95, spent: 0, outcome: .playing)))
        #expect(up == Position(bearing: 0, spent: 0, outcome: .playing))
        let probed: Position = try #require(rules.apply(.probe, to: start))
        #expect(probed == Position(bearing: start.bearing, spent: 1, outcome: .playing))
        // The probe that spends the last unit fails.
        let last: Position = Position(bearing: start.bearing, spent: fixture.level.allowance - 1, outcome: .playing)
        let spentOut: Position = try #require(rules.apply(.probe, to: last))
        #expect(spentOut == Position(bearing: start.bearing, spent: fixture.level.allowance, outcome: .failed))
    }

    @Test("selection wins exactly when the level accepts the bearing and band")
    func selections() throws {
        for index in 0..<20 {
            let fixture: HueCompassFixture = HueCompassFixtures.fixture(index)
            let rules: HueCompassRules = HueCompassRules(level: fixture.level)
            var bearing: Int = 0
            while bearing < 96 {
                let state: Position = Position(bearing: bearing, spent: 0, outcome: .playing)
                var band: Int = 0
                while band < 24 {
                    let next: Position = try #require(rules.apply(.select(bearing: bearing, band: band), to: state))
                    let accepted: Bool = fixture.level.accepts(bearing: bearing, band: band)
                    #expect(next == Position(bearing: bearing, spent: 1, outcome: accepted ? .won : .failed))
                    #expect(rules.isSolved(next) == accepted)
                    band += 1
                }
                bearing += 5
            }
        }
    }

    @Test("rules and play agree after every step of 200 seeded random walks")
    func agreesWithPlay() throws {
        var random: HueCompassRandom = HueCompassRandom(seed: HueCompassFixtures.seed)
        var wins: Int = 0
        var failures: Int = 0
        var steps: Int = 0
        for index in 0..<200 {
            let fixture: HueCompassFixture = HueCompassFixtures.fixture(index, tutorial: index % 3 == 2)
            let rules: HueCompassRules = HueCompassRules(level: fixture.level)
            var play: HueCompassPlay = try Self.playing(fixture.level)
            var state: Position = rules.initialState
            #expect(state.bearing == play.bearing && state.spent == play.spent)
            let solution: [HueCompassAction] = Self.singleStepSolution(fixture.solution)
            var solutionStep: Int = 0
            var walkSteps: Int = 0
            while play.stage == .playing && walkSteps < 400 {
                let moves: [HueCompassAction] = rules.moves(in: state)
                #expect(moves.count == 27)
                // Every fourth walk follows the known solution; the others mostly turn and probe, sometimes select.
                var move: HueCompassAction
                if index % 4 == 0 && solutionStep < solution.count {
                    move = solution[solutionStep]
                    solutionStep += 1
                } else {
                    let roll: Int = random.int(0...19)
                    if roll < 18 {
                        move = moves[roll % 3]
                    } else {
                        move = moves[3 + random.int(0...23)]
                    }
                }
                let next: Position = try #require(rules.apply(move, to: state))
                try play.apply(move, expecting: play.fingerprint)
                state = next
                steps += 1
                walkSteps += 1
                #expect(state.bearing == play.bearing)
                #expect(state.spent == play.spent)
                #expect(Self.outcome(of: play.stage) == state.outcome)
                #expect(rules.isSolved(state) == (play.stage == .won))
            }
            #expect(play.stage != .playing)
            #expect(rules.moves(in: state).isEmpty)
            if play.stage == .won { wins += 1 }
            if play.stage == .failed { failures += 1 }
        }
        #expect(wins >= 50)
        #expect(failures >= 50)
        #expect(steps > 1_000)
    }

    @Test("each fixture's known solution, its turn as single steps, solves through the rules (100 fixtures)")
    func knownSolutions() {
        var solved: Int = 0
        for index in 0..<100 {
            let fixture: HueCompassFixture = HueCompassFixtures.fixture(index)
            let rules: HueCompassRules = HueCompassRules(level: fixture.level)
            var state: Position = rules.initialState
            var legal: Bool = true
            for move in Self.singleStepSolution(fixture.solution) {
                guard rules.moves(in: state).contains(move), let next = rules.apply(move, to: state) else {
                    legal = false
                    break
                }
                state = next
            }
            #expect(legal)
            #expect(state.bearing == fixture.level.target && state.spent == 2)
            if legal && rules.isSolved(state) { solved += 1 }
        }
        #expect(solved == 100)
    }

    @Test("PuzzleValidator certifies a hand-made level two moves from its goal with a unique solution")
    func certifies() throws {
        let level: HueCompassLevel = try Self.twoMoveLevel()
        let rules: HueCompassRules = HueCompassRules(level: level)
        let solution: [HueCompassAction] = [.turn(-1), .select(bearing: 10, band: level.targetBand)]
        let budget: FairnessBudget = try FairnessBudget(minLength: 1, maxLength: 2, maxBranching: 27, nodeBudget: 10_000)
        let puzzle: PuzzleLevel<HueCompassRules> =
            try PuzzleLevel(rulesID: rules.rulesID, start: rules.initialState, solution: solution,
                            uniqueness: .solution, budget: budget, seed: 2_331)
        let certificate: PuzzleCertificate = PuzzleValidator.certify(puzzle, rules: rules)
        #expect(certificate.verdict == .valid)
        #expect(certificate.shortest == 2)
        #expect(certificate.solvedStates == 1)
        #expect(certificate.shortestPaths == 1)
        #expect(certificate.maxBranching == 27)
        #expect(certificate.explored <= 1 + 27 + 27 * 27)
        // A budget below the branching of 27 is refused.
        let narrow: FairnessBudget = try FairnessBudget(minLength: 1, maxLength: 2, maxBranching: 26, nodeBudget: 10_000)
        let tight: PuzzleLevel<HueCompassRules> =
            try PuzzleLevel(rulesID: rules.rulesID, start: rules.initialState, solution: solution, budget: narrow)
        #expect(PuzzleValidator.certify(tight, rules: rules).verdict == .tooBranching(27))
    }

    @Test("PuzzleValidator refuses other rules and an illegal move")
    func refusals() throws {
        let level: HueCompassLevel = try Self.twoMoveLevel()
        let rules: HueCompassRules = HueCompassRules(level: level)
        let start: Position = rules.initialState
        let budget: FairnessBudget = try FairnessBudget(minLength: 1, maxLength: 8, maxBranching: 27, nodeBudget: 10)
        let solution: [HueCompassAction] = [.turn(-1), .select(bearing: 10, band: level.targetBand)]
        let wrong: PuzzleLevel<HueCompassRules> =
            try PuzzleLevel(rulesID: "r02-g03-other", start: start, solution: solution, budget: budget)
        #expect(PuzzleValidator.certify(wrong, rules: rules).verdict == .wrongRules)

        let illegalSolutions: [[HueCompassAction]] = [
            [.turn(-2)],
            [.select(bearing: 10, band: level.targetBand)],
            [.turn(-1), .select(bearing: 11, band: level.targetBand)],
            [.turn(-1), .select(bearing: 10, band: level.targetBand), .probe],
        ]
        let indices: [Int] = [0, 0, 1, 2]
        for (i, illegalSolution) in illegalSolutions.enumerated() {
            let illegal: PuzzleLevel<HueCompassRules> =
                try PuzzleLevel(rulesID: rules.rulesID, start: start, solution: illegalSolution, budget: budget)
            #expect(PuzzleValidator.certify(illegal, rules: rules).verdict == .illegalMove(indices[i]))
        }
    }
}
