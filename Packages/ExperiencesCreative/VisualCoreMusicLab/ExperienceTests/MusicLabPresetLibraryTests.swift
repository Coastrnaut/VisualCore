// MusicLabPresetLibraryTests — feature 050 (A06-P04) T-A06-404 (FR-A06-411, FR-A06-412; SC-A06-403; US2). The preset
// library in a temporary experience storage: built-ins listed first, save → reload in a new library with the same
// choices, the numbered suffix on a name clash (on save and on rename, built-in names included), built-ins refused for
// rename and delete, delete removing the file, planted unreadable and newer files counted and left byte-identical,
// and a save beyond the storage file limit refused with a message and nothing changed. Short runs only.
import XCTest
@testable import VisualCoreMusicLabExperience
import VisualCoreExperience
import VisualCoreMusicLabCore

@MainActor
final class MusicLabPresetLibraryTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUpWithError() throws {
        suite = "dev.visualcore.a06-p04.presets.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var storage: ExperienceStorage {
        ExperienceStorage(id: ExperienceID(rawValue: "a06.preset-test")!, root: root, defaults: defaults)
    }

    /// Non-default choices for the geometry scene (three parameters).
    private func geometryChoices() throws -> [MappingChoice] {
        [try XCTUnwrap(MappingChoice(feature: 6, gain: 2.5)),
         try XCTUnwrap(MappingChoice(feature: 1, gain: 0.5)),
         try XCTUnwrap(MappingChoice(feature: 4, gain: 3))]
    }

    /// The user presets (entries after the built-ins).
    private func userPresets(_ library: MusicLabPresetLibrary) -> [MusicPreset] {
        Array(library.entries.dropFirst(MusicPreset.builtIns.count))
    }

    func testBuiltInsAreListedFirst() throws {
        let library = MusicLabPresetLibrary(storage: storage)
        XCTAssertEqual(MusicPreset.builtIns.count, 3)
        XCTAssertEqual(library.entries.map(\.id), MusicPreset.builtIns.map(\.id))
        XCTAssertTrue(library.entries.allSatisfy(\.isBuiltIn))
        _ = try XCTUnwrap(library.save(name: "aardvark", scene: .bars, choices: MusicLabScene.bars.defaultChoices))
        XCTAssertEqual(Array(library.entries.prefix(3)).map(\.id), MusicPreset.builtIns.map(\.id))
        XCTAssertEqual(userPresets(library).map(\.name), ["aardvark"])
        XCTAssertEqual(library.unreadable, 0)
        XCTAssertEqual(library.newer, 0)
        XCTAssertNil(library.lastMessage)
    }

    func testSaveThenReloadInANewLibraryKeepsTheChoices() throws {
        let fixed = Date(timeIntervalSinceReferenceDate: 1_000)
        let library = MusicLabPresetLibrary(storage: storage)
        let choices = try geometryChoices()
        let saved = try XCTUnwrap(library.save(name: "  Night drive  ", scene: .geometry, choices: choices,
                                               now: fixed))
        _ = try XCTUnwrap(library.save(name: "Bright", scene: .rings, choices: MusicLabScene.rings.defaultChoices))
        XCTAssertEqual(saved.name, "Night drive")
        XCTAssertFalse(saved.isBuiltIn)
        XCTAssertTrue(storage.exists(MusicPreset.fileName(for: saved.id)))
        XCTAssertEqual(userPresets(library).map(\.name), ["Bright", "Night drive"])

        let relaunched = MusicLabPresetLibrary(storage: storage)
        XCTAssertEqual(relaunched.entries.map(\.id), library.entries.map(\.id))
        let loaded = try XCTUnwrap(relaunched.preset(saved.id))
        XCTAssertEqual(loaded.name, "Night drive")
        XCTAssertEqual(loaded.scene, .geometry)
        XCTAssertEqual(loaded.choices, choices)
        XCTAssertEqual(loaded.saved, fixed)
        XCTAssertFalse(loaded.isBuiltIn)
    }

    func testSavingAnExistingNameGetsTheNextFreeSuffix() throws {
        let library = MusicLabPresetLibrary(storage: storage)
        let choices = MusicLabScene.bars.defaultChoices
        XCTAssertEqual(library.save(name: "Name", scene: .bars, choices: choices)?.name, "Name")
        XCTAssertEqual(library.save(name: "Name", scene: .bars, choices: choices)?.name, "Name 2")
        XCTAssertEqual(library.save(name: "name", scene: .bars, choices: choices)?.name, "name 3")
        let builtInName = try XCTUnwrap(MusicPreset.builtIns.first).name
        XCTAssertEqual(library.save(name: builtInName, scene: .bars, choices: choices)?.name, builtInName + " 2",
                       "a built-in's name is taken too")
        XCTAssertEqual(library.save(name: "   ", scene: .bars, choices: choices)?.name, "Untitled")
        XCTAssertNil(library.lastMessage)
    }

    func testRenameToAUsedNameIsMadeUniqueAndKeepsTheSavedDate() throws {
        let fixed = Date(timeIntervalSinceReferenceDate: 5_000)
        let library = MusicLabPresetLibrary(storage: storage)
        let a = try XCTUnwrap(library.save(name: "Aurora", scene: .geometry, choices: try geometryChoices(),
                                           now: fixed))
        _ = try XCTUnwrap(library.save(name: "Bloom", scene: .bars, choices: MusicLabScene.bars.defaultChoices))
        XCTAssertTrue(library.rename(a.id, to: "bloom"))
        XCTAssertNil(library.lastMessage)
        let renamed = try XCTUnwrap(library.preset(a.id))
        XCTAssertEqual(renamed.name, "bloom 2")
        XCTAssertEqual(renamed.saved, fixed)
        XCTAssertEqual(renamed.choices, try geometryChoices())
        XCTAssertEqual(MusicLabPresetLibrary(storage: storage).preset(a.id)?.name, "bloom 2", "the file was rewritten")

        XCTAssertTrue(library.rename(a.id, to: "BLOOM 2"), "a change of case of its own name is not a clash")
        XCTAssertEqual(library.preset(a.id)?.name, "BLOOM 2")
        let builtInName = try XCTUnwrap(MusicPreset.builtIns.last).name
        XCTAssertTrue(library.rename(a.id, to: builtInName))
        XCTAssertEqual(library.preset(a.id)?.name, builtInName + " 2")
        XCTAssertEqual(userPresets(library).count, 2)
    }

    func testBuiltInsCannotBeRenamedOrDeleted() throws {
        let library = MusicLabPresetLibrary(storage: storage)
        let builtIn = try XCTUnwrap(MusicPreset.builtIns.first)
        XCTAssertFalse(library.rename(builtIn.id, to: "Mine"))
        XCTAssertNotNil(library.lastMessage)
        XCTAssertFalse(library.delete(builtIn.id))
        XCTAssertNotNil(library.lastMessage)
        XCTAssertEqual(library.preset(builtIn.id)?.name, builtIn.name)
        XCTAssertEqual(library.entries.map(\.id), MusicPreset.builtIns.map(\.id))
        XCTAssertTrue(storage.list().isEmpty)
    }

    func testDeleteRemovesTheFile() throws {
        let library = MusicLabPresetLibrary(storage: storage)
        let a = try XCTUnwrap(library.save(name: "Aurora", scene: .bars, choices: MusicLabScene.bars.defaultChoices))
        let b = try XCTUnwrap(library.save(name: "Bloom", scene: .rings, choices: MusicLabScene.rings.defaultChoices))
        XCTAssertTrue(library.delete(a.id))
        XCTAssertNil(library.lastMessage)
        XCTAssertFalse(storage.list().contains(MusicPreset.fileName(for: a.id)))
        XCTAssertTrue(storage.list().contains(MusicPreset.fileName(for: b.id)))
        XCTAssertNil(library.preset(a.id))
        XCTAssertEqual(userPresets(library).map(\.id), [b.id])
        XCTAssertFalse(library.delete(a.id), "already gone")
        XCTAssertNotNil(library.lastMessage)
        XCTAssertFalse(library.rename(a.id, to: "Gone"))
        XCTAssertNotNil(library.lastMessage)
    }

    func testUnreadableAndNewerFilesAreCountedAndLeftByteIdentical() throws {
        let garbageID = UUID(uuidString: "00000000-0000-4000-8000-000000000a41")!
        let newerID = UUID(uuidString: "00000000-0000-4000-8000-000000000a42")!
        let garbageName = MusicPreset.fileName(for: garbageID)
        let newerName = MusicPreset.fileName(for: newerID)
        let garbage = Data("not a preset {".utf8)
        let newerFile = Data(("{\"choices\":[{\"feature\":0,\"gain\":1},{\"feature\":2,\"gain\":1}],\"format\":2,"
                              + "\"id\":\"\(newerID.uuidString)\",\"name\":\"Future\",\"palette\":3,\"saved\":0,"
                              + "\"scene\":0}").utf8)
        try storage.write(garbage, to: garbageName)
        try storage.write(newerFile, to: newerName)

        let library = MusicLabPresetLibrary(storage: storage)
        XCTAssertEqual(library.unreadable, 1)
        XCTAssertEqual(library.newer, 1)
        XCTAssertEqual(library.entries.map(\.id), MusicPreset.builtIns.map(\.id))

        let a = try XCTUnwrap(library.save(name: "Kept", scene: .bars, choices: MusicLabScene.bars.defaultChoices))
        XCTAssertTrue(library.rename(a.id, to: "Renamed"))
        XCTAssertFalse(library.rename(newerID, to: "Overwrite"), "a newer file is refused, never rewritten")
        XCTAssertNotNil(library.lastMessage)
        XCTAssertFalse(library.rename(garbageID, to: "Overwrite"))
        XCTAssertTrue(library.delete(a.id))
        library.reload()
        XCTAssertEqual(library.unreadable, 1)
        XCTAssertEqual(library.newer, 1)

        let relaunched = MusicLabPresetLibrary(storage: storage)
        XCTAssertEqual(relaunched.unreadable, 1)
        XCTAssertEqual(relaunched.newer, 1)
        XCTAssertEqual(try storage.read(garbageName), garbage)
        XCTAssertEqual(try storage.read(newerName), newerFile)
        XCTAssertEqual(storage.list().sorted(), [garbageName, newerName].sorted())
    }

    func testARefusedWriteSetsAMessageAndChangesNothing() throws {
        let library = MusicLabPresetLibrary(storage: storage)
        let kept = try XCTUnwrap(library.save(name: "Kept", scene: .bars, choices: MusicLabScene.bars.defaultChoices))
        let keptName = MusicPreset.fileName(for: kept.id)
        let keptData = try storage.read(keptName)
        for i in 0..<(StorageQuota.maxFiles - 1) {
            try storage.write(Data("filler \(i)".utf8), to: "filler-\(i).txt")
        }
        XCTAssertEqual(storage.list().count, StorageQuota.maxFiles)
        let entriesBefore = library.entries.map(\.id)

        XCTAssertNil(library.save(name: "Overflow", scene: .geometry, choices: try geometryChoices()))
        let message = try XCTUnwrap(library.lastMessage)
        XCTAssertTrue(message.hasPrefix("Couldn't save the preset: "), message)
        XCTAssertTrue(message.contains(StorageError.quotaExceeded("files").code), message)
        XCTAssertEqual(library.entries.map(\.id), entriesBefore)
        XCTAssertEqual(storage.list().count, StorageQuota.maxFiles)
        XCTAssertEqual(try storage.read(keptName), keptData)

        // A rename replaces the existing file, so it still works at the limit.
        XCTAssertTrue(library.rename(kept.id, to: "Still kept"))
        XCTAssertNil(library.lastMessage)
        XCTAssertEqual(userPresets(library).map(\.name), ["Still kept"])
    }
}
