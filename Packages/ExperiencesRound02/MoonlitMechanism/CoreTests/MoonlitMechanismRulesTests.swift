// MoonlitMechanismRulesTests — feature 431 (R02-G14-01) T-R02G1401-005 (FR-R02G1401-010). The rules as an R02-F23
// puzzle contract: the rules id and start position; the exact move order on a hand level (turn −1, +1; every re-seat by
// gear 1 … n − 1, then −1, +1; lamp −1, +1 when in range; then the run) and its refusals; the agreement with
// `MoonlitMechanismPlay` step by step on 200 seeded random walks (seed 2_431, fixture levels): on the first 20 walks
// every candidate (turns by −2 … 2, re-seats of gears −1 … n by −2 … 2, lamp steps by −2 … 2, the run) is tried with
// `apply(_:expecting:)` on a copy of the play with its current fingerprint and the accepted candidates are exactly the
// legal moves in order; on the others every legal move and 8 sampled candidates are tried; applying the chosen move gives
// the same phases, height, actions spent and outcome as the play's stage; one walk in three follows the fixture's known
// winning actions, so both outcomes occur; terminal positions (won, failed by a run, failed by the budget) have no moves
// and refuse every move; and the fixtures' known actions are legal at every step and solve. Explicit types, plain loops;
// each test well under 10 s.
import Testing
import VisualCoreSimulation
@testable import MoonlitMechanismCore

@Suite("MoonlitMechanismRules")
struct MoonlitMechanismRulesTests {
    typealias Rules = MoonlitMechanismRules
    typealias Position = MoonlitMechanismRules.Position

    /// The walk seed.
    static let walkSeed: UInt64 = 2_431
    /// The number of seeded walks.
    static let walkCount: Int = 200
    /// The walks whose every step tries every candidate with the play's `apply`.
    static let exhaustiveWalks: Int = 20
    /// The candidates per step of a later walk also tried with the play's `apply`.
    static let sampledCandidates: Int = 8

    /// A hand level: gears of 6, 12 (on gear 0) and 8 (on gear 1) teeth, three lamp heights starting at 1, budget 3.
    static func handLevel(budget: Int = 3) throws -> MoonlitMechanismLevel {
        func gear(_ teeth: Int, _ parent: Int?, _ column: Int) -> MoonlitMechanismGear {
            var blades: [Bool] = Array(repeating: false, count: teeth)
            blades[0] = true
            var slots: [[MoonlitMechanismCell]] = []
            for k in 0..<teeth { slots.append([MoonlitMechanismCell(column: k % 3, row: 1)]) }
            return MoonlitMechanismGear(teeth: teeth, phase: 0, blades: blades, depth: 1,
                                        centre: MoonlitMechanismCell(column: column, row: 1), parent: parent,
                                        alignment: 0, slots: slots)
        }
        let gears: [MoonlitMechanismGear] = [gear(6, nil, 1), gear(12, 0, 4), gear(8, 1, 7)]
        let first: [Int] = MoonlitMechanismTrain.cast(gears, phases: [0, 0, 0], height: 1, width: 10, rows: 8)
        let second: [Int] = MoonlitMechanismTrain.cast(gears, phases: MoonlitMechanismTrain.turned(gears,
            phases: [0, 0, 0], by: 2), height: 1, width: 10, rows: 8)
        return try MoonlitMechanismLevel(
            id: "hand", seed: 1, difficulty: 1, gears: gears, width: 10, rows: 8, lampHeights: 3, startingHeight: 1,
            keyFrames: [MoonlitMechanismKeyFrame(turns: 0, target: first, required: true),
                        MoonlitMechanismKeyFrame(turns: 2, target: second, required: true)],
            forbidden: [], allowance: 0, budget: budget)
    }

    /// A play of `level` started and past its tutorial.
    static func started(_ level: MoonlitMechanismLevel) -> MoonlitMechanismPlay {
        var play = MoonlitMechanismPlay(level: level)
        try? play.handle(.begin)
        if level.tutorial { try? play.handle(.dismissTutorial) }
        return play
    }

    /// The play after `action` (tried on a copy), or nil when the play refuses it.
    static func applied(_ play: MoonlitMechanismPlay, _ action: MoonlitMechanismAction,
                        fingerprint: String) -> MoonlitMechanismPlay? {
        var copy: MoonlitMechanismPlay = play
        do {
            try copy.apply(action, expecting: fingerprint)
            return copy
        } catch {
            return nil
        }
    }

    /// The rules' outcome of `play`'s stage.
    static func outcome(_ play: MoonlitMechanismPlay) -> Position.Outcome {
        switch play.stage {
        case .won: return .won
        case .failed: return .failed
        default: return .playing
        }
    }

    /// The rules' position of `play`.
    static func position(_ play: MoonlitMechanismPlay) -> Position {
        Position(phases: play.phases, height: play.height, actionsSpent: play.actionsSpent, outcome: outcome(play))
    }

