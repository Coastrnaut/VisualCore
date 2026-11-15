// AquariumLibraryTests — feature 072 (A09-P05) T-A09-505 (FR-A09-501, 502; SC-A09-501; edge cases "Saving with an
// empty or very long name", "Two saves with the same name", "A saved file of a newer format"). The library of saved
// aquariums in a temporary experience storage, short runs only: save, list, open in a new session (habitat, decor
// kinds, positions within 1e-9, rotations, scales, lighting, decoration kind and ambient rebuilt through the action
// port) and delete; name cleaning and duplicate names; the 13th save refused with no new file; damaged, foreign,
// invalid and newer files counted and left byte-identical; a save the storage quota refuses names the storage code
// and changes no file.
import Foundation
import XCTest
@testable import DigitalAquariumExperience
import DigitalAquariumCore
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class AquariumLibraryTests: XCTestCase {
    private var storage: ExperienceStorage!
    private var cleanUp: (@Sendable () -> Void)?

    override func setUpWithError() throws {
        let suite = "dev.visualcore.a09-p05.library.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        storage = ExperienceStorage(id: ExperienceID(rawValue: "a09.library-test")!, root: root, defaults: defaults)
        cleanUp = {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
    }

    override func tearDown() {
        cleanUp?()
    }

    /// A synthetic identity ending in `n`.
    private func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012ld", n))!
    }

    /// The library files in the storage.
    private func libraryFiles() -> [String] {
        storage.list().filter { $0.hasPrefix("aquarium-") }.sorted()
    }

    func testSaveListOpenInANewSessionAndDelete() async throws {
        let catalog = AquariumCore.catalog
        try XCTSkipIf(catalog.habitats.count < 2 || catalog.decor.count < 2, "the catalog needs two of each")
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session)
        // Arrange: the second habitat, its starter decor kept, one piece placed, turned and scaled, bright, ambient.
        let actions: [(String, [Double])] = [
            ("habitat.select", [1]), ("decor.kind", [1]), ("decor.place", [0.3, 0.4]),
            ("lighting.level", [2]), ("decor.kind", [0]), ("ambient.mode", [1]),
        ]
        for (control, values) in actions {
            XCTAssertTrue(shell.handle(control: control, values: values).isAccepted, control)
        }
        let placed = try AquariumTest.core(shell).state.document.decor.count - 1
        XCTAssertTrue(shell.handle(control: "decor.turn", values: [Double(placed), -2.5, 1.75]).isAccepted)
        let expected = try AquariumTest.core(shell).state

        let library = AquariumLibrary(storage: storage)
        XCTAssertEqual(library.entries, [])
        let when = Date(timeIntervalSinceReferenceDate: 2_000)
        XCTAssertTrue(library.save(name: "  Kelp evening ", core: try AquariumTest.core(shell), now: when,
                                   id: uuid(1)))
        XCTAssertNil(library.lastFailure)
        XCTAssertEqual(libraryFiles(), ["aquarium-00000000-0000-4000-8000-000000000001.json"])
        session.close()

        // A new session starts on the first habitat; a new library lists the save and opens it.
        let next = ExperienceSession()
        let reopened = try await AquariumTest.open(next)
        XCTAssertEqual(try AquariumTest.core(reopened).state.document.habitatIndex, 0)
        let listing = AquariumLibrary(storage: storage)
        XCTAssertEqual(listing.unreadable, 0)
        XCTAssertEqual(listing.newer, 0)
        let saved = try XCTUnwrap(listing.entry(uuid(1)))
        XCTAssertEqual(saved.name, "Kelp evening")
        XCTAssertEqual(saved.savedAt, when)
        XCTAssertTrue(listing.open(saved, port: reopened.port), listing.lastFailure ?? "")
        XCTAssertNil(listing.lastFailure)

        let rebuilt = try AquariumTest.core(reopened).state
        XCTAssertEqual(rebuilt.document.habitatIndex, 1)
        XCTAssertEqual(rebuilt.document.habitatId, expected.document.habitatId)
        XCTAssertEqual(rebuilt.document.lighting, 2)
        XCTAssertEqual(rebuilt.decorKind, 0)
        XCTAssertTrue(rebuilt.ambient)
        XCTAssertEqual(rebuilt.document.decor.count, expected.document.decor.count)
        for (got, want) in zip(rebuilt.document.decor, expected.document.decor) {
            XCTAssertEqual(got.kindId, want.kindId)
            XCTAssertEqual(got.position.x, want.position.x, accuracy: 1e-9)
            XCTAssertEqual(got.position.y, want.position.y, accuracy: 1e-9)
            XCTAssertEqual(got.rotation, want.rotation)
            XCTAssertEqual(got.scale, want.scale)
        }
        XCTAssertEqual(rebuilt.document.decor.last?.rotation, -2.5)
        XCTAssertEqual(rebuilt.document.decor.last?.scale, 1.75)

        // Delete removes the file; a second delete names the storage code.
        XCTAssertTrue(listing.delete(saved.id))
        XCTAssertEqual(listing.entries, [])
        XCTAssertEqual(libraryFiles(), [])
        XCTAssertFalse(listing.delete(saved.id))
        XCTAssertTrue(try XCTUnwrap(listing.lastFailure).contains("storage.not-found"))
        next.close()
    }

    func testNamesAreCleanedAndDuplicatesAreKeptInOrder() throws {
        let library = AquariumLibrary(storage: storage)
        let core = AquariumCore(seed: 7)
        XCTAssertTrue(library.save(name: "   ", core: core, id: uuid(1)))
        XCTAssertTrue(library.save(name: String(repeating: "z", count: 60), core: core, id: uuid(2)))
        XCTAssertTrue(library.save(name: "same", core: core, id: uuid(4)))
        XCTAssertTrue(library.save(name: "Same", core: core, id: uuid(3)))
        XCTAssertTrue(library.save(name: "apple", core: core, id: uuid(5)))
        XCTAssertEqual(library.entries.map(\.name),
                       ["apple", "My aquarium", "Same", "same", String(repeating: "z", count: 40)])
        XCTAssertEqual(library.entries.map(\.id), [uuid(5), uuid(1), uuid(3), uuid(4), uuid(2)],
                       "equal names ignoring case are ordered by id")
        XCTAssertEqual(libraryFiles().count, 5)
    }

    func testTheThirteenthSaveIsRefusedWithNoNewFile() throws {
        let library = AquariumLibrary(storage: storage)
        let core = AquariumCore(seed: 7)
        for i in 1...AquariumLibrary.maxEntries {
            XCTAssertTrue(library.save(name: "Tank \(i)", core: core, id: uuid(i)))
        }
        XCTAssertEqual(library.entries.count, 12)
        let before = storage.list()
        XCTAssertFalse(library.save(name: "One too many", core: core, id: uuid(13)))
        XCTAssertEqual(library.lastFailure, "Couldn't save the aquarium: the library already holds 12 aquariums.")
        XCTAssertEqual(storage.list(), before)
        XCTAssertFalse(storage.exists(AquariumLibrary.fileName(for: uuid(13))))
        XCTAssertEqual(library.entries.count, 12)
    }

    func testDamagedForeignInvalidAndNewerFilesAreCountedAndKept() throws {
        let catalog = AquariumCore.catalog
        let valid = AquariumConfiguration.make(document: AquariumCore(seed: 7).state.document, decorKind: 0,
                                               ambient: false, name: "Valid", id: uuid(1),
                                               savedAt: Date(timeIntervalSinceReferenceDate: 5))
        XCTAssertEqual(valid.validate(catalog: catalog), [])
        var newerObject = try XCTUnwrap(JSONSerialization.jsonObject(with: valid.fileData()) as? [String: Any])
        newerObject["format"] = 2
        newerObject["id"] = uuid(2).uuidString
        let newer = try JSONSerialization.data(withJSONObject: newerObject, options: [.sortedKeys])
        var invalid = valid
        invalid.id = uuid(5)
        invalid.lighting = 7
        let planted: [(String, Data)] = [
            (AquariumLibrary.fileName(for: uuid(3)), Data("{not json".utf8)),
            (AquariumLibrary.fileName(for: uuid(2)), newer),
            // Valid content under another id's name.
            (AquariumLibrary.fileName(for: uuid(4)), try valid.fileData()),
            (AquariumLibrary.fileName(for: uuid(5)), try invalid.fileData()),
            (AquariumLibrary.fileName(for: uuid(1)), try valid.fileData()),
        ]
        for (name, data) in planted { try storage.write(data, to: name) }
        let library = AquariumLibrary(storage: storage)
        XCTAssertEqual(library.unreadable, 3, "damaged, mismatched id, invalid")
        XCTAssertEqual(library.newer, 1)
        XCTAssertEqual(library.entries, [valid])

        // A save and a reload leave every planted file byte-identical.
        XCTAssertTrue(library.save(name: "Another", core: AquariumCore(seed: 7), id: uuid(6)))
        library.reload()
        XCTAssertEqual(library.unreadable, 3)
        XCTAssertEqual(library.newer, 1)
        XCTAssertEqual(library.entries.map(\.id), [uuid(6), uuid(1)])
        for (name, data) in planted {
            XCTAssertEqual(try storage.read(name), data, name)
        }
    }

    func testASaveTheStorageRefusesChangesNoFile() throws {
        for i in 0..<StorageQuota.maxFiles {
            try storage.write(Data("x".utf8), to: "other-\(i).bin")
        }
        let library = AquariumLibrary(storage: storage)
        let before = storage.list()
        XCTAssertFalse(library.save(name: "Full", core: AquariumCore(seed: 7), id: uuid(1)))
        let message = try XCTUnwrap(library.lastFailure)
        XCTAssertTrue(message.hasPrefix("Couldn't save the aquarium: "), message)
        XCTAssertTrue(message.contains(StorageError.quotaExceeded("files").code), message)
        XCTAssertEqual(storage.list(), before)
        XCTAssertEqual(library.entries, [])
    }

    func testOpenStopsAtTheFirstRefusalAndRefusesAnInvalidConfiguration() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session)
        let library = AquariumLibrary(storage: storage)
        var broken = AquariumConfiguration.make(document: try AquariumTest.core(shell).state.document, decorKind: 0,
                                                ambient: false, name: "Broken", id: uuid(1),
                                                savedAt: Date(timeIntervalSinceReferenceDate: 0))
        broken.lighting = 9
        let before = try AquariumTest.core(shell).state
        XCTAssertFalse(library.open(broken, port: shell.port))
        XCTAssertTrue(try XCTUnwrap(library.lastFailure).hasPrefix("Couldn't open the aquarium: "))
        XCTAssertEqual(try AquariumTest.core(shell).state.document, before.document, "nothing was sent")
        session.close()
    }
}
