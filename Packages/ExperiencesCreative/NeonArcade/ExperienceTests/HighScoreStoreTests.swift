// HighScoreStoreTests — feature 078 (A10-P04) T-A10-403 (FR-A10-411, FR-A10-412, FR-A10-413; SC-A10-402,
// SC-A10-403; clarifications 2 and 3; research D2 and D3; edge case "Storage full or refused"). The high-score table
// in a temporary `ExperienceStorage`, short and on files only: a table round-trips through `high-scores.json` and a
// run is entered once; an interrupted save — a partial file under the hidden temporary name of an atomic write beside
// the table — leaves the last complete table readable, while a truncated copy is reported as damaged; a damaged,
// truncated, newer or invalid file is reported, play goes on with an empty table and the next finished run writes a
// valid one; a refused storage is reported once and the table stays in memory; an ending watched after the core's run
// number restarted is entered under the next number; the new entry is marked.
import Foundation
import XCTest
@testable import NeonArcadeExperience
import NeonArcadeCore
import VisualCoreExperience

final class HighScoreStoreTests: XCTestCase {
    private var temporary: TemporaryArcadeStorage!

    override func setUp() {
        temporary = TemporaryArcadeStorage()
    }

    override func tearDown() {
        temporary.remove()
    }

    private var storage: ExperienceStorage { temporary.storage }

    /// The stored table, decoded.
    private func storedTable() throws -> HighScoreTable {
        try HighScoreTable.decode(storage.read(HighScoreStore.fileName)).get()
    }

    /// A table round-trips through its storage file; a run is entered once; a run that is not over is ignored.
    func testATableRoundTripsThroughStorageAndARunIsEnteredOnce() throws {
        let store = HighScoreStore(storage: storage)
        XCTAssertNil(store.problem, "no file is no problem")
        XCTAssertEqual(store.table, HighScoreTable())
        XCTAssertNil(store.record(run: GameRun.new(), number: 1), "a run that is not over is not entered")
        XCTAssertEqual(store.writes, 0)

        XCTAssertEqual(store.record(run: ArcadeTest.finishedRun(score: 120, wave: 2), number: 1), 0)
        XCTAssertEqual(store.record(run: ArcadeTest.finishedRun(score: 300, wave: 3), number: 2), 0)
        XCTAssertEqual(store.record(run: ArcadeTest.finishedRun(score: 120, wave: 1), number: 3), 2,
                       "a tie ranks below")
        XCTAssertNil(store.record(run: ArcadeTest.finishedRun(score: 300, wave: 3), number: 2), "run 2 again")
        XCTAssertNil(store.record(run: ArcadeTest.finishedRun(score: 0), number: 4), "a run that scores 0")
        XCTAssertEqual(store.writes, 4, "every processed run writes (run 4 moves the last run)")
        XCTAssertEqual(store.table.entries.map(\.run), [2, 1, 3])
        XCTAssertEqual(store.table.lastRun, 4)
        XCTAssertEqual(storage.list(), [HighScoreStore.fileName], "one file, no temporary file left")

        let reopened = HighScoreStore(storage: storage)
        XCTAssertNil(reopened.problem)
        XCTAssertEqual(reopened.table, store.table)
        XCTAssertEqual(try storedTable(), store.table)
        XCTAssertNil(reopened.record(run: ArcadeTest.finishedRun(score: 999), number: 3),
                     "a reopened table still knows run 3 was entered")
        XCTAssertEqual(reopened.writes, 0)
        let data = try storage.read(HighScoreStore.fileName)
        XCTAssertEqual(data, store.table.encoded(), "JSON with sorted keys")
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        for word in ["date", "name", "device"] { XCTAssertFalse(text.contains(word), "no \(word) is kept") }
    }

    /// An interrupted save: a partial file under the atomic write's hidden temporary name beside the table leaves the
    /// last complete table readable; a truncated copy is reported as damaged; a truncated table file is reported and
    /// the next finished run writes a valid table.
    func testAnInterruptedSaveLeavesTheLastCompleteTable() throws {
        let store = HighScoreStore(storage: storage)
        XCTAssertEqual(store.record(run: ArcadeTest.finishedRun(score: 500, wave: 4), number: 1), 0)
        XCTAssertEqual(store.record(run: ArcadeTest.finishedRun(score: 250, wave: 2), number: 2), 1)
        let complete = store.table

        // The save of run 3 is killed after half of the new table reached its temporary file.
        var next = complete
        XCTAssertEqual(next.enter(HighScoreEntry(score: 900, wave: 6, run: 3)), 0)
        let newBytes = next.encoded()
        let partial = newBytes.prefix(newBytes.count / 2)
        let hidden = temporary.folder.appendingPathComponent(".\(HighScoreStore.fileName).tmp-"
                                                             + "00000000-0000-4000-8000-000000000003")
        try Data(partial).write(to: hidden)
        XCTAssertEqual(storage.list(), [HighScoreStore.fileName], "the temporary file is hidden")
        let afterKill = HighScoreStore(storage: storage)
        XCTAssertNil(afterKill.problem)
        XCTAssertEqual(afterKill.table, complete, "the last complete table")

        // A truncated copy of the table does not read: damaged.
        let stored = try storage.read(HighScoreStore.fileName)
        try storage.write(stored.prefix(stored.count - 7), to: "high-scores-copy.json")
        XCTAssertEqual(HighScoreTable.decode(try storage.read("high-scores-copy.json")), .failure(.damaged))
        XCTAssertEqual(HighScoreTable.decode(stored), .success(complete), "the original still reads")

        // A truncated table file on its own is reported; play goes on with an empty table; the next run writes.
        try storage.write(stored.prefix(stored.count / 2), to: HighScoreStore.fileName)
        let damaged = HighScoreStore(storage: storage)
        XCTAssertEqual(damaged.problem, HighScoreStore.readProblem + ": " + HighScoreTableError.damaged.reason)
        XCTAssertEqual(damaged.reports.count, 1)
        XCTAssertEqual(damaged.table, HighScoreTable())
        XCTAssertEqual(try storage.read(HighScoreStore.fileName).count, stored.count / 2, "left in place")
        XCTAssertEqual(damaged.record(run: ArcadeTest.finishedRun(score: 40), number: 1), 0)
        XCTAssertNil(damaged.problem, "a valid table was written")
        XCTAssertEqual(try storedTable(), damaged.table)
        XCTAssertEqual(damaged.reports.count, 1, "reported once")
    }

