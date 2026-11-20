// WaveKnotKeeperRulesTests — feature 321 (R02-G03-01) T-R02G0301-005 (FR-R02G0301-008). The R02-F23 puzzle contract of
// Wave Knot Keeper: the initial state is the level's rope; moves are listed point index ascending, then direction in
// declaration order, keeping exactly those the play's refusal accepts (checked against a brute force, at most 16 · 6);
// every listed move is accepted by a play from that state and every unlisted one refused; the known fixture solutions
// reach a solved state through the rules for 100 fixtures; the rules agree with the play on 200 seeded random walks (rope
// equality and solved equal to the play's won stage); and R02-F23's PuzzleValidator certifies a seeded level two moves
// from its goal and refuses other rules and illegal moves. Fixtures seed 2_321. Explicit types, plain loops, short runs.
import Testing
@testable import WaveKnotKeeperCore
import VisualCoreSimulation

@Suite("Wave Knot Keeper rules (R02-F23 contract)")
struct WaveKnotKeeperRulesTests {
    /// The directions in declaration order, written out so the brute force does not reuse `allCases`.
    static let directions: [WaveKnotKeeperDirection] = [.plusX, .minusX, .plusY, .minusY, .plusZ, .minusZ]

    /// The brute-force move list: every point index, every direction, kept when the play's refusal finds nothing.
    static func bruteForceMoves(_ state: [WaveKnotKeeperPoint], level: WaveKnotKeeperLevel) -> [WaveKnotKeeperMove] {
        var result: [WaveKnotKeeperMove] = []
        var point: Int = 0
        while point < state.count {
            for direction in directions {
                let move: WaveKnotKeeperMove = WaveKnotKeeperMove(point: point, direction: direction)
                if WaveKnotKeeperPlay.refusal(of: move, points: state, level: level) == nil { result.append(move) }
            }
            point += 1
        }
        return result
    }

    /// Every candidate step of `state` plus two out-of-range point indices.
    static func candidates(_ state: [WaveKnotKeeperPoint]) -> [WaveKnotKeeperMove] {
        var result: [WaveKnotKeeperMove] = []
        for point in -1...state.count {
            for direction in directions {
                result.append(WaveKnotKeeperMove(point: point, direction: direction))
            }
        }
        return result
    }

    /// Checks that `play` (stage `playing`, allowance left) accepts every listed move and refuses every other candidate,
    /// and that each accepted move lands where `apply` says.
    static func checkAgainstPlay(_ play: WaveKnotKeeperPlay, rules: WaveKnotKeeperRules) {
        let state: [WaveKnotKeeperPoint] = play.points
        let listed: [WaveKnotKeeperMove] = rules.moves(in: state)
        let listedSet: Set<WaveKnotKeeperMove> = Set(listed)
        for move in candidates(state) {
            var copy: WaveKnotKeeperPlay = play
            var accepted: Bool = true
            do {
                try copy.apply(move, expecting: play.fingerprint)
            } catch {
                accepted = false
            }
            #expect(accepted == listedSet.contains(move))
            let next: [WaveKnotKeeperPoint]? = rules.apply(move, to: state)
            #expect((next != nil) == listedSet.contains(move))
            if accepted, let next {
                #expect(copy.points == next)
            }
        }
    }

    /// The certification budget: solutions of 1 … 2 moves, at most 96 moves per state, at most 1 + 96 + 96 · 96 states.
    static func budget() throws -> FairnessBudget {
        try FairnessBudget(minLength: 1, maxLength: 2, maxBranching: 96, nodeBudget: 10_000)
    }

    /// The first fixture whose rope two solution moves before the goal is a valid level start (not already won), with
    /// those two moves as its solution.
    static func twoMoveLevel() -> (level: WaveKnotKeeperLevel, solution: [WaveKnotKeeperMove])? {
        for index in 0..<40 {
            let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(index, gates: index % 2 == 1)
            let count: Int = fixture.solution.count
            guard count >= 2 else { continue }
            var points: [WaveKnotKeeperPoint] = fixture.level.points
            for move in fixture.solution.prefix(count - 2) {
                points[move.point] = points[move.point].moved(move.direction)
            }
            let tail: [WaveKnotKeeperMove] = Array(fixture.solution.suffix(2))
            let level: WaveKnotKeeperLevel? =
                try? WaveKnotKeeperLevel(id: "rules-two-move", seed: 2_321, band: fixture.level.band, points: points,
                                         gates: fixture.level.gates, target: fixture.level.target,
                                         tensionBound: fixture.level.tensionBound, allowance: 8)
            if let level { return (level, tail) }
        }
        return nil
    }

