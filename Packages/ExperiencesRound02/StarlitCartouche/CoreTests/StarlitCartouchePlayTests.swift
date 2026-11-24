// StarlitCartouchePlayTests — feature 451 (R02-G16-01) T-R02G1601-004 (FR-R02G1601-002 … 008, 014;
// SC-R02G1601-002 … 004; clarifications Q2 … Q5). The play of a Starlit Cartouche level: the full stage table of
// `handle(_:)`; the fixtures' known legs keep the play going (star, beat and strokes after each action equal the
// fixtures' own `step`, the report always the chart's report) and win exactly on the first leg that completes the
// cartouche at the beacon; each failure named on hand levels (`departure`, `hazard` with the lowest hazard, `arrival`
// early and late, `deadline` past an open window, `stroke`) on the exact leg with the ship, beat, strokes and legs
// unchanged; budget failure on the exact action with budgets one action either side, and a leg on
// the last action wins; the validation order stage, stale, action (unknown star, same star, no corridor, wait, out of
// range) with every refusal reachable, spending nothing and leaving the play unchanged; the fingerprint is the SHA-256
// of its canonical text; undo of every action restores the exact fingerprint, undo from failed returns to playing with
// the failing action refunded, a won play is final and a new leg clears redo; 500 seeded traces replay to the same
// records, fingerprints and outcome, and tampered traces are refused. Explicit types, plain loops, short traces; each
// test well under 10 s; no clock.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import StarlitCartoucheCore

struct StarlitCartouchePlayTests {
    typealias Play = StarlitCartouchePlay
    typealias Action = StarlitCartoucheAction
    typealias Level = StarlitCartoucheLevel

    /// The test seed of the feature.
    static let seed: UInt64 = 2_451

    /// One operation on a play, so that refusals can be listed and checked in loops.
    enum Op {
        case act(Action)
        case stale(Action)
        case undo
        case redo
        case event(StarlitCartoucheEvent)
    }

