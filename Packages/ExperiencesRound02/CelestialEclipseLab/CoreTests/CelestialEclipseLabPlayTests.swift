// CelestialEclipseLabPlayTests — feature 461 (R02-G17-01) T-R02G1701-004 (FR-R02G1701-003, 005, 006, 009;
// SC-R02G1701-002 … 004; clarifications Q2, Q4). The play of a Celestial Eclipse Lab level: the full stage table of
// `handle(_:)` with the recorded event kinds; the fixtures' known actions keep the timeline equal to the sky's timeline
// after every phase change and win on the run; each failure named on a hand level (`window`, `unwanted`, `horizon`);
// the budget refusal on the exact action with the run still allowed; the validation order stage, stale, action
// (unknown, fixed body, offset outside the period, same offset), budget, with every refusal reachable, spending nothing
// and leaving the play unchanged; the fingerprint is the SHA-256 of its canonical text; undo restores exact
// fingerprints and refunds, undo from failed returns to playing (recorded), a won play is final, redo re-applies and a
// new action clears redo; 500 seeded traces replay to the same records, fingerprints and outcome, and tampered traces
// are refused. Explicit types, plain loops, short traces; each test well under 10 s; no clock.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import CelestialEclipseLabCore

struct CelestialEclipseLabPlayTests {
    typealias Play = CelestialEclipseLabPlay
    typealias Action = CelestialEclipseLabAction
    typealias Level = CelestialEclipseLabLevel
    typealias Body = CelestialEclipseLabBody
    typealias Vector = CelestialEclipseLabVector

    /// The test seed of the feature.
    static let seed: UInt64 = 2_461

