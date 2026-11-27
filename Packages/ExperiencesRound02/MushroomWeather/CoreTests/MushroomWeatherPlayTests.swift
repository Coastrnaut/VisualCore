// MushroomWeatherPlayTests — feature 491 (R02-G20-01) T-R02G2001-004 (FR-R02G2001-005 … 008, 011, 014;
// SC-R02G2001-001, 002, 004; clarification Q5). The play of a Mushroom Weather level: the full stage table of
// `handle(_:)` with the recorded event kinds; the fixtures' known actions keep the report equal to the forest's report
// after every arrangement action and win on the run; each failure named on a hand level (`dried`, `mold`, `unstable`)
// and an action that turns a failing run into a win; the budget refusal on the exact action with the run still
// allowed; the validation order stage, stale, action (a slot, vent or moonlight out of range, a cell off the floor, on
// a colony or under another pod, unchanged, an empty slot), budget, with every refusal reachable, spending nothing and
// leaving the play unchanged; the fingerprint is the SHA-256 of its canonical text; undo restores exact fingerprints and
// refunds, undo from failed returns to playing (recorded), a won run is final, redo re-applies and a new action clears
// redo; 500 seeded traces replay to the same records, fingerprints and outcome, and tampered traces are refused.
// Explicit types, plain loops, short traces; each test well under 10 s; no clock.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import MushroomWeatherCore

struct MushroomWeatherPlayTests {
    typealias Play = MushroomWeatherPlay
    typealias Action = MushroomWeatherAction
    typealias Level = MushroomWeatherLevel
    typealias Cell = MushroomWeatherCell
    typealias Colony = MushroomWeatherColony
    typealias Arrangement = MushroomWeatherArrangement

    /// The test seed of the feature.
    static let seed: UInt64 = 2_491

    /// The 500 fixtures of the feature seed, built once (≈ 5 s in debug); only the known-actions test needs all 500.
    static let fixtures: [MushroomWeatherFixture] = MushroomWeatherFixture.all(count: 500)

    /// The first 25 fixtures, built on their own so the shorter tests need not wait for all 500.
    static let few: [MushroomWeatherFixture] = MushroomWeatherFixture.all(count: 25)