    @Test("rules id is the documented slug and the initial state is the level's rope")
    func conformance() {
        for index in 0..<10 {
            let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(index, gates: index % 2 == 1)
            let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: fixture.level)
            #expect(rules.rulesID == "r02-g03-wave-knot-keeper")
            #expect(rules.initialState == fixture.level.points)
            #expect(!rules.isSolved(rules.initialState))
        }
    }

    @Test("moves: the legal steps in point, direction order, equal to a brute force, at most 16 · 6")
    func movesOrder() {
        for index in 0..<60 {
            let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(index, gates: index % 2 == 1)
            let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: fixture.level)
            let states: [[WaveKnotKeeperPoint]] = [fixture.level.points, fixture.goal]
            for state in states {
                let moves: [WaveKnotKeeperMove] = rules.moves(in: state)
                #expect(moves == Self.bruteForceMoves(state, level: fixture.level))
                #expect(Set(moves).count == moves.count)
                #expect(moves.count <= 16 * 6)
                #expect(moves.count <= state.count * 6)
                // Strictly ascending in (point, direction index).
                var previous: Int = -1
                for move in moves {
                    var directionIndex: Int = 0
                    while Self.directions[directionIndex] != move.direction { directionIndex += 1 }
                    let key: Int = move.point * 6 + directionIndex
                    #expect(key > previous)
                    previous = key
                }
            }
        }
        // A rope with nothing in reach: the empty rope offers nothing and refuses every candidate.
        let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(0)
        let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: fixture.level)
        #expect(rules.moves(in: []).isEmpty)
        #expect(rules.apply(WaveKnotKeeperMove(point: 0, direction: .plusX), to: []) == nil)
    }

    @Test("apply refuses out-of-range, out-of-bounds and coincident steps and otherwise moves one point one unit")
    func applyRules() {
        let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(3)
        let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: fixture.level)
        let state: [WaveKnotKeeperPoint] = fixture.level.points
        #expect(rules.apply(WaveKnotKeeperMove(point: -1, direction: .plusX), to: state) == nil)
        #expect(rules.apply(WaveKnotKeeperMove(point: state.count, direction: .plusX), to: state) == nil)
        // Out of bounds: a point on the +x face of the lattice cannot step further.
        var edge: [WaveKnotKeeperPoint] = state
        edge[0] = WaveKnotKeeperPoint(x: 16, y: state[0].y, z: state[0].z)
        if !state.contains(edge[0]) {
            #expect(rules.apply(WaveKnotKeeperMove(point: 0, direction: .plusX), to: edge) == nil)
        }
        // Coincident: two points one unit apart along x.
        let pair: [WaveKnotKeeperPoint] = [
            WaveKnotKeeperPoint(x: 0, y: 0, z: 0), WaveKnotKeeperPoint(x: 1, y: 0, z: 0),
            WaveKnotKeeperPoint(x: 1, y: 5, z: 0), WaveKnotKeeperPoint(x: 0, y: 5, z: 0),
            WaveKnotKeeperPoint(x: -3, y: 5, z: 0), WaveKnotKeeperPoint(x: -3, y: 0, z: 0),
        ]
        #expect(rules.apply(WaveKnotKeeperMove(point: 0, direction: .plusX), to: pair) == nil)
        for start in [state, fixture.goal] {
            for move in rules.moves(in: start) {
                guard let next = rules.apply(move, to: start) else {
                    Issue.record("a listed move was refused: \(move)")
                    continue
                }
                var changes: Int = 0
                for i in start.indices where next[i] != start[i] {
                    changes += 1
                }
                #expect(changes == 1)
                #expect(next[move.point] == start[move.point].moved(move.direction))
                #expect(WaveKnotKeeperGeometry.tension(next) <= fixture.level.tensionBound)
            }
        }
    }

    @Test("each listed move is accepted by a play from that state and each unlisted one refused (40 fixtures)")
    func listedMatchesPlay() throws {
        for index in 0..<40 {
            let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(index, gates: index % 2 == 1)
            let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: fixture.level)
            let play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
            Self.checkAgainstPlay(play, rules: rules)
        }
    }

    @Test("the known solution reaches a solved state through the rules for 100 fixtures")
    func knownSolutions() {
        var solved: Int = 0
        for index in 0..<100 {
            let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(index, gates: index % 2 == 1)
            let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: fixture.level)
            var state: [WaveKnotKeeperPoint] = rules.initialState
            var legal: Bool = true
            for move in fixture.solution {
                guard rules.moves(in: state).contains(move), let next = rules.apply(move, to: state) else {
                    legal = false
                    break
                }
                state = next
            }
            #expect(legal)
            #expect(state == fixture.goal)
            if legal && rules.isSolved(state) { solved += 1 }
        }
        #expect(solved == 100)
    }

    @Test("rules and play agree on 200 seeded random walks")
    func agreesWithPlay() throws {
        var random: SeededRandom = SeededRandom(seed: 2_321)
        var wins: Int = 0
        var steps: Int = 0
        for index in 0..<200 {
            let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(index, gates: index % 2 == 1)
            let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: fixture.level)
            var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
            var state: [WaveKnotKeeperPoint] = rules.initialState
            #expect(state == play.points)
            var solutionStep: Int = 0
            while play.stage == .playing {
                let moves: [WaveKnotKeeperMove] = rules.moves(in: state)
                if moves.isEmpty { break }
                // Every fourth walk follows the known solution, so walks also reach wins.
                var move: WaveKnotKeeperMove = moves[Int(random.next() % UInt64(moves.count))]
                if index % 4 == 0 && solutionStep < fixture.solution.count {
                    move = fixture.solution[solutionStep]
                    solutionStep += 1
                }
                if steps % 7 == 0 { Self.checkAgainstPlay(play, rules: rules) }
                guard let next = rules.apply(move, to: state) else {
                    Issue.record("a chosen move was refused by the rules: \(move)")
                    break
                }
                try play.apply(move, expecting: play.fingerprint)
                state = next
                steps += 1
                #expect(state == play.points)
                #expect(rules.isSolved(state) == (play.stage == .won))
            }
            if play.stage == .won { wins += 1 }
        }
        #expect(wins >= 50)
        #expect(steps > 200)
    }

    @Test("PuzzleValidator certifies a seeded level two moves from its goal")
    func certifies() throws {
        guard let made = Self.twoMoveLevel() else {
            Issue.record("no fixture gives a two-move level")
            return
        }
        let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: made.level)
        let puzzle: PuzzleLevel<WaveKnotKeeperRules> =
            try PuzzleLevel(rulesID: rules.rulesID, start: made.level.points, solution: made.solution, uniqueness: .none,
                            budget: Self.budget(), seed: 2_321)
        let certificate: PuzzleCertificate = PuzzleValidator.certify(puzzle, rules: rules)
        #expect(certificate.verdict == .valid)
        let shortest: Int = certificate.shortest ?? 0
        #expect(shortest >= 1 && shortest <= 2)
        #expect(certificate.solvedStates >= 1)
        #expect(certificate.maxBranching <= made.level.points.count * 6)
        #expect(certificate.explored <= 1 + 96 + 96 * 96)
    }

    @Test("PuzzleValidator refuses other rules and an illegal move")
    func refusals() throws {
        let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(0)
        let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: fixture.level)
        let start: [WaveKnotKeeperPoint] = fixture.level.points
        let budget: FairnessBudget = try FairnessBudget(minLength: 1, maxLength: 64, maxBranching: 96, nodeBudget: 10)
        let wrong: PuzzleLevel<WaveKnotKeeperRules> =
            try PuzzleLevel(rulesID: "r02-g02-other", start: start, solution: fixture.solution, uniqueness: .none,
                            budget: budget)
        #expect(PuzzleValidator.certify(wrong, rules: rules).verdict == .wrongRules)

        let first: WaveKnotKeeperMove = fixture.solution[0]
        let illegalSolutions: [[WaveKnotKeeperMove]] = [
            [WaveKnotKeeperMove(point: start.count, direction: .plusX)],
            [WaveKnotKeeperMove(point: -1, direction: .minusZ)],
            [first, WaveKnotKeeperMove(point: 99, direction: .plusY)],
        ]
        let indices: [Int] = [0, 0, 1]
        for (i, illegalSolution) in illegalSolutions.enumerated() {
            let illegal: PuzzleLevel<WaveKnotKeeperRules> =
                try PuzzleLevel(rulesID: rules.rulesID, start: start, solution: illegalSolution, uniqueness: .none,
                                budget: budget)
            #expect(PuzzleValidator.certify(illegal, rules: rules).verdict == .illegalMove(indices[i]))
        }
    }
}