    static let events: [StarlitCartoucheEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    static func perform(_ op: Op, _ play: inout Play) throws(StarlitCartoucheError) {
        switch op {
        case .act(let action): try play.apply(action, expecting: play.fingerprint)
        case .stale(let action): try play.apply(action, expecting: "0000")
        case .undo: try play.undo()
        case .redo: try play.redo()
        case .event(let event): try play.handle(event)
        }
    }

    static func act(_ play: inout Play, _ action: Action) throws(StarlitCartoucheError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// The refusal of `op` on a copy of `play` (nil when accepted); a refused op must leave the copy unchanged.
    static func refusal(_ play: Play, _ op: Op,
                        sourceLocation: SourceLocation = #_sourceLocation) -> StarlitCartoucheError? {
        var copy: Play = play
        do {
            try perform(op, &copy)
            return nil
        } catch {
            #expect(copy == play, "refused op changed the play", sourceLocation: sourceLocation)
            #expect(copy.fingerprint == play.fingerprint, sourceLocation: sourceLocation)
            #expect(copy.actionsSpent == play.actionsSpent, sourceLocation: sourceLocation)
            #expect(copy.records == play.records, sourceLocation: sourceLocation)
            return error
        }
    }

    /// A play of `level` that has begun (and dismissed its tutorial).
    static func playing(_ level: Level) throws(StarlitCartoucheError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A row of four stars: 0 at x 0, 1 at x 2, 2 at x 4 (still) and 3 swinging between x 6 (even beats) and x 2 (odd
    /// beats); range 2 (r² = 4). Corridors 0 = 0–1 (travel 1), 1 = 1–2 (travel 2), 2 = 2–3 (travel 1) and 3 = 0–3
    /// (travel 1, flyable only on odd beats, squared distance 36 on even ones). Windows default to [0, deadline].
    static func row(start: Int = 0, beacon: Int = 2, symbol: [Int] = [0, 1], opens: [Int] = [0, 0, 0, 0],
                    closes: [Int]? = nil, hazards: [StarlitCartoucheHazard] = [], budget: Int = 4,
                    deadline: Int = 20, tutorial: Bool = false) throws(StarlitCartoucheError) -> Level {
        let orbits: [[StarlitCartoucheVector]] = [[StarlitCartoucheVector(0, 0, 0)], [StarlitCartoucheVector(2, 0, 0)],
                                                  [StarlitCartoucheVector(4, 0, 0)],
                                                  [StarlitCartoucheVector(6, 0, 0), StarlitCartoucheVector(2, 0, 0)]]
        var stars: [StarlitCartoucheStar] = []
        for i in 0..<4 {
            let close: Int = closes?[i] ?? deadline
            stars.append(StarlitCartoucheStar(orbit: orbits[i], glyph: StarlitCartoucheGlyphPoint(i, 0), open: opens[i],
                                              close: close))
        }
        let corridors: [StarlitCartoucheCorridor] = [StarlitCartoucheCorridor(0, 1, travel: 1),
                                                     StarlitCartoucheCorridor(1, 2, travel: 2),
                                                     StarlitCartoucheCorridor(2, 3, travel: 1),
                                                     StarlitCartoucheCorridor(0, 3, travel: 1)]
        return try Level(id: "play-row", seed: 21, difficulty: 1, stars: stars, range: 2, corridors: corridors,
                         hazards: hazards, start: start, beacon: beacon, deadline: deadline, symbol: symbol,
                         budget: budget, tutorial: tutorial)
    }

    /// `level` with another budget.
    static func rebudgeted(_ level: Level, budget: Int) throws(StarlitCartoucheError) -> Level {
        try Level(id: level.id, seed: level.seed, difficulty: level.difficulty, stars: level.stars, range: level.range,
                  corridors: level.corridors, hazards: level.hazards, start: level.start, beacon: level.beacon,
                  deadline: level.deadline, symbol: level.symbol, budget: budget, tutorial: level.tutorial)
    }

    /// The 0-based index of the first known leg after which, by the fixtures' own `step`, the drawn set equals the
    /// symbol and the ship is at the beacon; nil when a leg is refused or none completes.
    static func firstWin(_ fixture: StarlitCartoucheFixture) -> Int? {
        let level: Level = fixture.level
        var star: Int = level.start
        var beat: Int = 0
        var drawn: Set<Int> = []
        for (index, action) in fixture.actions.enumerated() {
            guard case .leg(let destination, let wait) = action,
                  let next = StarlitCartoucheFixture.step(level, star: star, beat: beat, destination: destination,
                                                          wait: wait)
            else { return nil }
            star = next.star
            beat = next.beat
            drawn.insert(next.corridor)
            if drawn == Set(level.symbol) && star == level.beacon { return index }
        }
        return nil
    }

    // MARK: Stages

    @Test func theStageTableAcceptsOnlyItsEvents() throws {
        let level: Level = try Self.row(budget: 1, tutorial: true)
        var plays: [StarlitCartoucheStage: Play] = [:]
        var play = Play(level: level)
        #expect(play.stage == .loading)
        #expect(play.star == level.start && play.beat == 0 && play.drawn.isEmpty && play.legs.isEmpty)
        #expect(play.actionsSpent == 0 && play.actionsLeft == 1 && play.failure == nil && play.records.isEmpty)
        #expect(play.report == level.startReport)
        plays[.loading] = play
        try play.handle(.begin)
        #expect(play.stage == .tutorial)
        plays[.tutorial] = play
        try play.handle(.dismissTutorial)
        #expect(play.stage == .playing)
        plays[.playing] = play
        var paused: Play = play
        try paused.handle(.pause)
        #expect(paused.stage == .paused)
        plays[.paused] = paused
        var failed: Play = play
        try Self.act(&failed, .leg(1, 0))
        #expect(failed.stage == .failed)
        #expect(failed.failure == .budget(1))
        plays[.failed] = failed
        var result: Play = failed
        try result.handle(.showResult)
        #expect(result.stage == .result)
        plays[.result] = result
        var won: Play = try Self.playing(try Self.row())
        try Self.act(&won, .leg(1, 0))
        try Self.act(&won, .leg(2, 0))
        #expect(won.stage == .won)
        plays[.won] = won
        var wonResult: Play = won
        try wonResult.handle(.showResult)
        #expect(wonResult.stage == .result)

        let accepted: [StarlitCartoucheStage: StarlitCartoucheEvent] = [.loading: .begin, .tutorial: .dismissTutorial,
                                                                         .playing: .pause, .paused: .resume,
                                                                         .won: .showResult, .failed: .showResult]
        for stage in StarlitCartoucheStage.allCases {
            guard let base = plays[stage] else {
                Issue.record("stage \(stage) not reached")
                continue
            }
            for event in Self.events where accepted[stage] != event {
                #expect(Self.refusal(base, .event(event)) == .stage, "\(stage) \(event)")
            }
        }
        var plain = Play(level: try Self.row())
        try plain.handle(.begin)
        #expect(plain.stage == .playing)
    }

    @Test func legsAreRefusedOutsidePlaying() throws {
        let level: Level = try Self.row(budget: 1, tutorial: true)
        var play = Play(level: level)
        #expect(Self.refusal(play, .act(.leg(1, 0))) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)
        try play.handle(.begin)
        #expect(Self.refusal(play, .act(.leg(1, 0))) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        try play.handle(.dismissTutorial)
        var paused: Play = play
        try paused.handle(.pause)
        #expect(Self.refusal(paused, .act(.leg(1, 0))) == .stage)
        // Stage is checked before the fingerprint and the action.
        #expect(Self.refusal(paused, .stale(.leg(9, 99))) == .stage)
        try Self.act(&play, .leg(1, 0))
        #expect(play.stage == .failed)
        #expect(Self.refusal(play, .act(.leg(0, 0))) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)
        try play.handle(.showResult)
        #expect(Self.refusal(play, .act(.leg(0, 0))) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)
        #expect(!play.canUndo && !play.canRedo)
    }

    // MARK: Validation

    @Test func everyRefusalReasonIsReachableInOrder() throws {
        let play: Play = try Self.playing(try Self.row())
        #expect(Self.refusal(play, .act(.leg(4, 0))) == .action("unknown star"))
        #expect(Self.refusal(play, .act(.leg(-1, 0))) == .action("unknown star"))
        #expect(Self.refusal(play, .act(.leg(0, 0))) == .action("same star"))
        #expect(Self.refusal(play, .act(.leg(2, 0))) == .action("no corridor"))
        #expect(Self.refusal(play, .act(.leg(1, 9))) == .action("wait"))
        #expect(Self.refusal(play, .act(.leg(1, -1))) == .action("wait"))
        #expect(Self.refusal(play, .act(.leg(3, 0))) == .action("out of range: 36 > 4"))
        #expect(Self.refusal(play, .act(.leg(3, 2))) == .action("out of range: 36 > 4"))
        // Range is judged at the departure beat: star 3 swings within range on odd beats.
        #expect(Self.refusal(play, .act(.leg(3, 1))) == nil)
        // Unknown before same before corridor before wait before range.
        #expect(Self.refusal(play, .act(.leg(9, 99))) == .action("unknown star"))
        #expect(Self.refusal(play, .act(.leg(0, 99))) == .action("same star"))
        #expect(Self.refusal(play, .act(.leg(2, 99))) == .action("no corridor"))
        #expect(Self.refusal(play, .act(.leg(3, 99))) == .action("wait"))
        // Stale before the action.
        #expect(Self.refusal(play, .stale(.leg(9, 99))) == .stale)
        #expect(Self.refusal(play, .stale(.leg(1, 0))) == .stale)
        #expect(Self.refusal(play, .undo) == .action("undo"))
        #expect(Self.refusal(play, .redo) == .action("redo"))
        #expect(StarlitCartoucheError.action("wait").reasonCode == "r02-g16.action")
        #expect(StarlitCartoucheError.stale.reasonCode == "r02-g16.stale")
        #expect(StarlitCartoucheError.stage.reasonCode == "r02-g16.stage")
    }

    // MARK: Winning

    @Test func theFixturesKnownLegsWinOnTheExactLeg() throws {
        let fixtures: [StarlitCartoucheFixture] = StarlitCartoucheFixture.all(count: 60, seed: Self.seed)
        for fixture in fixtures {
            let level: Level = fixture.level
            let win: Int = try #require(Self.firstWin(fixture), "\(level.id)")
            var play: Play = try Self.playing(level)
            var star: Int = level.start
            var beat: Int = 0
            var drawn: Set<Int> = []
            for position in 0...win {
                #expect(play.stage == .playing, "\(level.id) before \(position)")
                let action: Action = fixture.actions[position]
                try Self.act(&play, action)
                guard case .leg(let destination, let wait) = action,
                      let next = StarlitCartoucheFixture.step(level, star: star, beat: beat, destination: destination,
                                                              wait: wait)
                else {
                    Issue.record("fixture leg refused")
                    break
                }
                star = next.star
                beat = next.beat
                drawn.insert(next.corridor)
                #expect(play.star == star && play.beat == beat && play.drawn == drawn)
                #expect(play.legs.count == position + 1)
                #expect(play.report == StarlitCartoucheChart.report(level, star: star, beat: beat, drawn: drawn,
                                                                    legs: play.legs))
                #expect(play.actionsSpent == position + 1)
                #expect(play.report.matched == (position == win))
                #expect(play.stage == (position == win ? .won : .playing), "\(level.id) at \(position)")
            }
            #expect(play.failure == nil)
            #expect(play.records.count == win + 1)
            #expect(!play.canUndo && !play.canRedo)
            #expect(Self.refusal(play, .undo) == .stage)
            if win + 1 < fixture.actions.count {
                #expect(Self.refusal(play, .act(fixture.actions[win + 1])) == .stage)
            }
        }
    }

    @Test func aLegOnTheLastActionWins() throws {
        var hand: Play = try Self.playing(try Self.row(budget: 2))
        try Self.act(&hand, .leg(1, 0))
        try Self.act(&hand, .leg(2, 0))
        #expect(hand.stage == .won && hand.actionsLeft == 0 && hand.failure == nil)
        #expect(hand.star == 2 && hand.beat == 3 && hand.drawn == [0, 1])
        let fixtures: [StarlitCartoucheFixture] = StarlitCartoucheFixture.all(count: 30, seed: Self.seed)
        for fixture in fixtures {
            let win: Int = try #require(Self.firstWin(fixture))
            let level: Level = try Self.rebudgeted(fixture.level, budget: win + 1)
            var play: Play = try Self.playing(level)
            for position in 0...win { try Self.act(&play, fixture.actions[position]) }
            #expect(play.stage == .won)
            #expect(play.actionsLeft == 0)
            #expect(play.failure == nil)
        }
    }

    // MARK: Failures

    /// Checks that `play` failed with `failure` on its latest leg, with the route as in `before`.
    static func expectFailed(_ play: Play, _ failure: StarlitCartoucheFailure, code: String, before: Play,
                             sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(play.stage == .failed, sourceLocation: sourceLocation)
        #expect(play.failure == failure, sourceLocation: sourceLocation)
        #expect(play.failure?.code == code, sourceLocation: sourceLocation)
        #expect(play.star == before.star && play.beat == before.beat, sourceLocation: sourceLocation)
        #expect(play.drawn == before.drawn && play.legs == before.legs, sourceLocation: sourceLocation)
        #expect(play.report == before.report, sourceLocation: sourceLocation)
        #expect(play.actionsSpent == before.actionsSpent + 1, sourceLocation: sourceLocation)
        #expect(play.records.count == before.records.count + 1, sourceLocation: sourceLocation)
        let record: StarlitCartoucheRecord? = play.records.last
        #expect(record?.kind == .leg && record?.index == before.actionsSpent, sourceLocation: sourceLocation)
        #expect(record?.previous == before.fingerprint && record?.next == play.fingerprint,
                sourceLocation: sourceLocation)
    }

    @Test func aDepartureAfterTheWindowFailsOnTheExactLeg() throws {
        let level: Level = try Self.row(deadline: 5)
        var play: Play = try Self.playing(level)
        var clear: Play = play
        try Self.act(&clear, .leg(1, 4))
        #expect(clear.stage == .playing && clear.beat == 5)
        let before: Play = play
        try Self.act(&play, .leg(1, 6))
        Self.expectFailed(play, .departure(star: 0, beat: 6, close: 5), code: "window", before: before)
        // Undo returns to playing before the failing leg, the action refunded; redo brings the failure back.
        try play.undo()
        #expect(play.stage == .playing && play.failure == nil && play.actionsSpent == 0)
        #expect(play.fingerprint == before.fingerprint)
        #expect(play.records.count == 2 && play.records[1].kind == .undo && play.records[1].index == 1)
        try play.redo()
        #expect(play.stage == .failed && play.failure == .departure(star: 0, beat: 6, close: 5))
    }

    @Test func aHazardFailsOnTheExactLegNamingTheLowestHazard() throws {
        let hazards: [StarlitCartoucheHazard] = [StarlitCartoucheHazard(corridor: 0, from: 5, to: 6),
                                                 StarlitCartoucheHazard(corridor: 0, from: 0, to: 1),
                                                 StarlitCartoucheHazard(corridor: 0, from: 1, to: 1)]
        let level: Level = try Self.row(hazards: hazards)
        var play: Play = try Self.playing(level)
        // [2, 3] meets none; [4, 5] meets hazard 0 at its first beat.
        var clear: Play = play
        try Self.act(&clear, .leg(1, 2))
        #expect(clear.stage == .playing && clear.report.clearance == 1)
        var late: Play = play
        try Self.act(&late, .leg(1, 4))
        Self.expectFailed(late, .hazard(corridor: 0, hazard: 0, from: 5, to: 6), code: "hazard", before: play)
        let before: Play = play
        try Self.act(&play, .leg(1, 0))
        Self.expectFailed(play, .hazard(corridor: 0, hazard: 1, from: 0, to: 1), code: "hazard", before: before)
        var shown: Play = play
        try shown.handle(.showResult)
        #expect(shown.stage == .result)
        try play.undo()
        #expect(play.fingerprint == before.fingerprint)
        #expect(play.stage == .playing && play.actionsLeft == level.budget)
    }

    @Test func anArrivalOutsideTheWindowFailsEarlyAndLate() throws {
        let early: Level = try Self.row(opens: [0, 3, 0, 0])
        var play: Play = try Self.playing(early)
        var clear: Play = play
        try Self.act(&clear, .leg(1, 2))
        #expect(clear.stage == .playing && clear.beat == 3)
        var before: Play = play
        try Self.act(&play, .leg(1, 1))
        Self.expectFailed(play, .arrival(star: 1, beat: 2, open: 3, close: 20), code: "window", before: before)
        let late: Level = try Self.row(closes: [20, 4, 20, 20])
        play = try Self.playing(late)
        clear = play
        try Self.act(&clear, .leg(1, 3))
        #expect(clear.stage == .playing && clear.beat == 4)
        before = play
        try Self.act(&play, .leg(1, 4))
        Self.expectFailed(play, .arrival(star: 1, beat: 5, open: 0, close: 4), code: "window", before: before)
    }

    /// An arrival after the deadline at a star whose window is still open fails `deadline` on the exact leg; at a star
    /// whose window closed first, the arrival window is named (the check order).
    @Test func anArrivalAfterTheDeadlineFailsOnTheExactLeg() throws {
        let level: Level = try Self.row(closes: [30, 30, 30, 30], deadline: 5)
        var play: Play = try Self.playing(level)
        try Self.act(&play, .leg(1, 4))
        #expect(play.stage == .playing && play.beat == 5)
        let before: Play = play
        try Self.act(&play, .leg(0, 0))
        Self.expectFailed(play, .deadline(beat: 6, deadline: 5), code: "deadline", before: before)
        #expect(Self.text(play.failure) == "deadline 6 5")
        var shut: Play = try Self.playing(try Self.row(closes: [5, 30, 30, 30], deadline: 5))
        try Self.act(&shut, .leg(1, 4))
        let shutBefore: Play = shut
        try Self.act(&shut, .leg(0, 0))
        Self.expectFailed(shut, .arrival(star: 0, beat: 6, open: 0, close: 5), code: "window", before: shutBefore)
    }

    static func text(_ failure: StarlitCartoucheFailure?) -> String { Play.text(failure) }

    @Test func aStrayStrokeFailsOnTheExactLeg() throws {
        let level: Level = try Self.row(start: 1, beacon: 3, symbol: [1, 2])
        var play: Play = try Self.playing(level)
        try Self.act(&play, .leg(2, 0))
        try Self.act(&play, .leg(1, 0))
        #expect(play.stage == .playing && play.drawn == [1] && play.star == 1 && play.beat == 4)
        let before: Play = play
        try Self.act(&play, .leg(0, 0))
        Self.expectFailed(play, .stroke(corridor: 0), code: "stroke", before: before)
        #expect(play.records[2].index == 2 && play.records[2].action == .leg(0, 0))
        #expect(play.report.stray.isEmpty)
    }

    @Test func theBudgetFailsOnTheExactActionWithOneActionEitherSide() throws {
        for budget in [3, 4, 5] {
            let level: Level = try Self.row(budget: budget)
            var play: Play = try Self.playing(level)
            for index in 0..<budget {
                #expect(play.stage == .playing, "budget \(budget) before \(index)")
                #expect(play.actionsLeft == budget - index)
                try Self.act(&play, .leg(index % 2 == 0 ? 1 : 0, 0))
            }
            #expect(play.stage == .failed)
            #expect(play.failure == .budget(budget))
            #expect(play.failure?.code == "budget")
            #expect(play.actionsLeft == 0)
            #expect(play.legs.count == budget)
            #expect(Self.refusal(play, .act(.leg(1, 0))) == .stage)
            try play.undo()
            #expect(play.stage == .playing && play.actionsLeft == 1 && play.failure == nil)
        }
    }

    // MARK: Undo, redo, fingerprint

    @Test func theFingerprintIsTheHashOfItsCanonicalText() throws {
        let level: Level = try Self.row()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .leg(1, 0))
        let text: String = "{\"actions\":1,\"beat\":1,\"drawn\":[0],\"failure\":\"none\",\"legs\":[[0,1,0,0,0,1]],"
            + "\"level\":\"" + level.fingerprint + "\",\"schema\":1,\"stage\":\"playing\",\"star\":1}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text.utf8)))
        let hazard: StarlitCartoucheHazard = StarlitCartoucheHazard(corridor: 0, from: 0, to: 1)
        var failed: Play = try Self.playing(try Self.row(hazards: [hazard]))
        try Self.act(&failed, .leg(1, 0))
        let failedText: String = "{\"actions\":1,\"beat\":0,\"drawn\":[],\"failure\":\"hazard 0 0 0 1\",\"legs\":[],"
            + "\"level\":\"" + failed.level.fingerprint + "\",\"schema\":1,\"stage\":\"failed\",\"star\":0}"
        #expect(failed.fingerprint == StableHash.sha256Hex(Array(failedText.utf8)))
        var paused: Play = play
        try paused.handle(.pause)
        #expect(paused.fingerprint != play.fingerprint)
        #expect(Self.text(.departure(star: 1, beat: 2, close: 3)) == "departure 1 2 3")
        #expect(Self.text(.arrival(star: 1, beat: 2, open: 3, close: 4)) == "arrival 1 2 3 4")
        #expect(Self.text(.stroke(corridor: 2)) == "stroke 2")
        #expect(Self.text(.budget(4)) == "budget 4")
        #expect(Self.text(nil) == "none")
    }

