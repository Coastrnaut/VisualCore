// ScopePresetTests — feature 064 (A08-P04) T-A08-402 (FR-A08-410, FR-A08-430; clarification 4; research D4). The scope
// preset document, host-free and short: the format-1 file round trip with sorted keys and no source, freeze or cursor
// keys; name trimming and the 1…40 character limit; a greater format refused as `.newer`; damaged files refused as
// `.malformed`; applying keeps the source, the freeze and the cursors; the three built-ins with their ids, order and
// settings; the file name.
import Foundation
import Testing
import VisualCoreAudioDSP
import OscilloscopeStudioCore

@Suite struct ScopePresetTests {
    private let id = UUID(uuidString: "00000000-0000-4000-8000-000000000641")!
    private let now = Date(timeIntervalSinceReferenceDate: 815_000_000.5)

    private func customState() throws -> ScopeState {
        try #require(ScopeState(source: .microphone, waveform: .square, frequencyIndex: 1, gainIndex: 3,
                                timebaseIndex: 0, triggerLevel: -0.375, triggerSlope: .falling, triggerMode: .normal,
                                display: .xy, frozen: true, cursorsShown: true, cursorA: 0.1, cursorB: 0.2,
                                frequencyCursor: 0.3, levelCursor: -0.4))
    }

    private func json(_ preset: ScopePreset) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: preset.fileData()) as? [String: Any])
    }

    /// The file of `preset` with `key` replaced by `value` (a JSON literal) or removed when `value` is nil.
    private func edited(_ preset: ScopePreset, _ key: String, _ value: Any?) throws -> Data {
        var object = try json(preset)
        object[key] = value
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    @Test func theFileRoundTripsWithSortedKeysAndSettingsOnly() throws {
        let preset = try #require(ScopePreset.from(state: try customState(), name: "Bass check", id: id, now: now))
        let data = try preset.fileData()
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"display\":1,\"format\":1,\"frequency\":1,\"gain\":3,\"id\":"))
        let object = try json(preset)
        #expect(Set(object.keys) == ["display", "format", "frequency", "gain", "id", "level", "mode", "name",
                                     "savedAt", "slope", "timebase", "waveform"])
        let back = try ScopePreset.decode(data)
        #expect(back == preset)
        #expect(back.name == "Bass check" && back.savedAt == now && !back.isBuiltIn)
        #expect(try back.fileData() == data)
        #expect(ScopePreset.format == 1)
    }

    @Test func namesAreTrimmedAndLimitedToFortyCharacters() throws {
        let settings = ScopePreset.Settings(of: .initial)
        let trimmed = try #require(ScopePreset(id: id, name: "  \n Bass check \t", savedAt: now, settings: settings))
        #expect(trimmed.name == "Bass check")
        let forty = String(repeating: "é", count: 40)
        #expect(ScopePreset(id: id, name: forty, savedAt: now, settings: settings)?.name == forty)
        #expect(ScopePreset(id: id, name: " " + forty + " ", savedAt: now, settings: settings)?.name == forty)
        #expect(ScopePreset(id: id, name: forty + "x", savedAt: now, settings: settings) == nil)
        #expect(ScopePreset(id: id, name: "", savedAt: now, settings: settings) == nil)
        #expect(ScopePreset(id: id, name: " \n\t ", savedAt: now, settings: settings) == nil)
        #expect(ScopePreset.from(state: .initial, name: String(repeating: "a", count: 41), id: id, now: now) == nil)
        #expect(ScopePreset.validName("x") == "x")
        // Duplicates are allowed; presets are told apart by id.
        let other = UUID(uuidString: "00000000-0000-4000-8000-000000000642")!
        #expect(ScopePreset.from(state: .initial, name: "Same", id: other, now: now)?.name
                    == ScopePreset.from(state: .initial, name: "Same", id: id, now: now)?.name)
    }

    @Test func aNewerFormatIsRefusedAsNewer() throws {
        let preset = try #require(ScopePreset.from(state: .initial, name: "Later", id: id, now: now))
        #expect(throws: ScopePreset.FileError.newer(2)) { try ScopePreset.decode(try edited(preset, "format", 2)) }
        let unknownShape = Data("{\"format\":7,\"anything\":true}".utf8)
        #expect(throws: ScopePreset.FileError.newer(7)) { try ScopePreset.decode(unknownShape) }
    }

    @Test func damagedFilesAreRefusedAsMalformed() throws {
        let preset = try #require(ScopePreset.from(state: .initial, name: "Damaged", id: id, now: now))
        var damaged: [Data] = [Data(), Data("not json".utf8), Data("{}".utf8), Data("[1,2]".utf8)]
        let data = try preset.fileData()
        damaged.append(data.prefix(data.count / 2))
        for (key, value) in [("format", 0), ("waveform", 3), ("frequency", 4), ("gain", 5), ("timebase", 6),
                             ("slope", 2), ("mode", 2), ("display", 3)] as [(String, Any)] {
            damaged.append(try edited(preset, key, value))
        }
        damaged.append(try edited(preset, "level", 1.5))
        damaged.append(try edited(preset, "level", "nan"))
        damaged.append(try edited(preset, "name", ""))
        damaged.append(try edited(preset, "name", String(repeating: "n", count: 41)))
        damaged.append(try edited(preset, "id", "not-a-uuid"))
        damaged.append(try edited(preset, "id", "00000000-0000-4000-8000-0000000008A1"))   // a built-in's id
        damaged.append(try edited(preset, "savedAt", nil))
        for file in damaged {
            #expect(throws: ScopePreset.FileError.malformed) { try ScopePreset.decode(file) }
        }
    }

    @Test func applyingKeepsTheSourceFreezeAndCursors() throws {
        let saved = try #require(ScopePreset.from(state: try customState(), name: "Mine", id: id, now: now))
        let target = try #require(ScopeState(source: .file, waveform: .sweep, frequencyIndex: 3, gainIndex: 0,
                                             timebaseIndex: 5, triggerLevel: 0.5, triggerSlope: .rising,
                                             triggerMode: .auto, display: .spectrum, frozen: false,
                                             cursorsShown: true, cursorA: 0.6, cursorB: 0.7, frequencyCursor: 0.8,
                                             levelCursor: 0.9))
        let applied = saved.applied(to: target)
        #expect(applied.source == .file && !applied.frozen && applied.cursorsShown)
        #expect(applied.cursorA == 0.6 && applied.cursorB == 0.7)
        #expect(applied.frequencyCursor == 0.8 && applied.levelCursor == 0.9)
        #expect(applied.waveform == .square && applied.frequencyIndex == 1 && applied.gainIndex == 3)
        #expect(applied.timebaseIndex == 0 && applied.triggerLevel == -0.375)
        #expect(applied.triggerSlope == .falling && applied.triggerMode == .normal && applied.display == .xy)
        #expect(ScopePreset.Settings(of: applied) == saved.settings)
        // Applying the settings of a state to that state changes nothing.
        let state = try customState()
        let same = try #require(ScopePreset.from(state: state, name: "Same", id: id, now: now))
        #expect(same.applied(to: state) == state)
    }

    @Test func theBuiltInsComeInOrderWithFixedIds() throws {
        let builtIns = ScopePreset.builtIns
        #expect(builtIns.map(\.name) == ["Audio overview", "Bass detail", "Spectrum check"])
        #expect(builtIns.map { $0.id.uuidString } == ["00000000-0000-4000-8000-0000000008A1",
                                                      "00000000-0000-4000-8000-0000000008A2",
                                                      "00000000-0000-4000-8000-0000000008A3"])
        #expect(builtIns.allSatisfy { $0.isBuiltIn })
        #expect(builtIns.allSatisfy { $0.savedAt == Date(timeIntervalSinceReferenceDate: 0) })
        let overview = builtIns[0].applied(to: .initial)
        #expect(overview == .initial)
        let bass = builtIns[1].settings
        #expect(bass.waveform == .sine && ScopeSettings.frequencies[bass.frequencyIndex] == 100)
        #expect(ScopeSettings.gains[bass.gainIndex] == 2)
        #expect(ScopeSettings.timebasesMilliseconds[bass.timebaseIndex] == 5)
        #expect(bass.triggerLevel == 0 && bass.triggerSlope == .rising && bass.triggerMode == .auto)
        #expect(bass.display == .waveform)
        let spectrum = builtIns[2].applied(to: .initial)
        #expect(spectrum.display == .spectrum)
        var expected = ScopeState.initial
        expected.select(ScopeDisplay.spectrum)
        #expect(spectrum == expected)
    }

    @Test func theFileNameIsTheLowercasedId() throws {
        #expect(ScopePreset.fileName(for: id) == "scope-00000000-0000-4000-8000-000000000641.json")
        let mixed = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000008A1"))
        #expect(ScopePreset.fileName(for: mixed) == "scope-00000000-0000-4000-8000-0000000008a1.json")
        #expect(ScopePreset.id(fromFileName: ScopePreset.fileName(for: id)) == id)
        #expect(ScopePreset.id(fromFileName: "journey-00000000-0000-4000-8000-000000000641.json") == nil)
        #expect(ScopePreset.id(fromFileName: "scope-1234.json") == nil)
    }
}