    /// Every candidate action of a level with `count` gears: turns by −2 … 2, re-seats of gears −1 … `count` by
    /// −2 … 2, lamp steps by −2 … 2, then the run.
    static func candidates(_ count: Int) -> [MoonlitMechanismAction] {
        var result: [MoonlitMechanismAction] = []
        for step in -2...2 { result.append(.turn(step)) }
        for gear in -1...count {
            for step in -2...2 { result.append(.reseat(gear, step)) }
        }
        for step in -2...2 { result.append(.lamp(step)) }
        result.append(.run)
        return result
    }

    @Test("rules id and initial position")
    func initialPosition() throws {
        let level: MoonlitMechanismLevel = try Self.handLevel()
        let rules = Rules(level: level)
        #expect(rules.rulesID == "r02-g14-moonlit-mechanism")
        let start: Position = rules.initialState
        #expect(start.phases == [0, 0, 0])
        #expect(start.height == 1)
        #expect(start.actionsSpent == 0)
        #expect(start.outcome == .playing)
        #expect(!rules.isSolved(start))
        #expect(start == Self.position(Self.started(level)))
        let fixtures: [MoonlitMechanismFixture] = MoonlitMechanismFixture.all(count: 10)
        for (index, fixture) in fixtures.enumerated() {
            let fixtureRules = Rules(level: fixture.level)
            #expect(fixtureRules.initialState.phases == fixture.level.startingPhases, "fixture \(index) phases")
            #expect(fixtureRules.initialState.height == fixture.level.startingHeight, "fixture \(index) height")
            #expect(fixtureRules.initialState == Self.position(Self.started(fixture.level)), "fixture \(index) start")
        }
    }

