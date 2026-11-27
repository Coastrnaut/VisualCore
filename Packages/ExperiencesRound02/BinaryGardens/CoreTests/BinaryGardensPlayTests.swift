// BinaryGardensPlayTests — feature 501 (R02-G21-01) T-R02G2101-004 (FR-R02G2101-005 … 008, 011, 014;
// SC-R02G2101-001, 002, 004; clarification Q5). The play of a Binary Gardens level: the full stage table of
// `handle(_:)` with the recorded event kinds (showResult included); the 500 fixtures' known actions keep the report
// equal to the sky's report after every arrangement action and win on the run (SC-R02G2101-001); each failure named on
// the run (`frozen`, `scorched`, `unstable`, `wilted`, `bleached`) with its words; the budget refusal on the exact action
// with the run still allowed; the validation order stage, stale, action (a star, ring, phase, luminosity or tilt out of
// range, a locked control, an unchanged value, a separation breaker), budget, with every refusal reachable, spending
// nothing and leaving the play unchanged; the fingerprint is the SHA-256 of its canonical text; undo restores exact
// fingerprints, undo from failed returns to playing with the arrangement before the run (recorded) and a redo re-runs
// it to the same failure, a won run is final, nothing but resume is accepted while paused, a new action clears redo;
// 500 seeded traces replay to the same records, fingerprints and outcome, and tampered traces are refused. Explicit
// types, plain loops, short traces; each test well under 10 s; no clock.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import BinaryGardensCore

@Suite struct BinaryGardensPlayTests {
    typealias Play = BinaryGardensPlay
    typealias Action = BinaryGardensAction
    typealias Level = BinaryGardensLevel
    typealias Star = BinaryGardensStar
    typealias World = BinaryGardensWorld
    typealias Arrangement = BinaryGardensArrangement
    typealias Record = BinaryGardensRecord
    typealias Sky = BinaryGardensSky

    /// The test seed of the feature.
    static let seed: UInt64 = 2_501

    /// The 500 fixtures of the feature seed, built once; only the known-actions test needs all 500.
    static let fixtures: [BinaryGardensFixture] = BinaryGardensFixture.all(count: 500)

    /// The first 25 fixtures, built on their own so the shorter tests need not wait for all 500.
    static let few: [BinaryGardensFixture] = BinaryGardensFixture.all(count: 25)