    /// Applies `action` with the current fingerprint.
    static func act(_ play: inout Play, _ action: Action) throws(MushroomWeatherError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the level has a tutorial).
    static func playing(_ level: Level) throws(MushroomWeatherError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The hand level's floor cells, no two orthogonally adjacent (so no water flows between them).
    static let a: Cell = Cell(row: 0, column: 0)
    static let p1: Cell = Cell(row: 0, column: 2)
    static let p2: Cell = Cell(row: 0, column: 4)
    static let v: Cell = Cell(row: 2, column: 2)
    static let q: Cell = Cell(row: 2, column: 4)
    static let far: Cell = Cell(row: 5, column: 5)
    static let floor: Set<Cell> = [a, p1, p2, v, q, far]

    /// The default colony: on ``far`` (which holds 0 units and never changes) with band 100 … 200, so every run fails
    /// `unstable(0, 0)`.
    static let dryColony: Colony = Colony(cell: far, low: 100, high: 200)

    /// A hand 6 × 6 level whose floor is ``floor`` (every other cell blocked) with the given humidity and rates by cell
    /// (0 elsewhere), diffusion 8, one vent on ``v`` (open 100, closed 0, closed at the start), pod rules (one slot per
    /// entry of `pods`, release 10, grown release 20, threshold 1000), one colony, a run of 20 cycles and 5 required.
    static func hand(humidity: [Cell: Int] = [:], rates: [Cell: Int] = [:], colony: Colony = dryColony,
                     pods: [Cell?] = [nil, nil], moonlight: Int = 0, moldBound: Int = 10_000, budget: Int = 2,
                     tutorial: Bool = false, id: String = "hand", seed: UInt64 = 7) throws(MushroomWeatherError)
        -> Level {
        var blocked: [Cell] = []
        var h: [Int] = []
        var r: [Int] = []
        for row in 0..<6 {
            for column in 0..<6 {
                let cell: Cell = Cell(row: row, column: column)
                if !floor.contains(cell) { blocked.append(cell) }
                h.append(humidity[cell] ?? 0)
                r.append(rates[cell] ?? 0)
            }
        }
        let rules = MushroomWeatherPodRules(slots: pods.count, release: 10, grownRelease: 20, growthThreshold: 1000)
        return try Level(id: id, seed: seed, difficulty: 1, rows: 6, columns: 6, blocked: blocked, humidity: h,
                         diffusion: 8, rates: r, vents: [MushroomWeatherVent(cell: v, openRate: 100, closedRate: 0)],
                         podRules: rules, colonies: [colony], moldBound: moldBound, length: 20, required: 5,
                         start: Arrangement(pods: pods, ventsOpen: [false], moonlight: moonlight), budget: budget,
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

    @Test func theStageTableAcceptsOnlyItsEvents() throws {
        let events: [MushroomWeatherEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]
        var plain: Play = Play(level: try Self.hand())
        #expect(plain.stage == .loading)
        #expect(plain.arrangement == plain.level.start)
        for event in events where event != .begin {
            #expect(throws: MushroomWeatherError.stage) { try plain.handle(event) }
        }
        try plain.handle(.begin)
        #expect(plain.stage == .playing)
        var taught: Play = Play(level: try Self.hand(tutorial: true))
        try taught.handle(.begin)
        #expect(taught.stage == .tutorial)
        for event in events where event != .dismissTutorial {
            #expect(throws: MushroomWeatherError.stage) { try taught.handle(event) }
        }
        #expect(throws: MushroomWeatherError.stage) { try Self.act(&taught, .moonlight(level: 1)) }
        try taught.handle(.dismissTutorial)
        #expect(taught.stage == .playing)
        for event in events where event != .pause {
            #expect(throws: MushroomWeatherError.stage) { try plain.handle(event) }
        }
        try plain.handle(.pause)
        #expect(plain.stage == .paused)
        for event in events where event != .resume {
            #expect(throws: MushroomWeatherError.stage) { try plain.handle(event) }
        }
        try plain.handle(.resume)
        #expect(plain.stage == .playing)
        var recorded: [MushroomWeatherRecordKind] = []
        for record in plain.records { recorded.append(record.kind) }
        #expect(recorded == [.begin, .pause, .resume])
        var taughtKinds: [MushroomWeatherRecordKind] = []
        for record in taught.records { taughtKinds.append(record.kind) }
        #expect(taughtKinds == [.begin, .dismissTutorial])
        for (position, record) in plain.records.enumerated() {
            #expect(record.action == nil)
            #expect(record.index == position)
            #expect(record.schema == 1)
            #expect(record.seed == 7)
        }
        try Self.act(&plain, .run)
        #expect(plain.stage == .failed)
        for event in events where event != .showResult {
            #expect(throws: MushroomWeatherError.stage) { try plain.handle(event) }
        }
        let count: Int = plain.records.count
        try plain.handle(.showResult)
        #expect(plain.stage == .result)
        #expect(plain.records.count == count)
        for event in events {
            #expect(throws: MushroomWeatherError.stage) { try plain.handle(event) }
        }
        #expect(throws: MushroomWeatherError.stage) { try Self.act(&plain, .run) }
        #expect(throws: MushroomWeatherError.stage) { try Self.act(&plain, .moonlight(level: 2)) }
        #expect(throws: MushroomWeatherError.stage) { try plain.undo() }
        #expect(throws: MushroomWeatherError.stage) { try plain.redo() }
        // A won run shows its result too.
        let fixture: MushroomWeatherFixture = Self.few[3]
        var won: Play = try Self.playing(fixture.level)
        for action in fixture.actions { try Self.act(&won, action) }
        #expect(won.stage == .won)
        for event in events where event != .showResult {
            #expect(throws: MushroomWeatherError.stage) { try won.handle(event) }
        }
        try won.handle(.showResult)
        #expect(won.stage == .result)
    }

    @Test func theFixturesKnownActionsWinOnTheRun() throws {
        let fixtures: [MushroomWeatherFixture] = Self.fixtures
        #expect(fixtures.count == 500)
        for (position, fixture) in fixtures.enumerated() {
            var play: Play = try Self.playing(fixture.level)
            #expect(play.arrangement == fixture.level.start)
            #expect(!play.report.wins)
            var spent: Int = 0
            for action in fixture.actions {
                try Self.act(&play, action)
                if action != .run {
                    spent += 1
                    #expect(play.stage == .playing)
                    #expect(play.actionsSpent == spent)
                    #expect(play.actionsLeft == fixture.level.budget - spent)
                    if position % 25 == 0 {
                        #expect(play.report == MushroomWeatherForest.report(fixture.level,
                                                                            arrangement: play.arrangement))
                    }
                }
            }
            #expect(play.arrangement == fixture.winning)
            #expect(play.report == MushroomWeatherForest.report(fixture.level, arrangement: fixture.winning))
            #expect(play.stage == .won)
            #expect(play.failure == nil)
            #expect(play.actionsSpent == spent)
            #expect(play.records.last?.kind == .run)
            #expect(play.records.last?.action == .run)
            #expect(play.records.last?.next == play.fingerprint)
        }
    }

    @Test func eachFailureIsNamedOnTheRun() throws {
        // Dried: a sensitive colony at 1000 with floor 900 loses ⌊1000·200·7/4096⌋ = 341 in the first cycle.
        let sensitive: Colony = Colony(cell: Self.a, low: 900, high: 1000, survivalFloor: 900)
        let dried: Play = try Self.ran(try Self.hand(humidity: [Self.a: 1000], rates: [Self.a: 200],
                                                     colony: sensitive, moonlight: 3))
        // Mold: a pod cell at 995 releasing 10 exceeds the bound 1000 at cycle 1.
        let wide: Colony = Colony(cell: Self.far, low: 0, high: 1000)
        let moldy: Level = try Self.hand(humidity: [Self.a: 995], colony: wide, pods: [Self.a, nil], moldBound: 1000)
        let mold: Play = try Self.ran(moldy)
        // Unstable: the colony on `far` holds 0, below its band 100 … 200, for every cycle.
        let unstable: Play = try Self.ran(try Self.hand())
        // Unstable with a final run one cycle short: a colony drying from 5000 at rate 200 enters the band 0 … h₁₇ at
        // cycle 17, so its final run is 4 of the 5 required.
        var h: [Int] = [5000]
        for _ in 1...20 { h.append(h[h.count - 1] - h[h.count - 1] * 200 * 4 / 4096) }
        let short: Play = try Self.ran(try Self.hand(humidity: [Self.a: 5000], rates: [Self.a: 200],
                                                     colony: Colony(cell: Self.a, low: 0, high: h[17])))
        let cases: [(Play, MushroomWeatherFailure, String)] = [
            (dried, .dried(colony: 0, cycle: 1), "dried"),
            (mold, .mold(cell: Self.a, cycle: 1), "mold"),
            (unstable, .unstable(colony: 0, run: 0), "unstable"),
            (short, .unstable(colony: 0, run: 4), "unstable"),
        ]
        for (play, failure, code) in cases {
            #expect(play.stage == .failed)
            #expect(play.failure == failure)
            #expect(play.failure?.code == code)
            #expect(play.failure == play.report.failure)
            #expect(play.records.last?.kind == .run)
        }
        // Removing the pod keeps the cell at 995 (rate 0): the same level wins on the run.
        var rescued: Play = try Self.playing(moldy)
        try Self.act(&rescued, .remove(slot: 0))
        #expect(rescued.report.wins)
        try Self.act(&rescued, .run)
        #expect(rescued.stage == .won)
        #expect(rescued.failure == nil)
        // Undo from the failed mold run, then the same removal: an honest retry that wins.
        var retry: Play = mold
        try retry.undo()
        #expect(retry.stage == .playing)
        try Self.act(&retry, .remove(slot: 0))
        try Self.act(&retry, .run)
        #expect(retry.stage == .won)
        let fixture: MushroomWeatherFixture = Self.few[0]
        var won: Play = try Self.playing(fixture.level)
        for action in fixture.actions { try Self.act(&won, action) }
        #expect(won.stage == .won)
        #expect(won.failure == nil)
    }

    @Test func theBudgetRefusesTheExactActionAndTheRunIsStillAllowed() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 1))
        try Self.act(&play, .place(slot: 0, cell: Self.p1))
        #expect(play.actionsLeft == 0)
        let before: Play = play
        #expect(throws: MushroomWeatherError.budget) { try Self.act(&play, .place(slot: 1, cell: Self.p2)) }
        #expect(throws: MushroomWeatherError.budget) { try Self.act(&play, .place(slot: 0, cell: Self.p2)) }
        #expect(throws: MushroomWeatherError.budget) { try Self.act(&play, .remove(slot: 0)) }
        #expect(throws: MushroomWeatherError.budget) { try Self.act(&play, .vent(index: 0, open: true)) }
        #expect(throws: MushroomWeatherError.budget) { try Self.act(&play, .moonlight(level: 1)) }
        #expect(play == before)
        #expect(MushroomWeatherError.budget.reasonCode == "r02-g20.budget")
        try Self.act(&play, .run)
        #expect(play.stage == .failed)
        #expect(play.failure == .unstable(colony: 0, run: 0))
        #expect(play.failure == play.report.failure)
        // A fixture whose budget equals its known arrangement actions: one more is refused, the run still wins.
        var found: Bool = false
        for fixture in Self.few where fixture.level.budget == fixture.actions.count - 1 {
            var exact: Play = try Self.playing(fixture.level)
            for action in fixture.actions where action != .run { try Self.act(&exact, action) }
            #expect(exact.actionsLeft == 0)
            let spent: Play = exact
            let moon: Int = (exact.arrangement.moonlight + 1) % 4
            #expect(throws: MushroomWeatherError.budget) { try Self.act(&exact, .moonlight(level: moon)) }
            #expect(exact == spent)
            try Self.act(&exact, .run)
            #expect(exact.stage == .won)
            found = true
            break
        }
        #expect(found)
    }

    @Test func everyRefusalReasonIsReachableInOrder() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 2))
        let start: Play = play
        let refusals: [(Action, MushroomWeatherError)] = [
            (.place(slot: 2, cell: Self.p1), .action("slot out of range")),
            (.place(slot: -1, cell: Self.p1), .action("slot out of range")),
            (.place(slot: 0, cell: Cell(row: -1, column: 0)), .action("off floor")),
            (.place(slot: 0, cell: Cell(row: 6, column: 0)), .action("off floor")),
            (.place(slot: 0, cell: Cell(row: 0, column: 6)), .action("off floor")),
            (.place(slot: 0, cell: Cell(row: 0, column: -1)), .action("off floor")),
            (.place(slot: 0, cell: Cell(row: 0, column: 1)), .action("off floor")),
            (.place(slot: 0, cell: Self.far), .action("colony cell")),
            (.remove(slot: 0), .action("empty slot")),
            (.remove(slot: 2), .action("slot out of range")),
            (.remove(slot: -1), .action("slot out of range")),
            (.vent(index: 1, open: true), .action("vent out of range")),
            (.vent(index: -1, open: true), .action("vent out of range")),
            (.vent(index: 0, open: false), .action("unchanged")),
            (.moonlight(level: 4), .action("moonlight out of range")),
            (.moonlight(level: -1), .action("moonlight out of range")),
            (.moonlight(level: 0), .action("unchanged")),
        ]
        for (action, error) in refusals {
            #expect(throws: error) { try Self.act(&play, action) }
            #expect(play == start)
            #expect(throws: MushroomWeatherError.stale) { try play.apply(action, expecting: "stale") }
            #expect(play == start)
        }
        #expect(throws: MushroomWeatherError.stale) { try play.apply(.run, expecting: "stale") }
        #expect(throws: MushroomWeatherError.action("undo")) { try play.undo() }
        #expect(throws: MushroomWeatherError.action("redo")) { try play.redo() }
        #expect(play == start)
        try Self.act(&play, .place(slot: 0, cell: Self.p1))
        let placed: Play = play
        #expect(throws: MushroomWeatherError.action("occupied cell")) {
            try Self.act(&play, .place(slot: 1, cell: Self.p1))
        }
        #expect(throws: MushroomWeatherError.action("unchanged")) { try Self.act(&play, .place(slot: 0, cell: Self.p1)) }
        #expect(play == placed)
        // A move of the slot's pod to another free cell is accepted.
        try Self.act(&play, .place(slot: 0, cell: Self.p2))
        #expect(play.arrangement.pods == [Self.p2, nil])
        #expect(play.actionsLeft == 0)
        let spent: Play = play
        // The action check comes before the budget, the budget after it.
        #expect(throws: MushroomWeatherError.action("occupied cell")) {
            try Self.act(&play, .place(slot: 1, cell: Self.p2))
        }
        #expect(throws: MushroomWeatherError.action("colony cell")) {
            try Self.act(&play, .place(slot: 1, cell: Self.far))
        }
        #expect(throws: MushroomWeatherError.action("empty slot")) { try Self.act(&play, .remove(slot: 1)) }
        #expect(throws: MushroomWeatherError.action("unchanged")) { try Self.act(&play, .moonlight(level: 0)) }
        #expect(throws: MushroomWeatherError.budget) { try Self.act(&play, .remove(slot: 0)) }
        #expect(throws: MushroomWeatherError.budget) { try Self.act(&play, .place(slot: 1, cell: Self.q)) }
        #expect(play == spent)
        // The stage comes first, even with a stale fingerprint.
        try play.handle(.pause)
        let paused: Play = play
        #expect(throws: MushroomWeatherError.stage) { try play.apply(.remove(slot: 9), expecting: "stale") }
        #expect(throws: MushroomWeatherError.stage) { try Self.act(&play, .run) }
        #expect(play == paused)
        try play.handle(.resume)
        var loading: Play = Play(level: try Self.hand())
        #expect(throws: MushroomWeatherError.stage) { try Self.act(&loading, .run) }
        #expect(throws: MushroomWeatherError.stage) { try loading.apply(.moonlight(level: 9), expecting: "stale") }
        #expect(throws: MushroomWeatherError.stage) { try loading.undo() }
        #expect(throws: MushroomWeatherError.stage) { try loading.redo() }
        let fixture: MushroomWeatherFixture = Self.few[1]
        var winning: Play = try Self.playing(fixture.level)
        for action in fixture.actions { try Self.act(&winning, action) }
        #expect(winning.stage == .won)
        #expect(throws: MushroomWeatherError.stage) { try winning.undo() }
        #expect(throws: MushroomWeatherError.stage) { try winning.redo() }
        #expect(throws: MushroomWeatherError.stage) { try Self.act(&winning, .run) }
        #expect(!winning.canUndo)
        #expect(!winning.canRedo)
        // A record of another level (another seed) is refused.
        let failed: Play = try Self.ran(try Self.hand())
        #expect(throws: MushroomWeatherError.malformed("seed 0")) {
            _ = try Play.replay(level: try Self.hand(seed: 8), records: failed.records)
        }
        // A trace of another level with the same seed breaks the chain at once.
        let twin: Level = try Self.hand(budget: 3, id: "twin")
        #expect(throws: MushroomWeatherError.malformed("chain 0")) {
            _ = try Play.replay(level: twin, records: failed.records)
        }
        let codes: [String] = [MushroomWeatherError.action("x").reasonCode, MushroomWeatherError.stage.reasonCode,
                               MushroomWeatherError.stale.reasonCode, MushroomWeatherError.malformed("x").reasonCode]
        #expect(codes == ["r02-g20.action", "r02-g20.stage", "r02-g20.stale", "r02-g20.malformed"])
    }

    @Test func theFingerprintIsTheHashOfItsCanonicalText() throws {
        let level: Level = try Self.hand()
        var play: Play = try Self.playing(level)
        let text0: String = "{\"actions\":0,\"failure\":\"none\",\"level\":\"" + level.fingerprint
            + "\",\"moonlight\":0,\"pods\":[\"none\",\"none\"],\"schema\":1,\"stage\":\"playing\","
            + "\"vents\":[\"closed\"]}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text0.utf8)))
        try Self.act(&play, .place(slot: 1, cell: Self.p1))
        try Self.act(&play, .vent(index: 0, open: true))
        try Self.act(&play, .run)
        #expect(play.stage == .failed)
        let text1: String = "{\"actions\":2,\"failure\":\"unstable 0 0\",\"level\":\"" + level.fingerprint
            + "\",\"moonlight\":0,\"pods\":[\"none\",\"0 2\"],\"schema\":1,\"stage\":\"failed\","
            + "\"vents\":[\"open\"]}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text1.utf8)))
        #expect(Play.text(.dried(colony: 2, cycle: 14)) == "dried 2 14")
        #expect(Play.text(.mold(cell: Cell(row: 3, column: 4), cycle: 9)) == "mold 3 4 9")
        #expect(Play.text(.unstable(colony: 1, run: 3)) == "unstable 1 3")
        #expect(Play.text(nil as MushroomWeatherFailure?) == "none")
        #expect(Play.text(Cell(row: 2, column: 3)) == "2 3")
        #expect(Play.text(nil as Cell?) == "none")
        #expect(play.fingerprint.count == 64)
        // The moonlight changes the fingerprint.
        var moon: Play = try Self.playing(level)
        let f0: String = moon.fingerprint
        try Self.act(&moon, .moonlight(level: 3))
        #expect(moon.fingerprint != f0)
    }

    @Test func undoRestoresExactFingerprintsAndRedoReapplies() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 4))
        let f0: String = play.fingerprint
        try Self.act(&play, .place(slot: 0, cell: Self.p1))
        let f1: String = play.fingerprint
        let a1: Arrangement = play.arrangement
        try Self.act(&play, .vent(index: 0, open: true))
        let f2: String = play.fingerprint
        try Self.act(&play, .moonlight(level: 2))
        let f3: String = play.fingerprint
        let r3: MushroomWeatherReport = play.report
        try Self.act(&play, .run)
        #expect(play.stage == .failed)
        #expect(play.failure == .unstable(colony: 0, run: 0))
        let f4: String = play.fingerprint
        #expect(play.canUndo)
        #expect(!play.canRedo)
        try play.undo()
        #expect(play.stage == .playing)
        #expect(play.failure == nil)
        #expect(play.fingerprint == f3)
        #expect(play.report == r3)
        #expect(play.actionsSpent == 3)
        #expect(play.records.last?.kind == .undo)
        #expect(play.records.last?.previous == f4)
        #expect(play.records.last?.next == f3)
        try play.undo()
        #expect(play.fingerprint == f2)
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused)
        #expect(play.arrangement == a1)
        #expect(play.actionsSpent == 1)
        try play.handle(.resume)
        #expect(play.fingerprint == f1)
        try play.undo()
        #expect(play.fingerprint == f0)
        #expect(play.actionsLeft == 4)
        #expect(play.arrangement == play.level.start)
        #expect(play.report == play.level.startReport)
        #expect(throws: MushroomWeatherError.action("undo")) { try play.undo() }
        try play.redo()
        #expect(play.fingerprint == f1)
        try play.redo()
        #expect(play.fingerprint == f2)
        try play.redo()
        #expect(play.fingerprint == f3)
        try play.redo()
        #expect(play.fingerprint == f4)
        #expect(play.stage == .failed)
        #expect(throws: MushroomWeatherError.stage) { try play.redo() }
        try play.undo()
        try Self.act(&play, .place(slot: 1, cell: Self.q))
        #expect(!play.canRedo)
        #expect(throws: MushroomWeatherError.action("redo")) { try play.redo() }
        #expect(play.actionsLeft == 0)
        try Self.act(&play, .run)
        let replayed: Play = try Play.replay(level: play.level, records: play.records)
        #expect(replayed == play)
        // A won run is final.
        let fixture: MushroomWeatherFixture = Self.few[2]
        var won: Play = try Self.playing(fixture.level)
        for action in fixture.actions { try Self.act(&won, action) }
        #expect(won.stage == .won)
        let final: Play = won
        #expect(throws: MushroomWeatherError.stage) { try won.undo() }
        #expect(won == final)
    }

    /// A random action on `level`: placements on cells around the grid (some off it), removals, vent and moonlight
    /// changes, every index one beyond its range on both sides.
    static func randomAction(_ random: inout SeededRandom, level: Level) -> Action {
        let slots: Int = level.podRules.slots
        switch random.int(0...5) {
        case 0, 1, 2:
            let cell: Cell = Cell(row: random.int(-1...level.rows), column: random.int(-1...level.columns))
            return .place(slot: random.int(-1...slots), cell: cell)
        case 3:
            return .remove(slot: random.int(-1...slots))
        case 4:
            return .vent(index: random.int(-1...level.vents.count), open: random.int(0...1) == 1)
        default:
            return .moonlight(level: random.int(-1...4))
        }
    }

    @Test func fiveHundredSeededTracesReplayIdentically() throws {
        var random = SeededRandom(seed: Self.seed)
        var outcomes: [MushroomWeatherStage: Int] = [:]
        var refused: Int = 0
        var accepted: Int = 0
        for trace in 0..<500 {
            let fixture: MushroomWeatherFixture = Self.few[trace % 25]
            let level: Level = fixture.level
            var play: Play = try Self.playing(level)
            let steps: Int = random.int(1...10)
            for _ in 0..<steps {
                let roll: Int = random.int(0...11)
                if roll < 7 {
                    let action: Action = Self.randomAction(&random, level: level)
                    let before: String = play.fingerprint
                    let spent: Int = play.actionsSpent
                    do {
                        try Self.act(&play, action)
                        accepted += 1
                        let after: String = play.fingerprint
                        #expect(play.report == MushroomWeatherForest.report(level, arrangement: play.arrangement))
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
        #expect(accepted > 0)
        #expect(outcomes.count >= 2)
    }

    /// Checks that a trace with another seed, a broken chain, a wrong index, another schema, a forged next fingerprint
    /// or an action of another kind is refused.
    static func expectTamperedRefused(level: Level, records: [MushroomWeatherRecord]) throws {
        let last: Int = records.count - 1
        let r: MushroomWeatherRecord = records[last]
        var seed: [MushroomWeatherRecord] = records
        seed[last] = MushroomWeatherRecord(schema: r.schema, seed: r.seed + 1, index: r.index, kind: r.kind,
                                           action: r.action, previous: r.previous, next: r.next)
        #expect(throws: MushroomWeatherError.malformed("seed \(last)")) {
            _ = try Play.replay(level: level, records: seed)
        }
        var chain: [MushroomWeatherRecord] = records
        chain[last] = MushroomWeatherRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                            action: r.action, previous: "broken", next: r.next)
        #expect(throws: MushroomWeatherError.malformed("chain \(last)")) {
            _ = try Play.replay(level: level, records: chain)
        }
        var index: [MushroomWeatherRecord] = records
        index[last] = MushroomWeatherRecord(schema: r.schema, seed: r.seed, index: r.index + 1, kind: r.kind,
                                            action: r.action, previous: r.previous, next: r.next)
        #expect(throws: MushroomWeatherError.malformed("index \(last)")) {
            _ = try Play.replay(level: level, records: index)
        }
        var schema: [MushroomWeatherRecord] = records
        schema[last] = MushroomWeatherRecord(schema: 2, seed: r.seed, index: r.index, kind: r.kind,
                                             action: r.action, previous: r.previous, next: r.next)
        #expect(throws: MushroomWeatherError.malformed("schema \(last)")) {
            _ = try Play.replay(level: level, records: schema)
        }
        var next: [MushroomWeatherRecord] = records
        next[last] = MushroomWeatherRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                           action: r.action, previous: r.previous, next: "forged")
        #expect(throws: MushroomWeatherError.malformed("record \(last)")) {
            _ = try Play.replay(level: level, records: next)
        }
        // The first record is `begin`: an action attached to it, or a kind that needs an action, is refused.
        let b: MushroomWeatherRecord = records[0]
        var attached: [MushroomWeatherRecord] = records
        attached[0] = MushroomWeatherRecord(schema: b.schema, seed: b.seed, index: 0, kind: .begin, action: .run,
                                            previous: b.previous, next: b.next)
        #expect(throws: MushroomWeatherError.malformed("record 0")) {
            _ = try Play.replay(level: level, records: attached)
        }
        var missing: [MushroomWeatherRecord] = records
        missing[0] = MushroomWeatherRecord(schema: b.schema, seed: b.seed, index: 0, kind: .run, action: nil,
                                           previous: b.previous, next: b.next)
        #expect(throws: MushroomWeatherError.malformed("record 0")) {
            _ = try Play.replay(level: level, records: missing)
        }
    }
}
