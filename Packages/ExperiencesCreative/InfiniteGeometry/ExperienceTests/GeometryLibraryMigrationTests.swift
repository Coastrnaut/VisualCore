// GeometryLibraryMigrationTests — feature 045 (A05-P06) T-A05-605 (FR-A05-610; SC-A05-602; US2; data-model
// "Fixtures"). The five committed library fixtures (`Fixtures/Library/`) copied into a temporary experience storage
// under their own names: the format-1 file is the one entry, and its document opens through one atomic
// `composition.open` (18 values) on a changed engine with the digest committed in the file (the launch digest of seed
// 7, `scenario-manifest.json` "launch-first-frame"); the newer format and the newer document version are counted in
// `newer` and refused; the damaged file and the file without `format` are counted in `unreadable` (the Phase 04
// rule); and those four files stay byte for byte as committed after loading, after a save and after a reload. Short
// runs only.
import XCTest
import InfiniteGeometryCore
@testable import InfiniteGeometryExperience
import VisualCoreExperience

@MainActor
final class GeometryLibraryMigrationTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    /// The fixture file names without extension: listed / newer / newer / unreadable / unreadable.
    private static let listed = "composition-00000000-0000-4000-8000-00000000a501"
    private static let others = ["composition-00000000-0000-4000-8000-00000000a502",
                                 "composition-00000000-0000-4000-8000-00000000a503",
                                 "composition-00000000-0000-4000-8000-00000000a504",
                                 "composition-00000000-0000-4000-8000-00000000a505"]
    /// The id of the listed fixture (it matches its file name).
    private let listedID = UUID(uuidString: "00000000-0000-4000-8000-00000000A501")!
    /// The id of the newer-format fixture.
    private let newerFormatID = UUID(uuidString: "00000000-0000-4000-8000-00000000A502")!
    /// The id of the newer-document fixture.
    private let newerDocumentID = UUID(uuidString: "00000000-0000-4000-8000-00000000A503")!
    /// The digest committed in the format-1 fixture: the state of curated preset 0 with seed 7 and the default
    /// cameras (equal to the manifest's launch digest at seed 7).
    private static let committedDigest = "24bf4d9696e7c4149ad6802f0eedfb7709168c9f026189d1f3753a59ba88317f"

    override func setUpWithError() throws {
        suite = "dev.visualcore.a05-p06.library-migration.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var storage: ExperienceStorage {
        ExperienceStorage(id: ExperienceID(rawValue: "a05.library-migration-test")!, root: root, defaults: defaults)
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json",
                                                  subdirectory: "Fixtures/Library"), "missing fixture \(name)")
        return try Data(contentsOf: url)
    }

    /// Copies every fixture into the storage under its own name; returns the committed bytes by name.
    @discardableResult
    private func install() throws -> [String: Data] {
        var bytes: [String: Data] = [:]
        for name in [Self.listed] + Self.others {
            let data = try fixture(name)
            try storage.write(data, to: name + GeometryLibrary.fileExtension)
            bytes[name] = data
        }
        return bytes
    }

    /// Asserts that the four non-listed files are byte-identical to the committed fixtures.
    private func assertOthersUnchanged(_ bytes: [String: Data], _ when: String,
                                       file: StaticString = #filePath, line: UInt = #line) throws {
        for name in Self.others {
            XCTAssertEqual(try storage.read(name + GeometryLibrary.fileExtension), bytes[name],
                           "\(name) byte-identical \(when)", file: file, line: line)
        }
    }

    func testTheFixturesAreNamedByTheirIDs() throws {
        XCTAssertEqual(GeometryLibrary.fileName(for: listedID), Self.listed + GeometryLibrary.fileExtension)
        for name in [Self.listed] + Self.others {
            XCTAssertTrue(name.hasPrefix("composition-00000000-0000-4000-8000-"), name)
        }
        let text = String(decoding: try fixture(Self.others[3]), as: UTF8.self)
        XCTAssertFalse(text.contains("\"format\""), "the a505 fixture has no format key")
    }

    func testTheLibraryCountsOneEntryTwoNewerAndTwoUnreadable() throws {
        let bytes = try install()
        let library = GeometryLibrary(storage: storage)
        XCTAssertEqual(library.entries.count, 1)
        XCTAssertEqual(library.newer, 2, "newer format and newer document version")
        XCTAssertEqual(library.unreadable, 2, "damaged and without format")
        let entry = try XCTUnwrap(library.entries.first)
        XCTAssertEqual(entry.id, listedID)
        XCTAssertEqual(entry.name, "Seven")
        XCTAssertEqual(entry.saved, Date(timeIntervalSinceReferenceDate: 800_000_100.5))
        XCTAssertEqual(entry.digest, Self.committedDigest)
        XCTAssertNil(library.errorMessage)

        // The newer files are refused when opened.
        for id in [newerFormatID, newerDocumentID] {
            XCTAssertNil(library.document(for: GeometryLibraryEntry(id: id, name: "Newer", saved: Date(), digest: "")))
            XCTAssertEqual(library.errorMessage, "The composition was made by a newer version.")
        }
        try assertOthersUnchanged(bytes, "after loading")
        XCTAssertEqual(try storage.read(Self.listed + GeometryLibrary.fileExtension), bytes[Self.listed],
                       "loading never rewrites the listed file")
    }

    func testTheListedDocumentOpensWithTheCommittedDigest() async throws {
        try install()
        let library = GeometryLibrary(storage: storage)
        let entry = try XCTUnwrap(library.entries.first)
        let document = try XCTUnwrap(library.document(for: entry))
        XCTAssertEqual(document, GeometryDocument(core: try GeometryCore(seed: 7), name: "Seven"),
                       "the fixture is curated preset 0 with seed 7 and the default cameras")
        XCTAssertEqual(document.openValues.count, GeometryDocument.openValueCount)

        // The committed digest is the digest of that state as the controls compute it at save time.
        XCTAssertEqual(GeometryControls.digest(of: try GeometryCore(seed: 7)), entry.digest)

        // Opened on a changed engine through the one atomic action, the state's digest equals the committed one.
        let id = try XCTUnwrap(ExperienceID(rawValue: GeometryCore.experienceID))
        var engine = ExperienceEngine<GeometryCore>(id: id)
        try await engine.prepare(seed: GeometryCore.manifestSeed)
        try engine.activate()
        XCTAssertTrue(engine.handle(control: "preset.select", values: [1]).isAccepted)
        XCTAssertNotEqual(try engine.digest().hex, entry.digest, "the engine starts from another state")
        XCTAssertTrue(engine.handle(control: "composition.open", values: document.openValues).isAccepted)
        XCTAssertEqual(try engine.digest().hex, entry.digest, "the open restores the committed digest")
    }

    func testTheOtherFilesStayByteIdenticalAfterASave() throws {
        let bytes = try install()
        let library = GeometryLibrary(storage: storage)
        let core = try GeometryCore(seed: 11)
        let digest = try XCTUnwrap(GeometryControls.digest(of: core))
        let saved = try XCTUnwrap(library.save(GeometryDocument(core: core, name: "New"), digest: digest))
        XCTAssertNil(library.errorMessage)
        XCTAssertEqual(library.entries.map(\.id).sorted { $0.uuidString < $1.uuidString },
                       [listedID, saved.id].sorted { $0.uuidString < $1.uuidString })
        XCTAssertEqual(library.newer, 2)
        XCTAssertEqual(library.unreadable, 2)
        try assertOthersUnchanged(bytes, "after a save")
        XCTAssertEqual(try storage.read(Self.listed + GeometryLibrary.fileExtension), bytes[Self.listed])

        library.reload()
        XCTAssertEqual(library.entries.count, 2)
        try assertOthersUnchanged(bytes, "after a reload")
    }
}
