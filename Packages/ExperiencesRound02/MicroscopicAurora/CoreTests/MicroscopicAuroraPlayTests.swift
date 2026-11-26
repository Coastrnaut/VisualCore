// MicroscopicAuroraPlayTests — feature 481 (R02-G19-01) T-R02G1901-004 (FR-R02G1901-006 … 009, 011;
// SC-R02G1901-001, 002; clarification Q5). The play of a Microscopic Aurora level: the full stage table of
// `handle(_:)` with the recorded event kinds; the fixtures' known actions keep the report equal to the dish's report
// after every placement and removal and win on the play; each failure named on a hand level (`exit`, `coherence`,
// `coverage`, `connectedness`); the budget refusal on the exact action with the play still allowed; the validation
// order stage, stale, action (a slot or strength out of range, an outside or occupied cell, unchanged, an empty slot),
// budget, with every refusal reachable, spending nothing and leaving the play unchanged; the fingerprint is the
// SHA-256 of its canonical text; undo restores exact fingerprints and refunds, undo from failed returns to playing
// (recorded), a won play is final, redo re-applies and a new action clears redo; 500 seeded traces replay to the same
// records, fingerprints and outcome, and tampered traces are refused. Explicit types, plain loops, short traces; each
// test well under 10 s; no clock.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import MicroscopicAuroraCore

struct MicroscopicAuroraPlayTests {
    typealias Play = MicroscopicAuroraPlay
    typealias Action = MicroscopicAuroraAction
    typealias Level = MicroscopicAuroraLevel
    typealias Well = MicroscopicAuroraWell
    typealias Cell = MicroscopicAuroraCell
    typealias Point = MicroscopicAuroraPoint
    typealias Swimmer = MicroscopicAuroraSwimmer

    /// The test seed of the feature.
    static let seed: UInt64 = 2_481

    /// The 500 fixtures of the feature seed, built once (≈ 3.7 s in debug).
    static let fixtures: [MicroscopicAuroraFixture] = MicroscopicAuroraFixture.all(count: 500)

    /// The first 25 fixtures, built on their own so the shorter tests need not wait for all 500.
    static let few: [MicroscopicAuroraFixture] = MicroscopicAuroraFixture.all(count: 25)

