// MusicLabPresetMigrationTests — feature 052 (A06-P06) T-A06-605 (FR-A06-610; SC-A06-602; US2; spec clarification 3).
// The five committed preset fixtures (`Fixtures/`, bundled with `resources: [.copy("Fixtures")]`, T-A06-604) copied
// into a temporary experience storage under their own names: the format-1 file (rings, read with palette Aurora) and
// the format-2 file (geometry, palette Ember) are listed after the three built-ins with their scenes, choices and
// palettes; the format-3 file is counted in `newer`; the damaged file and the valid body claiming a built-in id are
// counted in `unreadable`; and every fixture stays byte for byte as committed after loading, after a save and a delete
// of another preset, and after a reload in a new store. Short runs only.
import XCTest
@testable import VisualCoreMusicLabExperience
import VisualCoreExperience
import VisualCoreMusicLabCore

@MainActor
final class MusicLabPresetMigrationTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    /// The fixture file names: format 1 / format 2 (both listed), format 3 (newer), damaged and built-in claim
    /// (both unreadable).
    private static let fixtureNames = [
        "preset-00000000-0000-4000-8000-0000000006b1.json",
        "preset-00000000-0000-4000-8000-0000000006b2.json",
        "preset-00000000-0000-4000-8000-0000000006b3.json",
        "preset-00000000-0000-4000-8000-0000000006b4.json",
        "preset-00000000-0000-4000-8000-0000000006a1.json",
    ]
    /// The id of the format-1 fixture.
    private let formatOneID = UUID(uuidString: "00000000-0000-4000-8000-0000000006B1")!
    /// The id of the format-2 fixture.
    private let formatTwoID = UUID(uuidString: "00000000-0000-4000-8000-0000000006B2")!

    override func setUpWithError() throws {
        suite = "dev.visualcore.a06-p06.preset-migration.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var storage: ExperienceStorage {
        ExperienceStorage(id: ExperienceID(rawValue: "a06.preset-migration-test")!, root: root, defaults: defaults)
    }

    /// The bundled fixture folder.
    private func fixtureFolder() throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil), "missing Fixtures folder")
    }

    /// Copies every file of the bundled fixture folder into the storage under its own name (through
    /// `ExperienceStorage.write`); returns the committed bytes by file name.
    @discardableResult
    private func install() throws -> [String: Data] {
        let files = try FileManager.default.contentsOfDirectory(at: fixtureFolder(), includingPropertiesForKeys: nil)
        var bytes: [String: Data] = [:]
        for url in files {
            let data = try Data(contentsOf: url)
            try storage.write(data, to: url.lastPathComponent)
            bytes[url.lastPathComponent] = data
        }
        return bytes
    }

    /// Asserts that every fixture file in the storage is byte-identical to the committed fixture.
    private func assertFixturesUnchanged(_ bytes: [String: Data], _ when: String,
                                         file: StaticString = #filePath, line: UInt = #line) throws {
        for name in Self.fixtureNames {
            XCTAssertEqual(try storage.read(name), bytes[name], "\(name) byte-identical \(when)",
                           file: file, line: line)
        }
    }

    func testTheBundleHoldsExactlyTheFiveFixturesNamedByTheirIDs() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: fixtureFolder().path).sorted()
        XCTAssertEqual(names, Self.fixtureNames.sorted())
        XCTAssertEqual(MusicPreset.fileName(for: formatOneID), Self.fixtureNames[0])
        XCTAssertEqual(MusicPreset.fileName(for: formatTwoID), Self.fixtureNames[1])
        XCTAssertEqual(MusicPreset.fileName(for: MusicPreset.builtIns[0].id), Self.fixtureNames[4],
                       "the a1 fixture claims the first built-in's id")
    }

    func testTheStoreListsTheBuiltInsAndTheTwoLoadableFixtures() throws {
        let bytes = try install()
        XCTAssertEqual(bytes.count, 5)
        let library = MusicLabPresetStore(storage: storage)
        XCTAssertEqual(library.entries.count, MusicPreset.builtIns.count + 2)
        XCTAssertEqual(Array(library.entries.prefix(3)), MusicPreset.builtIns)
        XCTAssertEqual(library.entries.dropFirst(3).map(\.id), [formatOneID, formatTwoID], "sorted by name")
        XCTAssertEqual(library.unreadable, 2, "damaged and built-in claim")
        XCTAssertEqual(library.newer, 1, "format 3")
        XCTAssertNil(library.lastMessage)

        let old = try XCTUnwrap(library.preset(formatOneID))
        XCTAssertEqual(old.name, "Old rings")
        XCTAssertEqual(old.scene, .rings)
        XCTAssertEqual(old.choices, [try XCTUnwrap(MappingChoice(feature: 0, gain: 1)),
                                     try XCTUnwrap(MappingChoice(feature: 5, gain: 1))])
        XCTAssertEqual(old.palette, .aurora, "format 1 reads with palette Aurora")
        XCTAssertEqual(old.saved, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertFalse(old.isBuiltIn)

        let warm = try XCTUnwrap(library.preset(formatTwoID))
        XCTAssertEqual(warm.name, "Warm pulse")
        XCTAssertEqual(warm.scene, .geometry)
        XCTAssertEqual(warm.choices, [try XCTUnwrap(MappingChoice(feature: 2, gain: 2)),
                                      try XCTUnwrap(MappingChoice(feature: 0, gain: 0.5)),
                                      try XCTUnwrap(MappingChoice(feature: 3, gain: 1.5))])
        XCTAssertEqual(warm.palette, .ember)
        XCTAssertEqual(warm.saved, Date(timeIntervalSinceReferenceDate: 100))
        XCTAssertFalse(warm.isBuiltIn)

        XCTAssertEqual(library.preset(MusicPreset.builtIns[0].id), MusicPreset.builtIns[0],
                       "the built-in claim never replaces the built-in")
        try assertFixturesUnchanged(bytes, "after loading")
    }

    func testEveryFixtureStaysByteIdenticalAfterASaveADeleteAndAReload() throws {
        let bytes = try install()
        let library = MusicLabPresetStore(storage: storage)
        let saved = try XCTUnwrap(library.save(name: "Fresh", scene: .bars, choices: MusicLabScene.bars.defaultChoices,
                                               palette: .mono, now: Date(timeIntervalSinceReferenceDate: 500)))
        XCTAssertNil(library.lastMessage)
        XCTAssertEqual(library.entries.count, MusicPreset.builtIns.count + 3)
        try assertFixturesUnchanged(bytes, "after a save")

        XCTAssertTrue(library.delete(saved.id))
        XCTAssertNil(library.lastMessage)
        XCTAssertFalse(storage.exists(MusicPreset.fileName(for: saved.id)))
        try assertFixturesUnchanged(bytes, "after a delete")

        let relaunched = MusicLabPresetStore(storage: storage)
        XCTAssertEqual(relaunched.entries.map(\.id),
                       MusicPreset.builtIns.map(\.id) + [formatOneID, formatTwoID])
        XCTAssertEqual(relaunched.unreadable, 2)
        XCTAssertEqual(relaunched.newer, 1)
        try assertFixturesUnchanged(bytes, "after a reload")
    }
}
