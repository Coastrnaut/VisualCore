// MyceliumArchitectPuzzleTests — feature 511 (R02-G22-01) T-R02G2201-005 (FR-R02G2201-011; research R14). The
// R02-F23 puzzle contract of Mycelium Architect: the rules id and the start position; the fixture's winning arrangement
// is solved and the start is not; the legal moves in the order of research R14 (nutrients on empty cells in ascending
// (row, column), blockers likewise, clears of placed items ascending, seeds ascending, unseeds ascending), compared with
// an independent enumeration; a starting seed is never unseeded; none with the budget spent; the run and refused moves
// give nil; and agreement with the play on 200 seeded walks (a move is legal in the puzzle exactly when the play
// accepts it in `playing` with actions left, both produce the same arrangement and actions spent, and the goal test
// equals the play's run outcome). Explicit types, plain loops.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MyceliumArchitectCore

@Suite struct MyceliumArchitectPuzzleTests {
    typealias Puzzle = MyceliumArchitectPuzzle
    typealias Position = MyceliumArchitectPuzzle.Position
    typealias Action = MyceliumArchitectAction
    typealias Level = MyceliumArchitectLevel
    typealias Cell = MyceliumArchitectCell
    typealias Direction = MyceliumArchitectDirection
    typealias Arrangement = MyceliumArchitectArrangement
    typealias Play = MyceliumArchitectPlay

    /// The fixtures of the feature seed used here.
    static let fixtures: [MyceliumArchitectFixture] = MyceliumArchitectFixture.all(count: 40)

    /// An independent enumeration of the legal moves, checked here by hand without the play's `changed`.
    static func handMoves(_ state: Position, level: Level) -> [Action] {
        guard state.actionsSpent >= 0 && state.actionsSpent < level.budget else { return [] }
        let a: Arrangement = state.arrangement
        var moves: [Action] = []
        if a.nutrients.count < level.maxNutrients {
            for row in 0..<level.height {
                for column in 0..<level.width {
                    let cell = Cell(column: column, row: row)
                    if level.isEmpty(cell, in: a) { moves.append(.nutrient(cell)) }
                }
            }
        }
        if a.blockers.count < level.maxBlockers {
            for row in 0..<level.height {
                for column in 0..<level.width {
                    let cell = Cell(column: column, row: row)
                    if level.isEmpty(cell, in: a) { moves.append(.blocker(cell)) }
                }
            }
        }
        var placed: [Cell] = a.nutrients + a.blockers
        placed.sort { (p: Cell, q: Cell) -> Bool in p.row != q.row ? p.row < q.row : p.column < q.column }
        for cell in placed { moves.append(.clear(cell)) }
        if a.seeds.count < level.maxSeeds {
            for raw in 0..<8 where !a.seeds.contains(Direction(rawValue: raw)!) {
                moves.append(.seed(Direction(rawValue: raw)!))
            }
        }
        for raw in 0..<8 {
            let direction: Direction = Direction(rawValue: raw)!
            if a.seeds.contains(direction) && !level.startSeeds.contains(direction) { moves.append(.unseed(direction)) }
        }
        return moves
    }

    /// The R14 rank of a move: (group, key), group 0 nutrient, 1 blocker, 2 clear, 3 seed, 4 unseed, 5 run.
    static func rank(_ move: Action, width: Int) -> (Int, Int) {
        switch move {
        case .nutrient(let c): return (0, c.row * width + c.column)
        case .blocker(let c): return (1, c.row * width + c.column)
        case .clear(let c): return (2, c.row * width + c.column)
        case .seed(let d): return (3, d.rawValue)
        case .unseed(let d): return (4, d.rawValue)
        case .run: return (5, 0)
        }
    }

    /// Whether `moves` follow the order of research R14 strictly.
    static func inOrder(_ moves: [Action], width: Int) -> Bool {
        var index: Int = 1
        while index < moves.count {
            let p: (Int, Int) = rank(moves[index - 1], width: width)
            let q: (Int, Int) = rank(moves[index], width: width)
            if !(p.0 < q.0 || (p.0 == q.0 && p.1 < q.1)) { return false }
            index += 1
        }
        return true
    }

    /// A random action, legal or not, including cells just off the board and the run.
    static func randomAction(_ random: inout SeededRandom, level: Level) -> Action {
        let cell = Cell(column: random.int(-1...level.width), row: random.int(-1...level.height))
        let direction: Direction = Direction(rawValue: random.int(0...7))!
        switch random.int(0...5) {
        case 0: return .nutrient(cell)
        case 1: return .blocker(cell)
        case 2: return .clear(cell)
        case 3: return .seed(direction)
        case 4: return .unseed(direction)
        default: return .run
        }
    }

    /// A play of `level` in stage `playing`.
    static func playing(_ level: Level) throws -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    @Test func rulesIDStartAndGoal() throws {
        let fixture: MyceliumArchitectFixture = Self.fixtures[0]
        let puzzle = Puzzle(level: fixture.level)
        #expect(puzzle.rulesID == "r02-g22-mycelium-architect")
        #expect(puzzle.initialState == Position(arrangement: fixture.level.start, actionsSpent: 0))
        let data: Data = try JSONEncoder().encode(puzzle.initialState)
        #expect(try JSONDecoder().decode(Position.self, from: data) == puzzle.initialState)
        for fixture in Self.fixtures {
            let rules = Puzzle(level: fixture.level)
            #expect(!rules.isSolved(rules.initialState))
            #expect(rules.isSolved(Position(arrangement: fixture.winning, actionsSpent: 0)))
        }
    }

