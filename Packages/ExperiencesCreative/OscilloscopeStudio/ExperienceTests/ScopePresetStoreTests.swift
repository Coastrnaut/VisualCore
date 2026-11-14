// ScopePresetStoreTests — feature 064 (A08-P04) T-A08-404 (FR-A08-410, FR-A08-430; SC-A08-404; story 3 AC1–AC3; edge
// cases "Preset names", "Storage full or unwritable"). The scope preset store in a temporary experience storage, short
// runs only (each test well under 10 s): the three built-ins listed first and refused for rename and delete; save,
// rename, apply (the presenter's individual actions on a core), delete and reload in 5 of 5 cases; names trimmed to
// 1…40 characters, duplicates allowed; planted damaged, newer, mismatched-id and built-in-id files counted and left
// byte-identical; a save beyond the storage file limit refused with the storage code and nothing changed; and a new
// session listing a saved preset and applying it, a built-in through `preset.apply`.
import Foundation
import XCTest
@testable import OscilloscopeStudioExperience
import OscilloscopeStudioCore
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class ScopePresetStoreTests: XCTestCase {
    private var storage: ExperienceStorage!
    private var cleanUp: (@Sendable () -> Void)?

    override func setUpWithError() throws {
        let made = try ScopeTest.temporaryStorage()
        storage = made.storage
        cleanUp = made.cleanUp
    }

    override func tearDown() {
        cleanUp?()
    }

    /// The user presets (entries after the built-ins).
    private func userPresets(_ store: ScopePresetStore) -> [ScopePreset] {
        Array(store.entries.dropFirst(ScopePreset.builtIns.count))
    }

    /// Five distinct scope states.
    private var states: [ScopeState] {
        [
            ScopeState(source: .testSignal, waveform: .square, frequencyIndex: 1, gainIndex: 2, timebaseIndex: 4,
                       triggerLevel: -0.25, triggerSlope: .falling, triggerMode: .normal, display: .waveform),
            ScopeState(source: .microphone, waveform: .sine, frequencyIndex: 0, gainIndex: 3, timebaseIndex: 5,
                       triggerLevel: 0.5, triggerSlope: .rising, triggerMode: .auto, display: .xy, frozen: true,
                       cursorsShown: true, cursorA: 0.1),
            ScopeState(source: .file, waveform: .sweep, frequencyIndex: 3, gainIndex: 0, timebaseIndex: 0,
                       triggerLevel: 1, triggerSlope: .rising, triggerMode: .normal, display: .spectrum),
            ScopeState(source: .testSignal, waveform: .sine, frequencyIndex: 2, gainIndex: 4, timebaseIndex: 2,
                       triggerLevel: -1, triggerSlope: .falling, triggerMode: .auto, display: .waveform),
            ScopeState(source: .testSignal, waveform: .square, frequencyIndex: 3, gainIndex: 1, timebaseIndex: 1,
                       triggerLevel: 0.05, triggerSlope: .rising, triggerMode: .auto, display: .xy),
        ].compactMap { $0 }
    }

    func testBuiltInsComeFirstAndAreReadOnly() throws {
        let store = ScopePresetStore(storage: storage)
        XCTAssertEqual(store.entries.map(\.name), ["Audio overview", "Bass detail", "Spectrum check"])
        XCTAssertTrue(store.entries.allSatisfy(\.isBuiltIn))
        let builtIn = ScopePreset.builtIns[0]
        XCTAssertFalse(store.rename(builtIn.id, to: "Mine"))
        XCTAssertEqual(store.lastMessage, "Built-in presets can't be renamed.")
        XCTAssertFalse(store.delete(builtIn.id))
        XCTAssertEqual(store.lastMessage, "Built-in presets can't be deleted.")
        _ = try XCTUnwrap(store.save(name: "aardvark", from: ScopeState.initial))
        XCTAssertEqual(Array(store.entries.prefix(3)).map(\.id), ScopePreset.builtIns.map(\.id))
        XCTAssertEqual(userPresets(store).map(\.name), ["aardvark"])
        XCTAssertEqual(store.unreadable, 0)
        XCTAssertEqual(store.newer, 0)
        XCTAssertNil(store.lastMessage)
        XCTAssertEqual(ScopePresetStore.builtInIndex(of: ScopePreset.builtIns[2]), 2)
        XCTAssertNil(ScopePresetStore.builtInIndex(of: userPresets(store)[0]))
    }

    func testSaveRenameApplyDeleteAndReloadInFiveOfFiveCases() throws {
        let cases = states
        XCTAssertEqual(cases.count, 5)
        var passed = 0
        for (index, state) in cases.enumerated() {
            let store = ScopePresetStore(storage: storage)
            let when = Date(timeIntervalSinceReferenceDate: Double(1_000 + index))
            let saved = try XCTUnwrap(store.save(name: "  Case \(index)  ", from: state, now: when))
            XCTAssertEqual(saved.name, "Case \(index)", "trimmed")
            XCTAssertTrue(storage.exists(ScopePreset.fileName(for: saved.id)))

            // Reload in a new store: the same settings.
            let reloaded = ScopePresetStore(storage: storage)
            let loaded = try XCTUnwrap(reloaded.preset(saved.id))
            XCTAssertEqual(loaded, saved)
            XCTAssertEqual(loaded.settings, ScopePreset.Settings(of: state))

            // Rename keeps the settings and the saved time.
            XCTAssertTrue(reloaded.rename(saved.id, to: "Renamed \(index)"))
            let renamed = try XCTUnwrap(ScopePresetStore(storage: storage).preset(saved.id))
            XCTAssertEqual(renamed.name, "Renamed \(index)")
            XCTAssertEqual(renamed.settings, saved.settings)
            XCTAssertEqual(renamed.savedAt, when)

            // Apply as the presenter does for a user preset: its settings as individual actions on a core.
            var core = ScopeCore(seed: 1)
            for (control, value) in ScopePresenter.presetActions(renamed.settings) {
                XCTAssertTrue(core.apply(ExperienceAction(control: control, values: [value], step: 0)).isAccepted,
                              "\(control) \(value)")
            }
            XCTAssertEqual(ScopePreset.Settings(of: core.state), renamed.settings)
            XCTAssertEqual(core.state.source, .testSignal, "the source is never part of a preset")
            XCTAssertFalse(core.state.frozen)
            XCTAssertFalse(core.state.cursorsShown)

            // Delete removes the file; a reload no longer lists it.
            XCTAssertTrue(reloaded.delete(saved.id))
            XCTAssertFalse(storage.exists(ScopePreset.fileName(for: saved.id)))
            XCTAssertNil(ScopePresetStore(storage: storage).preset(saved.id))
            XCTAssertFalse(reloaded.delete(saved.id), "already gone")
            XCTAssertTrue(try XCTUnwrap(reloaded.lastMessage).contains("storage.not-found"))
            passed += 1
        }
        XCTAssertEqual(passed, 5)
    }

    func testNamesAreTrimmedToOneToFortyCharactersAndDuplicatesAreAllowed() throws {
        let store = ScopePresetStore(storage: storage)
        XCTAssertNil(store.save(name: "   ", from: ScopeState.initial))
        XCTAssertEqual(store.lastMessage, "Couldn't save the preset: the name needs 1 to 40 characters.")
        XCTAssertNil(store.save(name: String(repeating: "x", count: 41), from: ScopeState.initial))
        XCTAssertEqual(storage.list(), [], "nothing written")
        let forty = try XCTUnwrap(store.save(name: String(repeating: "y", count: 40), from: ScopeState.initial))
        let first = try XCTUnwrap(store.save(name: "Same", from: ScopeState.initial))
        let second = try XCTUnwrap(store.save(name: "same ", from: ScopeState.initial))
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(userPresets(store).map(\.name).sorted(), ["Same", "same", String(repeating: "y", count: 40)])
        XCTAssertFalse(store.rename(forty.id, to: ""))
        XCTAssertEqual(store.lastMessage, "Couldn't rename the preset: the name needs 1 to 40 characters.")
        XCTAssertEqual(store.preset(forty.id)?.name, String(repeating: "y", count: 40))
    }

    func testDamagedNewerMismatchedAndBuiltInFilesAreKeptByteIdenticalAndCounted() throws {
        let valid = try XCTUnwrap(ScopePreset.from(state: ScopeState.initial, name: "Valid",
                                                    id: UUID(uuidString: "00000000-0000-4000-8000-000000000A01")!,
                                                    now: Date(timeIntervalSinceReferenceDate: 5)))
        var newerObject = try XCTUnwrap(JSONSerialization.jsonObject(with: valid.fileData()) as? [String: Any])
        newerObject["format"] = 2
        newerObject["id"] = "00000000-0000-4000-8000-000000000A02"
        let newer = try JSONSerialization.data(withJSONObject: newerObject, options: [.sortedKeys])
        var builtInObject = newerObject
        builtInObject["format"] = 1
        builtInObject["id"] = ScopePreset.builtIns[0].id.uuidString
        let planted: [(String, Data)] = [
            ("scope-00000000-0000-4000-8000-000000000a03.json", Data("{not json".utf8)),
            ("scope-00000000-0000-4000-8000-000000000a02.json", newer),
            // Valid content under another id's name.
            ("scope-00000000-0000-4000-8000-000000000a04.json", try valid.fileData()),
            (ScopePreset.fileName(for: ScopePreset.builtIns[0].id),
             try JSONSerialization.data(withJSONObject: builtInObject, options: [.sortedKeys])),
            (ScopePreset.fileName(for: valid.id), try valid.fileData()),
        ]
        for (name, data) in planted { try storage.write(data, to: name) }
        let store = ScopePresetStore(storage: storage)
        XCTAssertEqual(store.unreadable, 3, "damaged, mismatched id, built-in id")
        XCTAssertEqual(store.newer, 1)
        XCTAssertEqual(userPresets(store).map(\.id), [valid.id])
        // A save and a reload leave every planted file byte-identical.
        _ = try XCTUnwrap(store.save(name: "Another", from: ScopeState.initial))
        store.reload()
        XCTAssertEqual(store.unreadable, 3)
        XCTAssertEqual(store.newer, 1)
        for (name, data) in planted {
            XCTAssertEqual(try storage.read(name), data, name)
        }
        // A newer file is never rewritten by a rename.
        XCTAssertFalse(store.rename(UUID(uuidString: "00000000-0000-4000-8000-000000000A02")!, to: "Mine"))
        XCTAssertEqual(store.lastMessage, "Couldn't rename the preset: it was made by a newer version.")
        XCTAssertEqual(try storage.read(planted[1].0), newer)
    }

    func testASaveBeyondTheStorageLimitIsRefusedAndChangesNothing() throws {
        for i in 0..<StorageQuota.maxFiles {
            try storage.write(Data("x".utf8), to: "other-\(i).bin")
        }
        let store = ScopePresetStore(storage: storage)
        let before = storage.list()
        XCTAssertNil(store.save(name: "Full", from: ScopeState.initial))
        let message = try XCTUnwrap(store.lastMessage)
        XCTAssertTrue(message.hasPrefix("Couldn't save the preset: "), message)
        XCTAssertTrue(message.contains(StorageError.quotaExceeded("files").code), message)
        XCTAssertEqual(storage.list(), before)
        XCTAssertEqual(store.entries.map(\.id), ScopePreset.builtIns.map(\.id))
    }

    func testANewSessionListsASavedPresetAndAppliesIt() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, storage: storage)
        for (control, value) in [("gain.select", 2.0), ("timebase.select", 5), ("signal.frequency", 0),
                                 ("trigger.level", 0.3), ("display.select", 1)] {
            XCTAssertTrue(shell.handle(control: control, values: [value]).isAccepted)
        }
        let saved = try XCTUnwrap(shell.presenter.savePreset(named: "Bass check"))
        let expected = try XCTUnwrap(shell.engine.core).state
        XCTAssertEqual(saved.settings, ScopePreset.Settings(of: expected))
        session.close()

        let next = ExperienceSession()
        let reopened = try await ScopeTest.open(next, storage: storage)
        let presenter = reopened.presenter
        XCTAssertEqual(Array(presenter.presetEntries.prefix(3)).map(\.id), ScopePreset.builtIns.map(\.id))
        let listed = try XCTUnwrap(presenter.presetEntries.first { $0.name == "Bass check" })
        XCTAssertEqual(listed, saved)
        XCTAssertEqual(presenter.apply(listed), .accepted)
        let state = try XCTUnwrap(reopened.engine.core).state
        XCTAssertEqual(ScopePreset.Settings(of: state), saved.settings)

        // A built-in goes through `preset.apply`.
        XCTAssertEqual(presenter.apply(ScopePreset.builtIns[2]), .accepted)
        XCTAssertEqual(try XCTUnwrap(reopened.engine.core).state.display, .spectrum)
        XCTAssertTrue(presenter.renamePreset(listed.id, to: "Bass check 2"))
        XCTAssertTrue(presenter.deletePreset(listed.id))
        XCTAssertEqual(presenter.presetEntries.map(\.id), ScopePreset.builtIns.map(\.id))
        next.close()
    }
}
