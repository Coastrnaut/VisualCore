// PresetStoreTests — feature 120 (A16-P04) T-A16-408 (FR-A16-430; SC-A16-403). The saved experiments of Simulation
// Lab in a fresh experience storage: a round trip across a new store, the cap of 24 with its sentence, damaged and
// newer files reported and skipped, delete, and an invalid preset refused with its own sentence.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreRendering

/// A fresh experience storage of Simulation Lab under the temporary directory, removed by ``remove()`` (the
/// `TemporaryMoleculeStorage` pattern of Molecular Explorer).
struct TemporarySimulationStorage {
    /// The storage root.
    let root: URL
    /// The defaults suite name.
    let suite: String
    /// The experience's storage.
    let storage: ExperienceStorage

    /// A new empty storage under the temporary directory.
    init() {
        let name = "a16-presets-" + UUID().uuidString
        root = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        suite = name
        storage = ExperienceStorage(id: ExperienceID(rawValue: "a16.simulation-lab")!, root: root,
                                    defaults: UserDefaults(suiteName: name) ?? .standard)
    }

    /// Removes the folder and the defaults suite.
    func remove() {
        try? FileManager.default.removeItem(at: root)
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }
}

/// The preset library over a fresh storage.
@MainActor
final class PresetStoreTests: XCTestCase {
    /// The storage of the running test.
    private var temporary: TemporarySimulationStorage!

    /// A fresh storage per test.
    override func setUp() async throws {
        temporary = TemporarySimulationStorage()
    }

    /// Removes the storage.
    override func tearDown() async throws {
        temporary.remove()
        temporary = nil
    }

    /// A valid preset named `name` (the first bundled preset, renamed).
    private func preset(_ name: String) -> ExperimentPreset {
        var preset = ExperimentPreset.bundled[0]
        preset.name = name
        return preset
    }

    /// A saved preset is read back unchanged by a new store over the same storage.
    func testRoundTripAcrossStores() {
        let store = SimulationPresetStore(storage: temporary.storage)
        let id = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        XCTAssertNil(store.save(preset("Mine"), id: id))
        XCTAssertTrue(temporary.storage.exists("preset-00000000-0000-4000-8000-000000000001.json"))
        let again = SimulationPresetStore(storage: temporary.storage)
        XCTAssertEqual(again.entries, [SimulationPresetEntry(id: id, preset: preset("Mine"))])
        XCTAssertEqual(again.problems, [])
    }

    /// 24 saves are kept; the 25th is refused with the full sentence and writes nothing; replacing one still works.
    func testCapOfTwentyFour() {
        let store = SimulationPresetStore(storage: temporary.storage)
        var ids: [UUID] = []
        for index in 0..<SimulationPresetStore.cap {
            let id = UUID()
            ids.append(id)
            XCTAssertNil(store.save(preset("P\(index)"), id: id))
        }
        XCTAssertEqual(store.entries.count, 24)
        XCTAssertEqual(store.save(preset("Extra")), SimulationPresetStore.fullSentence)
        XCTAssertEqual(store.save(preset("Extra")), "The library holds 24 experiments; delete one first.")
        XCTAssertEqual(temporary.storage.list().count, 24)
        XCTAssertNil(store.save(preset("Renamed"), id: ids[0]))
        XCTAssertEqual(store.entries.count, 24)
    }

    /// A damaged file and a newer file are reported in `problems` and skipped; the valid one is listed.
    func testDamagedAndNewerFilesAreSkipped() throws {
        let damaged = "preset-00000000-0000-4000-8000-000000000002.json"
        let newer = "preset-00000000-0000-4000-8000-000000000003.json"
        try temporary.storage.write(Data([0xFF, 0x00, 0x7B, 0x13]), to: damaged)
        try temporary.storage.write(Data(#"{"schema":2}"#.utf8), to: newer)
        let store = SimulationPresetStore(storage: temporary.storage)
        XCTAssertNil(store.save(preset("Good")))
        XCTAssertEqual(store.entries.map(\.preset.name), ["Good"])
        XCTAssertEqual(store.problems, ["\(damaged): damaged", "\(newer): newer-version"])
        XCTAssertTrue(temporary.storage.exists(damaged), "a skipped file is never deleted")
    }

    /// Delete removes the file and the entry.
    func testDeleteRemoves() {
        let store = SimulationPresetStore(storage: temporary.storage)
        let id = UUID()
        XCTAssertNil(store.save(preset("Gone"), id: id))
        XCTAssertEqual(store.entries.count, 1)
        store.delete(id)
        XCTAssertEqual(store.entries, [])
        XCTAssertFalse(temporary.storage.exists(SimulationPresetStore.fileName(for: id)))
    }

    /// A name of 61 characters is refused with the preset's own sentence and writes nothing.
    func testInvalidPresetRefused() {
        let store = SimulationPresetStore(storage: temporary.storage)
        let invalid = preset(String(repeating: "a", count: 61))
        let sentence = invalid.problem()
        XCTAssertNotNil(sentence)
        XCTAssertEqual(store.save(invalid), sentence)
        XCTAssertEqual(store.entries, [])
        XCTAssertEqual(temporary.storage.list(), [])
    }

    /// Entries are sorted by name, then by id.
    func testSortedByNameThenId() {
        let store = SimulationPresetStore(storage: temporary.storage)
        let first = UUID(uuidString: "00000000-0000-4000-8000-000000000004")!
        let second = UUID(uuidString: "00000000-0000-4000-8000-000000000005")!
        XCTAssertNil(store.save(preset("Same"), id: second))
        XCTAssertNil(store.save(preset("Same"), id: first))
        XCTAssertNil(store.save(preset("Alpha")))
        XCTAssertEqual(store.entries.map(\.preset.name), ["Alpha", "Same", "Same"])
        XCTAssertEqual(store.entries.dropFirst().map(\.id), [first, second])
    }
}