    @Test func moveOrderAndRefusals() throws {
        for fixture in Self.fixtures {
            let level: Level = fixture.level
            let rules = Puzzle(level: level)
            var state: Position = rules.initialState
            // The known actions are legal moves in R14 order and reach a solved position.
            for action in fixture.actions.dropLast() {
                let legal: [Action] = rules.moves(in: state)
                #expect(legal == Self.handMoves(state, level: level))
                #expect(Self.inOrder(legal, width: level.width))
                #expect(legal.count <= 2 * level.width * level.height + 20)
                #expect(legal.contains(action))
                guard let next = rules.apply(action, to: state) else {
                    Issue.record("known action refused")
                    break
                }
                #expect(next.actionsSpent == state.actionsSpent + 1)
                state = next
            }
            #expect(rules.isSolved(state) && state.arrangement == fixture.winning)
            // With the placed items present, clears follow the blockers in merged cell order.
            let legal: [Action] = rules.moves(in: state)
            #expect(legal == Self.handMoves(state, level: level) && Self.inOrder(legal, width: level.width))
            // The run and a spent budget are refused.
            #expect(rules.apply(.run, to: state) == nil && !legal.contains(.run))
            let spent = Position(arrangement: level.start, actionsSpent: level.budget)
            #expect(rules.moves(in: spent).isEmpty)
            #expect(rules.apply(.seed(.north), to: spent) == nil)
            #expect(rules.moves(in: Position(arrangement: level.start, actionsSpent: -1)).isEmpty)
            // Cells that are not empty and off the board are refused.
            #expect(rules.apply(.nutrient(level.root), to: rules.initialState) == nil)
            #expect(rules.apply(.blocker(Cell(column: -1, row: 0)), to: rules.initialState) == nil)
            #expect(rules.apply(.clear(level.root), to: rules.initialState) == nil)
        }
    }

    @Test func startingSeedIsNeverUnseeded() throws {
        var checked: Int = 0
        for fixture in Self.fixtures {
            let f: Level = fixture.level
            let first: Direction = fixture.winning.seeds[0]
            guard let level = try? Level(
                id: "start-seed", seed: f.seed, difficulty: f.difficulty, width: f.width, height: f.height,
                root: f.root, terminals: f.terminals, rocks: f.rocks, toxins: f.toxins,
                fixedNutrients: f.fixedNutrients, strength: f.strength, reach: f.reach, curvature: f.curvature,
                obstacle: f.obstacle, maxNutrients: f.maxNutrients, maxBlockers: f.maxBlockers,
                maxSeeds: max(2, f.maxSeeds), startSeeds: [first], pulses: f.pulses,
                nutrientBudget: f.nutrientBudget, weightLimit: f.weightLimit, budget: f.budget,
                tutorial: false) else { continue }
            let rules = Puzzle(level: level)
            let legal: [Action] = rules.moves(in: rules.initialState)
            #expect(legal == Self.handMoves(rules.initialState, level: level))
            #expect(!legal.contains(.unseed(first)) && !legal.contains(.seed(first)))
            #expect(rules.apply(.unseed(first), to: rules.initialState) == nil)
            var other: Direction = .north
            for raw in 0..<8 where Direction(rawValue: raw)! != first {
                other = Direction(rawValue: raw)!
                break
            }
            guard let seeded = rules.apply(.seed(other), to: rules.initialState) else {
                Issue.record("seed refused")
                continue
            }
            let after: [Action] = rules.moves(in: seeded)
            #expect(after.contains(.unseed(other)) && !after.contains(.unseed(first)))
            #expect(Self.inOrder(after, width: level.width))
            checked += 1
        }
        #expect(checked > 0)
    }

    @Test(arguments: [0, 1, 2, 3])
    func agreesWithThePlayOnSeededWalks(quarter: Int) throws {
        var random = SeededRandom(seed: 2_511 + UInt64(quarter))
        var compared: Int = 0
        for walk in 0..<50 {
            let fixture: MyceliumArchitectFixture = Self.fixtures[(walk + quarter * 50) % Self.fixtures.count]
            let rules = Puzzle(level: fixture.level)
            var play: Play = try Self.playing(fixture.level)
            var state: Position = rules.initialState
            for _ in 0..<(fixture.level.budget + 6) {
                let legal: [Action] = rules.moves(in: state)
                let move: Action
                if !legal.isEmpty && random.int(0...2) > 0 {
                    move = legal[random.int(0...(legal.count - 1))]
                } else {
                    move = Self.randomAction(&random, level: fixture.level)
                }
                let next: Position? = rules.apply(move, to: state)
                var trial: Play = play
                let accepted: Bool = (try? trial.apply(move, expecting: trial.fingerprint)) != nil
                if case .run = move {
                    // The goal test equals the play's run outcome; the run is never a puzzle move.
                    #expect(next == nil && !legal.contains(move))
                    #expect(accepted && (trial.stage == .won) == rules.isSolved(state))
                    continue
                }
                #expect(accepted == (next != nil), "\(move)")
                #expect(legal.contains(move) == (next != nil))
                if let next, accepted {
                    #expect(next.arrangement == trial.arrangement && next.actionsSpent == trial.actionsSpent)
                    #expect(rules.isSolved(next) == trial.report.wins)
                    state = next
                    play = trial
                }
                compared += 1
            }
            if play.actionsLeft == 0 { #expect(rules.moves(in: state).isEmpty) }
        }
        #expect(compared > 300)
    }
}
