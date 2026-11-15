// ProgressSampleFileTests — feature 101 (A13-P06) T-A13-605 (FR-A13-610, FR-A13-612; SC-A13-602; clarification Q5;
// research D3).
// The four committed saved-progress samples (`Fixtures/`, bundled with `resources: [.copy("Fixtures")]`), each copied
// as `progress.json` into a temporary experience storage and loaded by a `ProgressStore`: the valid sample (the exact
// bytes `Progress.encoded()` gives after level 1 is solved in 1 move) loads with level 1 solved (best 1), level 2 open
// and level 3 locked; the newer (`"schema":2`), damaged (not JSON) and truncated (the valid file cut in half) samples
// are refused as `newer-version`, `damaged` and `damaged` and give fresh progress; every file stays byte for byte as
// committed (loading never writes). The stored schema-1 state example `MazeCore.schemaOneExample()` restores to its
// expected digest. Files and one engine per test, well under a second each.
import Foundation
import XCTest
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreExperience

@MainActor
final class ProgressSampleFileTests: XCTestCase {
    private var temporary: TemporaryMazeStorage!

    override func setUp() async throws {
        temporary = TemporaryMazeStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    private var storage: ExperienceStorage { temporary.storage }

    /// The committed bytes of the bundled sample `name` (`Fixtures/<name>`).
    private func sample(_ name: String) throws -> Data {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil),
                                   "missing Fixtures folder")
        return try Data(contentsOf: folder.appendingPathComponent(name))
    }

    /// Writes `bytes` as the experience's `progress.json`.
    private func install(_ bytes: Data) throws {
        try storage.write(bytes, to: ProgressStore.fileName)
    }

    /// The progress the valid sample holds: level 1 solved in 1 move.
    private func expectedProgress() -> LightMazeCore.Progress {
        var progress = LightMazeCore.Progress.fresh()
        XCTAssertTrue(progress.recordSolved(levelIndex: 0, moves: 1))
        return progress
    }

    func testExactlyTheFourSamplesAreBundled() throws {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }
        XCTAssertEqual(Set(names), ["progress-valid.json", "progress-newer.json", "progress-damaged.json",
                                    "progress-truncated.json"])
    }

    func testTheValidSampleLoadsWithLevelOneSolved() throws {
        let valid = try sample("progress-valid.json")
        XCTAssertEqual(valid, expectedProgress().encoded(), "exactly the bytes Progress.encoded() writes")
        try install(valid)
        let store = ProgressStore(storage: storage)
        let loaded = store.load()
        XCTAssertNil(loaded.refusal)
        XCTAssertEqual(loaded.progress.encoded(), valid)
        XCTAssertTrue(loaded.progress.isSolved(0), "level 1 solved")
        XCTAssertEqual(loaded.progress.best(0), 1, "level 1 best 1")
        XCTAssertTrue(loaded.progress.isOpen(1), "level 2 open")
        XCTAssertFalse(loaded.progress.isSolved(1))
        XCTAssertFalse(loaded.progress.isOpen(2), "level 3 locked")
        XCTAssertEqual(try storage.read(ProgressStore.fileName), valid, "loading never rewrites the file")
        XCTAssertEqual(store.writes, 0)
    }

    func testTheRefusedSamplesGiveFreshProgressAndStayByteIdentical() throws {
        let valid = try sample("progress-valid.json")
        XCTAssertEqual(try sample("progress-truncated.json"), valid.prefix(valid.count / 2),
                       "the valid file cut in half")
        let cases: [(name: String, refusal: String)] = [
            ("progress-newer.json", "newer-version"),
            ("progress-damaged.json", "damaged"),
            ("progress-truncated.json", "damaged"),
        ]
        let fresh = LightMazeCore.Progress.fresh().encoded()
        let store = ProgressStore(storage: storage)
        for item in cases {
            let bytes = try sample(item.name)
            try install(bytes)
            let loaded = store.load()
            XCTAssertEqual(loaded.refusal, item.refusal, item.name)
            XCTAssertEqual(loaded.progress.encoded(), fresh, "\(item.name): fresh progress")
            XCTAssertEqual(try storage.read(ProgressStore.fileName), bytes, "\(item.name): byte-identical")
        }
        XCTAssertEqual(store.writes, 0, "loading never writes")
        XCTAssertEqual(storage.list(), [ProgressStore.fileName])
    }

    func testTheSchemaOneStateExampleRestores() async throws {
        let example = try XCTUnwrap(MazeCore.schemaOneExample())
        XCTAssertEqual(example.version, 1)
        let id = try XCTUnwrap(ExperienceID(rawValue: MazeCore.experienceID))
        let problems = await SnapshotMigrationCheck.problems(for: MazeCore.self, id: id, examples: [example])
        XCTAssertEqual(problems, [])
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(snapshot.schemaVersion, 1)
        var engine = ExperienceEngine<MazeCore>(id: id)
        try await engine.prepare(seed: snapshot.seed)
        try engine.activate()
        try engine.restore(snapshot)
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.state.levelIndex, 1)
        XCTAssertTrue(core.state.moves.isEmpty, "the step 1 → 2 adds no moves")
        XCTAssertEqual(try engine.digest().hex, example.expectedDigest)
    }
}