    /// Applies `action` with the current fingerprint.
    static func act(_ play: inout Play, _ action: Action) throws(CelestialEclipseLabError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the level has a tutorial).
    static func playing(_ level: Level) throws(CelestialEclipseLabError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The hand level: body 0 fixed at the origin (z 10, period 4), body 1 (z 0, period 8) at the origin only at orbit
    /// index 0, body 2 (z −10, period 12) at the origin only at orbit index 0, all of radius 1, horizon 8; the target
    /// is body 0 over body 1 in ticks 2 … 3, then body 0 over body 2 in ticks 5 … 6. With phase p, body 1's only event
    /// in the horizon is at tick (8 − p) mod 8 and body 2's at tick (12 − p) mod 12 when below 8. Starting phases
    /// [0, 0, 4] fail `window` at tick 0; [0, 6, 7] win.
    static func hand(budget: Int = 2, tutorial: Bool = false,
                     phases: [Int] = [0, 0, 4]) throws(CelestialEclipseLabError) -> Level {
        var orbit0: [Vector] = []
        for _ in 0..<4 { orbit0.append(Vector(0, 0, 10)) }
        var orbit1: [Vector] = [Vector(0, 0, 0)]
        for _ in 1..<8 { orbit1.append(Vector(10, 0, 0)) }
        var orbit2: [Vector] = [Vector(0, 0, -10)]
        for _ in 1..<12 { orbit2.append(Vector(-10, 0, -10)) }
        let bodies: [Body] = [Body(orbit: orbit0, radius: 1, fixed: true), Body(orbit: orbit1, radius: 1),
                              Body(orbit: orbit2, radius: 1)]
        let target: [CelestialEclipseLabTarget] = [CelestialEclipseLabTarget(front: 0, back: 1, open: 2, close: 3),
                                                   CelestialEclipseLabTarget(front: 0, back: 2, open: 5, close: 6)]
        return try Level(id: "hand", seed: 7, difficulty: 1, bodies: bodies, horizon: 8, target: target,
                         phases: phases, budget: budget, tutorial: tutorial)
    }

    @Test func theStageTableAcceptsOnlyItsEvents() throws {
        let events: [CelestialEclipseLabEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]
        var plain: Play = Play(level: try Self.hand())
        #expect(plain.stage == .loading)
        for event in events where event != .begin {
            #expect(throws: CelestialEclipseLabError.stage) { try plain.handle(event) }
        }
        try plain.handle(.begin)
        #expect(plain.stage == .playing)
        var taught: Play = Play(level: try Self.hand(tutorial: true))
        try taught.handle(.begin)
        #expect(taught.stage == .tutorial)
        for event in events where event != .dismissTutorial {
            #expect(throws: CelestialEclipseLabError.stage) { try taught.handle(event) }
        }
        try taught.handle(.dismissTutorial)
        #expect(taught.stage == .playing)
        for event in events where event != .pause {
            #expect(throws: CelestialEclipseLabError.stage) { try plain.handle(event) }
        }
        try plain.handle(.pause)
        #expect(plain.stage == .paused)
        for event in events where event != .resume {
            #expect(throws: CelestialEclipseLabError.stage) { try plain.handle(event) }
        }
        try plain.handle(.resume)
        #expect(plain.stage == .playing)
        let kinds: [CelestialEclipseLabRecordKind] = [.begin, .pause, .resume]
        var recorded: [CelestialEclipseLabRecordKind] = []
        for record in plain.records { recorded.append(record.kind) }
        #expect(recorded == kinds)
        #expect(taught.records.map(\.kind) == [.begin, .dismissTutorial])
        try Self.act(&plain, .run)
        #expect(plain.stage == .failed)
        for event in events where event != .showResult {
            #expect(throws: CelestialEclipseLabError.stage) { try plain.handle(event) }
        }
        let count: Int = plain.records.count
        try plain.handle(.showResult)
        #expect(plain.stage == .result)
        #expect(plain.records.count == count)
        for event in events {
            #expect(throws: CelestialEclipseLabError.stage) { try plain.handle(event) }
        }
        #expect(throws: CelestialEclipseLabError.stage) { try Self.act(&plain, .run) }
        #expect(throws: CelestialEclipseLabError.stage) { try plain.undo() }
        #expect(throws: CelestialEclipseLabError.stage) { try plain.redo() }
    }

    @Test func theFixturesKnownActionsWinOnTheRun() throws {
        let fixtures: [CelestialEclipseLabFixture] = CelestialEclipseLabFixture.all(count: 40)
        for fixture in fixtures {
            var play: Play = try Self.playing(fixture.level)
            #expect(play.phases == fixture.level.phases)
            #expect(play.timeline == fixture.level.startTimeline)
            var changes: Int = 0
            for action in fixture.actions {
                try Self.act(&play, action)
                if case .phase = action {
                    changes += 1
                    #expect(play.stage == .playing)
                    #expect(play.actionsSpent == changes)
                    #expect(play.actionsLeft == fixture.level.budget - changes)
                    #expect(play.timeline == CelestialEclipseLabSky.timeline(fixture.level, phases: play.phases))
                }
            }
            #expect(play.phases == fixture.winning)
            #expect(play.stage == .won)
            #expect(play.failure == nil)
            #expect(play.actionsSpent == changes)
            #expect(play.records.last?.kind == .run)
            #expect(play.records.last?.next == play.fingerprint)
        }
    }

    /// The play of the hand level after setting body 1 to `phase1` and body 2 to `phase2` (skipping unchanged ones),
    /// then the run.
    static func run(_ phase1: Int, _ phase2: Int) throws -> Play {
        var play: Play = try playing(try hand())
        if phase1 != 0 { try act(&play, .phase(1, phase1)) }
        if phase2 != 4 { try act(&play, .phase(2, phase2)) }
        let phases: [Int] = play.phases
        let spent: Int = play.actionsSpent
        try act(&play, .run)
        #expect(play.phases == phases)
        #expect(play.actionsSpent == spent)
        return play
    }

    @Test func eachFailureIsNamedOnTheRun() throws {
        let won: Play = try Self.run(6, 7)
        #expect(won.stage == .won)
        #expect(won.failure == nil)
        let cases: [(Int, Int, CelestialEclipseLabFailure, String)] = [
            (0, 4, .window(front: 0, back: 1, tick: 0, open: 2, close: 3), "window"),
            (6, 8, .window(front: 0, back: 2, tick: 4, open: 5, close: 6), "window"),
            (6, 0, .unwanted(front: 0, back: 2, tick: 0), "unwanted"),
            (6, 2, .horizon(front: 0, back: 2, open: 5, close: 6), "horizon"),
            (2, 7, .unwanted(front: 0, back: 2, tick: 5), "unwanted"),
        ]
        for (phase1, phase2, failure, code) in cases {
            let play: Play = try Self.run(phase1, phase2)
            #expect(play.stage == .failed)
            #expect(play.failure == failure)
            #expect(play.failure?.code == code)
            #expect(play.failure == play.timeline.failure)
        }
    }

    @Test func theBudgetRefusesTheExactActionAndTheRunIsStillAllowed() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 1))
        try Self.act(&play, .phase(1, 6))
        #expect(play.actionsLeft == 0)
        let before: Play = play
        #expect(throws: CelestialEclipseLabError.budget) { try Self.act(&play, .phase(2, 7)) }
        #expect(play == before)
        #expect(CelestialEclipseLabError.budget.reasonCode == "r02-g17.budget")
        try Self.act(&play, .run)
        #expect(play.stage == .failed)
        #expect(play.failure == .horizon(front: 0, back: 2, open: 5, close: 6))
        var exact: Play = try Self.playing(try Self.hand(budget: 2))
        try Self.act(&exact, .phase(1, 6))
        try Self.act(&exact, .phase(2, 7))
        #expect(exact.actionsLeft == 0)
        #expect(throws: CelestialEclipseLabError.budget) { try Self.act(&exact, .phase(2, 8)) }
        try Self.act(&exact, .run)
        #expect(exact.stage == .won)
    }

    @Test func everyRefusalReasonIsReachableInOrder() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 1))
        let start: Play = play
        let refusals: [(Action, CelestialEclipseLabError)] = [
            (.phase(3, 0), .action("unknown body")),
            (.phase(-1, 0), .action("unknown body")),
            (.phase(0, 1), .action("fixed body")),
            (.phase(1, 8), .action("offset outside the period")),
            (.phase(1, -1), .action("offset outside the period")),
            (.phase(1, 0), .action("same offset")),
        ]
        for (action, error) in refusals {
            #expect(throws: error) { try Self.act(&play, action) }
            #expect(play == start)
            #expect(throws: CelestialEclipseLabError.stale) { try play.apply(action, expecting: "stale") }
            #expect(play == start)
        }
        #expect(throws: CelestialEclipseLabError.stale) { try play.apply(.run, expecting: "stale") }
        #expect(throws: CelestialEclipseLabError.action("undo")) { try play.undo() }
        #expect(throws: CelestialEclipseLabError.action("redo")) { try play.redo() }
        #expect(play == start)
        try Self.act(&play, .phase(1, 6))
        let spent: Play = play
        // The action check comes before the budget, the budget after it.
        #expect(throws: CelestialEclipseLabError.action("fixed body")) { try Self.act(&play, .phase(0, 1)) }
        #expect(throws: CelestialEclipseLabError.budget) { try Self.act(&play, .phase(2, 7)) }
        #expect(play == spent)
        // The stage comes first, even with a stale fingerprint.
        try play.handle(.pause)
        let paused: Play = play
        #expect(throws: CelestialEclipseLabError.stage) { try play.apply(.phase(9, 9), expecting: "stale") }
        #expect(throws: CelestialEclipseLabError.stage) { try Self.act(&play, .run) }
        #expect(play == paused)
        try play.handle(.resume)
        var loading: Play = Play(level: try Self.hand())
        #expect(throws: CelestialEclipseLabError.stage) { try Self.act(&loading, .run) }
        #expect(throws: CelestialEclipseLabError.stage) { try loading.undo() }
        #expect(throws: CelestialEclipseLabError.stage) { try loading.redo() }
        var winning: Play = try Self.run(6, 7)
        #expect(throws: CelestialEclipseLabError.stage) { try winning.undo() }
        #expect(throws: CelestialEclipseLabError.stage) { try winning.redo() }
        #expect(!winning.canUndo)
        #expect(throws: CelestialEclipseLabError.malformed("seed 0")) {
            let other: Level = try Self.hand(phases: [0, 1, 4])
            _ = try Play.replay(level: other, records: [CelestialEclipseLabRecord(
                schema: 1, seed: 8, index: 0, kind: .begin, action: nil, previous: "", next: "")])
        }
        let codes: [String] = [CelestialEclipseLabError.action("x").reasonCode,
                               CelestialEclipseLabError.stage.reasonCode,
                               CelestialEclipseLabError.stale.reasonCode,
                               CelestialEclipseLabError.malformed("x").reasonCode]
        #expect(codes == ["r02-g17.action", "r02-g17.stage", "r02-g17.stale", "r02-g17.malformed"])
    }

    @Test func theFingerprintIsTheHashOfItsCanonicalText() throws {
        let level: Level = try Self.hand()
        var play: Play = try Self.playing(level)
        let text0: String = "{\"actions\":0,\"failure\":\"none\",\"level\":\"" + level.fingerprint
            + "\",\"phases\":[0,0,4],\"schema\":1,\"stage\":\"playing\"}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text0.utf8)))
        try Self.act(&play, .phase(1, 6))
        try Self.act(&play, .run)
        let text1: String = "{\"actions\":1,\"failure\":\"horizon 0 2 5 6\",\"level\":\"" + level.fingerprint
            + "\",\"phases\":[0,6,4],\"schema\":1,\"stage\":\"failed\"}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text1.utf8)))
        #expect(Play.text(.window(front: 0, back: 1, tick: 0, open: 2, close: 3)) == "window 0 1 0 2 3")
        #expect(Play.text(.unwanted(front: 0, back: 2, tick: 5)) == "unwanted 0 2 5")
        #expect(play.fingerprint.count == 64)
    }

    @Test func undoRestoresExactFingerprintsAndRedoReapplies() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 3))
        let f0: String = play.fingerprint
        try Self.act(&play, .phase(1, 6))
        let f1: String = play.fingerprint
        try Self.act(&play, .phase(2, 2))
        let f2: String = play.fingerprint
        try Self.act(&play, .run)
        #expect(play.stage == .failed)
        let f3: String = play.fingerprint
        #expect(play.canUndo)
        #expect(!play.canRedo)
        try play.undo()
        #expect(play.stage == .playing)
        #expect(play.failure == nil)
        #expect(play.fingerprint == f2)
        #expect(play.records.last?.kind == .undo)
        #expect(play.records.last?.previous == f3)
        try play.undo()
        #expect(play.fingerprint == f1)
        #expect(play.actionsSpent == 1)
        #expect(play.phases == [0, 6, 4])
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused)
        try play.handle(.resume)
        #expect(play.fingerprint == f0)
        #expect(play.actionsLeft == 3)
        #expect(play.timeline == play.level.startTimeline)
        try play.redo()
        #expect(play.fingerprint == f1)
        try play.redo()
        #expect(play.fingerprint == f2)
        try play.redo()
        #expect(play.fingerprint == f3)
        #expect(play.stage == .failed)
        try play.undo()
        try Self.act(&play, .phase(2, 7))
        #expect(!play.canRedo)
        #expect(throws: CelestialEclipseLabError.action("redo")) { try play.redo() }
        try Self.act(&play, .run)
        #expect(play.stage == .won)
        let won: Play = play
        #expect(throws: CelestialEclipseLabError.stage) { try play.undo() }
        #expect(play == won)
        let replayed: Play = try Play.replay(level: play.level, records: play.records)
        #expect(replayed == play)
    }

    @Test func fiveHundredSeededTracesReplayIdentically() throws {
        let fixtures: [CelestialEclipseLabFixture] = CelestialEclipseLabFixture.all(count: 25)
        var random = SeededRandom(seed: Self.seed)
        var outcomes: [CelestialEclipseLabStage: Int] = [:]
        var refused: Int = 0
        for trace in 0..<500 {
            let fixture: CelestialEclipseLabFixture = fixtures[trace % fixtures.count]
            let level: Level = fixture.level
            var play: Play = try Self.playing(level)
            let steps: Int = random.int(1...10)
            for _ in 0..<steps {
                let roll: Int = random.int(0...11)
                if roll < 7 {
                    let body: Int = random.int(-1...level.bodies.count)
                    let offset: Int = random.int(-1...12)
                    let before: String = play.fingerprint
                    let spent: Int = play.actionsSpent
                    do {
                        try Self.act(&play, .phase(body, offset))
                        let after: String = play.fingerprint
                        try play.undo()
                        #expect(play.fingerprint == before)
                        #expect(play.actionsSpent == spent)
                        try play.redo()
                        #expect(play.fingerprint == after)
                    } catch {
                        refused += 1
                        #expect(play.fingerprint == before)
                    }
                } else if roll < 9 {
                    try? play.undo()
                } else if roll < 10 {
                    try? play.redo()
                } else if roll < 11 {
                    if play.stage == .playing {
                        try play.handle(.pause)
                    } else if play.stage == .paused {
                        try play.handle(.resume)
                    }
                } else {
                    try? Self.act(&play, .run)
                }
            }
            outcomes[play.stage, default: 0] += 1
            for (position, record) in play.records.enumerated() {
                #expect(record.index == position)
                if position > 0 { #expect(record.previous == play.records[position - 1].next) }
            }
            let replayed: Play = try Play.replay(level: level, records: play.records)
            #expect(replayed == play)
            #expect(replayed.fingerprint == play.fingerprint)
            if trace % 50 == 0 && play.records.count > 1 {
                try Self.expectTamperedRefused(level: level, records: play.records)
            }
        }
        #expect(refused > 0)
        #expect(outcomes.count >= 2)
    }

    /// Checks that a trace with another seed, a broken chain, a wrong index or another schema is refused.
    static func expectTamperedRefused(level: Level, records: [CelestialEclipseLabRecord]) throws {
        let last: Int = records.count - 1
        let r: CelestialEclipseLabRecord = records[last]
        var seed: [CelestialEclipseLabRecord] = records
        seed[last] = CelestialEclipseLabRecord(schema: r.schema, seed: r.seed + 1, index: r.index, kind: r.kind,
                                               action: r.action, previous: r.previous, next: r.next)
        #expect(throws: CelestialEclipseLabError.malformed("seed \(last)")) {
            _ = try Play.replay(level: level, records: seed)
        }
        var chain: [CelestialEclipseLabRecord] = records
        chain[last] = CelestialEclipseLabRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                                action: r.action, previous: "broken", next: r.next)
        #expect(throws: CelestialEclipseLabError.malformed("chain \(last)")) {
            _ = try Play.replay(level: level, records: chain)
        }
        var index: [CelestialEclipseLabRecord] = records
        index[last] = CelestialEclipseLabRecord(schema: r.schema, seed: r.seed, index: r.index + 1, kind: r.kind,
                                                action: r.action, previous: r.previous, next: r.next)
        #expect(throws: CelestialEclipseLabError.malformed("index \(last)")) {
            _ = try Play.replay(level: level, records: index)
        }
        var schema: [CelestialEclipseLabRecord] = records
        schema[last] = CelestialEclipseLabRecord(schema: 2, seed: r.seed, index: r.index, kind: r.kind,
                                                 action: r.action, previous: r.previous, next: r.next)
        #expect(throws: CelestialEclipseLabError.malformed("schema \(last)")) {
            _ = try Play.replay(level: level, records: schema)
        }
        var next: [CelestialEclipseLabRecord] = records
        next[last] = CelestialEclipseLabRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                               action: r.action, previous: r.previous, next: "forged")
        #expect(throws: CelestialEclipseLabError.malformed("record \(last)")) {
            _ = try Play.replay(level: level, records: next)
        }
    }
}