    @Test("legal moves: turns, re-seats by gear then −1, +1, lamp steps in range, then the run")
    func handOrder() throws {
        let rules = Rules(level: try Self.handLevel())
        let start: Position = rules.initialState
        #expect(rules.moves(in: start) == [.turn(-1), .turn(1), .reseat(1, -1), .reseat(1, 1), .reseat(2, -1),
                                           .reseat(2, 1), .lamp(-1), .lamp(1), .run])
        #expect(rules.apply(.turn(0), to: start) == nil)
        #expect(rules.apply(.turn(2), to: start) == nil)
        #expect(rules.apply(.reseat(0, 1), to: start) == nil)
        #expect(rules.apply(.reseat(3, 1), to: start) == nil)
        #expect(rules.apply(.reseat(-1, 1), to: start) == nil)
        #expect(rules.apply(.reseat(1, 2), to: start) == nil)
        #expect(rules.apply(.lamp(2), to: start) == nil)
        // A turn moves gear 0 and gear 2 forward and gear 1 back.
        let turned: Position = try #require(rules.apply(.turn(1), to: start))
        #expect(turned.phases == [1, 11, 1])
        #expect(turned.actionsSpent == 1)
        #expect(turned.outcome == .playing)
        // At the lowest height only lamp +1 is offered.
        let low: Position = try #require(rules.apply(.lamp(-1), to: start))
        #expect(low.height == 0)
        #expect(rules.moves(in: low) == [.turn(-1), .turn(1), .reseat(1, -1), .reseat(1, 1), .reseat(2, -1),
                                         .reseat(2, 1), .lamp(1), .run])
        #expect(rules.apply(.lamp(-1), to: low) == nil)
        // At the highest height only lamp −1 is offered.
        let high: Position = try #require(rules.apply(.lamp(1), to: start))
        #expect(high.height == 2)
        #expect(rules.moves(in: high) == [.turn(-1), .turn(1), .reseat(1, -1), .reseat(1, 1), .reseat(2, -1),
                                          .reseat(2, 1), .lamp(-1), .run])
        let reseated: Position = try #require(rules.apply(.reseat(2, -1), to: start))
        #expect(reseated.phases == [0, 0, 7])
    }

    @Test("terminal positions: won, failed by a run, failed by the budget offer and accept nothing")
    func terminalPositions() throws {
        let rules = Rules(level: try Self.handLevel())
        let start: Position = rules.initialState
        let won: Position = try #require(rules.apply(.run, to: start))
        #expect(won.outcome == .won)
        #expect(rules.isSolved(won))
        let misaligned: Position = try #require(rules.apply(.reseat(1, 1), to: start))
        let jammed: Position = try #require(rules.apply(.run, to: misaligned))
        #expect(jammed.outcome == .failed)
        #expect(jammed.actionsSpent == 2)
        let two: Position = try #require(rules.apply(.turn(1), to: misaligned))
        #expect(two.outcome == .playing)
        let spent: Position = try #require(rules.apply(.turn(-1), to: two))
        #expect(spent.outcome == .failed)
        #expect(spent.actionsSpent == 3)
        // A run on the last action of the budget can still win.
        let back: Position = try #require(rules.apply(.reseat(1, -1), to: misaligned))
        let lastRun: Position = try #require(rules.apply(.run, to: back))
        #expect(lastRun.outcome == .won)
        #expect(lastRun.actionsSpent == 3)
        for terminal in [won, jammed, spent, lastRun] {
            #expect(rules.moves(in: terminal).isEmpty)
            for candidate in Self.candidates(3) {
                #expect(rules.apply(candidate, to: terminal) == nil, "terminal refuses \(candidate)")
            }
        }
    }

    @Test("rules and play agree step by step on 200 seeded walks")
    func agreementWithPlay() throws {
        let fixtures: [MoonlitMechanismFixture] = MoonlitMechanismFixture.all(count: Self.walkCount)
        var random = SeededRandom(seed: Self.walkSeed)
        var wins: Int = 0
        var failures: Int = 0
        for (walk, fixture) in fixtures.enumerated() {
            let level: MoonlitMechanismLevel = fixture.level
            let rules = Rules(level: level)
            let all: [MoonlitMechanismAction] = Self.candidates(level.gears.count)
            var play: MoonlitMechanismPlay = Self.started(level)
            var state: Position = rules.initialState
            #expect(state == Self.position(play), "walk \(walk) start")
            let followKnown: Bool = walk % 3 == 0
            var step: Int = 0
            while state.outcome == .playing {
                let moves: [MoonlitMechanismAction] = rules.moves(in: state)
                #expect(!moves.isEmpty, "walk \(walk) step \(step) has moves")
                let fingerprint: String = play.fingerprint
                if walk < Self.exhaustiveWalks {
                    var accepted: [MoonlitMechanismAction] = []
                    for candidate in all {
                        let byPlay: Bool = Self.applied(play, candidate, fingerprint: fingerprint) != nil
                        let byRules: Bool = rules.apply(candidate, to: state) != nil
                        #expect(byPlay == byRules, "walk \(walk) step \(step) \(candidate)")
                        if byPlay { accepted.append(candidate) }
                    }
                    #expect(accepted == moves, "walk \(walk) step \(step) accepted")
                } else {
                    for move in moves {
                        #expect(Self.applied(play, move, fingerprint: fingerprint) != nil,
                                "walk \(walk) step \(step) play accepts \(move)")
                    }
                    for _ in 0..<Self.sampledCandidates {
                        let candidate: MoonlitMechanismAction = all[Int.random(in: 0..<all.count, using: &random)]
                        let byPlay: Bool = Self.applied(play, candidate, fingerprint: fingerprint) != nil
                        #expect(byPlay == moves.contains(candidate), "walk \(walk) step \(step) \(candidate)")
                    }
                }
                var move: MoonlitMechanismAction = moves[Int.random(in: 0..<moves.count, using: &random)]
                if followKnown, step < fixture.actions.count, moves.contains(fixture.actions[step]) {
                    move = fixture.actions[step]
                }
                let next: Position = try #require(rules.apply(move, to: state), "walk \(walk) step \(step) rules")
                try play.apply(move, expecting: fingerprint)
                state = next
                #expect(state.phases == play.phases, "walk \(walk) step \(step) phases")
                #expect(state.height == play.height, "walk \(walk) step \(step) height")
                #expect(state.actionsSpent == play.actionsSpent, "walk \(walk) step \(step) actions spent")
                #expect(state.outcome == Self.outcome(play), "walk \(walk) step \(step) outcome")
                step += 1
                #expect(step <= level.budget, "walk \(walk) within budget")
                if step > level.budget { break }
            }
            #expect(rules.moves(in: state).isEmpty, "walk \(walk) terminal has no moves")
            for candidate in all {
                #expect(rules.apply(candidate, to: state) == nil, "walk \(walk) terminal refuses \(candidate)")
            }
            if state.outcome == .won { wins += 1 } else { failures += 1 }
        }
        #expect(wins > 0)
        #expect(failures > 0)
    }

    @Test("the fixtures' known actions are legal at every step and solve")
    func knownActionsSolve() throws {
        let fixtures: [MoonlitMechanismFixture] = MoonlitMechanismFixture.all(count: Self.walkCount)
        for (index, fixture) in fixtures.enumerated() {
            let rules = Rules(level: fixture.level)
            var state: Position = rules.initialState
            for (step, action) in fixture.actions.enumerated() {
                #expect(rules.moves(in: state).contains(action), "fixture \(index) step \(step) legal")
                state = try #require(rules.apply(action, to: state), "fixture \(index) step \(step) applies")
            }
            #expect(rules.isSolved(state), "fixture \(index) solved")
            #expect(state.phases == fixture.solution, "fixture \(index) solution phases")
            #expect(state.height == fixture.solutionHeight, "fixture \(index) solution height")
        }
    }
}
