// StarlitCartoucheRulesTests — feature 451 (R02-G16-01) T-R02G1601-005 (FR-R02G1601-010). The rules as an R02-F23
// puzzle contract: the rules id and start position; the exact move order on a hand level (every corridor joining the
// ship's star in corridor index order, then waits 0 … 8, flyable legs only) and its refusals; the agreement with
// `StarlitCartouchePlay` step by step on 200 seeded random walks (seed 2_451, fixture levels): on the first 20 walks
// every candidate (legs to stars −1 … n after waits −1 … 9) is tried with `apply(_:expecting:)` on a copy of the play
// with its current fingerprint and the accepted candidates are exactly the legal moves in order; on the others every
// legal move and 8 sampled candidates are tried; applying the chosen move gives the same star, beat, drawn strokes,
// actions spent and outcome as the play; one walk in three follows the fixture's known legs, so wins, chart failures
// and budget failures occur; the legal moves are exactly the legs the chart accepts; terminal positions have no moves
// and refuse every move; and the fixtures' known legs are legal at every step and reach won (a route that passes its
// beacon with every stroke drawn wins before its last leg, exactly as the play does). Explicit types, plain loops;
// each test well under 10 s. Modelled on `VoxelOrigamiRulesTests` (feature 441).
import Testing
import VisualCoreSimulation
@testable import StarlitCartoucheCore

@Suite("StarlitCartoucheRules")
struct StarlitCartoucheRulesTests {
    typealias Rules = StarlitCartoucheRules
    typealias Position = StarlitCartoucheRules.Position

    /// The walk seed.
    static let walkSeed: UInt64 = 2_451
    /// The number of seeded walks.
    static let walkCount: Int = 200
    /// The walks whose every step tries every candidate with the play's `apply`.
    static let exhaustiveWalks: Int = 20
    /// The candidates per step of a later walk also tried with the play's `apply`.
    static let sampledCandidates: Int = 8

    /// The hand level: stars 0, 1, 2 still at x = 0, 2, 4; star 3 alternates between x = 6 (even beats, in range of
    /// star 2) and a far corner (odd beats); range 2; corridors 0–1, 1–2, 0–2 (never in range) and 2–3, travel 1;
    /// the symbol is corridors 0 and 1, start 0, beacon 2, open windows, deadline 64.
    static func handLevel(budget: Int = 3) throws -> StarlitCartoucheLevel {
        var stars: [StarlitCartoucheStar] = []
        for i in 0..<3 {
            stars.append(StarlitCartoucheStar(orbit: [StarlitCartoucheVector(i * 2, 0, 0)],
                                              glyph: StarlitCartoucheGlyphPoint(i, 0), open: 0, close: 64))
        }
        stars.append(StarlitCartoucheStar(orbit: [StarlitCartoucheVector(6, 0, 0), StarlitCartoucheVector(8, 8, 8)],
                                          glyph: StarlitCartoucheGlyphPoint(3, 0), open: 0, close: 64))
        let corridors: [StarlitCartoucheCorridor] = [StarlitCartoucheCorridor(0, 1, travel: 1),
                                                     StarlitCartoucheCorridor(1, 2, travel: 1),
                                                     StarlitCartoucheCorridor(0, 2, travel: 1),
                                                     StarlitCartoucheCorridor(2, 3, travel: 1)]
        return try StarlitCartoucheLevel(id: "hand", seed: 1, difficulty: 1, stars: stars, range: 2,
                                         corridors: corridors, hazards: [], start: 0, beacon: 2, deadline: 64,
                                         symbol: [0, 1], budget: budget)
    }

    /// A play of `level` started and past its tutorial.
    static func started(_ level: StarlitCartoucheLevel) -> StarlitCartouchePlay {
        var play = StarlitCartouchePlay(level: level)
        try? play.handle(.begin)
        if level.tutorial { try? play.handle(.dismissTutorial) }
        return play
    }

    /// The play after `action` (tried on a copy), or nil when the play refuses it.
    static func applied(_ play: StarlitCartouchePlay, _ action: StarlitCartoucheAction,
                        fingerprint: String) -> StarlitCartouchePlay? {
        var copy: StarlitCartouchePlay = play
        do {
            try copy.apply(action, expecting: fingerprint)
            return copy
        } catch {
            return nil
        }
    }

