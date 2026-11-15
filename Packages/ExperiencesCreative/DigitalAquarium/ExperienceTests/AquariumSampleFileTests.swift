// AquariumSampleFileTests — feature 073 (A09-P06) T-A09-605 (FR-A09-610, FR-A09-612; SC-A09-602; US2; research D3).
// The four committed saved-aquarium samples (`Fixtures/`, bundled with `resources: [.copy("Fixtures")]`, T-A09-604)
// copied into a temporary experience storage under their own names: the valid format-1 Reef sample (…a1) is listed
// with its name and fields; the format-2 sample (…a2) is counted in `newer`; the damaged sample (…a3, not JSON) and the
// valid body whose content id is a1's (…a4, mismatched name) are counted in `unreadable`; every sample stays byte for
// byte as committed after loading, a reload and the save of a new aquarium. The stored schema-1, 2 and 3 examples
// restore through an engine with the digests they name. Short runs only (well under 1 s each).
import Foundation
import XCTest
@testable import DigitalAquariumExperience
import DigitalAquariumCore
import VisualCoreExperience

@MainActor
final class AquariumSampleFileTests: XCTestCase {
    private var storage: ExperienceStorage!
    private var cleanUp: (@Sendable () -> Void)?

    /// The id of the valid sample (also the content id of the mismatched one).
    private let validID = UUID(uuidString: "00000000-0000-4000-8000-0000000000A1")!

    override func setUpWithError() throws {
        let suite = "dev.visualcore.a09-p06.samples.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        storage = ExperienceStorage(id: ExperienceID(rawValue: "a09.sample-test")!, root: root, defaults: defaults)
        cleanUp = {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
    }

    override func tearDown() {
        cleanUp?()
    }

    /// The synthetic sample id ending in `suffix` (`a1` … `a4`).
    private func sampleID(_ suffix: String) -> UUID {
        UUID(uuidString: "00000000-0000-4000-8000-0000000000" + suffix)!
    }

    /// Copies every file of the bundled fixture folder into the storage under its own name (through
    /// `ExperienceStorage.write`); returns the committed bytes by file name.
    private func install() throws -> [String: Data] {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil),
                                   "missing Fixtures folder")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        var bytes: [String: Data] = [:]
        for url in files where url.pathExtension == "json" {
            let data = try Data(contentsOf: url)
            try storage.write(data, to: url.lastPathComponent)
            bytes[url.lastPathComponent] = data
        }
        return bytes
    }

    func testTheSamplesLoadOrAreCountedAndStayByteIdentical() throws {
        let committed = try install()
        let names = ["a1", "a2", "a3", "a4"].map { AquariumLibrary.fileName(for: sampleID($0)) }
        XCTAssertEqual(Set(committed.keys), Set(names), "exactly the four samples are bundled")
        XCTAssertTrue(names.allSatisfy { $0 == $0.lowercased() })

        let library = AquariumLibrary(storage: storage)
        XCTAssertEqual(library.entries.count, 1)
        let valid = try XCTUnwrap(library.entries.first)
        XCTAssertEqual(valid.id, validID)
        XCTAssertEqual(valid.name, "Reef sample")
        XCTAssertEqual(valid.format, 1)
        XCTAssertEqual(valid.habitatIndex, 0)
        XCTAssertEqual(valid.lighting, 1)
        XCTAssertEqual(valid.decor.map(\.kindId), ["round-rock", "spiral-shell", "flat-rock"])
        XCTAssertEqual(valid.savedAt, Date(timeIntervalSinceReferenceDate: 800_000_000))
        XCTAssertEqual(valid.validate(catalog: AquariumCore.catalog), [])
        XCTAssertEqual(library.unreadable, 2, "damaged (a3) and mismatched name (a4)")
        XCTAssertEqual(library.newer, 1, "format 2 (a2)")
        XCTAssertNil(library.entry(sampleID("A4")))

        // The newer sample is recognised by its format; the mismatched one decodes but carries a1's id.
        XCTAssertThrowsError(try AquariumConfiguration.decode(committed[names[1]]!)) { error in
            XCTAssertEqual(error as? AquariumConfiguration.FileError, .newer(2))
        }
        XCTAssertThrowsError(try AquariumConfiguration.decode(committed[names[2]]!)) { error in
            XCTAssertEqual(error as? AquariumConfiguration.FileError, .malformed)
        }
        XCTAssertEqual(try AquariumConfiguration.decode(committed[names[3]]!).id, validID)

        // A reload and a save of a new aquarium leave every sample byte for byte.
        library.reload()
        XCTAssertTrue(library.save(name: "Fresh tank", core: AquariumCore(seed: 7),
                                   now: Date(timeIntervalSinceReferenceDate: 900), id: sampleID("B1")),
                      library.lastFailure ?? "")
        XCTAssertEqual(library.entries.map(\.id), [sampleID("B1"), validID])
        XCTAssertEqual(library.unreadable, 2)
        XCTAssertEqual(library.newer, 1)
        for name in names {
            XCTAssertEqual(try storage.read(name), committed[name], "\(name) is unchanged")
        }

        // A new library over the same storage sees the same counts; the samples are still unchanged.
        let again = AquariumLibrary(storage: storage)
        XCTAssertEqual(again.entries.map(\.id), [sampleID("B1"), validID])
        XCTAssertEqual(again.unreadable, 2)
        XCTAssertEqual(again.newer, 1)
        for name in names {
            XCTAssertEqual(try storage.read(name), committed[name], "\(name) is unchanged after a new library")
        }
    }

    func testTheStoredSchemaOneToThreeExamplesRestore() async throws {
        let examples = [AquariumCore.schemaOneExample(), AquariumCore.schemaTwoExample(),
                        AquariumCore.schemaThreeExample()]
        for (index, made) in examples.enumerated() {
            let example = try XCTUnwrap(made, "schema \(index + 1) example")
            XCTAssertEqual(example.version, index + 1)
            var engine = ExperienceEngine<AquariumCore>(id: AquariumTest.id)
            try await engine.prepare(seed: 3)
            try engine.activate()
            try engine.restore(ExperienceSnapshot(data: example.snapshot))
            XCTAssertEqual(try engine.digest().hex, example.expectedDigest, "schema \(index + 1)")
            XCTAssertEqual(try XCTUnwrap(engine.core).document.schema, HabitatDocument.currentSchema)
        }
    }
}
