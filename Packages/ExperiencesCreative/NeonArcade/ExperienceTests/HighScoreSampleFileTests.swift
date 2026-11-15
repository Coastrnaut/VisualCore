// HighScoreSampleFileTests — feature 080 (A10-P06) T-A10-605 (FR-A10-610; SC-A10-602; US2; clarification Q4). The
// four committed high-score samples (`Fixtures/`, bundled with `resources: [.copy("Fixtures")]`, T-A10-604), each
// copied as `high-scores.json` into a temporary experience storage and read by a `HighScoreStore`: the valid sample
// (board version 1, three entries, the exact bytes `HighScoreTable.encoded()` writes) is shown with no problem; the
// newer (board version 2), damaged (not JSON) and truncated (the valid file cut in half) samples are reported, play
// goes on with an empty table, and the file stays byte for byte as committed after a reload (a new store); the next
// finished run then writes a valid table in its place. Files only, well under 1 s.
import Foundation
import XCTest
@testable import NeonArcadeExperience
import NeonArcadeCore
import VisualCoreExperience

final class HighScoreSampleFileTests: XCTestCase {
    private var temporary: TemporaryArcadeStorage!

    override func setUp() {
        temporary = TemporaryArcadeStorage()
    }

    override func tearDown() {
        temporary.remove()
    }

    private var storage: ExperienceStorage { temporary.storage }

    /// The committed bytes of the bundled sample `name` (`Fixtures/<name>`).
    private func sample(_ name: String) throws -> Data {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil),
                                   "missing Fixtures folder")
        return try Data(contentsOf: folder.appendingPathComponent(name))
    }

    /// Writes `bytes` as the experience's `high-scores.json`.
    private func install(_ bytes: Data) throws {
        try storage.write(bytes, to: HighScoreStore.fileName)
    }

    /// The four samples are bundled, and nothing else.
    func testExactlyTheFourSamplesAreBundled() throws {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }
        XCTAssertEqual(Set(names), ["high-scores-valid.json", "high-scores-newer.json", "high-scores-damaged.json",
                                    "high-scores-truncated.json"])
    }

    /// The valid sample is the file form of a three-entry board-1 table and is shown with no problem.
    func testTheValidSampleIsShown() throws {
        let bytes = try sample("high-scores-valid.json")
        let expected = HighScoreTable(entries: [HighScoreEntry(score: 4200, wave: 5, run: 2),
                                                HighScoreEntry(score: 1800, wave: 3, run: 3),
                                                HighScoreEntry(score: 950, wave: 2, run: 1)], lastRun: 3)
        XCTAssertEqual(expected.validate(), [])
        XCTAssertEqual(bytes, expected.encoded(), "the sample has the exact shape encoded() writes (sorted keys)")

        try install(bytes)
        let store = HighScoreStore(storage: storage)
        XCTAssertNil(store.problem)
        XCTAssertEqual(store.reports, [])
        XCTAssertEqual(store.table, expected)
        XCTAssertEqual(store.table.entries.count, 3)
        XCTAssertEqual(store.best, HighScoreEntry(score: 4200, wave: 5, run: 2))
        XCTAssertEqual(try storage.read(HighScoreStore.fileName), bytes, "reading never rewrites the file")

        // The next finished run is entered after the stored last run and saved as a valid table.
        XCTAssertEqual(store.record(run: ArcadeTest.finishedRun(score: 2500, wave: 4), number: 4), 1)
        let saved = try HighScoreTable.decode(storage.read(HighScoreStore.fileName)).get()
        XCTAssertEqual(saved.entries.map(\.run), [2, 4, 3, 1])
        XCTAssertEqual(saved.lastRun, 4)
    }

    /// The newer, damaged and truncated samples are reported with an empty table, stay byte-identical after a reload,
    /// and the next finished run replaces them with a valid table.
    func testTheRefusedSamplesAreReportedKeptAndThenReplaced() throws {
        let cases: [(name: String, error: HighScoreTableError)] = [
            ("high-scores-newer.json", .newerVersion(2)),
            ("high-scores-damaged.json", .damaged),
            ("high-scores-truncated.json", .damaged),
        ]
        let valid = try sample("high-scores-valid.json")
        for (name, error) in cases {
            let bytes = try sample(name)
            if name.contains("truncated") {
                XCTAssertEqual(bytes, valid.prefix(valid.count / 2), "the truncated sample is the valid one cut in half")
            }
            guard case .failure(let failure) = HighScoreTable.decode(bytes) else {
                XCTFail("\(name) decodes")
                continue
            }
            XCTAssertEqual(failure, error, name)

            try install(bytes)
            let store = HighScoreStore(storage: storage)
            let problem = try XCTUnwrap(store.problem, "\(name) is reported")
            XCTAssertEqual(problem, HighScoreStore.readProblem + ": " + error.reason, name)
            XCTAssertEqual(store.reports, [problem], "\(name) is reported once")
            XCTAssertEqual(store.table, HighScoreTable(), "\(name): play goes on with an empty table")
            XCTAssertNil(store.best)
            XCTAssertEqual(try storage.read(HighScoreStore.fileName), bytes, "\(name) is unchanged after loading")

            let reloaded = HighScoreStore(storage: storage)
            XCTAssertEqual(reloaded.problem, problem, "\(name) is reported again by a new store")
            XCTAssertEqual(reloaded.table, HighScoreTable())
            XCTAssertEqual(try storage.read(HighScoreStore.fileName), bytes, "\(name) is unchanged after a reload")

            // A finished run writes a valid table in place of the refused file and clears the problem.
            XCTAssertEqual(reloaded.record(run: ArcadeTest.finishedRun(score: 640, wave: 3), number: 1), 0)
            XCTAssertNil(reloaded.problem, "\(name): the problem clears once a valid table is written")
            XCTAssertEqual(reloaded.writes, 1)
            let written = try storage.read(HighScoreStore.fileName)
            XCTAssertNotEqual(written, bytes)
            let table = try HighScoreTable.decode(written).get()
            XCTAssertEqual(table.entries, [HighScoreEntry(score: 640, wave: 3, run: 1)])
            XCTAssertEqual(table.lastRun, 1)
            XCTAssertEqual(written, table.encoded())
            XCTAssertNil(HighScoreStore(storage: storage).problem, "\(name): the replacement reads back")
            XCTAssertEqual(storage.list(), [HighScoreStore.fileName], "one file, no temporary file left")
        }
    }
}