    /// A newer or invalid file is reported, play continues with an empty table and the next run writes a valid one.
    func testANewerOrInvalidFileIsReportedAndThenReplaced() throws {
        let newer = Data(#"{"boardVersion":2,"entries":[],"lastRun":0}"#.utf8)
        let outOfOrder = HighScoreTable(entries: [HighScoreEntry(score: 10, wave: 1, run: 1),
                                                  HighScoreEntry(score: 50, wave: 1, run: 2)], lastRun: 2).encoded()
        for (name, data, word) in [("newer", newer, "newer"), ("invalid", outOfOrder, "out of order")] {
            try storage.write(data, to: HighScoreStore.fileName)
            let store = HighScoreStore(storage: storage)
            let problem = try XCTUnwrap(store.problem, name)
            XCTAssertTrue(problem.hasPrefix(HighScoreStore.readProblem), problem)
            XCTAssertTrue(problem.contains(word), problem)
            XCTAssertEqual(store.table, HighScoreTable(), name)
            XCTAssertEqual(store.record(run: ArcadeTest.finishedRun(score: 70, wave: 2), number: 3), 0, name)
            XCTAssertNil(store.problem, name)
            XCTAssertEqual(try storedTable().entries, [HighScoreEntry(score: 70, wave: 2, run: 3)], name)
        }
    }

    /// A storage that refuses writes is reported once; the table stays in memory for the session.
    func testARefusedStorageIsReportedOnceAndTheTableStaysInMemory() throws {
        // The root is a regular file, so the experience's folder cannot be created.
        try Data("x".utf8).write(to: temporary.root)
        let store = HighScoreStore(storage: storage)
        XCTAssertNil(store.problem, "nothing stored yet is no problem")
        XCTAssertEqual(store.record(run: ArcadeTest.finishedRun(score: 80), number: 1), 0)
        let problem = try XCTUnwrap(store.problem)
        XCTAssertTrue(problem.hasPrefix(HighScoreStore.saveProblem), problem)
        XCTAssertEqual(store.record(run: ArcadeTest.finishedRun(score: 95), number: 2), 0)
        XCTAssertEqual(store.reports, [problem], "reported once")
        XCTAssertEqual(store.writes, 0)
        XCTAssertEqual(store.table.entries.map(\.score), [95, 80], "kept in memory")
    }

    /// An ending watched while drawn whose run number the table has processed (the core's count restarted after a
    /// reset) is entered under the next number; the same ending not watched (a restored game-over screen) is not.
    /// The new entry is marked, and no mark remains after a run that did not rank.
    func testAWatchedEndingAfterARestartedCountIsEnteredAndMarked() {
        let store = HighScoreStore(storage: nil)
        for number in 1...3 {
            XCTAssertNotNil(store.record(run: ArcadeTest.finishedRun(score: 100 * number), number: number))
        }
        XCTAssertEqual(store.newEntry, HighScoreEntry(score: 300, wave: 1, run: 3))
        XCTAssertEqual(store.newEntryIndex, 0)
        XCTAssertNil(store.record(run: ArcadeTest.finishedRun(score: 150), number: 1), "a restored ending")
        XCTAssertEqual(store.record(run: ArcadeTest.finishedRun(score: 150), number: 1, live: true), 2)
        XCTAssertEqual(store.table.entries.map(\.run), [3, 2, 4, 1])
        XCTAssertEqual(store.table.lastRun, 4)
        XCTAssertEqual(store.newEntryIndex, 2)
        for number in 5...11 { store.record(run: ArcadeTest.finishedRun(score: 1_000 + number), number: number) }
        XCTAssertEqual(store.table.entries.count, HighScoreTable.maxEntries)
        XCTAssertEqual(store.newEntryIndex, 0)
        XCTAssertNil(store.record(run: ArcadeTest.finishedRun(score: 1), number: 12), "does not rank")
        XCTAssertNil(store.newEntry)
        XCTAssertNil(store.newEntryIndex)
        XCTAssertEqual(store.writes, 0, "without storage the table is kept in memory only")
    }
}
