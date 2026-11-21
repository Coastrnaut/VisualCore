// ColorfallCanyonsPlayTests — feature 341 (R02-G05-01) T-R02G0501-004 (FR-R02G0501-004 … 008; SC-R02G0501-001, 002,
// 004). The play of a Colorfall Canyons level: the 500 fixtures' known solutions win at exactly the first tick whose
// targets are met and fail on time without their carves; contamination, overflow and time fail at the exact tick one
// unit either side of each limit; every refusal is reachable and leaves the play unchanged; 500 seeded traces replay
// to the same records and fingerprint and a tampered record is refused; undo and redo restore exact fingerprints; the
// full stage table of `handle(_:)`; and the play fingerprint covers every part of the state.
import Foundation
import VisualCoreMath
import XCTest
@testable import ColorfallCanyonsCore

final class ColorfallCanyonsPlayTests: XCTestCase {
    private typealias Play = ColorfallCanyonsPlay

    /// One operation on a play, so that refusals can be listed and checked in loops.
    private enum Op {
        case act(ColorfallCanyonsAction)
        case stale(ColorfallCanyonsAction)
        case undo
        case redo
        case event(ColorfallCanyonsEvent)
    }

    private static let events: [ColorfallCanyonsEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    private static func perform(_ op: Op, _ play: inout Play) throws(ColorfallCanyonsError) {
        switch op {
        case .act(let action): try play.apply(action, expecting: play.fingerprint)
        case .stale(let action): try play.apply(action, expecting: "0000")
        case .undo: try play.undo()
        case .redo: try play.redo()
        case .event(let event): try play.handle(event)
        }
    }

    private static func act(_ play: inout Play, _ action: ColorfallCanyonsAction) throws(ColorfallCanyonsError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// The refusal of `op` on a copy of `play` (nil when accepted); a refused op must leave the copy unchanged.
    private func refusal(_ play: Play, _ op: Op, file: StaticString = #filePath, line: UInt = #line)
        -> ColorfallCanyonsError? {
        var copy: Play = play
        do {
            try Self.perform(op, &copy)
            return nil
        } catch {
            XCTAssertEqual(copy, play, "refused \(op) changed the play", file: file, line: line)
            XCTAssertEqual(copy.fingerprint, play.fingerprint, file: file, line: line)
            XCTAssertEqual(copy.records, play.records, file: file, line: line)
            return error
        }
    }

    /// A play of `level` that has begun (and dismissed its tutorial).
    private static func playing(_ level: ColorfallCanyonsLevel) throws(ColorfallCanyonsError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A 4 × 4 hand level: spring at cell 0 (height 5) beside the basin at cell 1 (height 0), plain open cells 2
    /// (height 3), 3 (height 0) and 5 (height 4), rock elsewhere and a drain at cell 15. With release 1 the basin holds
    /// t − 1 units of the spring's colour after tick t.
    private static func hand(color: ColorfallCanyonsColor = .cyan, open: Bool = true, capacity: Int = 999,
                             fill: Int = 999, shares: [Int] = [0, 1_000, 0], tolerance: Int = 0,
                             isProtected: Bool = false, toleratedWrong: Int = 0, budget: Int = 3,
                             tickLimit: Int = 3_600, tutorial: Bool = false) throws(ColorfallCanyonsError)
        -> ColorfallCanyonsLevel {
        var grounds = [ColorfallCanyonsGround](repeating: .rock, count: 16)
        var heights = [Int](repeating: 15, count: 16)
        for (cell, height) in [(0, 5), (1, 0), (2, 3), (3, 0), (5, 4)] {
            grounds[cell] = .open
            heights[cell] = height
        }
        grounds[15] = .drain
        heights[15] = 0
        let spring = ColorfallCanyonsSpring(cell: 0, color: color, release: 1, supply: 999, open: open)
        let basin = ColorfallCanyonsBasin(cell: 1, capacity: capacity, fill: fill, shares: shares, tolerance: tolerance,
                                          isProtected: isProtected, toleratedWrong: toleratedWrong)
        return try ColorfallCanyonsLevel(id: "hand", seed: 7, difficulty: 1, columns: 4, rows: 4, heights: heights,
                                         grounds: grounds, springs: [spring], basins: [basin], flowRate: 8,
                                         budget: budget, tickLimit: tickLimit, tutorial: tutorial)
    }

    /// A hand level that is won at tick 11 (cyan into a cyan basin with fill 10).
    private static func winnable(tickLimit: Int = 3_600, tutorial: Bool = false) throws(ColorfallCanyonsError)
        -> ColorfallCanyonsLevel {
        try hand(fill: 10, shares: [1_000, 0, 0], tickLimit: tickLimit, tutorial: tutorial)
    }

    /// A play of the winnable hand level brought into `stage`.
    private static func play(in stage: ColorfallCanyonsStage) throws(ColorfallCanyonsError) -> Play {
        var play = Play(level: try winnable(tickLimit: stage == .failed ? 5 : 3_600, tutorial: stage == .tutorial))
        switch stage {
        case .loading: break
        case .tutorial: try play.handle(.begin)
        case .playing: try play.handle(.begin)
        case .paused:
            try play.handle(.begin)
            try play.handle(.pause)
        case .won, .failed, .result:
            try play.handle(.begin)
            try act(&play, .step(600))
            if stage == .result { try play.handle(.showResult) }
        }
        return play
    }

    // MARK: - 1. Fixtures

    func testFixtureSolutionsWinAtTheFirstMetTickAndFailOnTimeWithoutCarves() throws {
        for index in 0..<500 {
            let fixture = ColorfallCanyonsFixtures.fixture(index)
            let level = fixture.level
            var play = try Self.playing(level)
            for action in fixture.solution { try Self.act(&play, action) }
            XCTAssertEqual(play.stage, .won, "fixture \(index)")
            XCTAssertNil(play.failure, "fixture \(index)")
            XCTAssertEqual(play.records.count, fixture.solution.count, "fixture \(index)")
            XCTAssertEqual(play.spent, fixture.solution.count - 1, "fixture \(index)")
            XCTAssertTrue(level.basins.allSatisfy { $0.accepts(play.fluid.masses[$0.cell]) }, "fixture \(index)")
            XCTAssertTrue(play.fluid.isConserved(), "fixture \(index)")

            var single = try Self.playing(level)
            for action in fixture.solution.dropLast() { try Self.act(&single, action) }
            var guardTicks: Int = 0
            while single.stage == .playing, guardTicks <= level.tickLimit {
                try Self.act(&single, .step(1))
                guardTicks += 1
                if single.stage == .playing {
                    XCTAssertEqual(single.fluid.verdict(level: level), .running, "fixture \(index)")
                }
            }
            XCTAssertEqual(single.stage, .won, "fixture \(index)")
            XCTAssertEqual(single.fluid, play.fluid, "fixture \(index): the step stops at the first met tick")
            XCTAssertEqual(single.fluid.tick, play.fluid.tick, "fixture \(index)")

            var stuck = try Self.playing(level)
            for action in fixture.solution {
                if case .carve = action { continue }
                try Self.act(&stuck, action)
            }
            XCTAssertEqual(stuck.stage, .failed, "fixture \(index)")
            XCTAssertEqual(stuck.failure, .time, "fixture \(index)")
            XCTAssertEqual(stuck.fluid.tick, level.tickLimit, "fixture \(index)")
        }
    }

    // MARK: - 2. Failure boundaries

    func testContaminationFailsAtTheExactTickPastTheToleratedWrongMass() throws {
        for tolerated in [0, 1, 5, 20] {
            let level = try Self.hand(isProtected: true, toleratedWrong: tolerated)
            var play = try Self.playing(level)
            try Self.act(&play, .step(tolerated + 1))
            XCTAssertEqual(play.stage, .playing, "tolerated \(tolerated)")
            XCTAssertEqual(level.basins[0].wrongMass(play.fluid.masses[1]), tolerated)
            try Self.act(&play, .step(1))
            XCTAssertEqual(play.stage, .failed)
            XCTAssertEqual(play.failure, .contamination)
            XCTAssertEqual(play.fluid.tick, tolerated + 2)

            var long = try Self.playing(level)
            try Self.act(&long, .step(600))
            XCTAssertEqual(long.failure, .contamination)
            XCTAssertEqual(long.fluid.tick, tolerated + 2, "a step stops at the deciding tick")

            var unprotected = try Self.playing(try Self.hand(isProtected: false, toleratedWrong: tolerated))
            try Self.act(&unprotected, .step(tolerated + 2))
            XCTAssertEqual(unprotected.stage, .playing, "an unprotected basin is never contaminated")
        }
    }

    func testOverflowFailsAtTheExactTickPastTheCapacity() throws {
        for capacity in [1, 2, 7, 30] {
            let level = try Self.hand(capacity: capacity, fill: capacity)
            var play = try Self.playing(level)
            try Self.act(&play, .step(capacity + 1))
            XCTAssertEqual(play.stage, .playing, "capacity \(capacity)")
            XCTAssertEqual(play.fluid.volume(1), capacity)
            try Self.act(&play, .step(1))
            XCTAssertEqual(play.failure, .overflow)
            XCTAssertEqual(play.fluid.tick, capacity + 2)

            var long = try Self.playing(level)
            try Self.act(&long, .step(600))
            XCTAssertEqual(long.failure, .overflow)
            XCTAssertEqual(long.fluid.tick, capacity + 2)

            var both = try Self.playing(try Self.hand(capacity: capacity, fill: capacity, isProtected: true,
                                                      toleratedWrong: capacity))
            try Self.act(&both, .step(600))
            XCTAssertEqual(both.failure, .contamination, "contamination is decided before overflow")
            XCTAssertEqual(both.fluid.tick, capacity + 2)
        }
    }

    func testTimeFailsAtTheExactTickLimitAndAWinOnTheLimitTickWins() throws {
        for limit in [1, 2, 10, 600, 900] {
            var play = try Self.playing(try Self.hand(tickLimit: limit))
            var left: Int = limit - 1
            while left > 0 {
                let ticks: Int = min(left, 600)
                try Self.act(&play, .step(ticks))
                left -= ticks
            }
            XCTAssertEqual(play.stage, .playing, "limit \(limit)")
            XCTAssertEqual(play.fluid.tick, limit - 1)
            try Self.act(&play, .step(1))
            XCTAssertEqual(play.failure, .time)
            XCTAssertEqual(play.fluid.tick, limit)
        }
        var long = try Self.playing(try Self.hand(tickLimit: 37))
        try Self.act(&long, .step(600))
        XCTAssertEqual(long.failure, .time)
        XCTAssertEqual(long.fluid.tick, 37)

        // Fill 10 is met at tick 11: a limit of 11 wins, a limit of 10 fails on time at tick 10.
        var onLimit = try Self.playing(try Self.winnable(tickLimit: 11))
        try Self.act(&onLimit, .step(600))
        XCTAssertEqual(onLimit.stage, .won)
        XCTAssertEqual(onLimit.fluid.tick, 11)
        var short = try Self.playing(try Self.winnable(tickLimit: 10))
        try Self.act(&short, .step(600))
        XCTAssertEqual(short.failure, .time)
        XCTAssertEqual(short.fluid.tick, 10)
    }

    // MARK: - 3. Refusals

    func testEveryRefusalIsReachableAndLeavesThePlayUnchanged() throws {
        let actions: [Op] = [.act(.carve(2)), .act(.valve(0)), .act(.step(1)), .stale(.carve(2))]
        for stage in [ColorfallCanyonsStage.loading, .tutorial, .paused, .won, .failed, .result] {
            let play = try Self.play(in: stage)
            XCTAssertEqual(play.stage, stage)
            for op in actions { XCTAssertEqual(refusal(play, op), .stage, "\(op) in \(stage)") }
        }
        for stage in [ColorfallCanyonsStage.loading, .tutorial, .won, .result] {
            XCTAssertEqual(refusal(try Self.play(in: stage), .undo), .stage, "undo in \(stage)")
        }
        for stage in [ColorfallCanyonsStage.loading, .tutorial, .won, .failed, .result] {
            XCTAssertEqual(refusal(try Self.play(in: stage), .redo), .stage, "redo in \(stage)")
        }

        let level = try Self.hand(budget: 3)
        var play = try Self.playing(level)
        XCTAssertEqual(refusal(play, .stale(.carve(2))), .stale)
        XCTAssertEqual(refusal(play, .stale(.carve(-1))), .stale, "stale is checked before range")
        for action in [ColorfallCanyonsAction.carve(-1), .carve(16), .valve(-1), .valve(1), .step(0), .step(601)] {
            XCTAssertEqual(refusal(play, .act(action)), .action("range"), "\(action)")
        }
        for cell in [0, 1, 15, 4, 3] {
            XCTAssertEqual(refusal(play, .act(.carve(cell))), .action("not-carvable"), "cell \(cell)")
        }
        XCTAssertEqual(refusal(play, .undo), .action("nothing-to-undo"))
        XCTAssertEqual(refusal(play, .redo), .action("nothing-to-redo"))

        for _ in 0..<3 { try Self.act(&play, .carve(2)) }
        XCTAssertEqual(play.fluid.heights[2], 0)
        XCTAssertEqual(play.remaining, 0)
        XCTAssertEqual(refusal(play, .act(.carve(2))), .action("not-carvable"), "carved down to height 0")
        XCTAssertEqual(refusal(play, .act(.carve(4))), .action("not-carvable"), "carvability is checked before budget")
        XCTAssertEqual(refusal(play, .act(.carve(5))), .budget)
        XCTAssertEqual(refusal(play, .act(.valve(0))), .budget)
        XCTAssertNil(refusal(play, .act(.step(1))), "a step spends nothing")
        XCTAssertEqual(refusal(play, .redo), .action("nothing-to-redo"))

        var won = try Self.play(in: .won)
        XCTAssertFalse(won.canUndo)
        XCTAssertEqual(refusal(won, .undo), .stage, "a won play is final")
        try won.handle(.showResult)
        XCTAssertEqual(refusal(won, .undo), .stage)

        var failed = try Self.play(in: .failed)
        try failed.undo()
        try failed.redo()
        XCTAssertEqual(failed.stage, .failed)
        XCTAssertFalse(failed.canRedo)
        XCTAssertEqual(refusal(failed, .redo), .stage, "redo from failed")
    }

    // MARK: - 4. Replay

    func testSeededTracesReplayToIdenticalRecordsAndTamperedRecordsAreRefused() throws {
        var random = ColorfallCanyonsRandom(seed: 341_004)
        var stepTampers: Int = 0
        for index in 0..<500 {
            let tutorial: Bool = index % 4 == 1
            let level: ColorfallCanyonsLevel = index % 2 == 0
                ? ColorfallCanyonsFixtures.fixture(index, tutorial: tutorial).level
                : ColorfallCanyonsFixtures.randomLevel(index, tutorial: tutorial)
            var play = try Self.playing(level)
            // Steps that ran all their ticks undecided: changing their length changes their record (a step stopped
            // by a verdict is the same record at any longer length).
            var undecided: [Int] = []
            for _ in 0..<random.int(4...18) {
                let op: Op
                switch random.int(0...9) {
                case 0...2: op = .act(.carve(random.int(-1...level.cellCount)))
                case 3: op = .act(.valve(random.int(-1...level.springs.count)))
                case 4...6: op = .act(.step(random.int(0...40)))
                case 7: op = .undo
                default: op = .redo
                }
                var next: Play = play
                do {
                    try Self.perform(op, &next)
                    play = next
                    if case .act(.step) = op, play.stage == .playing { undecided.append(play.records.count - 1) }
                } catch {
                    XCTAssertEqual(next, play, "trace \(index): a refused \(op) changed the play")
                }
                if play.stage == .won { break }
            }
            for k in play.records.indices.dropLast() {
                XCTAssertEqual(play.records[k].next, play.records[k + 1].previous, "trace \(index) record \(k)")
            }
            if let last = play.records.last { XCTAssertEqual(last.next, play.fingerprint, "trace \(index)") }

            let replayed = try Play.replay(level: level, records: play.records)
            XCTAssertEqual(replayed.records, play.records, "trace \(index)")
            XCTAssertEqual(replayed.fingerprint, play.fingerprint, "trace \(index)")
            XCTAssertEqual(replayed, play, "trace \(index)")

            guard let lastIndex = play.records.indices.last else { continue }
            var tampered = play.records
            let r = tampered[lastIndex]
            tampered[lastIndex] = ColorfallCanyonsRecord(schema: r.schema, seed: r.seed, tick: r.tick, kind: r.kind,
                                                         action: r.action, previous: r.previous, next: r.previous + "0")
            XCTAssertThrowsError(try Play.replay(level: level, records: tampered)) { error in
                XCTAssertEqual(error as? ColorfallCanyonsError, .malformed("record \(lastIndex)"), "trace \(index)")
            }
            if let k = undecided.first, case .step(let ticks) = play.records[k].action {
                var changed = play.records
                let s = changed[k]
                changed[k] = ColorfallCanyonsRecord(schema: s.schema, seed: s.seed, tick: s.tick, kind: s.kind,
                                                    action: .step(ticks < 600 ? ticks + 1 : ticks - 1),
                                                    previous: s.previous, next: s.next)
                XCTAssertThrowsError(try Play.replay(level: level, records: changed)) { error in
                    XCTAssertEqual(error as? ColorfallCanyonsError, .malformed("record \(k)"), "trace \(index)")
                }
                stepTampers += 1
            }
        }
        XCTAssertGreaterThan(stepTampers, 100)
    }

    func testAHandTraceWithAChangedActionOrNextFingerprintIsMalformed() throws {
        let level = try Self.winnable()
        var play = try Self.playing(level)
        try Self.act(&play, .step(3))
        try Self.act(&play, .carve(2))
        try play.undo()
        try play.redo()
        try Self.act(&play, .step(2))
        XCTAssertEqual(try Play.replay(level: level, records: play.records), play)
        var records = play.records
        let first = records[0]
        records[0] = ColorfallCanyonsRecord(schema: first.schema, seed: first.seed, tick: first.tick, kind: first.kind,
                                            action: .step(4), previous: first.previous, next: first.next)
        XCTAssertThrowsError(try Play.replay(level: level, records: records)) { error in
            XCTAssertEqual(error as? ColorfallCanyonsError, .malformed("record 0"))
        }
        records = play.records
        let undo = records[2]
        records[2] = ColorfallCanyonsRecord(schema: undo.schema, seed: undo.seed, tick: undo.tick, kind: undo.kind,
                                            action: undo.action, previous: undo.previous, next: records[1].next)
        XCTAssertThrowsError(try Play.replay(level: level, records: records)) { error in
            XCTAssertEqual(error as? ColorfallCanyonsError, .malformed("record 2"))
        }
    }

    // MARK: - 5. Undo and redo

    func testUndoAndRedoRestoreExactFingerprintsForEveryActionKind() throws {
        var play = try Self.playing(try Self.hand(open: false, budget: 5))
        let start: String = play.fingerprint
        var history: [String] = [start]
        for action in [ColorfallCanyonsAction.carve(2), .valve(0), .step(3), .carve(5), .step(1)] {
            let before: String = play.fingerprint
            let spentBefore: Int = play.spent
            try Self.act(&play, action)
            let after: String = play.fingerprint
            XCTAssertNotEqual(before, after, "\(action)")
            let count: Int = play.records.count
            try play.undo()
            XCTAssertEqual(play.fingerprint, before, "undo of \(action)")
            XCTAssertEqual(play.spent, spentBefore, "undo of \(action) returns the action spent")
            XCTAssertEqual(play.records[count].kind, .undo)
            XCTAssertNil(play.records[count].action)
            XCTAssertEqual(play.records[count].previous, after)
            XCTAssertEqual(play.records[count].next, before)
            try play.redo()
            XCTAssertEqual(play.fingerprint, after, "redo of \(action)")
            XCTAssertEqual(play.records[count + 1].kind, .redo)
            XCTAssertEqual(play.records[count + 1].previous, before)
            XCTAssertEqual(play.records[count + 1].next, after)
            history.append(after)
        }
        for k in stride(from: history.count - 2, through: 0, by: -1) {
            try play.undo()
            XCTAssertEqual(play.fingerprint, history[k])
        }
        XCTAssertFalse(play.canUndo)
        for k in 1..<history.count {
            try play.redo()
            XCTAssertEqual(play.fingerprint, history[k])
        }
        XCTAssertFalse(play.canRedo)
    }

    func testUndoFromFailedReturnsToPlayingAndPausedStaysPaused() throws {
        var play = try Self.playing(try Self.winnable(tickLimit: 5))
        try Self.act(&play, .step(2))
        let beforeFailure: String = play.fingerprint
        try Self.act(&play, .step(600))
        XCTAssertEqual(play.failure, .time)
        let failed: String = play.fingerprint
        XCTAssertTrue(play.canUndo)
        try play.undo()
        XCTAssertEqual(play.stage, .playing)
        XCTAssertNil(play.failure)
        XCTAssertEqual(play.fingerprint, beforeFailure)
        try play.redo()
        XCTAssertEqual(play.stage, .failed)
        XCTAssertEqual(play.fingerprint, failed)

        var paused = try Self.playing(try Self.hand())
        try Self.act(&paused, .carve(2))
        let carvedFluid = paused.fluid
        try paused.handle(.pause)
        try paused.undo()
        XCTAssertEqual(paused.stage, .paused)
        XCTAssertEqual(paused.fluid.heights[2], 3)
        XCTAssertEqual(paused.spent, 0)
        try paused.redo()
        XCTAssertEqual(paused.stage, .paused)
        XCTAssertEqual(paused.fluid, carvedFluid)
        XCTAssertEqual(paused.spent, 1)
        try paused.handle(.resume)
        XCTAssertEqual(paused.stage, .playing)
    }

    func testANewActionClearsRedo() throws {
        var play = try Self.playing(try Self.hand())
        try Self.act(&play, .carve(2))
        try play.undo()
        XCTAssertTrue(play.canRedo)
        try Self.act(&play, .valve(0))
        XCTAssertFalse(play.canRedo)
        XCTAssertEqual(refusal(play, .redo), .action("nothing-to-redo"))
        try play.undo()
        try Self.act(&play, .step(1))
        XCTAssertFalse(play.canRedo, "a step clears redo too")
    }

    // MARK: - 6. Stage table

    func testEveryStageEventPairFollowsTheTable() throws {
        for stage in ColorfallCanyonsStage.allCases {
            for event in Self.events {
                let play = try Self.play(in: stage)
                let expected: ColorfallCanyonsStage?
                switch (stage, event) {
                case (.loading, .begin): expected = .playing
                case (.tutorial, .dismissTutorial): expected = .playing
                case (.playing, .pause): expected = .paused
                case (.paused, .resume): expected = .playing
                case (.won, .showResult), (.failed, .showResult): expected = .result
                default: expected = nil
                }
                if let expected {
                    var moved = play
                    try moved.handle(event)
                    XCTAssertEqual(moved.stage, expected, "\(stage) --\(event)-->")
                    XCTAssertEqual(moved.fluid, play.fluid)
                    XCTAssertEqual(moved.records, play.records, "events are not recorded")
                } else {
                    XCTAssertEqual(refusal(play, .event(event)), .stage, "\(stage) --\(event)-->")
                }
            }
        }
        var tutorial = Play(level: try Self.winnable(tutorial: true))
        try tutorial.handle(.begin)
        XCTAssertEqual(tutorial.stage, .tutorial, "loading --begin--> tutorial when the level asks for one")
    }

    // MARK: - 7. Fingerprint

    /// The documented fingerprint layout, computed independently from the given parts.
    private static func reference(level: ColorfallCanyonsLevel, tick: Int, heights: [Int], valves: [Bool],
                                  supplies: [Int], masses: [[Int]], spilled: [Int], spent: Int,
                                  stage: ColorfallCanyonsStage, failure: ColorfallCanyonsFailure?) -> String {
        var bytes: [UInt8] = [1]
        bytes += Array(level.fingerprint.utf8)
        bytes += [UInt8(tick >> 24 & 0xFF), UInt8(tick >> 16 & 0xFF), UInt8(tick >> 8 & 0xFF), UInt8(tick & 0xFF)]
        for h in heights { bytes.append(UInt8(h)) }
        for v in valves { bytes.append(v ? 1 : 0) }
        var pairs: [Int] = supplies
        for cell in masses { pairs += cell }
        pairs += spilled
        for value in pairs { bytes += [UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)] }
        bytes.append(UInt8(spent))
        bytes += Array(stage.rawValue.utf8)
        if let failure {
            bytes.append(0)
            bytes += Array(failure.rawValue.utf8)
        }
        return StableHash.sha256Hex(bytes)
    }

    private static func reference(_ play: Play) -> String {
        let f = play.fluid
        return reference(level: play.level, tick: f.tick, heights: f.heights, valves: f.valves, supplies: f.supplies,
                         masses: f.masses, spilled: f.spilled, spent: play.spent, stage: play.stage,
                         failure: play.failure)
    }

    func testTheFingerprintCoversEveryPartOfThePlay() throws {
        for stage in ColorfallCanyonsStage.allCases {
            let play = try Self.play(in: stage)
            XCTAssertEqual(play.fingerprint, Self.reference(play), "\(stage)")
        }
        var play = try Self.playing(try Self.hand(color: .coral, budget: 5))
        var seen: Set<String> = [play.fingerprint]
        for action in [ColorfallCanyonsAction.step(3), .carve(2), .valve(0), .step(1), .carve(5)] {
            try Self.act(&play, action)
            XCTAssertEqual(play.fingerprint, Self.reference(play), "\(action)")
            XCTAssertTrue(seen.insert(play.fingerprint).inserted, "\(action) changes the fingerprint")
        }
        try play.handle(.pause)
        XCTAssertTrue(seen.insert(play.fingerprint).inserted, "the stage changes the fingerprint")
        XCTAssertEqual(play.fingerprint, Self.reference(play))
        XCTAssertGreaterThan(play.fluid.volume(1), 0)

        let f = play.fluid
        let base: String = Self.reference(play)
        var variants: [String: String] = [:]
        func vary(_ name: String, tick: Int? = nil, heights: [Int]? = nil, valves: [Bool]? = nil,
                  supplies: [Int]? = nil, masses: [[Int]]? = nil, spilled: [Int]? = nil, spent: Int? = nil,
                  stage: ColorfallCanyonsStage? = nil, failure: ColorfallCanyonsFailure? = nil) {
            variants[name] = Self.reference(level: play.level, tick: tick ?? f.tick, heights: heights ?? f.heights,
                                            valves: valves ?? f.valves, supplies: supplies ?? f.supplies,
                                            masses: masses ?? f.masses, spilled: spilled ?? f.spilled,
                                            spent: spent ?? play.spent, stage: stage ?? play.stage,
                                            failure: failure ?? play.failure)
        }
        vary("tick", tick: f.tick + 1)
        for cell in f.heights.indices {
            var h = f.heights
            h[cell] = h[cell] == 15 ? 14 : h[cell] + 1
            vary("height \(cell)", heights: h)
        }
        vary("valve", valves: f.valves.map { !$0 })
        vary("supply", supplies: f.supplies.map { $0 + 1 })
        for cell in f.masses.indices {
            for c in 0..<3 {
                var m = f.masses
                m[cell][c] += 1
                vary("mass \(cell).\(c)", masses: m)
            }
        }
        for c in 0..<3 {
            var s = f.spilled
            s[c] += 1
            vary("spilled \(c)", spilled: s)
        }
        vary("spent", spent: play.spent + 1)
        vary("stage", stage: .playing)
        vary("failure", stage: .failed, failure: .time)
        vary("other failure", stage: .failed, failure: .overflow)
        var distinct: Set<String> = [base]
        for (name, value) in variants.sorted(by: { $0.key < $1.key }) {
            XCTAssertNotEqual(value, base, name)
            XCTAssertTrue(distinct.insert(value).inserted, "\(name) collides")
        }
    }

    /// Agent B's finding (2026-11-21): an undo or redo made while paused, and an action after resuming, replay.
    func testUndoAndRedoWhilePausedReplay() throws {
        let level = ColorfallCanyonsFixtures.fixture(0).level
        var play = ColorfallCanyonsPlay(level: level)
        try play.handle(.begin)
        try play.apply(.step(1), expecting: play.fingerprint)
        try play.apply(.step(2), expecting: play.fingerprint)
        try play.handle(.pause)
        try play.undo()
        try play.redo()
        try play.undo()
        try play.handle(.resume)
        try play.apply(.step(1), expecting: play.fingerprint)
        let replayed = try ColorfallCanyonsPlay.replay(level: level, records: play.records)
        XCTAssertEqual(replayed.records, play.records)
        XCTAssertEqual(replayed.fingerprint, play.fingerprint)
    }
}
