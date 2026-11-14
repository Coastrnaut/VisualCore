// ScopePresetMigrationTests — feature 066 (A08-P06) T-A08-605 (FR-A08-610; SC-A08-602; US2; spec clarification 3).
// The five committed scope preset fixtures (`Fixtures/`, bundled with `resources: [.copy("Fixtures")]`, T-A08-604)
// copied into a temporary experience storage under their own names: the two format-1 files (square waveform; sine
// spectrum) are listed after the three built-ins with their settings; the format-2 file is counted in `newer`; the
// damaged file and the valid body claiming the built-in "Audio overview" id are counted in `unreadable`; and every
// fixture stays byte for byte as committed after loading, after a save and a delete of another preset, and after a
// reload in a new store. Short runs only (well under 1 s).
import Foundation
import XCTest
@testable import OscilloscopeStudioExperience
import OscilloscopeStudioCore
import VisualCoreAudioDSP
import VisualCoreExperience

@MainActor
final class ScopePresetMigrationTests: XCTestCase {
    private var storage: ExperienceStorage!
    private var cleanUp: (@Sendable () -> Void)?

    /// The fixture file names: two format 1 (both listed), format 2 (newer), damaged and built-in claim (both
    /// unreadable).
    private static let fixtureNames = [
        "scope-00000000-0000-4000-8000-0000000008c1.json",
        "scope-00000000-0000-4000-8000-0000000008c2.json",
        "scope-00000000-0000-4000-8000-0000000008c3.json",
        "scope-00000000-0000-4000-8000-0000000008c4.json",
        "scope-00000000-0000-4000-8000-0000000008a1.json",
    ]
    /// The id of the format-1 waveform fixture.
    private let squareID = UUID(uuidString: "00000000-0000-4000-8000-0000000008C1")!
    /// The id of the format-1 spectrum fixture.
    private let spectrumID = UUID(uuidString: "00000000-0000-4000-8000-0000000008C2")!

    override func setUpWithError() throws {
        let made = try ScopeTest.temporaryStorage()
        storage = made.storage
        cleanUp = made.cleanUp
    }

    override func tearDown() {
        cleanUp?()
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
        XCTAssertEqual(ScopePreset.fileName(for: squareID), Self.fixtureNames[0])
        XCTAssertEqual(ScopePreset.fileName(for: spectrumID), Self.fixtureNames[1])
        XCTAssertEqual(ScopePreset.fileName(for: ScopePreset.builtIns[0].id), Self.fixtureNames[4],
                       "the a1 fixture claims the Audio overview built-in's id")
        for name in Self.fixtureNames {
            XCTAssertNotNil(ScopePreset.id(fromFileName: name), "\(name) is a preset file name")
        }
    }

