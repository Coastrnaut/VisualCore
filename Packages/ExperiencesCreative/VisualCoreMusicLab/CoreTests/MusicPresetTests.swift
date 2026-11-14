// MusicPresetTests — feature 050 (A06-P04) T-A06-403 (FR-A06-411, FR-A06-412, FR-A06-413; spec clarifications 3–4;
// data-model "MusicPreset"; research D5, D6). Name cleaning and uniqueness, validation of choices, the three
// read-only built-ins, the seven `preset.apply` action values, the format-1 file round trip, refusal of newer and
// malformed files, and the file-name/id round trip.
import Foundation
import Testing
import VisualCoreMusicLabCore

@Suite struct MusicPresetTests {
    private static let fileID = UUID(uuidString: "00000000-0000-4000-8000-000000000403")!

    private static func choice(_ feature: Int, _ gain: Double) -> MappingChoice {
        MappingChoice(feature: feature, gain: gain)!
    }

    private static func sample() -> MusicPreset {
        MusicPreset(
            id: fileID, name: "My bars", scene: .bars, choices: [choice(1, 2.5), choice(6, 0.75)],
            saved: Date(timeIntervalSinceReferenceDate: 815_000_000.5), isBuiltIn: true)!
    }

    private static func json(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private static func validObject() -> [String: Any] {
        [
            "choices": [["feature": 0, "gain": 1.0], ["feature": 2, "gain": 1.0]],
            "format": 1, "id": fileID.uuidString, "name": "Ok", "saved": 0.0, "scene": 0,
        ]
    }

    // MARK: Names

    @Test func cleanTrimsCutsAndDefaults() {
        #expect(MusicPreset.clean("  Pulse \n") == "Pulse")
        let long = String(repeating: "a", count: 80)
        #expect(MusicPreset.clean(long) == String(repeating: "a", count: 60))
        #expect(MusicPreset.clean("") == "Untitled")
        #expect(MusicPreset.clean(" \n\t ") == "Untitled")
        #expect(MusicPreset.nameLimit == 60)
    }

    @Test func uniqueNameAppendsFirstFreeNumberIgnoringCase() {
        #expect(MusicPreset.uniqueName("Pulse", among: []) == "Pulse")
        #expect(MusicPreset.uniqueName("Pulse", among: ["pulse"]) == "Pulse 2")
        #expect(MusicPreset.uniqueName("Pulse", among: ["Pulse", "Pulse 2"]) == "Pulse 3")
        #expect(MusicPreset.uniqueName("  pulse ", among: ["PULSE", "pulse 3"]) == "pulse 2")
        #expect(MusicPreset.uniqueName("", among: ["Untitled"]) == "Untitled 2")
    }

    @Test func uniqueNameKeepsLongNamesWithinTheLimit() {
        let long = String(repeating: "b", count: 60)
        let unique = MusicPreset.uniqueName(long, among: [long])
        #expect(unique.count == 60)
        #expect(unique == String(repeating: "b", count: 58) + " 2")
        let next = MusicPreset.uniqueName(long, among: [long, unique])
        #expect(next == String(repeating: "b", count: 58) + " 3")
    }

    // MARK: Validation

    @Test func initRefusesWrongCountAndInvalidChoices() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        #expect(
            MusicPreset(id: Self.fileID, name: "x", scene: .bars, choices: [Self.choice(0, 1)], saved: date) == nil)
        #expect(
            MusicPreset(
                id: Self.fileID, name: "x", scene: .geometry, choices: MusicLabScene.bars.defaultChoices, saved: date)
                == nil)
        var bad = Self.choice(0, 1)
        bad.gain = 9
        #expect(
            MusicPreset(id: Self.fileID, name: "x", scene: .bars, choices: [bad, Self.choice(2, 1)], saved: date)
                == nil)
        let ok = MusicPreset(
            id: Self.fileID, name: "  ", scene: .rings, choices: MusicLabScene.rings.defaultChoices, saved: date)
        #expect(ok?.name == "Untitled")
        #expect(ok?.isBuiltIn == false)
    }

    // MARK: Built-ins

    @Test func builtInsAreValidReadOnlyAndDistinct() {
        let builtIns = MusicPreset.builtIns
        #expect(builtIns.map(\.name) == ["Spectrum", "Waveform rings", "Pulse geometry"])
        #expect(builtIns.map(\.scene) == [.bars, .rings, .geometry])
        #expect(
            builtIns.map(\.id.uuidString) == [
                "00000000-0000-4000-8000-0000000006A1", "00000000-0000-4000-8000-0000000006A2",
                "00000000-0000-4000-8000-0000000006A3",
            ])
        #expect(Set(builtIns.map(\.id)).count == 3)
        #expect(Set(builtIns.map { $0.name.lowercased() }).count == 3)
        for preset in builtIns {
            #expect(preset.isBuiltIn)
            #expect(preset.choices.count == preset.scene.parameters.count)
            #expect(preset.choices.allSatisfy { $0.isValid })
            #expect(preset.choices != preset.scene.defaultChoices)
            #expect(preset.saved == Date(timeIntervalSinceReferenceDate: 0))
        }
    }

    // MARK: Action values

    @Test func actionValuesFillMissingSlotsWithZero() {
        #expect(Self.sample().actionValues == [0, 1, 2.5, 6, 0.75, 0, 0])
        #expect(MusicPreset.builtIns[1].actionValues == [1, 3, 1.2, 6, 2, 0, 0])
        #expect(MusicPreset.builtIns[2].actionValues == [2, 2, 1.5, 5, 1, 3, 1.5])
        #expect(MusicPreset.builtIns.allSatisfy { $0.actionValues.count == 7 })
    }

    // MARK: File coding

    @Test func fileRoundTripIsEqualAndNotBuiltIn() throws {
        let preset = Self.sample()
        let data = try preset.fileData()
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix("{\"choices\":"))
        #expect(text.contains("\"format\":1"))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let keys: Set<String> = ["choices", "format", "id", "name", "saved", "scene"]
        #expect(object.map { Set($0.keys) } == keys)
        let decoded = try MusicPreset.decode(data, fileID: Self.fileID)
        #expect(decoded.isBuiltIn == false)
        let expected = MusicPreset(
            id: preset.id, name: preset.name, scene: preset.scene, choices: preset.choices, saved: preset.saved)
        #expect(decoded == expected)
        #expect(MusicPreset.format == 1)
    }

    @Test func builtInRoundTripDropsTheFlag() throws {
        for preset in MusicPreset.builtIns {
            let decoded = try MusicPreset.decode(preset.fileData(), fileID: preset.id)
            #expect(decoded.isBuiltIn == false)
            #expect(decoded.name == preset.name && decoded.choices == preset.choices && decoded.scene == preset.scene)
        }
    }

    @Test func newerFormatIsRefused() {
        var object = Self.validObject()
        object["format"] = 2
        #expect(throws: MusicPreset.FileError.newer(2)) {
            try MusicPreset.decode(Self.json(object), fileID: Self.fileID)
        }
        #expect(throws: MusicPreset.FileError.newer(7)) {
            try MusicPreset.decode(Self.json(["format": 7, "future": true]), fileID: Self.fileID)
        }
    }

    @Test func malformedFilesAreRefused() throws {
        #expect(try MusicPreset.decode(Self.json(Self.validObject()), fileID: Self.fileID).name == "Ok")
        let other = UUID(uuidString: "00000000-0000-4000-8000-000000000404")!
        #expect(throws: MusicPreset.FileError.malformed) {
            try MusicPreset.decode(Self.json(Self.validObject()), fileID: other)
        }
        var scene = Self.validObject()
        scene["scene"] = 3
        var count = Self.validObject()
        count["choices"] = [["feature": 0, "gain": 1.0]]
        var invalid = Self.validObject()
        invalid["choices"] = [["feature": 9, "gain": 1.0], ["feature": 2, "gain": 1.0]]
        var missing = Self.validObject()
        missing.removeValue(forKey: "name")
        var badID = Self.validObject()
        badID["id"] = "not-a-uuid"
        var oldFormat = Self.validObject()
        oldFormat["format"] = 0
        for object in [scene, count, invalid, missing, badID, oldFormat] {
            #expect(throws: MusicPreset.FileError.malformed) {
                try MusicPreset.decode(Self.json(object), fileID: Self.fileID)
            }
        }
        for garbage in [Data(), Data("garbage".utf8), Data("[]".utf8), Data("{}".utf8)] {
            #expect(throws: MusicPreset.FileError.malformed) {
                try MusicPreset.decode(garbage, fileID: Self.fileID)
            }
        }
    }

    @Test func fileNameAndIDRoundTrip() {
        let name = MusicPreset.fileName(for: Self.fileID)
        #expect(name == "preset-00000000-0000-4000-8000-000000000403.json")
        #expect(MusicPreset.id(fromFileName: name) == Self.fileID)
        #expect(MusicPreset.id(fromFileName: "preset-nope.json") == nil)
        #expect(MusicPreset.id(fromFileName: "other-00000000-0000-4000-8000-000000000403.json") == nil)
        #expect(MusicPreset.id(fromFileName: "preset-00000000-0000-4000-8000-000000000403.txt") == nil)
        for preset in MusicPreset.builtIns {
            #expect(MusicPreset.id(fromFileName: MusicPreset.fileName(for: preset.id)) == preset.id)
        }
    }
}