    /// The rules' outcome of `play`'s stage.
    static func outcome(_ play: StarlitCartouchePlay) -> Position.Outcome {
        switch play.stage {
        case .won: return .won
        case .failed: return .failed
        default: return .playing
        }
    }

    /// The rules' position of `play`.
    static func position(_ play: StarlitCartouchePlay) -> Position {
        Position(star: play.star, beat: play.beat, drawn: play.drawn, actionsSpent: play.actionsSpent,
                 outcome: outcome(play))
    }

    /// Every candidate action of a level with `count` stars: legs to stars −1 … `count` after waits −1 … 9.
    static func candidates(_ count: Int) -> [StarlitCartoucheAction] {
        var result: [StarlitCartoucheAction] = []
        for star in -1...count {
            for wait in -1...9 { result.append(.leg(star, wait)) }
        }
        return result
    }

    /// The legs the chart accepts from `state`, in corridor index order then wait order.
    static func flyable(_ level: StarlitCartoucheLevel, _ state: Position) -> [StarlitCartoucheAction] {
        var result: [StarlitCartoucheAction] = []
        for index in level.corridors.indices {
            let corridor: StarlitCartoucheCorridor = level.corridors[index]
            guard corridor.a == state.star || corridor.b == state.star else { continue }
            let destination: Int = corridor.a == state.star ? corridor.b : corridor.a
            for wait in 0...8 {
                do {
                    let leg: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: state.star,
                                                                                 at: state.beat, to: destination,
                                                                                 wait: wait)
                    #expect(leg.corridor == index)
                    result.append(.leg(destination, wait))
                } catch {
                    continue
                }
            }
        }
        return result
    }

    /// Whether the play, applying the fixture's known legs, wins before the last one (a route that revisits its
    /// beacon with every stroke drawn); the play stops there, as the rules do.
    func wonEarly(_ fixture: StarlitCartoucheFixture) -> Bool {
        var play: StarlitCartouchePlay = Self.started(fixture.level)
        for action in fixture.actions.dropLast() {
            try? play.apply(action, expecting: play.fingerprint)
            if play.stage == .won { return true }
        }
        return false
    }

    @Test("rules id and initial position")
    func initialPosition() throws {
        let level: StarlitCartoucheLevel = try Self.handLevel()
        let rules = Rules(level: level)
        #expect(rules.rulesID == "r02-g16-starlit-cartouche")
        let start: Position = rules.initialState
        #expect(start.star == 0)
        #expect(start.beat == 0)
        #expect(start.drawn.isEmpty)
        #expect(start.actionsSpent == 0)
        #expect(start.outcome == .playing)
        #expect(!rules.isSolved(start))
        #expect(start == Self.position(Self.started(level)))
        let fixtures: [StarlitCartoucheFixture] = StarlitCartoucheFixture.all(count: 10)
        for (index, fixture) in fixtures.enumerated() {
            let fixtureRules = Rules(level: fixture.level)
            #expect(fixtureRules.initialState.star == fixture.level.start, "fixture \(index) star")
            #expect(fixtureRules.initialState == Self.position(Self.started(fixture.level)), "fixture \(index) start")
        }
    }

    @Test("legal moves: corridors from the star in index order, waits 0 … 8, flyable only; refusals")
    func handOrder() throws {
        let rules = Rules(level: try Self.handLevel())
        let start: Position = rules.initialState
        var fromStart: [StarlitCartoucheAction] = []
        for wait in 0...8 { fromStart.append(.leg(1, wait)) }
        #expect(rules.moves(in: start) == fromStart)
        let atTwo = Position(star: 2, beat: 2, drawn: [0, 1], actionsSpent: 1, outcome: .playing)
        var fromTwo: [StarlitCartoucheAction] = []
        for wait in 0...8 { fromTwo.append(.leg(1, wait)) }
        for wait in [0, 2, 4, 6, 8] { fromTwo.append(.leg(3, wait)) }
        #expect(rules.moves(in: atTwo) == fromTwo)
        let atOne = Position(star: 1, beat: 1, drawn: [0], actionsSpent: 1, outcome: .playing)
        var fromOne: [StarlitCartoucheAction] = []
        for wait in 0...8 { fromOne.append(.leg(0, wait)) }
        for wait in 0...8 { fromOne.append(.leg(2, wait)) }
        #expect(rules.moves(in: atOne) == fromOne)
        #expect(rules.apply(.leg(0, 0), to: start) == nil)
        #expect(rules.apply(.leg(-1, 0), to: start) == nil)
        #expect(rules.apply(.leg(4, 0), to: start) == nil)
        #expect(rules.apply(.leg(3, 0), to: start) == nil)
        #expect(rules.apply(.leg(2, 0), to: start) == nil)
        #expect(rules.apply(.leg(1, -1), to: start) == nil)
        #expect(rules.apply(.leg(1, 9), to: start) == nil)
        #expect(rules.apply(.leg(3, 1), to: atTwo) == nil)
        let flown: Position = try #require(rules.apply(.leg(1, 2), to: start))
        #expect(flown == Position(star: 1, beat: 3, drawn: [0], actionsSpent: 1, outcome: .playing))
        let won: Position = try #require(rules.apply(.leg(2, 0), to: flown))
        #expect(won == Position(star: 2, beat: 4, drawn: [0, 1], actionsSpent: 2, outcome: .won))
        #expect(rules.isSolved(won))
        let stroke: Position = try #require(rules.apply(.leg(3, 0), to: atTwo))
        #expect(stroke == Position(star: 2, beat: 2, drawn: [0, 1], actionsSpent: 2, outcome: .failed))
    }

    @Test("terminal positions: won, failed by the chart and failed by the budget offer and accept nothing")
    func terminalPositions() throws {
        let rules = Rules(level: try Self.handLevel(budget: 2))
        let start: Position = rules.initialState
        let one: Position = try #require(rules.apply(.leg(1, 0), to: start))
        #expect(one.outcome == .playing)
        let spent: Position = try #require(rules.apply(.leg(0, 0), to: one))
        #expect(spent.outcome == .failed)
        #expect(spent.actionsSpent == 2)
        var terminals: [Position] = [spent]
        let fixtures: [StarlitCartoucheFixture] = StarlitCartoucheFixture.all(count: 10)
        for fixture in fixtures {
            let fixtureRules = Rules(level: fixture.level)
            var state: Position = fixtureRules.initialState
            for action in fixture.actions where state.outcome == .playing {
                state = try #require(fixtureRules.apply(action, to: state))
            }
            #expect(state.outcome == .won)
            #expect(fixtureRules.moves(in: state).isEmpty)
            for candidate in Self.candidates(fixture.level.stars.count) {
                #expect(fixtureRules.apply(candidate, to: state) == nil, "won refuses \(candidate)")
            }
        }
        terminals.append(Position(star: 0, beat: 0, drawn: [], actionsSpent: 0, outcome: .won))
        terminals.append(Position(star: 0, beat: 0, drawn: [], actionsSpent: 1, outcome: .failed))
        terminals.append(Position(star: 1, beat: 1, drawn: [0], actionsSpent: 2, outcome: .playing))
        for terminal in terminals {
            #expect(rules.moves(in: terminal).isEmpty)
            for candidate in Self.candidates(4) {
                #expect(rules.apply(candidate, to: terminal) == nil, "terminal refuses \(candidate)")
            }
        }
    }

    @Test("rules and play agree step by step on 200 seeded walks")
    func agreementWithPlay() throws {
        let fixtures: [StarlitCartoucheFixture] = StarlitCartoucheFixture.all(count: Self.walkCount)
        #expect(fixtures.count == Self.walkCount)
        var random = SeededRandom(seed: Self.walkSeed)
        var wins: Int = 0
        var chartFailures: Int = 0
        var budgetFailures: Int = 0
        for (walk, fixture) in fixtures.enumerated() {
            let level: StarlitCartoucheLevel = fixture.level
            let rules = Rules(level: level)
            let all: [StarlitCartoucheAction] = Self.candidates(level.stars.count)
            var play: StarlitCartouchePlay = Self.started(level)
            var state: Position = rules.initialState
            #expect(state == Self.position(play), "walk \(walk) start")
            let followKnown: Bool = walk % 3 == 0
            var step: Int = 0
            while state.outcome == .playing {
                let moves: [StarlitCartoucheAction] = rules.moves(in: state)
                #expect(moves == Self.flyable(level, state), "walk \(walk) step \(step) flyable legs")
                if moves.isEmpty { break }
                let fingerprint: String = play.fingerprint
                if walk < Self.exhaustiveWalks {
                    var accepted: [StarlitCartoucheAction] = []
                    for candidate in all {
                        let byPlay: Bool = Self.applied(play, candidate, fingerprint: fingerprint) != nil
                        let byRules: Bool = rules.apply(candidate, to: state) != nil
                        #expect(byPlay == byRules, "walk \(walk) step \(step) \(candidate)")
                        if byPlay { accepted.append(candidate) }
                    }
                    var ordered: [StarlitCartoucheAction] = []
                    for move in moves where accepted.contains(move) { ordered.append(move) }
                    #expect(ordered == moves && accepted.count == moves.count, "walk \(walk) step \(step) accepted")
                } else {
                    for move in moves {
                        #expect(Self.applied(play, move, fingerprint: fingerprint) != nil,
                                "walk \(walk) step \(step) play accepts \(move)")
                    }
                    for _ in 0..<Self.sampledCandidates {
                        let candidate: StarlitCartoucheAction = all[random.int(0...(all.count - 1))]
                        let byPlay: Bool = Self.applied(play, candidate, fingerprint: fingerprint) != nil
                        #expect(byPlay == moves.contains(candidate), "walk \(walk) step \(step) \(candidate)")
                    }
                }
                var move: StarlitCartoucheAction = moves[random.int(0...(moves.count - 1))]
                if followKnown, step < fixture.actions.count, moves.contains(fixture.actions[step]) {
                    move = fixture.actions[step]
                }
                let next: Position = try #require(rules.apply(move, to: state), "walk \(walk) step \(step) rules")
                try play.apply(move, expecting: fingerprint)
                state = next
                #expect(state == Self.position(play), "walk \(walk) step \(step) position")
                step += 1
                #expect(step <= level.budget, "walk \(walk) within budget")
                if step > level.budget { break }
            }
            #expect(rules.moves(in: state).isEmpty, "walk \(walk) terminal has no moves")
            for candidate in all {
                #expect(rules.apply(candidate, to: state) == nil, "walk \(walk) terminal refuses \(candidate)")
            }
            switch play.failure {
            case .budget: budgetFailures += 1
            case .some: chartFailures += 1
            case nil: if state.outcome == .won { wins += 1 }
            }
        }
        #expect(wins > 0)
        #expect(chartFailures > 0)
        #expect(budgetFailures > 0)
    }

    @Test("the fixtures' known legs are legal at every step and reach won")
    func knownLegsSolve() throws {
        let fixtures: [StarlitCartoucheFixture] = StarlitCartoucheFixture.all(count: Self.walkCount)
        for (index, fixture) in fixtures.enumerated() {
            let rules = Rules(level: fixture.level)
            var state: Position = rules.initialState
            for (step, action) in fixture.actions.enumerated() where state.outcome == .playing {
                #expect(rules.moves(in: state).contains(action), "fixture \(index) step \(step) legal")
                state = try #require(rules.apply(action, to: state), "fixture \(index) step \(step) applies")
            }
            #expect(rules.isSolved(state), "fixture \(index) solved")
            #expect(state.actionsSpent >= 1 && state.actionsSpent <= fixture.actions.count,
                    "fixture \(index) actions spent")
            #expect(state.actionsSpent == fixture.actions.count || wonEarly(fixture),
                    "fixture \(index) won no earlier than the play")
            #expect(state.star == fixture.level.beacon, "fixture \(index) at the beacon")
            #expect(state.drawn == Set(fixture.level.symbol), "fixture \(index) symbol drawn")
        }
    }
}