    func testTheFormatOneFixturesAreWhatTheEncoderWrites() throws {
        let folder = try fixtureFolder()
        for index in 0..<2 {
            let data = try Data(contentsOf: folder.appendingPathComponent(Self.fixtureNames[index]))
            let preset = try ScopePreset.decode(data)
            XCTAssertEqual(try preset.fileData(), data, "\(Self.fixtureNames[index]) re-encodes byte for byte")
        }
        let newer = try Data(contentsOf: folder.appendingPathComponent(Self.fixtureNames[2]))
        XCTAssertThrowsError(try ScopePreset.decode(newer)) { XCTAssertEqual($0 as? ScopePreset.FileError, .newer(2)) }
        let damaged = try Data(contentsOf: folder.appendingPathComponent(Self.fixtureNames[3]))
        XCTAssertThrowsError(try ScopePreset.decode(damaged)) {
            XCTAssertEqual($0 as? ScopePreset.FileError, .malformed)
        }
        let claim = try Data(contentsOf: folder.appendingPathComponent(Self.fixtureNames[4]))
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: claim), "the claim is valid JSON")
        XCTAssertThrowsError(try ScopePreset.decode(claim), "a body claiming a built-in id is refused") {
            XCTAssertEqual($0 as? ScopePreset.FileError, .malformed)
        }
    }

    func testTheStoreListsTheBuiltInsAndTheTwoLoadableFixtures() throws {
        let bytes = try install()
        XCTAssertEqual(bytes.count, 5)
        let store = ScopePresetStore(storage: storage)
        XCTAssertEqual(store.entries.count, ScopePreset.builtIns.count + 2)
        XCTAssertEqual(Array(store.entries.prefix(3)), ScopePreset.builtIns)
        XCTAssertEqual(store.entries.prefix(3).map(\.id.uuidString),
                       ["00000000-0000-4000-8000-0000000008A1", "00000000-0000-4000-8000-0000000008A2",
                        "00000000-0000-4000-8000-0000000008A3"], "the built-ins in their fixed order")
        XCTAssertEqual(store.entries.dropFirst(3).map(\.id), [squareID, spectrumID], "sorted by name")
        XCTAssertEqual(store.unreadable, 2, "damaged and built-in claim")
        XCTAssertEqual(store.newer, 1, "format 2")
        XCTAssertNil(store.lastMessage)

        let square = try XCTUnwrap(store.preset(squareID))
        XCTAssertEqual(square.name, "Old square")
        XCTAssertEqual(square.savedAt, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertFalse(square.isBuiltIn)
        XCTAssertEqual(square.settings, ScopePreset.Settings(waveform: .square, frequencyIndex: 1, gainIndex: 2,
                                                             timebaseIndex: 4, triggerLevel: -0.25,
                                                             triggerSlope: .falling, triggerMode: .normal,
                                                             display: .waveform))

        let spectrum = try XCTUnwrap(store.preset(spectrumID))
        XCTAssertEqual(spectrum.name, "Quiet spectrum")
        XCTAssertEqual(spectrum.savedAt, Date(timeIntervalSinceReferenceDate: 100))
        XCTAssertFalse(spectrum.isBuiltIn)
        XCTAssertEqual(spectrum.settings, ScopePreset.Settings(waveform: .sine, frequencyIndex: 3, gainIndex: 1,
                                                               timebaseIndex: 0, triggerLevel: 0.5,
                                                               triggerSlope: .rising, triggerMode: .auto,
                                                               display: .spectrum))

        XCTAssertEqual(store.preset(ScopePreset.builtIns[0].id), ScopePreset.builtIns[0],
                       "the built-in claim never replaces the built-in")
        XCTAssertEqual(store.preset(ScopePreset.builtIns[0].id)?.name, "Audio overview")
        try assertFixturesUnchanged(bytes, "after loading")
    }

    func testEveryFixtureStaysByteIdenticalAfterASaveADeleteAndAReload() throws {
        let bytes = try install()
        let store = ScopePresetStore(storage: storage)
        let state = try XCTUnwrap(ScopeState(source: .testSignal, waveform: .sweep, frequencyIndex: 2, gainIndex: 3,
                                             timebaseIndex: 1, triggerLevel: 0.1, triggerSlope: .rising,
                                             triggerMode: .auto, display: .waveform))
        let saved = try XCTUnwrap(store.save(name: "Fresh", from: state,
                                             now: Date(timeIntervalSinceReferenceDate: 500)))
        XCTAssertNil(store.lastMessage)
        XCTAssertEqual(store.entries.count, ScopePreset.builtIns.count + 3)
        try assertFixturesUnchanged(bytes, "after a save")

        XCTAssertTrue(store.delete(saved.id))
        XCTAssertNil(store.lastMessage)
        XCTAssertFalse(storage.exists(ScopePreset.fileName(for: saved.id)))
        try assertFixturesUnchanged(bytes, "after a delete")

        let relaunched = ScopePresetStore(storage: storage)
        XCTAssertEqual(relaunched.entries.map(\.id), ScopePreset.builtIns.map(\.id) + [squareID, spectrumID])
        XCTAssertEqual(relaunched.unreadable, 2)
        XCTAssertEqual(relaunched.newer, 1)
        try assertFixturesUnchanged(bytes, "after a reload")
    }
}
