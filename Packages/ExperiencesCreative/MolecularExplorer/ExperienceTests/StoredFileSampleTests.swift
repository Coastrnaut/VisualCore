// StoredFileSampleTests — feature 115 (A15-P06) T-A15-605 (FR-A15-610; SC-A15-602; clarification Q5). The committed
// sample files under `ExperienceTests/Fixtures` are answered by the code that reads them in the app:
//   - `recent-*.json` installed as `recent.json` in a temporary storage and loaded by `RecentStore`, and
//     `settings-*.json` installed as `settings.json` and loaded by `SettingsStore`: the valid sample (exactly the bytes
//     the document's `encoded()` writes) loads; the newer, damaged and oversized samples are refused with their reasons
//     (`newer-version`, `damaged`, `oversized`); every file is byte for byte the same afterwards;
//   - `import-*.xyz` copied to a temporary file and opened by `MoleculeImporter.importFile(at:isActive:send:)` with a
//     core of its own answering the actions: the valid sample (water) imports, the damaged sample (an element this
//     explorer does not know) is refused with the parser's sentence, the oversized sample (65,537 bytes) is refused
//     before its bytes are read (`readCount` stays 0); the picked file is unchanged and a refused import writes no
//     copy.
// Recent ids outside the library are already proved dropped by `RecentStoreTests` (A15-P04). Short, no GPU, no
// picker, no prompt, no network.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience

@MainActor
final class StoredFileSampleTests: XCTestCase {
    /// The experience's temporary storage.
    private var temporary: TemporaryMoleculeStorage!
    /// The temporary folder the picked import files are copied to.
    private var files: URL!