    /// Applies `action` with the current fingerprint.
    static func act(_ play: inout Play, _ action: Action) throws(MicroscopicAuroraError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the level has a tutorial).
    static func playing(_ level: Level) throws(MicroscopicAuroraError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A swimmer at (x, y) moving by (vx, vy) per tick.
    static func swimmer(_ x: Int, _ y: Int, _ vx: Int = 0, _ vy: Int = 0) -> Swimmer {
        Swimmer(position: Point(x: x, y: y), velocity: Point(x: vx, y: vy))
    }

    /// Four swimmers resting in row 12, column 12.
    static let resting: [Swimmer] = [swimmer(3082, 3082), swimmer(3100, 3100), swimmer(3082, 3100),
                                     swimmer(3100, 3082)]

    /// The far stencil: four cells around row 5, column 5, away from the dish centre.
    static let far: [Cell] = [Cell(row: 5, column: 5), Cell(row: 5, column: 6), Cell(row: 6, column: 5),
                              Cell(row: 6, column: 6)]

    /// A hand level of radius 10 and 120 ticks with weightless swarm rules (no swimmer accelerates without a well):
    /// threshold 1, coverage 500, the required coherence `coherence`, the coherence radius `kappa` cells. By default
    /// four swimmers rest in row 12, column 12 and the stencil is ``far`` (failing `coverage` 0 of 2).
    static func hand(swimmers: [Swimmer] = resting, stencil: [Cell] = far, kappa: Int = 2, coherence: Int = 2,
                     budget: Int = 2, tutorial: Bool = false,
                     id: String = "hand", seed: UInt64 = 7) throws(MicroscopicAuroraError) -> Level {
        let rules = MicroscopicAuroraSwarmRules(neighbourRadius: 2, separationRadius: 1, coherenceRadius: kappa,
                                                separationWeight: 0, alignmentWeight: 0, cohesionWeight: 0,
                                                maxAcceleration: 2, maxSpeed: 48)
        return try Level(id: id, seed: seed, difficulty: 1, radius: 10, length: 120, rules: rules, swimmers: swimmers,
                         stencil: stencil, threshold: 1, coverage: 500, coherence: coherence, wells: [nil, nil, nil],
                         budget: budget, tutorial: tutorial)
    }

    /// The well in row 12, column 12 (where the hand level's swimmers rest).
    static let centreWell: Well = Well(cell: Cell(row: 12, column: 12), strength: 2, sense: .clockwise)

    @Test func theStageTableAcceptsOnlyItsEvents() throws {
        let events: [MicroscopicAuroraEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]
        var plain: Play = Play(level: try Self.hand())
        #expect(plain.stage == .loading)
        #expect(plain.wells == [nil, nil, nil])
        for event in events where event != .begin {
            #expect(throws: MicroscopicAuroraError.stage) { try plain.handle(event) }
        }
        try plain.handle(.begin)
        #expect(plain.stage == .playing)
        var taught: Play = Play(level: try Self.hand(tutorial: true))
        try taught.handle(.begin)
        #expect(taught.stage == .tutorial)
        for event in events where event != .dismissTutorial {
            #expect(throws: MicroscopicAuroraError.stage) { try taught.handle(event) }
        }
        try taught.handle(.dismissTutorial)
        #expect(taught.stage == .playing)
        for event in events where event != .pause {
            #expect(throws: MicroscopicAuroraError.stage) { try plain.handle(event) }
        }
        try plain.handle(.pause)
        #expect(plain.stage == .paused)
        for event in events where event != .resume {
            #expect(throws: MicroscopicAuroraError.stage) { try plain.handle(event) }
        }
        try plain.handle(.resume)
        #expect(plain.stage == .playing)
        let kinds: [MicroscopicAuroraRecordKind] = [.begin, .pause, .resume]
        var recorded: [MicroscopicAuroraRecordKind] = []
        for record in plain.records { recorded.append(record.kind) }
        #expect(recorded == kinds)
        var taughtKinds: [MicroscopicAuroraRecordKind] = []
        for record in taught.records { taughtKinds.append(record.kind) }
        #expect(taughtKinds == [.begin, .dismissTutorial])
        try Self.act(&plain, .play)
        #expect(plain.stage == .failed)
        for event in events where event != .showResult {
            #expect(throws: MicroscopicAuroraError.stage) { try plain.handle(event) }
        }
        let count: Int = plain.records.count
        try plain.handle(.showResult)
        #expect(plain.stage == .result)
        #expect(plain.records.count == count)
        for event in events {
            #expect(throws: MicroscopicAuroraError.stage) { try plain.handle(event) }
        }
        #expect(throws: MicroscopicAuroraError.stage) { try Self.act(&plain, .play) }
        #expect(throws: MicroscopicAuroraError.stage) { try plain.undo() }
        #expect(throws: MicroscopicAuroraError.stage) { try plain.redo() }
    }

    @Test func theFixturesKnownActionsWinOnThePlay() throws {
        let fixtures: [MicroscopicAuroraFixture] = Self.fixtures
        #expect(fixtures.count == 500)
        for (position, fixture) in fixtures.enumerated() {
            var play: Play = try Self.playing(fixture.level)
            #expect(play.wells == fixture.level.wells)
            #expect(!play.report.wins)
            var spent: Int = 0
            for action in fixture.actions {
                try Self.act(&play, action)
                if action != .play {
                    spent += 1
                    #expect(play.stage == .playing)
                    #expect(play.actionsSpent == spent)
                    #expect(play.actionsLeft == fixture.level.budget - spent)
                    if position % 25 == 0 {
                        #expect(play.report == MicroscopicAuroraDish.report(fixture.level, wells: play.placedWells))
                    }
                }
            }
            #expect(play.wells == fixture.winning)
            #expect(play.stage == .won)
            #expect(play.failure == nil)
            #expect(play.actionsSpent == spent)
            #expect(play.records.last?.kind == .play)
            #expect(play.records.last?.next == play.fingerprint)
        }
    }

    /// The play of `level` right after `begin`, then the play; the wells and the actions spent are unchanged.
    static func played(_ level: Level) throws -> Play {
        var play: Play = try playing(level)
        let wells: [Well?] = play.wells
        try act(&play, .play)
        #expect(play.wells == wells)
        #expect(play.actionsSpent == 0)
        return play
    }

    @Test func eachFailureIsNamedOnThePlay() throws {
        // Swimmer 3 starts 10 units inside the rim moving outward by 20: it leaves at tick 1.
        let exit: Play = try Self.played(try Self.hand(swimmers: [Self.swimmer(4072, 3072), Self.swimmer(4072, 3172),
                                                                  Self.swimmer(4172, 3072),
                                                                  Self.swimmer(5622, 3072, 20, 0)], kappa: 8))
        // Two pairs 400 units apart part by 80 a tick: 560 > 512 (two cells) at tick 2, leaving groups of 2 < 3.
        let parting: [Swimmer] = [Self.swimmer(2872, 3072, -40, 0), Self.swimmer(2872, 3122, -40, 0),
                                  Self.swimmer(3272, 3072, 40, 0), Self.swimmer(3272, 3122, 40, 0)]
        let coherence: Play = try Self.played(try Self.hand(swimmers: parting, coherence: 3))
        let coverage: Play = try Self.played(try Self.hand())
        // Two resting pairs light row 12, columns 12 and 14: half the stencil, in two groups.
        let pairs: [Swimmer] = [Self.swimmer(3082, 3082), Self.swimmer(3100, 3100), Self.swimmer(3594, 3082),
                                Self.swimmer(3610, 3100)]
        let split: [Cell] = [Cell(row: 5, column: 5), Cell(row: 5, column: 6), Cell(row: 12, column: 12),
                             Cell(row: 12, column: 14)]
        let connectedness: Play = try Self.played(try Self.hand(swimmers: pairs, stencil: split))
        let cases: [(Play, MicroscopicAuroraFailure, String)] = [
            (exit, .exit(swimmer: 3, tick: 1), "exit"),
            (coherence, .coherence(tick: 2, group: 2), "coherence"),
            (coverage, .coverage(lit: 0, needed: 2), "coverage"),
            (connectedness, .connectedness(cell: Cell(row: 12, column: 14)), "connectedness"),
        ]
        for (play, failure, code) in cases {
            #expect(play.stage == .failed)
            #expect(play.failure == failure)
            #expect(play.failure?.code == code)
            #expect(play.failure == play.report.failure)
        }
        let fixture: MicroscopicAuroraFixture = Self.few[0]
        var won: Play = try Self.playing(fixture.level)
        for action in fixture.actions { try Self.act(&won, action) }
        #expect(won.stage == .won)
        #expect(won.failure == nil)
    }

    @Test func theBudgetRefusesTheExactActionAndThePlayIsStillAllowed() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 1))
        try Self.act(&play, .place(slot: 0, well: Self.centreWell))
        #expect(play.actionsLeft == 0)
        let before: Play = play
        let other: Well = Well(cell: Cell(row: 10, column: 10), strength: 1, sense: .counterclockwise)
        #expect(throws: MicroscopicAuroraError.budget) { try Self.act(&play, .place(slot: 1, well: other)) }
        #expect(throws: MicroscopicAuroraError.budget) { try Self.act(&play, .remove(slot: 0)) }
        #expect(play == before)
        #expect(MicroscopicAuroraError.budget.reasonCode == "r02-g19.budget")
        try Self.act(&play, .play)
        #expect(play.stage == .failed)
        #expect(play.failure != nil)
        #expect(play.failure == play.report.failure)
        // A fixture whose budget equals its known placements: the extra placement is refused, the play still wins.
        var found: Bool = false
        for fixture in Self.few where fixture.level.budget == fixture.actions.count - 1 {
            var exact: Play = try Self.playing(fixture.level)
            for action in fixture.actions where action != .play { try Self.act(&exact, action) }
            #expect(exact.actionsLeft == 0)
            let spent: Play = exact
            #expect(throws: MicroscopicAuroraError.budget) { try Self.act(&exact, .remove(slot: 0)) }
            #expect(exact == spent)
            try Self.act(&exact, .play)
            #expect(exact.stage == .won)
            found = true
            break
        }
        #expect(found)
    }

    @Test func everyRefusalReasonIsReachableInOrder() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 2))
        let start: Play = play
        let c: Cell = Self.centreWell.cell
        let refusals: [(Action, MicroscopicAuroraError)] = [
            (.place(slot: 3, well: Self.centreWell), .action("slot out of range")),
            (.place(slot: -1, well: Self.centreWell), .action("slot out of range")),
            (.place(slot: 0, well: Well(cell: c, strength: 0, sense: .clockwise)), .action("strength out of range")),
            (.place(slot: 0, well: Well(cell: c, strength: 5, sense: .clockwise)), .action("strength out of range")),
            (.place(slot: 0, well: Well(cell: Cell(row: 0, column: 0), strength: 1, sense: .clockwise)),
             .action("outside cell")),
            (.place(slot: 0, well: Well(cell: Cell(row: 24, column: 12), strength: 1, sense: .clockwise)),
             .action("outside cell")),
            (.place(slot: 0, well: Well(cell: Cell(row: 12, column: -1), strength: 1, sense: .clockwise)),
             .action("outside cell")),
            (.remove(slot: 0), .action("empty slot")),
            (.remove(slot: 3), .action("slot out of range")),
            (.remove(slot: -1), .action("slot out of range")),
        ]
        for (action, error) in refusals {
            #expect(throws: error) { try Self.act(&play, action) }
            #expect(play == start)
            #expect(throws: MicroscopicAuroraError.stale) { try play.apply(action, expecting: "stale") }
            #expect(play == start)
        }
        #expect(throws: MicroscopicAuroraError.stale) { try play.apply(.play, expecting: "stale") }
        #expect(throws: MicroscopicAuroraError.action("undo")) { try play.undo() }
        #expect(throws: MicroscopicAuroraError.action("redo")) { try play.redo() }
        #expect(play == start)
        try Self.act(&play, .place(slot: 0, well: Self.centreWell))
        let placed: Play = play
        #expect(throws: MicroscopicAuroraError.action("occupied cell")) {
            try Self.act(&play, .place(slot: 1, well: Well(cell: c, strength: 1, sense: .counterclockwise)))
        }
        #expect(throws: MicroscopicAuroraError.action("unchanged")) {
            try Self.act(&play, .place(slot: 0, well: Self.centreWell))
        }
        #expect(play == placed)
        // The slot's own cell is not occupied: a change of strength on it is accepted.
        try Self.act(&play, .place(slot: 0, well: Well(cell: c, strength: 3, sense: .clockwise)))
        #expect(play.actionsLeft == 0)
        let spent: Play = play
        // The action check comes before the budget, the budget after it.
        #expect(throws: MicroscopicAuroraError.action("occupied cell")) {
            try Self.act(&play, .place(slot: 2, well: Self.centreWell))
        }
        #expect(throws: MicroscopicAuroraError.action("empty slot")) { try Self.act(&play, .remove(slot: 2)) }
        #expect(throws: MicroscopicAuroraError.budget) { try Self.act(&play, .remove(slot: 0)) }
        #expect(play == spent)
        // The stage comes first, even with a stale fingerprint.
        try play.handle(.pause)
        let paused: Play = play
        #expect(throws: MicroscopicAuroraError.stage) { try play.apply(.remove(slot: 9), expecting: "stale") }
        #expect(throws: MicroscopicAuroraError.stage) { try Self.act(&play, .play) }
        #expect(play == paused)
        try play.handle(.resume)
        var loading: Play = Play(level: try Self.hand())
        #expect(throws: MicroscopicAuroraError.stage) { try Self.act(&loading, .play) }
        #expect(throws: MicroscopicAuroraError.stage) { try loading.undo() }
        #expect(throws: MicroscopicAuroraError.stage) { try loading.redo() }
        let fixture: MicroscopicAuroraFixture = Self.few[1]
        var winning: Play = try Self.playing(fixture.level)
        for action in fixture.actions { try Self.act(&winning, action) }
        #expect(winning.stage == .won)
        #expect(throws: MicroscopicAuroraError.stage) { try winning.undo() }
        #expect(throws: MicroscopicAuroraError.stage) { try winning.redo() }
        #expect(throws: MicroscopicAuroraError.stage) { try Self.act(&winning, .play) }
        #expect(!winning.canUndo)
        // A record of another level (another seed) is refused.
        let failed: Play = try Self.played(try Self.hand())
        #expect(throws: MicroscopicAuroraError.malformed("seed 0")) {
            _ = try Play.replay(level: try Self.hand(seed: 8), records: failed.records)
        }
        // A trace of another level with the same seed breaks the chain at once.
        let twin: Level = try Self.hand(budget: 3, id: "twin")
        #expect(throws: MicroscopicAuroraError.malformed("chain 0")) {
            _ = try Play.replay(level: twin, records: failed.records)
        }
        let codes: [String] = [MicroscopicAuroraError.action("x").reasonCode, MicroscopicAuroraError.stage.reasonCode,
                               MicroscopicAuroraError.stale.reasonCode,
                               MicroscopicAuroraError.malformed("x").reasonCode]
        #expect(codes == ["r02-g19.action", "r02-g19.stage", "r02-g19.stale", "r02-g19.malformed"])
    }

    @Test func theFingerprintIsTheHashOfItsCanonicalText() throws {
        let level: Level = try Self.hand()
        var play: Play = try Self.playing(level)
        let text0: String = "{\"actions\":0,\"failure\":\"none\",\"level\":\"" + level.fingerprint
            + "\",\"schema\":1,\"stage\":\"playing\",\"wells\":[\"none\",\"none\",\"none\"]}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text0.utf8)))
        let well: Well = Well(cell: Cell(row: 7, column: 12), strength: 3, sense: .counterclockwise)
        try Self.act(&play, .place(slot: 1, well: well))
        try Self.act(&play, .play)
        #expect(play.stage == .failed)
        let failure: String = Play.text(play.failure)
        let text1: String = "{\"actions\":1,\"failure\":\"" + failure + "\",\"level\":\"" + level.fingerprint
            + "\",\"schema\":1,\"stage\":\"failed\",\"wells\":[\"none\",\"7 12 3 counterclockwise\",\"none\"]}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text1.utf8)))
        #expect(Play.text(.exit(swimmer: 3, tick: 41)) == "exit 3 41")
        #expect(Play.text(.coherence(tick: 88, group: 3)) == "coherence 88 3")
        #expect(Play.text(.coverage(lit: 30, needed: 32)) == "coverage 30 32")
        #expect(Play.text(.connectedness(cell: Cell(row: 9, column: 4))) == "connectedness 9 4")
        #expect(Play.text(nil as MicroscopicAuroraFailure?) == "none")
        #expect(Play.text(Well(cell: Cell(row: 2, column: 3), strength: 1, sense: .clockwise)) == "2 3 1 clockwise")
        #expect(play.fingerprint.count == 64)
    }

    @Test func undoRestoresExactFingerprintsAndRedoReapplies() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 4))
        let f0: String = play.fingerprint
        try Self.act(&play, .place(slot: 0, well: Self.centreWell))
        let f1: String = play.fingerprint
        let w1: [Well?] = play.wells
        try Self.act(&play, .remove(slot: 0))
        let f2: String = play.fingerprint
        try Self.act(&play, .play)
        #expect(play.stage == .failed)
        #expect(play.failure == .coverage(lit: 0, needed: 2))
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
        #expect(play.wells == w1)
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
        let well: Well = Well(cell: Cell(row: 11, column: 11), strength: 1, sense: .counterclockwise)
        try Self.act(&play, .place(slot: 2, well: well))
        #expect(!play.canRedo)
        #expect(throws: MicroscopicAuroraError.action("redo")) { try play.redo() }
        try Self.act(&play, .remove(slot: 2))
        #expect(play.actionsLeft == 0)
        try Self.act(&play, .play)
        let replayed: Play = try Play.replay(level: play.level, records: play.records)
        #expect(replayed == play)
        // A won play is final.
        let fixture: MicroscopicAuroraFixture = Self.few[2]
        var won: Play = try Self.playing(fixture.level)
        for action in fixture.actions { try Self.act(&won, action) }
        #expect(won.stage == .won)
        let final: Play = won
        #expect(throws: MicroscopicAuroraError.stage) { try won.undo() }
        #expect(won == final)
    }

    /// A random action: mostly placements on cells near the dish (some out of range), removals, every slot −1 … 3.
    static func randomAction(_ random: inout SeededRandom) -> Action {
        let slot: Int = random.int(-1...3)
        if random.int(0...2) == 0 { return .remove(slot: slot) }
        let cell: Cell = Cell(row: random.int(-1...24), column: random.int(-1...24))
        let sense: MicroscopicAuroraSense = random.int(0...1) == 0 ? .clockwise : .counterclockwise
        return .place(slot: slot, well: Well(cell: cell, strength: random.int(0...5), sense: sense))
    }

    @Test func fiveHundredSeededTracesReplayIdentically() throws {
        var random = SeededRandom(seed: Self.seed)
        var outcomes: [MicroscopicAuroraStage: Int] = [:]
        var refused: Int = 0
        var accepted: Int = 0
        for trace in 0..<500 {
            let fixture: MicroscopicAuroraFixture = Self.few[trace % 25]
            let level: Level = fixture.level
            var play: Play = try Self.playing(level)
            let steps: Int = random.int(1...10)
            for _ in 0..<steps {
                let roll: Int = random.int(0...11)
                if roll < 7 {
                    let action: Action = Self.randomAction(&random)
                    let before: String = play.fingerprint
                    let spent: Int = play.actionsSpent
                    do {
                        try Self.act(&play, action)
                        accepted += 1
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
        #expect(accepted > 0)
        #expect(outcomes.count >= 2)
    }

    /// Checks that a trace with another seed, a broken chain, a wrong index, another schema or a forged next
    /// fingerprint is refused.
    static func expectTamperedRefused(level: Level, records: [MicroscopicAuroraRecord]) throws {
        let last: Int = records.count - 1
        let r: MicroscopicAuroraRecord = records[last]
        var seed: [MicroscopicAuroraRecord] = records
        seed[last] = MicroscopicAuroraRecord(schema: r.schema, seed: r.seed + 1, index: r.index, kind: r.kind,
                                             action: r.action, previous: r.previous, next: r.next)
        #expect(throws: MicroscopicAuroraError.malformed("seed \(last)")) {
            _ = try Play.replay(level: level, records: seed)
        }
        var chain: [MicroscopicAuroraRecord] = records
        chain[last] = MicroscopicAuroraRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                              action: r.action, previous: "broken", next: r.next)
        #expect(throws: MicroscopicAuroraError.malformed("chain \(last)")) {
            _ = try Play.replay(level: level, records: chain)
        }
        var index: [MicroscopicAuroraRecord] = records
        index[last] = MicroscopicAuroraRecord(schema: r.schema, seed: r.seed, index: r.index + 1, kind: r.kind,
                                              action: r.action, previous: r.previous, next: r.next)
        #expect(throws: MicroscopicAuroraError.malformed("index \(last)")) {
            _ = try Play.replay(level: level, records: index)
        }
        var schema: [MicroscopicAuroraRecord] = records
        schema[last] = MicroscopicAuroraRecord(schema: 2, seed: r.seed, index: r.index, kind: r.kind,
                                               action: r.action, previous: r.previous, next: r.next)
        #expect(throws: MicroscopicAuroraError.malformed("schema \(last)")) {
            _ = try Play.replay(level: level, records: schema)
        }
        var next: [MicroscopicAuroraRecord] = records
        next[last] = MicroscopicAuroraRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                             action: r.action, previous: r.previous, next: "forged")
        #expect(throws: MicroscopicAuroraError.malformed("record \(last)")) {
            _ = try Play.replay(level: level, records: next)
        }
    }
}