    @Test func undoRestoresExactFingerprintsAndANewLegClearsRedo() throws {
        let fixtures: [StarlitCartoucheFixture] = StarlitCartoucheFixture.all(count: 30, seed: Self.seed)
        for fixture in fixtures {
            let win: Int = try #require(Self.firstWin(fixture))
            let level: Level = try Self.rebudgeted(fixture.level, budget: 16)
            var play: Play = try Self.playing(level)
            var history: [String] = [play.fingerprint]
            for position in 0..<win {
                try Self.act(&play, fixture.actions[position])
                history.append(play.fingerprint)
            }
            for position in stride(from: history.count - 2, through: 0, by: -1) {
                try play.undo()
                #expect(play.fingerprint == history[position])
            }
            #expect(Self.refusal(play, .undo) == .action("undo"))
            for position in 1..<history.count {
                try play.redo()
                #expect(play.fingerprint == history[position])
            }
            #expect(Self.refusal(play, .redo) == .action("redo"))
            if history.count > 1 {
                try play.handle(.pause)
                try play.undo()
                #expect(play.stage == .paused)
                #expect(play.canRedo)
                try play.handle(.resume)
                #expect(play.fingerprint == history[history.count - 2])
                var flown: Play = play
                try Self.act(&flown, fixture.actions[history.count - 2])
                #expect(flown.stage == .playing)
                #expect(flown.fingerprint == history[history.count - 1])
                #expect(!flown.canRedo)
                #expect(Self.refusal(flown, .redo) == .action("redo"))
            }
        }
        // From failed: undo restores the exact moment before the failing leg.
        var failed: Play = try Self.playing(try Self.row(start: 1, beacon: 3, symbol: [1, 2]))
        try Self.act(&failed, .leg(2, 0))
        let before: String = failed.fingerprint
        try Self.act(&failed, .leg(3, 0))
        #expect(failed.stage == .won)
        failed = try Self.playing(try Self.row(start: 1, beacon: 3, symbol: [1, 2]))
        try Self.act(&failed, .leg(2, 0))
        try Self.act(&failed, .leg(1, 0))
        let retry: String = failed.fingerprint
        try Self.act(&failed, .leg(0, 0))
        #expect(failed.stage == .failed && failed.canUndo && !failed.canRedo)
        try failed.undo()
        #expect(failed.fingerprint == retry && failed.actionsSpent == 2 && failed.stage == .playing)
        try failed.undo()
        #expect(failed.fingerprint == before)
    }

