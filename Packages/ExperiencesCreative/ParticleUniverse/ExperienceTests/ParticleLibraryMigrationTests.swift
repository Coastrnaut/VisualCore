// ParticleLibraryMigrationTests — feature 038 (A04-P06) T-A04-606 (FR-A04-610, FR-A04-611; US2; edge cases).
// The committed library fixtures (`Fixtures/Library/`: without `format`, format 1, format 2, damaged) copied into a
// temporary experience storage as `scene-<uuid>.json`: the two readable forms open with every field equal, the newer
// format is counted in `newer` and kept byte-identical, the damaged file is counted in `unreadable` and kept, save
// and rename write `"format":1`, and a file written now still decodes with the wrapper as it was before this phase.
import XCTest
import ParticleUniverseCore
@testable import ParticleUniverseExperience
import VisualCoreExperience

@MainActor
final class ParticleLibraryMigrationTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    /// The fixed ids of the committed fixtures.
    private let noFormatID = UUID(uuidString: "0A0E0001-0000-4000-8000-000000000001")!
    private let format1ID = UUID(uuidString: "0A0E0001-0000-4000-8000-000000000002")!
    private let format2ID = UUID(uuidString: "0A0E0001-0000-4000-8000-000000000003")!

    /// The library wrapper as it was before A04-P06 (no `format`).
    private struct OldFile: Decodable {
        var id: UUID
        var saved: Date
        var document: SceneDocument
    }

    override func setUpWithError() throws {
        suite = "dev.visualcore.a04-p06.library-migration.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var storage: ExperienceStorage {
        ExperienceStorage(id: ExperienceID(rawValue: "a04.library-migration-test")!, root: root, defaults: defaults)
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json",
                                                  subdirectory: "Fixtures/Library"), "missing fixture \(name)")
        return try Data(contentsOf: url)
    }

    /// The fixture's `document` field decoded directly with `SceneDocument.decode(_:)`.
    private func embeddedDocument(_ data: Data) throws -> SceneDocument {
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let document = try XCTUnwrap(object["document"])
        return try SceneDocument.decode(try JSONSerialization.data(withJSONObject: document))
    }

    private func text(_ id: UUID) throws -> String {
        String(decoding: try storage.read(ParticleLibrary.fileName(for: id)), as: UTF8.self)
    }

    func testTheFormatWrittenNowIsOne() {
        XCTAssertEqual(ParticleLibrary.format, 1)
    }

    func testFilesWithoutFormatAndOfFormatOneOpenWithEveryFieldEqual() throws {
        let noFormat = try fixture("scene-no-format")
        let format1 = try fixture("scene-format-1")
        XCTAssertFalse(String(decoding: noFormat, as: UTF8.self).contains("\"format\""))
        try storage.write(noFormat, to: ParticleLibrary.fileName(for: noFormatID))
        try storage.write(format1, to: ParticleLibrary.fileName(for: format1ID))

        let library = ParticleLibrary(storage: storage)
        XCTAssertEqual(library.unreadable, 0)
        XCTAssertEqual(library.newer, 0)
        XCTAssertEqual(library.entries.map(\.name), ["Nebula Old", "Nebula One"])
        XCTAssertEqual(library.entries.map(\.id), [noFormatID, format1ID])

        let old = try XCTUnwrap(library.entries.first { $0.id == noFormatID })
        XCTAssertEqual(old.name, "Nebula Old")
        XCTAssertEqual(old.saved, Date(timeIntervalSinceReferenceDate: 800_000_000))
        XCTAssertEqual(library.document(for: old), try embeddedDocument(noFormat))
        XCTAssertNil(library.errorMessage)

        let one = try XCTUnwrap(library.entries.first { $0.id == format1ID })
        XCTAssertEqual(one.name, "Nebula One")
        XCTAssertEqual(one.saved, Date(timeIntervalSinceReferenceDate: 800_000_100.5))
        XCTAssertEqual(library.document(for: one), try embeddedDocument(format1))
        XCTAssertNil(library.errorMessage)

        // Loading never rewrites a file.
        XCTAssertEqual(try storage.read(ParticleLibrary.fileName(for: noFormatID)), noFormat)
        XCTAssertEqual(try storage.read(ParticleLibrary.fileName(for: format1ID)), format1)
    }

    func testANewerFormatIsCountedAsNewerKeptAndRefused() throws {
        let format2 = try fixture("scene-format-2")
        let name = ParticleLibrary.fileName(for: format2ID)
        try storage.write(format2, to: name)

        let library = ParticleLibrary(storage: storage)
        XCTAssertEqual(library.newer, 1)
        XCTAssertEqual(library.unreadable, 0)
        XCTAssertTrue(library.entries.isEmpty)
        XCTAssertNil(library.document(for: ParticleLibraryEntry(id: format2ID, name: "Nebula Two", saved: Date())))
        XCTAssertEqual(library.errorMessage, "The scene was made by a newer version.")
        library.reload()
        XCTAssertEqual(library.newer, 1)
        XCTAssertEqual(try storage.read(name), format2, "a newer file is kept byte-identical")
    }

    func testADamagedFileIsCountedAsUnreadableAndKept() throws {
        let damaged = try fixture("scene-damaged")
        let name = ParticleLibrary.fileName(for: UUID())
        try storage.write(damaged, to: name)

        let library = ParticleLibrary(storage: storage)
        XCTAssertEqual(library.unreadable, 1)
        XCTAssertEqual(library.newer, 0)
        XCTAssertTrue(library.entries.isEmpty)
        XCTAssertEqual(try storage.read(name), damaged)
    }

    func testSaveAndRenameWriteFormatOne() throws {
        let library = ParticleLibrary(storage: storage)
        let document = try embeddedDocument(try fixture("scene-format-1"))
        let saved = try XCTUnwrap(library.save(document))
        XCTAssertTrue(try text(saved.id).contains("\"format\":1"))
        XCTAssertTrue(try text(saved.id).contains("\"version\":2"))

        // A file without `format` gains it when renamed.
        try storage.write(try fixture("scene-no-format"), to: ParticleLibrary.fileName(for: noFormatID))
        library.reload()
        let old = try XCTUnwrap(library.entries.first { $0.id == noFormatID })
        XCTAssertTrue(library.rename(old, to: "Renamed"))
        let renamed = try text(noFormatID)
        XCTAssertTrue(renamed.contains("\"format\":1"))
        XCTAssertTrue(renamed.contains("\"name\":\"Renamed\""))
        XCTAssertEqual(library.entries.first { $0.id == noFormatID }?.saved,
                       Date(timeIntervalSinceReferenceDate: 800_000_000))
    }

    func testAFileWrittenNowDecodesWithTheOldWrapper() throws {
        let library = ParticleLibrary(storage: storage)
        let document = try embeddedDocument(try fixture("scene-format-1"))
        let saved = try XCTUnwrap(library.save(document))
        let data = try storage.read(ParticleLibrary.fileName(for: saved.id))
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"format\":1"))
        let old = try JSONDecoder().decode(OldFile.self, from: data)
        XCTAssertEqual(old.id, saved.id)
        XCTAssertEqual(old.saved, saved.saved)
        XCTAssertEqual(old.document, library.document(for: saved))
        XCTAssertEqual(old.document.name, document.name)
    }
}