    /// Applies `action` with the current fingerprint.
    static func act(_ play: inout Play, _ action: Action) throws(BinaryGardensError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the level has a tutorial).
    static func playing(_ level: Level) throws(BinaryGardensError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A world at radius 30 held still with the given bounds, window and bloom band.
    static func world(lethalLow: Int = 0, comfortLow: Int = 1, comfortHigh: Int = 199_999,
                      lethalHigh: Int = 200_000, window: Int = 1, bloomLow: Int = 9_600_000,
                      bloomHigh: Int = 9_600_000) -> World {
        World(radius: 30, phase: 0, speed: 0, lethalLow: lethalLow, comfortLow: comfortLow, comfortHigh: comfortHigh,
              lethalHigh: lethalHigh, window: window, bloomLow: bloomLow, bloomHigh: bloomHigh)
    }

    /// The hand level: rings 2, 10 and 12 units; star speed 1; luminosities 4 and 16; star 1 on ring 1 at phase 0
    /// with luminosity 4 (ring and luminosity adjustable, phase locked); star 2 on ring 2 at phase 24 with luminosity
    /// 16 (ring and phase adjustable, luminosity locked); tilt 0 of 3; minimum separation 9 (the stars start about 12
    /// units apart; star 2 at phase 0 would be 8 units from star 1); clamp 1; one world (by default never blooming, so
    /// every run fails `wilted`); tolerance 0.
    static func hand(worlds: [World] = [world()], budget: Int = 3, tutorial: Bool = false, maxTilt: Int = 3,
                     id: String = "hand", seed: UInt64 = 7) throws(BinaryGardensError) -> Level {
        let stars: [Star] = [
            Star(ring: 0, phase: 0, luminosity: 0, ringAdjustable: true, phaseAdjustable: false,
                 luminosityAdjustable: true),
            Star(ring: 1, phase: 24, luminosity: 1, ringAdjustable: true, phaseAdjustable: true,
                 luminosityAdjustable: false),
        ]
        return try Level(id: id, seed: seed, difficulty: 1, ringRadii: [2, 10, 12], starSpeed: 1,
                         luminosityLevels: [4, 16], stars: stars, maxTilt: maxTilt, startTilt: 0,
                         minimumSeparation: 9, clampRadius: 1, worlds: worlds, lethalTolerance: 0, budget: budget,
                         tutorial: tutorial)
    }

    /// The play of `level` right after `begin`, then the run; the arrangement and the actions spent are unchanged.
    static func ran(_ level: Level) throws -> Play {
        var play: Play = try playing(level)
        let arrangement: Arrangement = play.arrangement
        try act(&play, .run)
        #expect(play.arrangement == arrangement)
        #expect(play.actionsSpent == 0)
        return play
    }

    /// The kinds of `play`'s records.
    static func kinds(_ play: Play) -> [Record.Kind] { play.records.map(\.kind) }

    @Test func theStageTableAcceptsOnlyItsEvents() throws {
        let events: [BinaryGardensEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]
        var plain: Play = Play(level: try Self.hand())
        #expect(plain.stage == .loading && plain.arrangement == plain.level.start)
        for event in events where event != .begin {
            #expect(throws: BinaryGardensError.stage) { try plain.handle(event) }
        }
        #expect(throws: BinaryGardensError.stage) { try Self.act(&plain, .run) }
        #expect(throws: BinaryGardensError.stage) { try plain.undo() }
        try plain.handle(.begin)
        #expect(plain.stage == .playing)
        var taught: Play = Play(level: try Self.hand(tutorial: true))
        try taught.handle(.begin)
        #expect(taught.stage == .tutorial)
        for event in events where event != .dismissTutorial {
            #expect(throws: BinaryGardensError.stage) { try taught.handle(event) }
        }
        #expect(throws: BinaryGardensError.stage) { try Self.act(&taught, .tilt(step: 1)) }
        try taught.handle(.dismissTutorial)
        #expect(taught.stage == .playing)
        for event in events where event != .pause {
            #expect(throws: BinaryGardensError.stage) { try plain.handle(event) }
        }
        try Self.act(&plain, .tilt(step: 1))
        try plain.handle(.pause)
        #expect(plain.stage == .paused)
        for event in events where event != .resume {
            #expect(throws: BinaryGardensError.stage) { try plain.handle(event) }
        }
        // Nothing but resume while paused: no action, no run, no undo, no redo.
        let paused: Play = plain
        #expect(throws: BinaryGardensError.stage) { try Self.act(&plain, .tilt(step: 2)) }
        #expect(throws: BinaryGardensError.stage) { try Self.act(&plain, .run) }
        #expect(throws: BinaryGardensError.stage) { try plain.undo() }
        #expect(throws: BinaryGardensError.stage) { try plain.redo() }
        #expect(plain == paused && !plain.canUndo && !plain.canRedo)
        try plain.handle(.resume)
        #expect(plain.stage == .playing && plain.canUndo)
        #expect(Self.kinds(plain) == [.begin, .tilt, .pause, .resume])
        #expect(Self.kinds(taught) == [.begin, .dismissTutorial])
        for (position, record) in plain.records.enumerated() {
            #expect(record.index == position && record.schema == 1 && record.levelSeed == 7)
            #expect((record.kind == .tilt) == (record.action != nil))
            if position > 0 { #expect(record.previous == plain.records[position - 1].next) }
        }
        try Self.act(&plain, .run)
        #expect(plain.stage == .failed)
        for event in events where event != .showResult {
            #expect(throws: BinaryGardensError.stage) { try plain.handle(event) }
        }
        #expect(throws: BinaryGardensError.stage) { try plain.redo() }
        #expect(throws: BinaryGardensError.stage) { try Self.act(&plain, .tilt(step: 2)) }
        try plain.handle(.showResult)
        #expect(plain.stage == .result)
        #expect(Self.kinds(plain).suffix(2) == [.run, .showResult])
        #expect(plain.records.last?.next == plain.fingerprint)
        for event in events {
            #expect(throws: BinaryGardensError.stage) { try plain.handle(event) }
        }
        #expect(throws: BinaryGardensError.stage) { try plain.undo() }
        #expect(throws: BinaryGardensError.stage) { try Self.act(&plain, .run) }
        #expect(BinaryGardensStage.allCases.count == 7 && Record.Kind.allCases.count == 12)
    }

    @Test func theFixturesKnownActionsWinOnTheRun() throws {
        #expect(Self.fixtures.count == 500)
        for fixture in Self.fixtures {
            var play: Play = try Self.playing(fixture.level)
            #expect(!play.report.wins)
            for action in fixture.actions {
                try Self.act(&play, action)
                if action != .run {
                    #expect(play.report == Sky.report(fixture.level, arrangement: play.arrangement))
                    #expect(play.stage == .playing)
                }
            }
            #expect(play.stage == .won && play.failure == nil && play.arrangement == fixture.winning)
            #expect(play.actionsSpent == fixture.actions.count - 1 && play.actionsLeft >= 0)
            #expect(throws: BinaryGardensError.stage) { try play.undo() }
            try play.handle(.showResult)
            #expect(play.stage == .result)
        }
    }

    @Test func eachFailureIsNamedOnTheRun() throws {
        let cases: [(World, BinaryGardensFailure)] = [
            (Self.world(lethalLow: 199_997, comfortLow: 199_998, comfortHigh: 199_999, bloomLow: 0),
             .frozen(world: 0, tick: 1)),
            (Self.world(comfortHigh: 2, lethalHigh: 3, bloomLow: 0), .scorched(world: 0, tick: 1)),
            (Self.world(comfortHigh: 2, window: 5, bloomLow: 0), .unstable(world: 0, window: 0, required: 5)),
        ]
        for (world, failure) in cases {
            let play: Play = try Self.ran(try Self.hand(worlds: [world]))
            #expect(play.stage == .failed && play.failure == failure)
            #expect(play.records.last?.kind == .run && play.records.last?.action == .run)
        }
        let wilted: Play = try Self.ran(try Self.hand())
        let integral: Int = wilted.report.worlds[0].integral
        #expect(wilted.failure == .wilted(world: 0, integral: integral, low: 9_600_000, high: 9_600_000))
        #expect(wilted.level.failureDescription(wilted.failure!)
            == "world 1 wilted: integral " + Level.grouped(integral) + " below the bloom band 9 600 000 … 9 600 000")
        let bleached: Play = try Self.ran(try Self.hand(worlds: [Self.world(bloomLow: 0, bloomHigh: 0)]))
        #expect(bleached.failure == .bleached(world: 0, integral: integral, low: 0, high: 0))
        // Two worlds: the second freezes while the first only wilts; the lethal walk names world 2 first.
        let two: Play = try Self.ran(try Self.hand(worlds: [
            Self.world(),
            Self.world(lethalLow: 199_997, comfortLow: 199_998, comfortHigh: 199_999, bloomLow: 0),
        ]))
        #expect(two.failure == .frozen(world: 1, tick: 1))
        #expect(two.level.failureDescription(two.failure!) == "world 2 froze at tick 1")
        // A fixture: running the start fails with the report's failure; undoing it and the known actions win.
        for fixture in Self.few {
            var play: Play = try Self.playing(fixture.level)
            let predicted: BinaryGardensFailure? = play.report.failure
            try Self.act(&play, .run)
            #expect(play.stage == .failed && play.failure == predicted && predicted != nil)
            try play.undo()
            #expect(play.stage == .playing && play.failure == nil && play.arrangement == fixture.level.start)
            for action in fixture.actions { try Self.act(&play, action) }
            #expect(play.stage == .won)
        }
    }

    @Test func theBudgetRefusesTheExactActionAndTheRunIsStillAllowed() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 2))
        try Self.act(&play, .tilt(step: 1))
        #expect(play.actionsLeft == 1)
        try Self.act(&play, .ring(star: 0, index: 1))
        #expect(play.actionsLeft == 0 && play.actionsSpent == 2)
        let spent: Play = play
        #expect(throws: BinaryGardensError.budget) { try Self.act(&play, .tilt(step: 2)) }
        #expect(throws: BinaryGardensError.budget) { try Self.act(&play, .luminosity(star: 0, index: 1)) }
        #expect(play == spent)
        // An invalid action with no action left is refused for the action first.
        #expect(throws: BinaryGardensError.action("unchanged")) { try Self.act(&play, .tilt(step: 1)) }
        try Self.act(&play, .run)
        #expect(play.stage == .failed && play.actionsSpent == 2)
        // Undo of the run and of the last action refunds it.
        try play.undo()
        try play.undo()
        #expect(play.actionsLeft == 1 && play.arrangement.rings == [0, 1])
        for fixture in Self.few {
            var p: Play = try Self.playing(fixture.level)
            let known: [Action] = Array(fixture.actions.dropLast())
            for action in known { try Self.act(&p, action) }
            #expect(p.actionsLeft == fixture.level.budget - known.count)
        }
    }

    @Test func everyRefusalReasonIsReachableInOrder() throws {
        let level: Level = try Self.hand()
        var loading: Play = Play(level: level)
        // Stage before stale: a stale previous fingerprint while loading is refused for the stage.
        #expect(throws: BinaryGardensError.stage) {
            try loading.apply(.tilt(step: 1), expecting: String(repeating: "0", count: 64))
        }
        var play: Play = try Self.playing(level)
        let before: Play = play
        // Stale before action: an invalid action with a stale fingerprint is refused stale.
        #expect(throws: BinaryGardensError.stale) {
            try play.apply(.tilt(step: 9), expecting: String(repeating: "0", count: 64))
        }
        #expect(throws: BinaryGardensError.stale) { try play.apply(.run, expecting: "stale") }
        let cases: [(Action, String)] = [
            (.ring(star: 2, index: 0), "star out of range"),
            (.ring(star: -1, index: 0), "star out of range"),
            (.phase(star: 2, step: 0), "star out of range"),
            (.luminosity(star: 5, index: 0), "star out of range"),
            (.ring(star: 0, index: 3), "ring out of range"),
            (.ring(star: 0, index: -1), "ring out of range"),
            (.phase(star: 1, step: 48), "phase out of range"),
            (.phase(star: 1, step: -1), "phase out of range"),
            (.luminosity(star: 0, index: 2), "luminosity out of range"),
            (.tilt(step: 4), "tilt out of range"),
            (.tilt(step: -1), "tilt out of range"),
            (.phase(star: 0, step: 5), "locked"),
            (.luminosity(star: 1, index: 0), "locked"),
            (.ring(star: 0, index: 0), "unchanged"),
            (.phase(star: 1, step: 24), "unchanged"),
            (.luminosity(star: 0, index: 0), "unchanged"),
            (.tilt(step: 0), "unchanged"),
            (.phase(star: 1, step: 0), "separation"),
            // Range before locked: a locked phase out of range is refused for the range.
            (.phase(star: 0, step: 48), "phase out of range"),
            // Locked before unchanged: star 1's locked phase set to itself.
            (.phase(star: 0, step: 0), "locked"),
        ]
        for (action, name) in cases {
            #expect(throws: BinaryGardensError.action(name), "\(action)") { try Self.act(&play, action) }
        }
        #expect(play == before && play.records.count == 1)
        // A phase that keeps the separation is accepted: star 2 to phase 12 (perpendicular, about 10.2 units).
        try Self.act(&play, .phase(star: 1, step: 12))
        #expect(play.actionsSpent == 1)
        // The tilt is locked when T_max = 0.
        var flat: Play = try Self.playing(try Self.hand(maxTilt: 0))
        #expect(throws: BinaryGardensError.action("locked")) { try Self.act(&flat, .tilt(step: 0)) }
        #expect(throws: BinaryGardensError.action("tilt out of range")) { try Self.act(&flat, .tilt(step: 1)) }
        // Budget last; undo and redo with nothing to do.
        var empty: Play = try Self.playing(level)
        #expect(throws: BinaryGardensError.action("undo")) { try empty.undo() }
        #expect(throws: BinaryGardensError.action("redo")) { try empty.redo() }
        var codes: Set<String> = []
        for error: BinaryGardensError in [.level("x"), .action("x"), .budget, .stage, .stale, .newerSchema(2),
                                          .malformed("x")] { codes.insert(error.reasonCode) }
        #expect(codes == ["r02-g21.level", "r02-g21.action", "r02-g21.budget", "r02-g21.stage", "r02-g21.stale",
                          "r02-g21.newer-schema", "r02-g21.malformed"])
    }

    @Test func theFingerprintIsTheHashOfItsCanonicalText() throws {
        var play: Play = try Self.playing(try Self.hand())
        let text: String = "{\"actions\":0,\"failure\":\"none\",\"level\":\"\(play.level.fingerprint)\","
            + "\"luminosities\":[0,1],\"phases\":[0,24],\"rings\":[0,1],\"schema\":1,\"stage\":\"playing\",\"tilt\":0}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text.utf8)))
        try Self.act(&play, .tilt(step: 2))
        try Self.act(&play, .run)
        let integral: Int = play.report.worlds[0].integral
        let failed: String = "{\"actions\":1,\"failure\":\"wilted 0 \(integral) 9600000 9600000\",\"level\":\""
            + play.level.fingerprint + "\",\"luminosities\":[0,1],\"phases\":[0,24],\"rings\":[0,1],\"schema\":1,"
            + "\"stage\":\"failed\",\"tilt\":2}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(failed.utf8)))
        #expect(Play.text(.frozen(world: 1, tick: 50)) == "frozen 1 50")
        #expect(Play.text(.scorched(world: 0, tick: 3)) == "scorched 0 3")
        #expect(Play.text(.unstable(world: 2, window: 7, required: 9)) == "unstable 2 7 9")
        #expect(Play.text(.bleached(world: 0, integral: 5, low: 1, high: 4)) == "bleached 0 5 1 4")
        // Every stage and every arrangement change gives another fingerprint.
        var seen: Set<String> = []
        var p: Play = Play(level: try Self.hand(tutorial: true))
        seen.insert(p.fingerprint)
        try p.handle(.begin)
        seen.insert(p.fingerprint)
        try p.handle(.dismissTutorial)
        seen.insert(p.fingerprint)
        try p.handle(.pause)
        seen.insert(p.fingerprint)
        try p.handle(.resume)
        try Self.act(&p, .luminosity(star: 0, index: 1))
        seen.insert(p.fingerprint)
        #expect(seen.count == 5)
    }

    @Test func undoRestoresExactFingerprintsAndRedoReapplies() throws {
        var play: Play = try Self.playing(try Self.hand())
        var fingerprints: [String] = [play.fingerprint]
        for action: Action in [.tilt(step: 1), .ring(star: 1, index: 2), .luminosity(star: 0, index: 1)] {
            try Self.act(&play, action)
            fingerprints.append(play.fingerprint)
        }
        try Self.act(&play, .run)
        let failure: BinaryGardensFailure? = play.failure
        let failedPrint: String = play.fingerprint
        #expect(play.stage == .failed && failure != nil && play.canUndo && !play.canRedo)
        // Undo from failed: playing with the arrangement before the run, actions spent unchanged, recorded.
        try play.undo()
        #expect(play.stage == .playing && play.failure == nil && play.fingerprint == fingerprints[3])
        #expect(play.actionsSpent == 3 && play.records.last?.kind == .undo && play.canRedo)
        // Redo re-runs the run and ends failed again with the same failure.
        try play.redo()
        #expect(play.stage == .failed && play.failure == failure && play.fingerprint == failedPrint)
        try play.undo()
        for index in stride(from: 2, through: 0, by: -1) {
            try play.undo()
            #expect(play.fingerprint == fingerprints[index])
            #expect(play.report == Sky.report(play.level, arrangement: play.arrangement))
        }
        #expect(throws: BinaryGardensError.action("undo")) { try play.undo() }
        for index in 1...3 {
            try play.redo()
            #expect(play.fingerprint == fingerprints[index])
        }
        try play.undo()
        // A new action clears the redo stack.
        try Self.act(&play, .ring(star: 0, index: 1))
        #expect(!play.canRedo)
        #expect(throws: BinaryGardensError.action("redo")) { try play.redo() }
        // A won run is final.
        let fixture: BinaryGardensFixture = Self.few[0]
        var won: Play = try Self.playing(fixture.level)
        for action in fixture.actions { try Self.act(&won, action) }
        #expect(won.stage == .won && !won.canUndo)
        let final: Play = won
        #expect(throws: BinaryGardensError.stage) { try won.undo() }
        #expect(throws: BinaryGardensError.stage) { try won.redo() }
        #expect(won == final)
    }

    /// A random action of `level`, legal or not (stars −1 … 2, indices −1 … count, phases −1 … 48, tilts −1 … T + 1),
    /// with a run one time in nine.
    static func randomAction(_ random: inout SeededRandom, level: Level) -> Action {
        let star: Int = random.int(0...9) == 0 ? random.int(-1...2) : random.int(0...1)
        switch random.int(0...8) {
        case 0, 1: return .ring(star: star, index: random.int(-1...level.ringRadii.count))
        case 2, 3: return .phase(star: star, step: random.int(-1...48))
        case 4, 5: return .luminosity(star: star, index: random.int(-1...level.luminosityLevels.count))
        case 6, 7: return .tilt(step: random.int(-1...(level.maxTilt + 1)))
        default: return .run
        }
    }

    /// Plays a seeded trace of `steps` steps on `level` (actions, undo, redo, pause and resume, showResult), ignoring
    /// refusals.
    static func trace(_ random: inout SeededRandom, level: Level, steps: Int) throws -> Play {
        var play: Play = try playing(level)
        for _ in 0..<steps {
            switch random.int(0...11) {
            case 0: try? play.undo()
            case 1: try? play.redo()
            case 2: try? play.handle(.pause)
            case 3: try? play.handle(.resume)
            case 4: try? play.undo()
            default:
                let action: Action = randomAction(&random, level: level)
                try? play.apply(action, expecting: play.fingerprint)
            }
        }
        if play.stage == .won || play.stage == .failed, random.int(0...1) == 0 { try play.handle(.showResult) }
        return play
    }

    @Test func fiveHundredSeededTracesReplayIdentically() throws {
        var random = SeededRandom(seed: Self.seed)
        var ended: Int = 0
        var undone: Int = 0
        for index in 0..<500 {
            let fixture: BinaryGardensFixture = Self.few[index % Self.few.count]
            let play: Play = try Self.trace(&random, level: fixture.level, steps: 6 + index % 10)
            let replayed: Play = try Play.replay(level: fixture.level, records: play.records)
            #expect(replayed == play && replayed.fingerprint == play.fingerprint)
            #expect(replayed.records == play.records && replayed.stage == play.stage)
            let twice: Play = try Play.replay(level: fixture.level, records: play.records)
            #expect(twice == replayed)
            if play.stage == .won || play.stage == .failed || play.stage == .result { ended += 1 }
            if play.records.contains(where: { $0.kind == .undo }) { undone += 1 }
            if index < 60 { try Self.expectTamperedRefused(level: fixture.level, records: play.records) }
        }
        #expect(ended > 50 && undone > 50)
    }

    /// Whether `body` throws a `.malformed` refusal.
    static func isMalformed(_ body: () throws(BinaryGardensError) -> Void) -> Bool {
        do {
            try body()
            return false
        } catch {
            if case .malformed = error { return true }
            return false
        }
    }

    /// A tampered trace is refused: a record removed, an index, seed or schema changed, an action swapped, an event
    /// given an action, another level's play.
    static func expectTamperedRefused(level: Level, records: [Record]) throws {
        guard records.count >= 2 else { return }
        var removed: [Record] = records
        removed.remove(at: 0)
        #expect(Self.isMalformed { () throws(BinaryGardensError) in _ = try Play.replay(level: level, records: removed) })
        let r: Record = records[1]
        let index = Record(schema: r.schema, levelSeed: r.levelSeed, index: 5, kind: r.kind, action: r.action,
                           previous: r.previous, next: r.next)
        let seed = Record(schema: r.schema, levelSeed: r.levelSeed + 1, index: r.index, kind: r.kind, action: r.action,
                          previous: r.previous, next: r.next)
        let schema = Record(schema: 2, levelSeed: r.levelSeed, index: r.index, kind: r.kind, action: r.action,
                            previous: r.previous, next: r.next)
        let next = Record(schema: r.schema, levelSeed: r.levelSeed, index: r.index, kind: r.kind, action: r.action,
                          previous: r.previous, next: String(repeating: "f", count: 64))
        let kind = Record(schema: r.schema, levelSeed: r.levelSeed, index: r.index,
                          kind: r.action == nil ? .ring : .undo, action: r.action, previous: r.previous, next: r.next)
        for tampered in [index, seed, schema, next, kind] {
            var trace: [Record] = records
            trace[1] = tampered
            #expect(Self.isMalformed { () throws(BinaryGardensError) in _ = try Play.replay(level: level, records: trace) })
        }
        let other: Level = try Self.hand(id: "other", seed: level.seed)
        #expect(Self.isMalformed { () throws(BinaryGardensError) in _ = try Play.replay(level: other, records: records) })
    }
}
