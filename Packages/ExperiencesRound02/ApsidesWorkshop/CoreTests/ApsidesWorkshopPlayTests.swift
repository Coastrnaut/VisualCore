// ApsidesWorkshopPlayTests — feature 471 (R02-G18-01) T-R02G1801-004 (FR-R02G1801-006 … 009, 011;
// SC-R02G1801-001, 002; clarification Q4). The play of an Apsides Workshop level: the full stage table of
// `handle(_:)` with the recorded event kinds; the fixtures' known orbits keep the report equal to the sky's report
// after every tuning and win on the play; each failure named on a hand level (`contact`, `order`, `share`,
// `apsis-sector`, `apsis-distance`); the budget refusal on the exact action with the play still allowed; the
// validation order stage, stale, action (a step out of range, unchanged, an invalid orbit), budget, with every refusal
// reachable, spending nothing and leaving the play unchanged; the fingerprint is the SHA-256 of its canonical text;
// undo restores exact fingerprints and refunds, undo from failed returns to playing (recorded), a won play is final,
// redo re-applies and a new action clears redo; 500 seeded traces replay to the same records, fingerprints and
// outcome, and tampered traces are refused. Explicit types, plain loops, short traces; each test well under 10 s; no
// clock.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import ApsidesWorkshopCore

struct ApsidesWorkshopPlayTests {
    typealias Play = ApsidesWorkshopPlay
    typealias Action = ApsidesWorkshopAction
    typealias Level = ApsidesWorkshopLevel
    typealias Orbit = ApsidesWorkshopOrbit
    typealias Target = ApsidesWorkshopTarget
    typealias Planet = ApsidesWorkshopPlanet

    /// The test seed of the feature.
    static let seed: UInt64 = 2_471

