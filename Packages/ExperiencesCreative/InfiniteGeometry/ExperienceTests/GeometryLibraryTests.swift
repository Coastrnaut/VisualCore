// GeometryLibraryTests — feature 043 (A05-P04) T-A05-403 (FR-A05-402, FR-A05-403, FR-A05-405; US1; SC-A05-402). The
// library of saved compositions in a temporary experience storage: save, list by name, open, rename, delete, the
// numbered suffix on a name clash (on save and on rename), an empty name saved as "Untitled", a save beyond the
// storage file limit that fails with a message and keeps every file, damaged and newer files counted, refused and
// kept, and a new library over the same storage listing the same entries. Short runs only.
import XCTest
@testable import InfiniteGeometryExperience
import VisualCoreExperience

@MainActor
final class GeometryLibraryTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUpWithError() throws {
        suite = "dev.visualcore.a05-p04.library.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var storage: ExperienceStorage {
        ExperienceStorage(id: ExperienceID(rawValue: "a05.library-test")!, root: root, defaults: defaults)
    }

    private func document(_ name: String, seed: UInt64 = 7) throws -> GeometryDocument {
        GeometryDocument(core: try GeometryCore(seed: seed), name: name)
    }

    /// The file `name` as a JSON object, changed by `change` and written as `newName`.
    private func rewrite(_ name: String, as newName: String, change: (inout [String: Any]) -> Void) throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: try storage.read(name)) as? [String: Any])
        change(&object)
        try storage.write(try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), to: newName)
    }

    func testSaveListsByNameAndOpensTheSameDocument() throws {
        let fixed = Date(timeIntervalSinceReferenceDate: 1_000)
        let library = GeometryLibrary(storage: storage, now: { fixed })
        XCTAssertTrue(library.entries.isEmpty)
        let b = try document("Beta", seed: 11)
        let a = try document("alpha", seed: 12)
        let savedB = try XCTUnwrap(library.save(b, digest: "bbbb"))
        let savedA = try XCTUnwrap(library.save(a, digest: "aaaa"))
        XCTAssertNil(library.errorMessage)
        XCTAssertEqual(library.entries.map(\.name), ["alpha", "Beta"])
        XCTAssertEqual(library.entries.map(\.id), [savedA.id, savedB.id])
        XCTAssertEqual(library.entries.map(\.digest), ["aaaa", "bbbb"])
        XCTAssertEqual(savedA.saved, fixed)
        XCTAssertTrue(storage.exists(GeometryLibrary.fileName(for: savedA.id)))
        XCTAssertEqual(library.document(for: savedA), a)
        XCTAssertEqual(library.document(for: savedB), b)
        XCTAssertEqual(library.unreadable, 0)
        XCTAssertEqual(library.newer, 0)

        let text = try XCTUnwrap(String(data: try storage.read(GeometryLibrary.fileName(for: savedA.id)),
                                        encoding: .utf8))
        XCTAssertTrue(text.contains("\"format\":1"), text)
        XCTAssertTrue(text.contains("\"id\":\"\(savedA.id.uuidString)\""), text)
        let keys = ["\"digest\"", "\"document\"", "\"format\"", "\"id\"", "\"saved\""]
            .compactMap { text.range(of: $0)?.lowerBound }
        XCTAssertEqual(keys.count, 5)
        XCTAssertEqual(keys, keys.sorted(), "sorted keys")
    }

    func testSavingUnderAnExistingNameKeepsBothWithTheNextFreeSuffix() throws {
        let library = GeometryLibrary(storage: storage)
        let first = try XCTUnwrap(library.save(try document("Spiral"), digest: "1"))
        let second = try XCTUnwrap(library.save(try document("Spiral", seed: 8), digest: "2"))
        let third = try XCTUnwrap(library.save(try document("spiral", seed: 9), digest: "3"))
        XCTAssertEqual(first.name, "Spiral")
        XCTAssertEqual(second.name, "Spiral 2")
        XCTAssertEqual(third.name, "spiral 3")
        XCTAssertEqual(Set(library.entries.map(\.name)), ["Spiral", "Spiral 2", "spiral 3"])
        XCTAssertEqual(library.document(for: second)?.name, "Spiral 2")
        XCTAssertEqual(library.document(for: second), try document("Spiral 2", seed: 8))
    }

    func testAnEmptyNameIsSavedAsUntitled() throws {
        let library = GeometryLibrary(storage: storage)
        XCTAssertEqual(library.save(try document("   "), digest: "1")?.name, GeometryDocument.untitledName)
        XCTAssertEqual(library.save(try document(""), digest: "2")?.name, GeometryDocument.untitledName + " 2")
        let long = String(repeating: "x", count: GeometryDocument.maxNameLength)
        XCTAssertEqual(library.save(try document(long), digest: "3")?.name, long)
        let clash = try XCTUnwrap(library.save(try document(long), digest: "4"))
        XCTAssertEqual(clash.name.count, GeometryDocument.maxNameLength)
        XCTAssertTrue(clash.name.hasSuffix(" 2"))
        XCTAssertNil(library.errorMessage)
    }

    func testRenameChangesTheNameAndSuffixesAClash() throws {
        let library = GeometryLibrary(storage: storage)
        let a = try XCTUnwrap(library.save(try document("Aurora"), digest: "aa"))
        let b = try XCTUnwrap(library.save(try document("Bloom", seed: 8), digest: "bb"))
        XCTAssertTrue(library.rename(a, to: "  Comet  "))
        XCTAssertNil(library.errorMessage)
        XCTAssertEqual(library.entries.map(\.name), ["Bloom", "Comet"])
        let renamed = try XCTUnwrap(library.entries.first { $0.id == a.id })
        XCTAssertEqual(renamed.saved, a.saved)
        XCTAssertEqual(renamed.digest, "aa")
        XCTAssertEqual(library.document(for: renamed)?.name, "Comet")

        XCTAssertTrue(library.rename(renamed, to: "bloom"))
        XCTAssertEqual(library.entries.first { $0.id == a.id }?.name, "bloom 2")
        XCTAssertEqual(library.document(for: b)?.name, "Bloom", "the other entry is untouched")
        XCTAssertTrue(library.rename(renamed, to: "BLOOM 2"), "a change of case of its own name is not a clash")
        XCTAssertEqual(library.entries.first { $0.id == a.id }?.name, "BLOOM 2")
        XCTAssertTrue(library.rename(renamed, to: "  "))
        XCTAssertEqual(library.entries.first { $0.id == a.id }?.name, GeometryDocument.untitledName)
        XCTAssertEqual(library.entries.count, 2)
    }

    func testDeleteRemovesOnlyThatFile() throws {
        let library = GeometryLibrary(storage: storage)
        let a = try XCTUnwrap(library.save(try document("Aurora"), digest: "1"))
        let b = try XCTUnwrap(library.save(try document("Bloom"), digest: "2"))
        XCTAssertTrue(library.delete(a))
        XCTAssertNil(library.errorMessage)
        XCTAssertEqual(library.entries.map(\.id), [b.id])
        XCTAssertFalse(storage.exists(GeometryLibrary.fileName(for: a.id)))
        XCTAssertTrue(storage.exists(GeometryLibrary.fileName(for: b.id)))
        XCTAssertNil(library.document(for: a))
        XCTAssertNotNil(library.errorMessage)
        XCTAssertFalse(library.delete(a))
        XCTAssertNotNil(library.errorMessage)
        XCTAssertFalse(library.rename(a, to: "Gone"))
        XCTAssertNotNil(library.errorMessage)
    }

    func testDamagedAndNewerFilesAreCountedRefusedAndKept() throws {
        let library = GeometryLibrary(storage: storage)
        let good = try XCTUnwrap(library.save(try document("Good"), digest: "1"))
        let goodName = GeometryLibrary.fileName(for: good.id)
        let garbageID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let truncatedID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let mismatchID = UUID(uuidString: "00000000-0000-4000-8000-000000000003")!
        let newerFormatID = UUID(uuidString: "00000000-0000-4000-8000-000000000004")!
        let newerVersionID = UUID(uuidString: "00000000-0000-4000-8000-000000000005")!
        let garbage = GeometryLibrary.fileName(for: garbageID)
        let truncated = GeometryLibrary.fileName(for: truncatedID)
        let mismatch = GeometryLibrary.fileName(for: mismatchID)
        let newerFormat = GeometryLibrary.fileName(for: newerFormatID)
        let newerVersion = GeometryLibrary.fileName(for: newerVersionID)
        try storage.write(Data("not json".utf8), to: garbage)
        let full = try storage.read(goodName)
        try storage.write(full.prefix(full.count / 2), to: truncated)
        try storage.write(full, to: mismatch) // its id is the good file's, not its name's
        try rewrite(goodName, as: newerFormat) {
            $0["format"] = 2
            $0["id"] = newerFormatID.uuidString
        }
        try rewrite(goodName, as: newerVersion) {
            var document = $0["document"] as? [String: Any] ?? [:]
            document["version"] = GeometryDocument.version + 1
            $0["document"] = document
            $0["id"] = newerVersionID.uuidString
        }
        try storage.write(Data("unrelated".utf8), to: "notes.txt")
        let before = try storage.list().sorted().map { try storage.read($0) }

        library.reload()
        XCTAssertEqual(library.entries.map(\.id), [good.id])
        XCTAssertEqual(library.unreadable, 3)
        XCTAssertEqual(library.newer, 2)

        let stray = GeometryLibraryEntry(id: newerFormatID, name: "x", saved: Date(), digest: "")
        XCTAssertNil(library.document(for: stray))
        XCTAssertEqual(library.errorMessage, "The composition was made by a newer version.")
        let strayVersion = GeometryLibraryEntry(id: newerVersionID, name: "x", saved: Date(), digest: "")
        XCTAssertNil(library.document(for: strayVersion))
        XCTAssertEqual(library.errorMessage, "The composition was made by a newer version.")
        let damaged = GeometryLibraryEntry(id: garbageID, name: "x", saved: Date(), digest: "")
        XCTAssertNil(library.document(for: damaged))
        XCTAssertNotNil(library.errorMessage)

        let relaunched = GeometryLibrary(storage: storage)
        XCTAssertEqual(relaunched.unreadable, 3)
        XCTAssertEqual(relaunched.newer, 2)
        XCTAssertEqual(try storage.list().sorted().map { try storage.read($0) }, before, "nothing rewritten")
        for name in [garbage, truncated, mismatch, newerFormat, newerVersion, "notes.txt"] {
            XCTAssertTrue(storage.exists(name), name)
        }
    }

    func testANewLibraryOverTheSameStorageListsTheSameEntries() throws {
        let first = GeometryLibrary(storage: storage)
        let a = try XCTUnwrap(first.save(try document("Aurora"), digest: "1"))
        _ = try XCTUnwrap(first.save(try document("Bloom", seed: 8), digest: "2"))
        XCTAssertTrue(first.rename(a, to: "Zenith"))
        let relaunched = GeometryLibrary(storage: storage)
        XCTAssertEqual(relaunched.entries, first.entries)
        XCTAssertEqual(relaunched.entries.map(\.name), ["Bloom", "Zenith"])
        let zenith = try XCTUnwrap(relaunched.entries.last)
        XCTAssertEqual(relaunched.document(for: zenith), try document("Zenith"))
    }

    func testASaveBeyondTheFileLimitFailsWithAMessageAndKeepsTheFiles() throws {
        let library = GeometryLibrary(storage: storage)
        let kept = try XCTUnwrap(library.save(try document("Kept"), digest: "1"))
        let keptName = GeometryLibrary.fileName(for: kept.id)
        let keptData = try storage.read(keptName)
        for i in 0..<(StorageQuota.maxFiles - 1) {
            try storage.write(Data("filler \(i)".utf8), to: "filler-\(i).txt")
        }
        XCTAssertEqual(storage.list().count, StorageQuota.maxFiles)
        let entriesBefore = library.entries
        XCTAssertNil(library.save(try document("Overflow"), digest: "2"))
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
