// ChronoConstellatorRulesTests — feature 351 (R02-G06-01) T-R02G0601-005 (FR-R02G0601-010). The R02-F23 puzzle contract
// of Chrono Constellator: the rules id and the initial position (the level's default timeline, tick 0, playing); the
// moves in their fixed order (phases, holds with start 1 … 32 and length 1 … 32, releases, step(tick limit)), computed
// independently from the level's budget, tick limit and holds, each listed move accepted; after tick 0 only rewind, a
// won position offers and accepts nothing, and unlisted moves are refused; the rules agree with ChronoConstellatorPlay
// (timeline, tick and outcome, and which sampled edits are refused) after every move of 200 seeded walks over fixtures
// and random levels; each fixture's known winning timeline, then step(tick limit), solves through the rules at exactly
// its win tick. Fixtures seed 2_351. Walks sample moves rather than expanding the hold grid every move, so each test
// stays short. Explicit types, plain loops.
import Foundation
import Testing
@testable import ChronoConstellatorCore
import VisualCoreSimulation

@Suite("Chrono Constellator rules (R02-F23 contract)")
struct ChronoConstellatorRulesTests {
    typealias Position = ChronoConstellatorRules.Position

    /// A playing play of `level` (begun, the tutorial dismissed when it has one).
    static func playing(_ level: ChronoConstellatorLevel) throws -> ChronoConstellatorPlay {
        var play: ChronoConstellatorPlay = ChronoConstellatorPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The rules' outcome for a play stage.
    static func outcome(of stage: ChronoConstellatorStage) -> Position.Outcome? {
        switch stage {
        case .playing: .playing
        case .won: .won
        case .failed: .failed
        default: nil
        }
    }

    /// The stars whose phase in `phases` differs from the level's default.
    static func changed(_ phases: [Int], level: ChronoConstellatorLevel) -> Int {
        var count: Int = 0
        for star in level.stars.indices where phases[star] != level.stars[star].phase { count += 1 }
        return count
    }

    /// The moves the rules must list at tick 0 while playing, computed independently from the budget, the tick limit and
    /// the holds (no overlap or touch within a star).
    static func expectedMoves(level: ChronoConstellatorLevel, timeline: ChronoConstellatorTimeline)
        -> [ChronoConstellatorAction] {
        var result: [ChronoConstellatorAction] = []
        let holds: [ChronoConstellatorHold] = timeline.holds
        for star in level.stars.indices {
            for offset in 0..<level.stars[star].length where offset != timeline.phases[star] {
                var phases: [Int] = timeline.phases
                phases[star] = offset
                if changed(phases, level: level) + holds.count <= level.budget { result.append(.phase(star, offset)) }
            }
        }
        let room: Bool = changed(timeline.phases, level: level) + holds.count + 1 <= level.budget
        for star in level.stars.indices {
            for start in 1...32 {
                for length in 1...32 {
                    let end: Int = start + length - 1
                    guard room, end <= level.tickLimit else { continue }
                    var free: Bool = true
                    for other in holds where other.star == star {
                        if start <= other.end + 1 && other.start <= end + 1 { free = false }
                    }
                    if free { result.append(.hold(star, start, length)) }
                }
            }
        }
        for hold in holds { result.append(.release(hold.star, hold.start)) }
        result.append(.step(level.tickLimit))
        return result
    }

    /// A sampled edit for `level`: a phase, a hold (start and length 1 … 32) or a release, any of which may be refused.
    static func candidate(level: ChronoConstellatorLevel, timeline: ChronoConstellatorTimeline,
                          random: inout ChronoConstellatorRandom) -> ChronoConstellatorAction {
        let star: Int = random.int(0..<level.stars.count)
        switch random.int(0...3) {
        case 0:
            return .phase(star, random.int(0..<level.stars[star].length))
        case 1, 2:
            return .hold(star, random.int(1...32), random.int(1...32))
        default:
            if !timeline.holds.isEmpty && random.bool() {
                let hold: ChronoConstellatorHold = timeline.holds[random.int(0..<timeline.holds.count)]
                return .release(hold.star, hold.start)
            }
            return .release(star, random.int(1...32))
        }
    }

    @Test("rules id is the documented slug and the initial state is the default timeline at tick 0, playing")
    func conformance() {
        for index in 0..<20 {
            let level: ChronoConstellatorLevel = index % 2 == 0
                ? ChronoConstellatorFixtures.fixture(index).level
                : ChronoConstellatorFixtures.randomLevel(index)
            let rules: ChronoConstellatorRules = ChronoConstellatorRules(level: level)
            #expect(rules.rulesID == "r02-g06-chrono-constellator")
            #expect(rules.level == level)
            let start: Position = rules.initialState
            #expect(start == Position(timeline: ChronoConstellatorTimeline(level: level), tick: 0, outcome: .playing))
            #expect(!rules.isSolved(start))
        }
    }

    @Test("moves at tick 0: phases, holds (start 1 … 32, length 1 … 32), releases, step(tick limit); each accepted")
    func movesOrder() throws {
        var random: ChronoConstellatorRandom = ChronoConstellatorRandom(seed: ChronoConstellatorFixtures.seed)
        var holdsListed: Int = 0
        var releasesListed: Int = 0
        for index in 0..<40 {
            let level: ChronoConstellatorLevel = index % 2 == 0
                ? ChronoConstellatorFixtures.fixture(index).level
                : ChronoConstellatorFixtures.randomLevel(index)
            let rules: ChronoConstellatorRules = ChronoConstellatorRules(level: level)
            let timelines: [ChronoConstellatorTimeline] = [
                ChronoConstellatorTimeline(level: level),
                ChronoConstellatorFixtures.randomTimeline(level, random: &random),
            ]
            for timeline in timelines {
                let state: Position = Position(timeline: timeline, tick: 0, outcome: .playing)
                let moves: [ChronoConstellatorAction] = rules.moves(in: state)
                #expect(moves == Self.expectedMoves(level: level, timeline: timeline))
                #expect(Set(moves).count == moves.count)
                #expect(moves.last == .step(level.tickLimit))
                for move in moves {
                    switch move {
                    case .hold: holdsListed += 1
                    case .release: releasesListed += 1
                    default: break
                    }
                    guard let next = rules.apply(move, to: state) else {
                        Issue.record("listed move \(move) refused on \(level.id)")
                        continue
                    }
                    if case .step = move {
                        #expect(next.tick >= 1 && next.outcome != .playing)
                    } else {
                        #expect(next.tick == 0 && next.outcome == .playing)
                    }
                }
            }
        }
        #expect(holdsListed > 1_000)
        #expect(releasesListed > 10)
    }

    @Test("after tick 0 only rewind; a won position offers and accepts nothing; unlisted moves are refused")
    func terminalAndUnlisted() throws {
        let fixture: ChronoConstellatorFixture = ChronoConstellatorFixtures.fixture(4)
        let level: ChronoConstellatorLevel = fixture.level
        let rules: ChronoConstellatorRules = ChronoConstellatorRules(level: level)
        let start: Position = rules.initialState
        let timeline: ChronoConstellatorTimeline = ChronoConstellatorFixtures.winningTimeline(fixture)
        let edits: [ChronoConstellatorAction] = [.phase(0, (timeline.phases[0] + 1) % level.stars[0].length),
                                                 .hold(1, 1, 1), .release(0, 1), .step(level.tickLimit)]
        // Won: nothing.
        let won: Position = try #require(rules.apply(.step(level.tickLimit),
                                                      to: Position(timeline: timeline, tick: 0, outcome: .playing)))
        #expect(won.outcome == .won && won.tick == fixture.winTick)
        #expect(rules.isSolved(won))
        #expect(rules.moves(in: won).isEmpty)
        for move in edits + [.rewind] { #expect(rules.apply(move, to: won) == nil) }
        // Failed, or playing after tick 0: only rewind, which keeps the timeline.
        let failed: Position = Position(timeline: timeline, tick: 3, outcome: .failed)
        let mid: Position = Position(timeline: timeline, tick: 1, outcome: .playing)
        for state in [failed, mid] {
            #expect(rules.moves(in: state) == [.rewind])
            #expect(!rules.isSolved(state))
            for move in edits { #expect(rules.apply(move, to: state) == nil) }
            let rewound: Position = try #require(rules.apply(.rewind, to: state))
            #expect(rewound == Position(timeline: timeline, tick: 0, outcome: .playing))
        }
        // Unlisted at tick 0: rewind, other step lengths, holds outside 1 … 32, out-of-range edits, a missing release.
        let unlisted: [ChronoConstellatorAction] = [
            .rewind, .step(level.tickLimit - 1), .step(level.tickLimit + 1), .step(0), .hold(0, 33, 1), .hold(0, 1, 33), .hold(0, 0, 1),
            .hold(-1, 1, 1), .hold(level.stars.count, 1, 1), .phase(0, start.timeline.phases[0]), .phase(0, -1),
            .phase(0, level.stars[0].length), .phase(level.stars.count, 0), .release(0, 1), .release(-1, 1),
        ]
        let listed: Set<ChronoConstellatorAction> = Set(rules.moves(in: start))
        for move in unlisted {
            #expect(!listed.contains(move))
            #expect(rules.apply(move, to: start) == nil)
        }
    }

    @Test("rules and play agree on timeline, tick, outcome and refusals after every move of 200 seeded walks")
    func agreesWithPlay() throws {
        var random: ChronoConstellatorRandom = ChronoConstellatorRandom(seed: ChronoConstellatorFixtures.seed)
        var wins: Int = 0
        var failures: Int = 0
        var moves: Int = 0
        var edits: Int = 0
        var refusals: Int = 0
        for index in 0..<200 {
            let fixture: ChronoConstellatorFixture = ChronoConstellatorFixtures.fixture(index)
            let level: ChronoConstellatorLevel = index % 2 == 0
                ? fixture.level
                : ChronoConstellatorFixtures.randomLevel(index)
            let rules: ChronoConstellatorRules = ChronoConstellatorRules(level: level)
            var play: ChronoConstellatorPlay = try Self.playing(level)
            var state: Position = rules.initialState
            #expect(state.timeline == play.timeline && state.tick == play.tick)
            for round in 0..<3 {
                if play.stage == .won { break }
                if state.tick != 0 {
                    // A failed play is retried honestly: rewind to tick 0 with the timeline kept.
                    let rewound: Position = try #require(rules.apply(.rewind, to: state))
                    try play.apply(.rewind, expecting: play.fingerprint)
                    state = rewound
                    moves += 1
                    #expect(state.timeline == play.timeline && state.tick == 0 && play.tick == 0)
                    #expect(Self.outcome(of: play.stage) == state.outcome)
                }
                var plan: [ChronoConstellatorAction] = []
                if index % 4 == 0 && round == 0 {
                    // Every fourth walk builds the fixture's known winning timeline.
                    for star in fixture.phases.indices where fixture.phases[star] != state.timeline.phases[star] {
                        plan.append(.phase(star, fixture.phases[star]))
                    }
                    for hold in fixture.holds { plan.append(.hold(hold.star, hold.start, hold.length)) }
                    plan.append(.step(level.tickLimit))
                } else {
                    plan = [.step(level.tickLimit)]
                }
                if !(index % 4 == 0 && round == 0) {
                    // Sampled edits: the rules accept exactly what the play accepts.
                    for _ in 0..<random.int(1...6) {
                        let move: ChronoConstellatorAction = Self.candidate(level: level, timeline: state.timeline,
                                                                             random: &random)
                        let next: Position? = rules.apply(move, to: state)
                        var trial: ChronoConstellatorPlay = play
                        let accepted: Bool = (try? trial.apply(move, expecting: trial.fingerprint)) != nil
                        #expect((next != nil) == accepted, "\(level.id) \(move)")
                        guard let next else {
                            refusals += 1
                            continue
                        }
                        play = trial
                        state = next
                        moves += 1
                        edits += 1
                        #expect(state.timeline == play.timeline && state.tick == play.tick)
                    }
                }
                for move in plan {
                    let next: Position = try #require(rules.apply(move, to: state), "\(level.id) \(move)")
                    try play.apply(move, expecting: play.fingerprint)
                    state = next
                    moves += 1
                    #expect(state.timeline == play.timeline)
                    #expect(state.tick == play.tick)
                    #expect(Self.outcome(of: play.stage) == state.outcome)
                    #expect(rules.isSolved(state) == (play.stage == .won))
                }
                if index % 4 == 0 && round == 0 {
                    #expect(play.stage == .won && play.tick == fixture.winTick)
                }
                // After a step the play is decided: only rewind, or nothing once won.
                #expect(rules.moves(in: state) == (play.stage == .won ? [] : [.rewind]))
                if play.stage == .won { wins += 1 }
                if play.stage == .failed { failures += 1 }
            }
        }
        #expect(wins >= 50)
        #expect(failures >= 100)
        #expect(moves > 1_000)
        #expect(edits > 200)
        #expect(refusals > 100)
    }

    @Test("each fixture's winning timeline, then step(tick limit), solves through the rules at its win tick (100)")
    func knownSolutions() throws {
        var solved: Int = 0
        for index in 0..<100 {
            let fixture: ChronoConstellatorFixture = ChronoConstellatorFixtures.fixture(index)
            let level: ChronoConstellatorLevel = fixture.level
            let rules: ChronoConstellatorRules = ChronoConstellatorRules(level: level)
            var state: Position = rules.initialState
            var solution: [ChronoConstellatorAction] = []
            for star in fixture.phases.indices where fixture.phases[star] != level.stars[star].phase {
                solution.append(.phase(star, fixture.phases[star]))
            }
            for hold in fixture.holds { solution.append(.hold(hold.star, hold.start, hold.length)) }
            solution.append(.step(level.tickLimit))
            var legal: Bool = true
            for move in solution {
                guard let next = rules.apply(move, to: state) else {
                    legal = false
                    break
                }
                state = next
            }
            #expect(legal)
            #expect(state.timeline == ChronoConstellatorFixtures.winningTimeline(fixture))
            #expect(state.tick == fixture.winTick)
            if legal && rules.isSolved(state) { solved += 1 }
        }
        #expect(solved == 100)
    }

    @Test("positions round-trip through JSON")
    func coding() throws {
        let level: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(3)
        let rules: ChronoConstellatorRules = ChronoConstellatorRules(level: level)
        var random: ChronoConstellatorRandom = ChronoConstellatorRandom(seed: ChronoConstellatorFixtures.seed)
        let timeline: ChronoConstellatorTimeline = ChronoConstellatorFixtures.randomTimeline(level, random: &random)
        let state: Position = try #require(rules.apply(.step(level.tickLimit),
                                                        to: Position(timeline: timeline, tick: 0, outcome: .playing)))
        let data: Data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(Position.self, from: data) == state)
    }
}
