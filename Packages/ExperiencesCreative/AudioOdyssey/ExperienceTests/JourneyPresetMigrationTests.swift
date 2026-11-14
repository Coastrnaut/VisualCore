// JourneyPresetMigrationTests — feature 059 (A07-P06) T-A07-605 (FR-A07-610; SC-A07-602; US2; spec clarification 3;
// research D4). The five committed journey fixtures (`Fixtures/`, bundled with `resources: [.copy("Fixtures")]`,
// T-A07-604) copied into a temporary experience storage under their own names: the two format-1 files (tunnel; star
// corridor with calm motion on) are listed after the three built-ins with their worlds, mappings and calm motion; the
// format-2 file is counted in `newer`; the damaged file and the valid body claiming the built-in Deep tunnel id are
// counted in `unreadable`; and every fixture stays byte for byte as committed after loading, after a save and a delete
// of another journey, and after a reload in a new store. Short runs only (well under 1 s).
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreExperience

@MainActor
final class JourneyPresetMigrationTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    /// The fixture file names: two format 1 (both listed), format 2 (newer), damaged and built-in claim (both
    /// unreadable).
    private static let fixtureNames = [
        "journey-00000000-0000-4000-8000-0000000007c1.json",
        "journey-00000000-0000-4000-8000-0000000007c2.json",
        "journey-00000000-0000-4000-8000-0000000007c3.json",
        "journey-00000000-0000-4000-8000-0000000007c4.json",
        "journey-00000000-0000-4000-8000-0000000007b1.json",
    ]
    /// The id of the format-1 tunnel fixture.
    private let tunnelID = UUID(uuidString: "00000000-0000-4000-8000-0000000007C1")!
    /// The id of the format-1 star-corridor fixture.
    private let starsID = UUID(uuidString: "00000000-0000-4000-8000-0000000007C2")!

    override func setUpWithError() throws {
        suite = "dev.visualcore.a07-p06.journey-migration.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var storage: ExperienceStorage {
        ExperienceStorage(id: ExperienceID(rawValue: "a07.journey-migration-test")!, root: root, defaults: defaults)
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
        XCTAssertEqual(JourneyPreset.fileName(for: tunnelID), Self.fixtureNames[0])
        XCTAssertEqual(JourneyPreset.fileName(for: starsID), Self.fixtureNames[1])
        XCTAssertEqual(JourneyPreset.fileName(for: JourneyPreset.builtIns[0].id), Self.fixtureNames[4],
                       "the b1 fixture claims the Deep tunnel built-in's id")
    }

    func testTheFormatOneFixturesAreWhatTheEncoderWrites() throws {
        let folder = try fixtureFolder()
        for (index, id) in [tunnelID, starsID].enumerated() {
            let data = try Data(contentsOf: folder.appendingPathComponent(Self.fixtureNames[index]))
            let preset = try JourneyPreset.decode(data, fileID: id)
            XCTAssertEqual(try preset.fileData(), data, "\(Self.fixtureNames[index]) re-encodes byte for byte")
        }
        let newer = try Data(contentsOf: folder.appendingPathComponent(Self.fixtureNames[2]))
        XCTAssertThrowsError(try JourneyPreset.decode(newer, fileID: UUID(uuidString:
            "00000000-0000-4000-8000-0000000007C3")!)) { XCTAssertEqual($0 as? JourneyPreset.FileError, .newer(2)) }
        let damaged = try Data(contentsOf: folder.appendingPathComponent(Self.fixtureNames[3]))
        XCTAssertThrowsError(try JourneyPreset.decode(damaged, fileID: UUID(uuidString:
            "00000000-0000-4000-8000-0000000007C4")!)) { XCTAssertEqual($0 as? JourneyPreset.FileError, .malformed) }
        let claim = try Data(contentsOf: folder.appendingPathComponent(Self.fixtureNames[4]))
        XCTAssertNoThrow(try JourneyPreset.decode(claim, fileID: JourneyPreset.builtIns[0].id),
                         "the claim is a valid body; only the store refuses it for its built-in id")
    }

    func testTheStoreListsTheBuiltInsAndTheTwoLoadableFixtures() throws {
        let bytes = try install()
        XCTAssertEqual(bytes.count, 5)
        let store = JourneyPresetStore(storage: storage)
        XCTAssertEqual(store.entries.count, JourneyPreset.builtIns.count + 2)
        XCTAssertEqual(Array(store.entries.prefix(3)), JourneyPreset.builtIns)
        XCTAssertEqual(store.entries.dropFirst(3).map(\.id), [tunnelID, starsID], "sorted by name")
        XCTAssertEqual(store.unreadable, 2, "damaged and built-in claim")
        XCTAssertEqual(store.newer, 1, "format 2")
        XCTAssertNil(store.lastMessage)

        let tunnel = try XCTUnwrap(store.preset(tunnelID))
        XCTAssertEqual(tunnel.name, "Old tunnel")
        XCTAssertEqual(tunnel.world, .tunnel)
        XCTAssertFalse(tunnel.calmMotion)
        XCTAssertEqual(tunnel.speedTarget, 3)
        XCTAssertEqual(tunnel.easing, .standard)
        XCTAssertEqual(tunnel.mapping(for: .tunnel),
                       WorldMapping(primary: ChannelMapping(channel: .low, sensitivity: .high),
                                    light: ChannelMapping(channel: .overall)))
        XCTAssertEqual(tunnel.mapping(for: .landscape), WorldMapping.defaults(for: .landscape))
        XCTAssertEqual(tunnel.mapping(for: .starCorridor), WorldMapping.defaults(for: .starCorridor))
        XCTAssertEqual(tunnel.saved, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertFalse(tunnel.isBuiltIn)

        let stars = try XCTUnwrap(store.preset(starsID))
        XCTAssertEqual(stars.name, "Quiet stars")
        XCTAssertEqual(stars.world, .starCorridor)
        XCTAssertTrue(stars.calmMotion)
        XCTAssertEqual(stars.speedTarget, 2.5)
        XCTAssertEqual(stars.easing, .gentle)
        XCTAssertEqual(stars.mapping(for: .starCorridor),
                       WorldMapping(primary: ChannelMapping(channel: .transient, sensitivity: .low),
                                    light: ChannelMapping(channel: .high)))
        XCTAssertEqual(stars.saved, Date(timeIntervalSinceReferenceDate: 100))
        XCTAssertFalse(stars.isBuiltIn)

        XCTAssertEqual(store.preset(JourneyPreset.builtIns[0].id), JourneyPreset.builtIns[0],
                       "the built-in claim never replaces the built-in")
        try assertFixturesUnchanged(bytes, "after loading")
    }

    func testEveryFixtureStaysByteIdenticalAfterASaveADeleteAndAReload() throws {
        let bytes = try install()
        let store = JourneyPresetStore(storage: storage)
        let saved = try XCTUnwrap(store.save(name: "Fresh", from: JourneyState(seed: 7, world: .landscape),
                                             now: Date(timeIntervalSinceReferenceDate: 500)))
        XCTAssertNil(store.lastMessage)
        XCTAssertEqual(store.entries.count, JourneyPreset.builtIns.count + 3)
        try assertFixturesUnchanged(bytes, "after a save")

        XCTAssertTrue(store.delete(saved.id))
        XCTAssertNil(store.lastMessage)
        XCTAssertFalse(storage.exists(JourneyPreset.fileName(for: saved.id)))
        try assertFixturesUnchanged(bytes, "after a delete")

        let relaunched = JourneyPresetStore(storage: storage)
        XCTAssertEqual(relaunched.entries.map(\.id), JourneyPreset.builtIns.map(\.id) + [tunnelID, starsID])
        XCTAssertEqual(relaunched.unreadable, 2)
        XCTAssertEqual(relaunched.newer, 1)
        try assertFixturesUnchanged(bytes, "after a reload")
    }
}