    // MARK: Replay

    @Test func fiveHundredSeededTracesReplayIdentically() throws {
        let fixtures: [StarlitCartoucheFixture] = StarlitCartoucheFixture.all(count: 25, seed: Self.seed)
        var random = SeededRandom(seed: Self.seed)
        var outcomes: [StarlitCartoucheStage: Int] = [:]
        var refused: Int = 0
        for trace in 0..<500 {
            let fixture: StarlitCartoucheFixture = fixtures[trace % fixtures.count]
            var play: Play = try Self.playing(fixture.level)
            let steps: Int = random.int(1...10)
            for _ in 0..<steps {
                let roll: Int = random.int(0...9)
                if roll < 6 {
                    let destination: Int = random.int(-1...fixture.level.stars.count)
                    let wait: Int = random.int(-1...9)
                    let before: String = play.fingerprint
                    let spent: Int = play.actionsSpent
                    do {
                        try Self.act(&play, .leg(destination, wait))
                        let after: String = play.fingerprint
                        if play.stage != .won {
                            try play.undo()
                            #expect(play.fingerprint == before)
                            #expect(play.actionsSpent == spent)
                            try play.redo()
                            #expect(play.fingerprint == after)
                        }
                    } catch {
                        refused += 1
                        #expect(play.fingerprint == before)
                    }
                } else if roll < 8 {
                    try? play.undo()
                } else if roll < 9 {
                    try? play.redo()
                } else if play.stage == .playing {
                    try play.handle(.pause)
                    try? play.undo()
                    try play.handle(.resume)
                }
            }
            outcomes[play.stage, default: 0] += 1
            var replayed: Play = try Play.replay(level: fixture.level, records: play.records)
            // Pauses are not records: a trace whose last record was taken paused ends paused on replay.
            if let last = play.records.last { #expect(last.next == replayed.fingerprint) }
            if replayed.stage == .paused, play.stage == .playing { try replayed.handle(.resume) }
            #expect(replayed == play, "trace \(trace)")
            #expect(replayed.fingerprint == play.fingerprint)
            for record in play.records {
                #expect(record.schema == Play.schema && record.seed == fixture.level.seed)
            }
        }
        #expect(refused > 0)
        #expect((outcomes[.playing] ?? 0) > 0)
        #expect((outcomes[.failed] ?? 0) > 0)
    }

    @Test func recordsRoundTripAndTamperedTracesAreRefused() throws {
        let level: Level = try Self.row()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .leg(1, 0))
        try play.handle(.pause)
        try play.undo()
        try play.handle(.resume)
        try play.redo()
        try Self.act(&play, .leg(0, 0))
        try Self.act(&play, .leg(3, 1))
        #expect(play.stage == .failed && play.failure == .stroke(corridor: 3))
        try play.undo()
        let records: [StarlitCartoucheRecord] = play.records
        let data: Data = try JSONEncoder().encode(records)
        let decoded: [StarlitCartoucheRecord] = try JSONDecoder().decode([StarlitCartoucheRecord].self, from: data)
        #expect(decoded == records)
        #expect(try Play.replay(level: level, records: decoded) == play)

        func refusal(_ edited: [StarlitCartoucheRecord]) -> StarlitCartoucheError? {
            do {
                _ = try Play.replay(level: level, records: edited)
                return nil
            } catch {
                return error
            }
        }
        func edit(_ index: Int, schema: Int? = nil, seed: UInt64? = nil, action: Action?? = nil,
                  previous: String? = nil, next: String? = nil) -> [StarlitCartoucheRecord] {
            var copy: [StarlitCartoucheRecord] = records
            let r: StarlitCartoucheRecord = copy[index]
            copy[index] = StarlitCartoucheRecord(schema: schema ?? r.schema, seed: seed ?? r.seed, index: r.index,
                                                 kind: r.kind, action: action ?? r.action,
                                                 previous: previous ?? r.previous, next: next ?? r.next)
            return copy
        }
        #expect(refusal(edit(1, schema: 2)) == .malformed("schema 1"))
        #expect(refusal(edit(0, seed: 99)) == .malformed("seed 0"))
        #expect(refusal(edit(2, previous: "beef")) == .malformed("replay"))
        #expect(refusal(edit(3, next: "beef")) == .malformed("record 3"))
        #expect(refusal(edit(0, action: .some(nil))) == .malformed("record 0"))
        #expect(refusal(edit(1, action: .some(.leg(1, 0)))) == .malformed("record 1"))
        #expect(refusal(edit(0, action: .some(.leg(1, 1)))) == .malformed("record 0"))
        #expect(refusal(edit(0, action: .some(.leg(2, 0)))) == .action("no corridor"))
    }
}
