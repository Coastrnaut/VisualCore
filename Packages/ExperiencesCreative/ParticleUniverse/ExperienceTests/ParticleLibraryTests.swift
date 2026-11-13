// ParticleLibraryTests — feature 036 (A04-P04) T-A04-406 (FR-A04-405, FR-A04-414; US1; edge cases: name clashes,
// storage full, library limits). The library of named scenes in a temporary experience storage: save, list by name,
// open, rename (refused on a clash), delete, the numbered suffix on a name clash, unreadable files counted and kept,
// a relaunch over the same storage, and a save beyond the storage file limit that fails with a message and changes
// nothing.
import XCTest
import ParticleUniverseCore
@testable import ParticleUniverseExperience
import VisualCoreExperience

@MainActor
final class ParticleLibraryTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUpWithError() throws {
        suite = "dev.visualcore.a04-p04.library.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var storage: ExperienceStorage {
        ExperienceStorage(id: ExperienceID(rawValue: "a04.library-test")!, root: root, defaults: defaults)
    }

    private func document(_ name: String, family: EmitterFamily = .fountain, trails: Bool = false) throws -> SceneDocument {
        try SceneDocument(name: name, scene: .single(family, seed: 7),
                          force: SavedForce(kind: PlacedForceKind.allCases[0].rawValue, x: 10, y: -20, strength: 1),
                          trailsOn: trails, trailStrength: 0.5, additive: true)
    }

    func testSaveListsByNameAndOpensTheSameDocument() throws {
        let library = ParticleLibrary(storage: storage)
        XCTAssertTrue(library.entries.isEmpty)
        let b = try document("Beta", family: .curtain)
        let a = try document("alpha", family: .halo, trails: true)
        let savedB = try XCTUnwrap(library.save(b))
        let savedA = try XCTUnwrap(library.save(a))
        XCTAssertNil(library.errorMessage)
        XCTAssertEqual(library.entries.map(\.name), ["alpha", "Beta"])
        XCTAssertEqual(library.entries.map(\.id), [savedA.id, savedB.id])
        XCTAssertTrue(storage.exists(ParticleLibrary.fileName(for: savedA.id)))
        XCTAssertEqual(library.document(for: savedA), a)
        XCTAssertEqual(library.document(for: savedB), b)
        XCTAssertEqual(library.unreadable, 0)
    }

    func testSavingUnderAnExistingNameKeepsBothWithTheNextFreeSuffix() throws {
        let library = ParticleLibrary(storage: storage)
        let first = try XCTUnwrap(library.save(try document("Storm")))
        let second = try XCTUnwrap(library.save(try document("Storm", family: .halo)))
        let third = try XCTUnwrap(library.save(try document("storm", family: .curtain)))
        XCTAssertEqual(first.name, "Storm")
        XCTAssertEqual(second.name, "Storm 2")
        XCTAssertEqual(third.name, "storm 3")
        XCTAssertEqual(Set(library.entries.map(\.name)), ["Storm", "Storm 2", "storm 3"])
        XCTAssertEqual(library.document(for: second)?.name, "Storm 2")
        XCTAssertEqual(library.document(for: first)?.scene.emitters.first?.family, .fountain)
        XCTAssertEqual(library.document(for: second)?.scene.emitters.first?.family, .halo)
    }

    func testTheSuffixKeepsTheNameWithinTheLimit() throws {
        let library = ParticleLibrary(storage: storage)
        let long = String(repeating: "x", count: SceneDocument.maxNameLength)
        XCTAssertEqual(library.save(try document(long))?.name, long)
        let second = try XCTUnwrap(library.save(try document(long)))
        XCTAssertEqual(second.name.count, SceneDocument.maxNameLength)
        XCTAssertTrue(second.name.hasSuffix(" 2"))
        XCTAssertEqual(library.entries.count, 2)
    }

    func testRenameChangesTheNameAndIsRefusedOnAClash() throws {
        let library = ParticleLibrary(storage: storage)
        let a = try XCTUnwrap(library.save(try document("Aurora")))
        let b = try XCTUnwrap(library.save(try document("Bloom", family: .halo)))
        XCTAssertTrue(library.rename(a, to: "  Comet  "))
        XCTAssertNil(library.errorMessage)
        XCTAssertEqual(library.entries.map(\.name), ["Bloom", "Comet"])
        let renamed = try XCTUnwrap(library.entries.first { $0.id == a.id })
        XCTAssertEqual(library.document(for: renamed)?.name, "Comet")

        XCTAssertFalse(library.rename(renamed, to: "bloom"))
        XCTAssertNotNil(library.errorMessage)
        XCTAssertEqual(library.entries.map(\.name), ["Bloom", "Comet"])
        XCTAssertEqual(library.document(for: b)?.name, "Bloom")

        XCTAssertFalse(library.rename(renamed, to: "   "))
        XCTAssertNotNil(library.errorMessage)
        XCTAssertTrue(library.rename(renamed, to: "comet"), "a change of case of its own name is not a clash")
        XCTAssertEqual(library.entries.map(\.name), ["Bloom", "comet"])
    }

    func testRemoveDeletesTheFile() throws {
        let library = ParticleLibrary(storage: storage)
        let a = try XCTUnwrap(library.save(try document("Aurora")))
        let b = try XCTUnwrap(library.save(try document("Bloom")))
        XCTAssertTrue(library.remove(a))
        XCTAssertNil(library.errorMessage)
        XCTAssertEqual(library.entries.map(\.id), [b.id])
        XCTAssertFalse(storage.exists(ParticleLibrary.fileName(for: a.id)))
        XCTAssertNil(library.document(for: a))
        XCTAssertFalse(library.remove(a))
        XCTAssertNotNil(library.errorMessage)
    }

    func testUnreadableFilesAreCountedAndNeverDeleted() throws {
        let library = ParticleLibrary(storage: storage)
        let good = try XCTUnwrap(library.save(try document("Good")))
        let garbage = ParticleLibrary.fileName(for: UUID())
        let truncated = ParticleLibrary.fileName(for: UUID())
        try storage.write(Data("not json".utf8), to: garbage)
        let full = try XCTUnwrap(storage.read(ParticleLibrary.fileName(for: good.id)))
        try storage.write(full.prefix(full.count / 2), to: truncated)
        try storage.write(Data("unrelated".utf8), to: "notes.txt")
        library.reload()
        XCTAssertEqual(library.entries.map(\.id), [good.id])
        XCTAssertEqual(library.unreadable, 2)
        XCTAssertTrue(storage.exists(garbage))
        XCTAssertTrue(storage.exists(truncated))
        XCTAssertTrue(storage.exists("notes.txt"))
        XCTAssertEqual(ParticleLibrary(storage: storage).unreadable, 2)
    }

    /// T-A04-422 (US2/AC2, FR-A04-410): a scene saved by a newer version is counted as newer, not as unreadable, and
    /// kept.
    func testNewerVersionScenesAreCountedSeparatelyAndKept() throws {
        let library = ParticleLibrary(storage: storage)
        let good = try XCTUnwrap(library.save(try document("Good")))
        let full = try XCTUnwrap(storage.read(ParticleLibrary.fileName(for: good.id)))
        let text = try XCTUnwrap(String(data: full, encoding: .utf8))
        XCTAssertTrue(text.contains("\"version\":2"), "the saved document carries version 2")
        let newerID = UUID()
        let newerText = text.replacingOccurrences(of: "\"version\":2", with: "\"version\":3")
            .replacingOccurrences(of: good.id.uuidString, with: newerID.uuidString)
        let newerName = ParticleLibrary.fileName(for: newerID)
        try storage.write(Data(newerText.utf8), to: newerName)
        library.reload()
        XCTAssertEqual(library.entries.map(\.id), [good.id])
        XCTAssertEqual(library.newer, 1)
        XCTAssertEqual(library.unreadable, 0)
        XCTAssertTrue(storage.exists(newerName))
    }

    func testANewLibraryOverTheSameStorageListsTheSameEntries() throws {
        let first = ParticleLibrary(storage: storage)
        let a = try XCTUnwrap(first.save(try document("Aurora")))
        _ = try XCTUnwrap(first.save(try document("Bloom", family: .halo)))
        XCTAssertTrue(first.rename(a, to: "Zenith"))
        let relaunched = ParticleLibrary(storage: storage)
        XCTAssertEqual(relaunched.entries, first.entries)
        XCTAssertEqual(relaunched.entries.map(\.name), ["Bloom", "Zenith"])
        let zenith = try XCTUnwrap(relaunched.entries.last)
        XCTAssertEqual(relaunched.document(for: zenith)?.name, "Zenith")
    }

    func testASaveBeyondTheFileLimitFailsWithAMessageAndChangesNothing() throws {
        let library = ParticleLibrary(storage: storage)
        let kept = try XCTUnwrap(library.save(try document("Kept")))
        let keptName = ParticleLibrary.fileName(for: kept.id)
        let keptData = try storage.read(keptName)
        for i in 0..<(StorageQuota.maxFiles - 1) {
            try storage.write(Data("filler \(i)".utf8), to: "filler-\(i).txt")
        }
        XCTAssertEqual(storage.list().count, StorageQuota.maxFiles)
        let entriesBefore = library.entries
        XCTAssertNil(library.save(try document("Overflow")))
        let message = try XCTUnwrap(library.errorMessage)
        XCTAssertTrue(message.contains(StorageError.quotaExceeded("files").code), message)
        XCTAssertEqual(storage.list().count, StorageQuota.maxFiles)
        XCTAssertEqual(try storage.read(keptName), keptData)
        XCTAssertEqual(library.entries, entriesBefore)
        // A rename replaces the existing file, so it still works at the limit.
        XCTAssertTrue(library.rename(kept, to: "Still kept"))
        XCTAssertEqual(library.entries.map(\.name), ["Still kept"])
    }
}
