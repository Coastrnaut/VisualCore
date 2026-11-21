// ColorfallCanyonsRulesTests — feature 341 (R02-G05-01) T-R02G0501-005 (FR-R02G0501-010). The R02-F23 puzzle contract
// of Colorfall Canyons: the rules id and the initial position (the level's starting fluid, nothing spent, playing); the
// moves in their fixed order (carve each carvable cell in index order, valve each spring, then step(1)); carves and
// valves only while actions are left; ended positions offer and accept nothing, and unlisted moves are refused; the rules
// agree with ColorfallCanyonsPlay (fluid, spent and outcome) after every move of 200 seeded random walks over fixtures
// and random levels; each fixture's known solution, its step written as single ticks, solves through the rules; and
// R02-F23's PuzzleValidator certifies a hand-made two-tick level with a unique solution and refuses an illegal move.
// Fixtures seed 2_341. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import ColorfallCanyonsCore
import VisualCoreSimulation

@Suite("Colorfall Canyons rules (R02-F23 contract)")
struct ColorfallCanyonsRulesTests {
    typealias Position = ColorfallCanyonsRules.Position

    /// A playing play of `level` (begun, the tutorial dismissed when it has one).
    static func playing(_ level: ColorfallCanyonsLevel) throws -> ColorfallCanyonsPlay {
        var play: ColorfallCanyonsPlay = ColorfallCanyonsPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The rules' outcome for a play stage.
    static func outcome(of stage: ColorfallCanyonsStage) -> Position.Outcome? {
        switch stage {
        case .playing: .playing
        case .won: .won
        case .failed: .failed
        default: nil
        }
    }

    /// A solution with every step(n) written as n single steps, the only steps the rules list.
    static func singleTickSolution(_ solution: [ColorfallCanyonsAction]) -> [ColorfallCanyonsAction] {
        var result: [ColorfallCanyonsAction] = []
        for action in solution {
            if case .step(let ticks) = action {
                for _ in 0..<ticks { result.append(.step(1)) }
            } else {
                result.append(action)
            }
        }
        return result
    }

    /// The moves the rules must list, computed independently from the level's grounds, springs and basins.
    static func expectedMoves(level: ColorfallCanyonsLevel, state: Position) -> [ColorfallCanyonsAction] {
        guard state.outcome == .playing else { return [] }
        var result: [ColorfallCanyonsAction] = []
        if state.spent < level.budget {
            let occupied: Set<Int> = Set(level.springs.map(\.cell) + level.basins.map(\.cell))
            for cell in 0..<level.cellCount
            where level.grounds[cell] == .open && !occupied.contains(cell) && state.fluid.heights[cell] > 0 {
                result.append(.carve(cell))
            }
            for spring in 0..<level.springs.count { result.append(.valve(spring)) }
        }
        result.append(.step(1))
        return result
    }

    /// A hand-made 4 × 4 level two ticks from its goal: row 1 holds an open spring (height 1, release 2, supply 2), the
    /// basin east of it (height 0, fill 2, capacity 2) and one carvable open cell; every other cell is rock but a drain in
    /// the corner. Flow rate 2, budget 1, tick limit 10. Tick 1 releases 2 units, tick 2 passes them into the basin.
    static func twoTickLevel() throws -> ColorfallCanyonsLevel {
        var grounds: [ColorfallCanyonsGround] = Array(repeating: .rock, count: 16)
        var heights: [Int] = Array(repeating: 15, count: 16)
        grounds[4] = .open
        heights[4] = 1
        grounds[5] = .open
        heights[5] = 0
        grounds[6] = .open
        heights[6] = 5
        grounds[15] = .drain
        heights[15] = 0
        let spring: ColorfallCanyonsSpring = ColorfallCanyonsSpring(cell: 4, color: .cyan, release: 2, supply: 2, open: true)
        let basin: ColorfallCanyonsBasin = ColorfallCanyonsBasin(cell: 5, capacity: 2, fill: 2, shares: [1_000, 0, 0],
                                                                 tolerance: 0, isProtected: false, toleratedWrong: 0)
        return try ColorfallCanyonsLevel(id: "rules-two-tick", seed: 2_341, difficulty: 1, columns: 4, rows: 4,
                                         heights: heights, grounds: grounds, springs: [spring], basins: [basin],
                                         flowRate: 2, budget: 1, tickLimit: 10)
    }

    @Test("rules id is the documented slug and the initial state is the level's starting fluid, nothing spent, playing")
    func conformance() {
        for index in 0..<20 {
            let level: ColorfallCanyonsLevel = index % 2 == 0
                ? ColorfallCanyonsFixtures.fixture(index).level
                : ColorfallCanyonsFixtures.randomLevel(index, tutorial: true)
            let rules: ColorfallCanyonsRules = ColorfallCanyonsRules(level: level)
            #expect(rules.rulesID == "r02-g05-colorfall-canyons")
            #expect(rules.level == level)
            let start: Position = rules.initialState
            #expect(start == Position(fluid: ColorfallCanyonsFluid(level: level), spent: 0, outcome: .playing))
            #expect(!rules.isSolved(start))
        }
    }

    @Test("moves: carvable cells in index order, then every spring's valve, then step(1)")
    func movesOrder() throws {
        for index in 0..<40 {
            let level: ColorfallCanyonsLevel = index % 2 == 0
                ? ColorfallCanyonsFixtures.fixture(index).level
                : ColorfallCanyonsFixtures.randomLevel(index)
            let rules: ColorfallCanyonsRules = ColorfallCanyonsRules(level: level)
            var state: Position = rules.initialState
            // Check the start, then after carving the first listed cell down to 0 (it leaves the list).
            for _ in 0..<2 {
                let moves: [ColorfallCanyonsAction] = rules.moves(in: state)
                #expect(moves == Self.expectedMoves(level: level, state: state))
                #expect(Set(moves).count == moves.count)
                #expect(moves.last == .step(1))
                let carves: Int = moves.filter { if case .carve = $0 { true } else { false } }.count
                #expect(moves.count == carves + level.springs.count + 1)
                guard case .carve(let cell) = moves.first else { break }
                var height: Int = state.fluid.heights[cell]
                var fluid: ColorfallCanyonsFluid = state.fluid
                while height > 0 {
                    fluid.carve(cell)
                    height -= 1
                }
                state = Position(fluid: fluid, spent: 0, outcome: .playing)
                #expect(!rules.moves(in: state).contains(.carve(cell)))
                #expect(rules.apply(.carve(cell), to: state) == nil)
            }
        }
    }

    @Test("carves and valves are offered and accepted only while actions are left")
    func budgetGating() throws {
        for index in 0..<20 {
            let level: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.randomLevel(index)
            let rules: ColorfallCanyonsRules = ColorfallCanyonsRules(level: level)
            let start: Position = rules.initialState
            let open: [ColorfallCanyonsAction] = rules.moves(in: start)
            let exhausted: Position = Position(fluid: start.fluid, spent: level.budget, outcome: .playing)
            #expect(rules.moves(in: exhausted) == [.step(1)])
            for move in open where move != .step(1) {
                #expect(rules.apply(move, to: exhausted) == nil)
                // With one action left the move is accepted and spends it.
                let last: Position = Position(fluid: start.fluid, spent: level.budget - 1, outcome: .playing)
                let after: Position = try #require(rules.apply(move, to: last))
                #expect(after.spent == level.budget)
                #expect(after.outcome == .playing)
                #expect(after.fluid.tick == 0)
                #expect(rules.moves(in: after) == [.step(1)])
            }
            let stepped: Position = try #require(rules.apply(.step(1), to: exhausted))
            #expect(stepped.spent == level.budget)
            #expect(stepped.fluid.tick == 1)
        }
    }

    @Test("ended positions offer and accept nothing; unlisted moves are refused")
    func endedAndUnlisted() throws {
        let fixture: ColorfallCanyonsFixture = ColorfallCanyonsFixtures.fixture(4)
        let level: ColorfallCanyonsLevel = fixture.level
        let rules: ColorfallCanyonsRules = ColorfallCanyonsRules(level: level)
        let start: Position = rules.initialState
        let outcomes: [Position.Outcome] = [.won, .failed]
        for outcome in outcomes {
            let ended: Position = Position(fluid: start.fluid, spent: 0, outcome: outcome)
            #expect(rules.moves(in: ended).isEmpty)
            let candidates: [ColorfallCanyonsAction] = [.carve(fixture.dam), .valve(0), .step(1)]
            for move in candidates {
                #expect(rules.apply(move, to: ended) == nil)
            }
            #expect(rules.isSolved(ended) == (outcome == .won))
        }
        let unlisted: [ColorfallCanyonsAction] = [.step(0), .step(2), .step(600), .step(-1), .carve(-1),
                                                  .carve(level.cellCount), .carve(0), .carve(level.springs[0].cell),
                                                  .carve(level.basins[0].cell), .valve(-1), .valve(level.springs.count)]
        let listed: Set<ColorfallCanyonsAction> = Set(rules.moves(in: start))
        for move in unlisted {
            #expect(!listed.contains(move))
            #expect(rules.apply(move, to: start) == nil)
        }
        // Listed moves: a carve lowers one step and a valve toggles, each spending one action; a step spends nothing.
        let carved: Position = try #require(rules.apply(.carve(fixture.dam), to: start))
        #expect(carved.fluid.heights[fixture.dam] == start.fluid.heights[fixture.dam] - 1)
        #expect(carved.spent == 1 && carved.outcome == .playing)
        let toggled: Position = try #require(rules.apply(.valve(0), to: start))
        #expect(toggled.fluid.valves[0] == !start.fluid.valves[0])
        #expect(toggled.spent == 1)
        let stepped: Position = try #require(rules.apply(.step(1), to: start))
        #expect(stepped.fluid.tick == 1 && stepped.spent == 0)
    }

    @Test("rules and play agree on fluid, spent and outcome after every move of 200 seeded random walks")
    func agreesWithPlay() throws {
        var random: ColorfallCanyonsRandom = ColorfallCanyonsRandom(seed: ColorfallCanyonsFixtures.seed)
        var wins: Int = 0
        var failures: Int = 0
        var moves: Int = 0
        var carvesAndValves: Int = 0
        for index in 0..<200 {
            let fixture: ColorfallCanyonsFixture = ColorfallCanyonsFixtures.fixture(index, tutorial: index % 3 == 2)
            let level: ColorfallCanyonsLevel = index % 2 == 0
                ? fixture.level
                : ColorfallCanyonsFixtures.randomLevel(index, tutorial: index % 3 == 2)
            let rules: ColorfallCanyonsRules = ColorfallCanyonsRules(level: level)
            var play: ColorfallCanyonsPlay = try Self.playing(level)
            var state: Position = rules.initialState
            #expect(state.fluid == play.fluid && state.spent == play.spent)
            let solution: [ColorfallCanyonsAction] = Self.singleTickSolution(fixture.solution)
            var solutionStep: Int = 0
            var walkSteps: Int = 0
            while play.stage == .playing && walkSteps < 100 {
                let listed: [ColorfallCanyonsAction] = rules.moves(in: state)
                if walkSteps < 20 { #expect(listed == Self.expectedMoves(level: level, state: state)) }
                // Every fourth walk follows the fixture's known solution; the others mostly step, sometimes act.
                let move: ColorfallCanyonsAction
                if index % 4 == 0 && solutionStep < solution.count {
                    move = solution[solutionStep]
                    solutionStep += 1
                } else if random.int(0...9) < 7 {
                    move = .step(1)
                } else {
                    move = listed[random.int(0...(listed.count - 1))]
                }
                let next: Position = try #require(rules.apply(move, to: state))
                try play.apply(move, expecting: play.fingerprint)
                state = next
                moves += 1
                walkSteps += 1
                if move != .step(1) { carvesAndValves += 1 }
                #expect(state.fluid == play.fluid)
                #expect(state.spent == play.spent)
                #expect(Self.outcome(of: play.stage) == state.outcome)
                #expect(rules.isSolved(state) == (play.stage == .won))
            }
            // A walk ends with the play, or after 100 moves on a random level with a long tick limit.
            #expect(play.stage != .playing || (index % 2 == 1 && walkSteps == 100))
            #expect(rules.moves(in: state).isEmpty == (play.stage != .playing))
            if play.stage == .won { wins += 1 }
            if play.stage == .failed { failures += 1 }
        }
        #expect(wins >= 50)
        #expect(failures >= 50)
        #expect(moves > 1_000)
        #expect(carvesAndValves > 100)
    }

    @Test("each fixture's known solution, its step as single ticks, solves through the rules (100 fixtures)")
    func knownSolutions() throws {
        var solved: Int = 0
        for index in 0..<100 {
            let fixture: ColorfallCanyonsFixture = ColorfallCanyonsFixtures.fixture(index)
            let rules: ColorfallCanyonsRules = ColorfallCanyonsRules(level: fixture.level)
            var state: Position = rules.initialState
            var legal: Bool = true
            for move in Self.singleTickSolution(fixture.solution) {
                if state.outcome != .playing { break }
                guard rules.moves(in: state).contains(move), let next = rules.apply(move, to: state) else {
                    legal = false
                    break
                }
                state = next
            }
            #expect(legal)
            // The play's single step(tickLimit) stops at the same tick with the same fluid.
            var play: ColorfallCanyonsPlay = try Self.playing(fixture.level)
            for action in fixture.solution { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .won)
            #expect(play.fluid == state.fluid && play.spent == state.spent)
            if legal && rules.isSolved(state) { solved += 1 }
        }
        #expect(solved == 100)
    }

    @Test("positions round-trip through JSON")
    func coding() throws {
        let level: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.randomLevel(3)
        let rules: ColorfallCanyonsRules = ColorfallCanyonsRules(level: level)
        var state: Position = rules.initialState
        for _ in 0..<5 { state = try #require(rules.apply(.step(1), to: state)) }
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(Position.self, from: data) == state)
    }

    @Test("PuzzleValidator certifies a hand-made two-tick level with a unique solution")
    func certifies() throws {
        let level: ColorfallCanyonsLevel = try Self.twoTickLevel()
        let rules: ColorfallCanyonsRules = ColorfallCanyonsRules(level: level)
        #expect(rules.moves(in: rules.initialState) == [.carve(6), .valve(0), .step(1)])
        let solution: [ColorfallCanyonsAction] = [.step(1), .step(1)]
        let budget: FairnessBudget = try FairnessBudget(minLength: 1, maxLength: 4, maxBranching: 3, nodeBudget: 10_000)
        let puzzle: PuzzleLevel<ColorfallCanyonsRules> =
            try PuzzleLevel(rulesID: rules.rulesID, start: rules.initialState, solution: solution,
                            uniqueness: .solution, budget: budget, seed: 2_341)
        let certificate: PuzzleCertificate = PuzzleValidator.certify(puzzle, rules: rules)
        #expect(certificate.verdict == .valid)
        #expect(certificate.shortest == 2)
        #expect(certificate.shortestPaths == 1)
        #expect(certificate.maxBranching == 3)
        #expect(certificate.explored <= 1 + 3 + 9 + 27 + 81)
        // A branching bound below 3 is refused.
        let narrow: FairnessBudget = try FairnessBudget(minLength: 1, maxLength: 4, maxBranching: 2, nodeBudget: 10_000)
        let tight: PuzzleLevel<ColorfallCanyonsRules> =
            try PuzzleLevel(rulesID: rules.rulesID, start: rules.initialState, solution: solution, budget: narrow)
        #expect(PuzzleValidator.certify(tight, rules: rules).verdict == .tooBranching(3))
    }

    @Test("PuzzleValidator refuses other rules, an illegal move and an unsolved solution")
    func refusals() throws {
        let level: ColorfallCanyonsLevel = try Self.twoTickLevel()
        let rules: ColorfallCanyonsRules = ColorfallCanyonsRules(level: level)
        let start: Position = rules.initialState
        let budget: FairnessBudget = try FairnessBudget(minLength: 1, maxLength: 8, maxBranching: 3, nodeBudget: 10)
        let solution: [ColorfallCanyonsAction] = [.step(1), .step(1)]
        let wrong: PuzzleLevel<ColorfallCanyonsRules> =
            try PuzzleLevel(rulesID: "r02-g04-hue-compass", start: start, solution: solution, budget: budget)
        #expect(PuzzleValidator.certify(wrong, rules: rules).verdict == .wrongRules)
        let illegalSolutions: [[ColorfallCanyonsAction]] = [
            [.step(2)],
            [.carve(5)],
            [.valve(0), .valve(0)],
            [.step(1), .step(1), .step(1)],
        ]
        let indices: [Int] = [0, 0, 1, 2]
        for (i, illegalSolution) in illegalSolutions.enumerated() {
            let illegal: PuzzleLevel<ColorfallCanyonsRules> =
                try PuzzleLevel(rulesID: rules.rulesID, start: start, solution: illegalSolution, budget: budget)
            #expect(PuzzleValidator.certify(illegal, rules: rules).verdict == .illegalMove(indices[i]))
        }
        let unsolved: PuzzleLevel<ColorfallCanyonsRules> =
            try PuzzleLevel(rulesID: rules.rulesID, start: start, solution: [.step(1)], budget: budget)
        #expect(PuzzleValidator.certify(unsolved, rules: rules).verdict == .notSolved)
    }
}