    /// Applies `action` with the current fingerprint.
    static func act(_ play: inout Play, _ action: Action) throws(ApsidesWorkshopError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the level has a tutorial).
    static func playing(_ level: Level) throws(ApsidesWorkshopError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The hand level: period 16, no planets, one target (the periapsis in sector 0 at 620 … 660 twentieths) and the
    /// circular starting orbit of size 40 turned by 15° (periapsis in sector 0 at 800, failing `apsis-distance`). The
    /// circle of size 32 (640) wins; turning the periapsis to step 4 or more moves it out of sector 0; eccentricity 15
    /// at size 40 leaves the sky (40 · 35 > 1280).
    static func hand(budget: Int = 2, tutorial: Bool = false) throws(ApsidesWorkshopError) -> Level {
        let target: Target = Target(kind: .periapsis, sector: 0, low: 620, high: 660)
        return try Level(id: "hand", seed: 7, difficulty: 1, period: 16, planets: [], targets: [target],
                         orbit: Orbit(size: 40, eccentricity: 0, direction: 1), budget: budget, tutorial: tutorial)
    }

    /// A level of period 16 around the circle of size 16 turned by 15°: tick t lies at 15° + 22.5°·t, so sector s
    /// holds ticks 2s and 2s + 1 (no position near a sector boundary), every share is close to 125 and both apsides
    /// read 320 twentieths with the periapsis in sector 0.
    static func circle(planets: [Planet] = [], targets: [Target]) throws(ApsidesWorkshopError) -> Level {
        try Level(id: "circle", seed: 11, difficulty: 1, period: 16, planets: planets, targets: targets,
                  orbit: Orbit(size: 16, eccentricity: 0, direction: 1), budget: 1)
    }

    @Test func theStageTableAcceptsOnlyItsEvents() throws {
        let events: [ApsidesWorkshopEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]
        var plain: Play = Play(level: try Self.hand())
        #expect(plain.stage == .loading)
        for event in events where event != .begin {
            #expect(throws: ApsidesWorkshopError.stage) { try plain.handle(event) }
        }
        try plain.handle(.begin)
        #expect(plain.stage == .playing)
        var taught: Play = Play(level: try Self.hand(tutorial: true))
        try taught.handle(.begin)
        #expect(taught.stage == .tutorial)
        for event in events where event != .dismissTutorial {
            #expect(throws: ApsidesWorkshopError.stage) { try taught.handle(event) }
        }
        try taught.handle(.dismissTutorial)
        #expect(taught.stage == .playing)
        for event in events where event != .pause {
            #expect(throws: ApsidesWorkshopError.stage) { try plain.handle(event) }
        }
        try plain.handle(.pause)
        #expect(plain.stage == .paused)
        for event in events where event != .resume {
            #expect(throws: ApsidesWorkshopError.stage) { try plain.handle(event) }
        }
        try plain.handle(.resume)
        #expect(plain.stage == .playing)
        let kinds: [ApsidesWorkshopRecordKind] = [.begin, .pause, .resume]
        var recorded: [ApsidesWorkshopRecordKind] = []
        for record in plain.records { recorded.append(record.kind) }
        #expect(recorded == kinds)
        #expect(taught.records.map(\.kind) == [.begin, .dismissTutorial])
        try Self.act(&plain, .play)
        #expect(plain.stage == .failed)
        for event in events where event != .showResult {
            #expect(throws: ApsidesWorkshopError.stage) { try plain.handle(event) }
        }
        let count: Int = plain.records.count
        try plain.handle(.showResult)
        #expect(plain.stage == .result)
        #expect(plain.records.count == count)
        for event in events {
            #expect(throws: ApsidesWorkshopError.stage) { try plain.handle(event) }
        }
        #expect(throws: ApsidesWorkshopError.stage) { try Self.act(&plain, .play) }
        #expect(throws: ApsidesWorkshopError.stage) { try plain.undo() }
        #expect(throws: ApsidesWorkshopError.stage) { try plain.redo() }
    }

    /// The fixture's known actions in an order whose intermediate orbit is valid: the periapsis knob first unless
    /// the start's size with the winning knob is invalid, then the size first (one of the two orders is always valid,
    /// since validity is monotone in the size and the eccentricity).
    static func knownActions(_ fixture: ApsidesWorkshopFixture) -> [Action] {
        var actions: [Action] = fixture.actions
        guard actions.count == 3, case .periapsis(let k, let d) = actions[0] else { return actions }
        let between: Orbit = Orbit(size: fixture.level.orbit.size, eccentricity: k, direction: d)
        if !between.isValid { actions.swapAt(0, 1) }
        return actions
    }

    @Test func theFixturesKnownOrbitsWinOnThePlay() throws {
        let fixtures: [ApsidesWorkshopFixture] = ApsidesWorkshopFixture.all(count: 500)
        #expect(fixtures.count == 500)
        for (position, fixture) in fixtures.enumerated() {
            var play: Play = try Self.playing(fixture.level)
            #expect(play.orbit == fixture.level.orbit)
            #expect(!play.report.wins)
            var tunings: Int = 0
            for action in Self.knownActions(fixture) {
                try Self.act(&play, action)
                if action != .play {
                    tunings += 1
                    #expect(play.stage == .playing)
                    #expect(play.actionsSpent == tunings)
                    #expect(play.actionsLeft == fixture.level.budget - tunings)
                    if position % 10 == 0 {
                        #expect(play.report == ApsidesWorkshopSky.report(fixture.level, orbit: play.orbit))
                    }
                }
            }
            #expect(play.orbit == fixture.winning)
            #expect(play.stage == .won)
            #expect(play.failure == nil)
            #expect(play.actionsSpent == tunings)
            #expect(play.records.last?.kind == .play)
            #expect(play.records.last?.next == play.fingerprint)
        }
    }

    /// The play of `level` right after `begin`, then the play; the orbit and the actions spent are unchanged.
    static func played(_ level: Level) throws -> Play {
        var play: Play = try playing(level)
        let orbit: Orbit = play.orbit
        try act(&play, .play)
        #expect(play.orbit == orbit)
        #expect(play.actionsSpent == 0)
        return play
    }

    @Test func eachFailureIsNamedOnThePlay() throws {
        let wide: [Target] = [.sweep(sector: 0, low: 0, high: 1000)]
        let contact: Play = try Self.played(try Self.circle(planets: [Planet(x: 15, y: 4, radius: 2)], targets: wide))
        let order: Play = try Self.played(try Self.circle(targets: [.sweep(sector: 2, low: 0, high: 1000),
                                                                    .sweep(sector: 1, low: 0, high: 1000)]))
        let share: Play = try Self.played(try Self.circle(targets: [.sweep(sector: 0, low: 500, high: 1000)]))
        let sector: Play = try Self.played(try Self.circle(targets: [Target(kind: .periapsis, sector: 3, low: 0,
                                                                            high: 1280)]))
        let distance: Play = try Self.played(try Self.circle(targets: [Target(kind: .periapsis, sector: 0, low: 0,
                                                                              high: 100)]))
        let shareValue: Int = share.report.shares[0]
        #expect(shareValue < 500)
        let cases: [(Play, ApsidesWorkshopFailure, String)] = [
            (contact, .contact(planet: 0, tick: 0), "contact"),
            (order, .order(target: 1, tick: 2), "order"),
            (share, .share(target: 0, tick: 0, share: shareValue), "share"),
            (sector, .apsisSector(target: 0, sector: 0), "apsis-sector"),
            (distance, .apsisDistance(target: 0, distance: 320), "apsis-distance"),
        ]
        for (play, failure, code) in cases {
            #expect(play.stage == .failed)
            #expect(play.failure == failure)
            #expect(play.failure?.code == code)
            #expect(play.failure == play.report.failure)
        }
        var won: Play = try Self.playing(try Self.hand())
        try Self.act(&won, .size(32))
        try Self.act(&won, .play)
        #expect(won.stage == .won)
        #expect(won.failure == nil)
    }

    @Test func theBudgetRefusesTheExactActionAndThePlayIsStillAllowed() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 1))
        try Self.act(&play, .size(36))
        #expect(play.actionsLeft == 0)
        let before: Play = play
        #expect(throws: ApsidesWorkshopError.budget) { try Self.act(&play, .size(32)) }
        #expect(play == before)
        #expect(ApsidesWorkshopError.budget.reasonCode == "r02-g18.budget")
        try Self.act(&play, .play)
        #expect(play.stage == .failed)
        #expect(play.failure == .apsisDistance(target: 0, distance: 720))
        var exact: Play = try Self.playing(try Self.hand(budget: 2))
        try Self.act(&exact, .size(36))
        try Self.act(&exact, .size(32))
        #expect(exact.actionsLeft == 0)
        #expect(throws: ApsidesWorkshopError.budget) { try Self.act(&exact, .periapsis(0, 2)) }
        try Self.act(&exact, .play)
        #expect(exact.stage == .won)
    }

    @Test func everyRefusalReasonIsReachableInOrder() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 1))
        let start: Play = play
        let refusals: [(Action, ApsidesWorkshopError)] = [
            (.size(7), .action("size out of range")),
            (.size(49), .action("size out of range")),
            (.periapsis(16, 1), .action("eccentricity out of range")),
            (.periapsis(-1, 1), .action("eccentricity out of range")),
            (.periapsis(0, 24), .action("direction out of range")),
            (.periapsis(0, -1), .action("direction out of range")),
            (.size(40), .action("unchanged")),
            (.periapsis(0, 1), .action("unchanged")),
            (.periapsis(15, 1), .action("invalid orbit")),
        ]
        for (action, error) in refusals {
            #expect(throws: error) { try Self.act(&play, action) }
            #expect(play == start)
            #expect(throws: ApsidesWorkshopError.stale) { try play.apply(action, expecting: "stale") }
            #expect(play == start)
        }
        #expect(throws: ApsidesWorkshopError.stale) { try play.apply(.play, expecting: "stale") }
        #expect(throws: ApsidesWorkshopError.action("undo")) { try play.undo() }
        #expect(throws: ApsidesWorkshopError.action("redo")) { try play.redo() }
        #expect(play == start)
        // The lower validity bound: size 8 needs eccentricity at most 12 (8 · 8 ≥ 60).
        var small: Play = try Self.playing(try Self.hand(budget: 3))
        try Self.act(&small, .size(8))
        #expect(throws: ApsidesWorkshopError.action("invalid orbit")) { try Self.act(&small, .periapsis(13, 1)) }
        try Self.act(&small, .periapsis(12, 1))
        try Self.act(&play, .size(36))
        let spent: Play = play
        // The action check comes before the budget, the budget after it.
        #expect(throws: ApsidesWorkshopError.action("unchanged")) { try Self.act(&play, .size(36)) }
        #expect(throws: ApsidesWorkshopError.budget) { try Self.act(&play, .size(32)) }
        #expect(play == spent)
        // The stage comes first, even with a stale fingerprint.
        try play.handle(.pause)
        let paused: Play = play
        #expect(throws: ApsidesWorkshopError.stage) { try play.apply(.size(99), expecting: "stale") }
        #expect(throws: ApsidesWorkshopError.stage) { try Self.act(&play, .play) }
        #expect(play == paused)
        try play.handle(.resume)
        var loading: Play = Play(level: try Self.hand())
        #expect(throws: ApsidesWorkshopError.stage) { try Self.act(&loading, .play) }
        #expect(throws: ApsidesWorkshopError.stage) { try loading.undo() }
        #expect(throws: ApsidesWorkshopError.stage) { try loading.redo() }
        var winning: Play = try Self.playing(try Self.hand())
        try Self.act(&winning, .size(32))
        try Self.act(&winning, .play)
        #expect(throws: ApsidesWorkshopError.stage) { try winning.undo() }
        #expect(throws: ApsidesWorkshopError.stage) { try winning.redo() }
        #expect(!winning.canUndo)
        // A record of another level (another seed) is refused.
        #expect(throws: ApsidesWorkshopError.malformed("seed 0")) {
            let other: Level = try Self.circle(targets: [.sweep(sector: 0, low: 500, high: 1000)])
            _ = try Play.replay(level: other, records: [ApsidesWorkshopRecord(
                schema: 1, seed: 7, index: 0, kind: .begin, action: nil, previous: "", next: "")])
        }
        // A trace of another level with the same seed breaks the chain at once.
        let level: Level = try Self.hand()
        let twin: Level = try Level(id: "twin", seed: 7, difficulty: 1, period: 16, planets: [],
                                    targets: level.targets, orbit: level.orbit, budget: 2)
        #expect(throws: ApsidesWorkshopError.malformed("chain 0")) {
            _ = try Play.replay(level: twin, records: winning.records)
        }
        let codes: [String] = [ApsidesWorkshopError.action("x").reasonCode, ApsidesWorkshopError.stage.reasonCode,
                               ApsidesWorkshopError.stale.reasonCode, ApsidesWorkshopError.malformed("x").reasonCode]
        #expect(codes == ["r02-g18.action", "r02-g18.stage", "r02-g18.stale", "r02-g18.malformed"])
    }

    @Test func theFingerprintIsTheHashOfItsCanonicalText() throws {
        let level: Level = try Self.hand()
        var play: Play = try Self.playing(level)
        let text0: String = "{\"actions\":0,\"failure\":\"none\",\"level\":\"" + level.fingerprint
            + "\",\"orbit\":[40,0,1],\"schema\":1,\"stage\":\"playing\"}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text0.utf8)))
        try Self.act(&play, .size(36))
        try Self.act(&play, .play)
        let text1: String = "{\"actions\":1,\"failure\":\"apsis-distance 0 720\",\"level\":\"" + level.fingerprint
            + "\",\"orbit\":[36,0,1],\"schema\":1,\"stage\":\"failed\"}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text1.utf8)))
        #expect(Play.text(.contact(planet: 1, tick: 5)) == "contact 1 5")
        #expect(Play.text(.order(target: 2, tick: 9)) == "order 2 9")
        #expect(Play.text(.share(target: 0, tick: 3, share: 184)) == "share 0 3 184")
        #expect(Play.text(.apsisSector(target: 1, sector: 6)) == "apsis-sector 1 6")
        #expect(play.fingerprint.count == 64)
    }

    @Test func undoRestoresExactFingerprintsAndRedoReapplies() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 4))
        let f0: String = play.fingerprint
        try Self.act(&play, .size(36))
        let f1: String = play.fingerprint
        try Self.act(&play, .periapsis(0, 4))
        let f2: String = play.fingerprint
        try Self.act(&play, .play)
        #expect(play.stage == .failed)
        #expect(play.failure == .apsisSector(target: 0, sector: 1))
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
        #expect(play.orbit == Orbit(size: 36, eccentricity: 0, direction: 1))
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused)
        try play.handle(.resume)
        #expect(play.fingerprint == f0)
        #expect(play.actionsLeft == 4)
        #expect(play.report == play.level.startReport)
        try play.redo()
        #expect(play.fingerprint == f1)
        try play.redo()
        #expect(play.fingerprint == f2)
        try play.redo()
        #expect(play.fingerprint == f3)
        #expect(play.stage == .failed)
        try play.undo()
        try Self.act(&play, .size(32))
        #expect(!play.canRedo)
        #expect(throws: ApsidesWorkshopError.action("redo")) { try play.redo() }
        try Self.act(&play, .periapsis(0, 1))
        #expect(play.actionsLeft == 0)
        try Self.act(&play, .play)
        #expect(play.stage == .won)
        let won: Play = play
        #expect(throws: ApsidesWorkshopError.stage) { try play.undo() }
        #expect(play == won)
        let replayed: Play = try Play.replay(level: play.level, records: play.records)
        #expect(replayed == play)
    }

    @Test func fiveHundredSeededTracesReplayIdentically() throws {
        let fixtures: [ApsidesWorkshopFixture] = ApsidesWorkshopFixture.all(count: 25)
        var random = SeededRandom(seed: Self.seed)
        var outcomes: [ApsidesWorkshopStage: Int] = [:]
        var refused: Int = 0
        for trace in 0..<500 {
            let fixture: ApsidesWorkshopFixture = fixtures[trace % fixtures.count]
            let level: Level = fixture.level
            var play: Play = try Self.playing(level)
            let steps: Int = random.int(1...10)
            for _ in 0..<steps {
                let roll: Int = random.int(0...11)
                if roll < 7 {
                    let action: Action
                    if random.int(0...1) == 0 {
                        action = .periapsis(random.int(-1...16), random.int(-1...24))
                    } else {
                        action = .size(random.int(7...49))
                    }
                    let before: String = play.fingerprint
                    let spent: Int = play.actionsSpent
                    do {
                        try Self.act(&play, action)
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
                    try? Self.act(&play, .play)
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

    /// Checks that a trace with another seed, a broken chain, a wrong index, another schema or a forged next
    /// fingerprint is refused.
    static func expectTamperedRefused(level: Level, records: [ApsidesWorkshopRecord]) throws {
        let last: Int = records.count - 1
        let r: ApsidesWorkshopRecord = records[last]
        var seed: [ApsidesWorkshopRecord] = records
        seed[last] = ApsidesWorkshopRecord(schema: r.schema, seed: r.seed + 1, index: r.index, kind: r.kind,
                                           action: r.action, previous: r.previous, next: r.next)
        #expect(throws: ApsidesWorkshopError.malformed("seed \(last)")) {
            _ = try Play.replay(level: level, records: seed)
        }
        var chain: [ApsidesWorkshopRecord] = records
        chain[last] = ApsidesWorkshopRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                            action: r.action, previous: "broken", next: r.next)
        #expect(throws: ApsidesWorkshopError.malformed("chain \(last)")) {
            _ = try Play.replay(level: level, records: chain)
        }
        var index: [ApsidesWorkshopRecord] = records
        index[last] = ApsidesWorkshopRecord(schema: r.schema, seed: r.seed, index: r.index + 1, kind: r.kind,
                                            action: r.action, previous: r.previous, next: r.next)
        #expect(throws: ApsidesWorkshopError.malformed("index \(last)")) {
            _ = try Play.replay(level: level, records: index)
        }
        var schema: [ApsidesWorkshopRecord] = records
        schema[last] = ApsidesWorkshopRecord(schema: 2, seed: r.seed, index: r.index, kind: r.kind,
                                             action: r.action, previous: r.previous, next: r.next)
        #expect(throws: ApsidesWorkshopError.malformed("schema \(last)")) {
            _ = try Play.replay(level: level, records: schema)
        }
        var next: [ApsidesWorkshopRecord] = records
        next[last] = ApsidesWorkshopRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                           action: r.action, previous: r.previous, next: "forged")
        #expect(throws: ApsidesWorkshopError.malformed("record \(last)")) {
            _ = try Play.replay(level: level, records: next)
        }
    }
}