    override func setUp() async throws {
        temporary = TemporaryMoleculeStorage()
        files = FileManager.default.temporaryDirectory
            .appendingPathComponent("me-samples-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        temporary.remove()
        try? FileManager.default.removeItem(at: files)
    }

    // MARK: Helpers

    /// The bundled `Fixtures` folder.
    private func fixtures() throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil), "missing Fixtures folder")
    }

    /// The bytes of the bundled sample `name`.
    private func sample(_ name: String) throws -> Data {
        try Data(contentsOf: try fixtures().appendingPathComponent(name))
    }

    /// The sample `name` copied to a picked file of the same name in the temporary folder.
    private func picked(_ name: String) throws -> URL {
        let url = files.appendingPathComponent(name, isDirectory: false)
        try sample(name).write(to: url)
        return url
    }

    // MARK: Bundle

    func testExactlyTheElevenSamplesAreBundled() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: try fixtures().path)
            .filter { !$0.hasPrefix(".") }
        var expected: Set<String> = ["import-valid.xyz", "import-damaged.xyz", "import-oversized.xyz"]
        for document in ["recent", "settings"] {
            for kind in ["valid", "newer", "damaged", "oversized"] { expected.insert("\(document)-\(kind).json") }
        }
        XCTAssertEqual(Set(names), expected)
    }

    // MARK: recent.json

    func testTheValidRecentSampleLoads() throws {
        let bytes = try sample("recent-valid.json")
        let expected = RecentMolecules(ids: ["water", "caffeine"])
        XCTAssertEqual(bytes, expected.encoded(), "exactly the bytes RecentMolecules.encoded() writes")
        try temporary.storage.write(bytes, to: RecentMolecules.fileName)
        let store = RecentStore(storage: temporary.storage)
        XCTAssertEqual(store.loadResult, .loaded(expected))
        XCTAssertEqual(store.recent, expected)
        XCTAssertEqual(store.message, "")
        XCTAssertEqual(try temporary.storage.read(RecentMolecules.fileName), bytes, "loading never rewrites it")
    }

    func testTheRefusedRecentSamplesAreRefusedAndUntouched() throws {
        let cases: [(String, DocumentRefusal)] = [
            ("recent-newer.json", .newerVersion), ("recent-damaged.json", .damaged),
            ("recent-oversized.json", .oversized),
        ]
        for (name, refusal) in cases {
            let bytes = try sample(name)
            try temporary.storage.write(bytes, to: RecentMolecules.fileName)
            let store = RecentStore(storage: temporary.storage)
            XCTAssertEqual(store.loadResult, .refused(refusal), name)
            XCTAssertEqual(store.recent, RecentMolecules(), "\(name): the list is empty")
            XCTAssertEqual(store.message, "Recent molecules could not be read (\(refusal.rawValue)).", name)
            XCTAssertEqual(try temporary.storage.read(RecentMolecules.fileName), bytes, "\(name) stays byte-identical")
        }
        XCTAssertGreaterThan(try sample("recent-oversized.json").count, RecentMolecules.maxBytes)
    }

    // MARK: settings.json

    func testTheValidSettingsSampleLoads() throws {
        let bytes = try sample("settings-valid.json")
        let expected = MoleculeSettings(labels: .selected)
        XCTAssertEqual(bytes, expected.encoded(), "exactly the bytes MoleculeSettings.encoded() writes")
        try temporary.storage.write(bytes, to: MoleculeSettings.fileName)
        let store = SettingsStore(storage: temporary.storage)
        XCTAssertEqual(store.loadResult, .loaded(expected))
        XCTAssertEqual(store.labels, .selected)
        XCTAssertEqual(store.message, "")
        XCTAssertEqual(try temporary.storage.read(MoleculeSettings.fileName), bytes, "loading never rewrites it")
    }

    func testTheRefusedSettingsSamplesAreRefusedAndUntouched() throws {
        let cases: [(String, DocumentRefusal)] = [
            ("settings-newer.json", .newerVersion), ("settings-damaged.json", .damaged),
            ("settings-oversized.json", .oversized),
        ]
        for (name, refusal) in cases {
            let bytes = try sample(name)
            try temporary.storage.write(bytes, to: MoleculeSettings.fileName)
            let store = SettingsStore(storage: temporary.storage)
            XCTAssertEqual(store.loadResult, .refused(refusal), name)
            XCTAssertEqual(store.labels, .all, "\(name): the default label mode")
            XCTAssertEqual(store.message,
                           "Settings could not be read (\(refusal.rawValue)); labels are shown for all atoms.", name)
            XCTAssertEqual(try temporary.storage.read(MoleculeSettings.fileName), bytes, "\(name) stays byte-identical")
        }
        XCTAssertGreaterThan(try sample("settings-oversized.json").count, MoleculeSettings.maxBytes)
    }

    // MARK: import.xyz

    func testTheValidImportSampleImports() throws {
        let url = try picked("import-valid.xyz")
        let bytes = try sample("import-valid.xyz")
        XCTAssertEqual(bytes, Data(MoleculeLibraryData.records[0].xyz.utf8), "the sample is the library's water")
        let importer = MoleculeImporter(storage: temporary.storage)
        var core = MoleculeCore(seed: 1)
        let outcome = importer.importFile(at: url, isActive: true) { control, values in
            core.apply(ExperienceAction(control: control, values: values, step: 0))
        }
        XCTAssertEqual(outcome, .imported(title: "import-valid", atoms: 3, storageCode: nil))
        XCTAssertEqual(importer.readCount, 1)
        XCTAssertEqual(core.selection, MoleculeCore.importedSelection)
        XCTAssertEqual(core.imported?.molecule.atoms.count, 3)
        XCTAssertEqual(try temporary.storage.read(MoleculeImporter.fileName), bytes, "the accepted bytes are kept")
        XCTAssertEqual(try Data(contentsOf: url), bytes, "the picked file is unchanged")
    }

    func testTheDamagedImportSampleIsRefusedWithItsSentence() throws {
        let url = try picked("import-damaged.xyz")
        let bytes = try sample("import-damaged.xyz")
        let importer = MoleculeImporter(storage: temporary.storage)
        var core = MoleculeCore(seed: 1)
        let before = try moleculeDigest(core)
        var sent = 0
        let outcome = importer.importFile(at: url, isActive: true) { control, values in
            sent += 1
            return core.apply(ExperienceAction(control: control, values: values, step: 0))
        }
        let sentence = "This file could not be opened: an element this explorer does not know (line 4)."
        XCTAssertEqual(outcome, .refused(sentence))
        guard case .failure(let refusal) = XYZParser.parse(bytes) else { return XCTFail("the parser accepts it") }
        XCTAssertEqual(MoleculeImport.sentence(refusal), sentence, "the parser's own sentence")
        XCTAssertEqual(importer.readCount, 1)
        XCTAssertEqual(sent, 0, "no action is sent for a refused file")
        XCTAssertEqual(try moleculeDigest(core), before, "the engine state is unchanged")
        XCTAssertFalse(temporary.storage.exists(MoleculeImporter.fileName), "no copy is written")
        XCTAssertEqual(try Data(contentsOf: url), bytes, "the picked file is unchanged")
    }

    func testTheOversizedImportSampleIsRefusedWithoutBeingRead() throws {
        let url = try picked("import-oversized.xyz")
        let bytes = try sample("import-oversized.xyz")
        XCTAssertEqual(bytes.count, MoleculeImport.maxBytes + 1)
        XCTAssertEqual(MoleculeImporter.fileSize(url), 65_537)
        let importer = MoleculeImporter(storage: temporary.storage)
        var sent = 0
        let outcome = importer.importFile(at: url, isActive: true) { _, _ in
            sent += 1
            return .accepted
        }
        XCTAssertEqual(outcome, .refused(MoleculeImport.tooLargeSentence))
        XCTAssertEqual(importer.readCount, 0, "the bytes were never read")
        XCTAssertEqual(sent, 0)
        XCTAssertFalse(temporary.storage.exists(MoleculeImporter.fileName), "no copy is written")
        XCTAssertEqual(try Data(contentsOf: url), bytes, "the picked file is unchanged")
    }
}
