// JourneyPresetTests — feature 057 (A07-P04) T-A07-402 (FR-A07-401, FR-A07-402, FR-A07-403, FR-A07-404; clarifications
// 1–3; data-model "JourneyPreset"; research D2, D3). Name cleaning and uniqueness, validation, the capture of a journey
// state, the three read-only built-ins, the sixteen `preset.apply` values and their validation, the format-1 file round
// trip, refusal of newer and malformed files, and the file-name/id round trip.
import Foundation
import Testing
import AudioOdysseyCore

@Suite struct JourneyPresetTests {
    private static let fileID = UUID(uuidString: "00000000-0000-4000-8000-000000000402")!

    private static func custom() -> [WorldMapping] {
        [
            WorldMapping(primary: ChannelMapping(channel: .high, sensitivity: .low),
                         light: ChannelMapping(channel: .transient, sensitivity: .high)),
            WorldMapping(primary: ChannelMapping(channel: .overall, sensitivity: .high),
                         light: ChannelMapping(channel: .low, sensitivity: .low)),
            WorldMapping(primary: ChannelMapping(channel: .mid, sensitivity: .medium),
                         light: ChannelMapping(channel: .high, sensitivity: .medium)),
        ]
    }

    private static func sample() -> JourneyPreset {
        JourneyPreset(id: fileID, name: "My flight", saved: Date(timeIntervalSinceReferenceDate: 815_000_000.5),
                      world: .landscape, mappings: custom(), speedTarget: 5.5, easing: .brisk, calmMotion: true,
                      isBuiltIn: true)!
    }

    private static func json(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private static func mappingObject(_ p: Int = 0, _ ps: Int = 1, _ l: Int = 4, _ ls: Int = 1) -> [String: Any] {
        ["lightChannel": l, "lightSensitivity": ls, "primaryChannel": p, "primarySensitivity": ps]
    }

    private static func validObject() -> [String: Any] {
        [
            "calm": false, "easing": 1, "format": 1, "id": fileID.uuidString,
            "mappings": [mappingObject(0), mappingObject(1), mappingObject(3)], "name": "Ok", "saved": 0.0,
            "speedTarget": 4.0, "world": 0,
        ]
    }

    // MARK: Names

    @Test func cleanTrimsCutsAndDefaults() {
        #expect(JourneyPreset.clean("  Deep \n") == "Deep")
        #expect(JourneyPreset.clean(String(repeating: "a", count: 80)) == String(repeating: "a", count: 60))
        #expect(JourneyPreset.clean("") == "Untitled")
        #expect(JourneyPreset.clean(" \n\t ") == "Untitled")
        #expect(JourneyPreset.nameLimit == 60)
    }

    @Test func uniqueNameAppendsFirstFreeNumberIgnoringCase() {
        #expect(JourneyPreset.uniqueName("Flight", among: []) == "Flight")
        #expect(JourneyPreset.uniqueName("Flight", among: ["flight"]) == "Flight 2")
        #expect(JourneyPreset.uniqueName("Flight", among: ["Flight", "Flight 2"]) == "Flight 3")
        #expect(JourneyPreset.uniqueName("  flight ", among: ["FLIGHT", "flight 3"]) == "flight 2")
        #expect(JourneyPreset.uniqueName("", among: ["Untitled"]) == "Untitled 2")
        #expect(JourneyPreset.uniqueName("deep tunnel", among: JourneyPreset.builtIns.map(\.name)) == "deep tunnel 2")
    }

    @Test func uniqueNameKeepsLongNamesWithinTheLimit() {
        let long = String(repeating: "b", count: 60)
        let unique = JourneyPreset.uniqueName(long, among: [long])
        #expect(unique == String(repeating: "b", count: 58) + " 2")
        #expect(JourneyPreset.uniqueName(long, among: [long, unique]) == String(repeating: "b", count: 58) + " 3")
    }

    // MARK: Validation and capture

    @Test func initValidatesMappingsAndSpeedTarget() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        func make(_ mappings: [WorldMapping], _ speed: Double) -> JourneyPreset? {
            JourneyPreset(id: Self.fileID, name: "x", saved: date, world: .tunnel, mappings: mappings,
                          speedTarget: speed, easing: .standard, calmMotion: false)
        }
        #expect(make(Array(WorldMapping.allDefaults.prefix(2)), 4) == nil)
        #expect(make(WorldMapping.allDefaults + [WorldMapping.defaults(for: .tunnel)], 4) == nil)
        for bad in [Double.nan, .infinity, -.infinity, 0.25, 7.5, -1] { #expect(make(WorldMapping.allDefaults, bad) == nil) }
        #expect(make(WorldMapping.allDefaults, 3.3)?.speedTarget == 3.5)
        #expect(make(WorldMapping.allDefaults, 0.5)?.speedTarget == 0.5)
        #expect(make(WorldMapping.allDefaults, 7)?.speedTarget == 7)
        let ok = JourneyPreset(id: Self.fileID, name: "  ", saved: date, world: .starCorridor,
                               mappings: WorldMapping.allDefaults, speedTarget: 2, easing: .gentle, calmMotion: true)
        #expect(ok?.name == "Untitled")
        #expect(ok?.isBuiltIn == false)
    }

    @Test func initFromStateCapturesTheJourneyFields() {
        let state = JourneyState(seed: 7, world: .starCorridor, distance: 12, speedTarget: 6.5, speed: 3,
                                 paused: true, source: .microphone, easing: .brisk, calmMotion: true,
                                 mappings: Self.custom())
        let preset = JourneyPreset(from: state, id: Self.fileID, name: " Captured ",
                                   saved: Date(timeIntervalSinceReferenceDate: 10))
        #expect(preset.name == "Captured" && preset.id == Self.fileID && preset.isBuiltIn == false)
        #expect(preset.world == .starCorridor && preset.speedTarget == 6.5 && preset.easing == .brisk)
        #expect(preset.calmMotion && preset.mappings == Self.custom())
        #expect(preset.mapping(for: .landscape) == Self.custom()[1])
    }

    // MARK: Built-ins

    @Test func builtInsAreValidReadOnlyDistinctAndAsSpecified() {
        let builtIns = JourneyPreset.builtIns
        #expect(builtIns.map(\.name) == ["Deep tunnel", "Rolling hills", "Night stars"])
        #expect(builtIns.map(\.world) == [.tunnel, .landscape, .starCorridor])
        #expect(builtIns.map(\.speedTarget) == [3.5, 4.0, 2.5])
        #expect(builtIns.map(\.easing) == [.gentle, .standard, .gentle])
        #expect(builtIns.map(\.calmMotion) == [false, false, true])
        #expect(builtIns.map(\.id.uuidString) == [
            "00000000-0000-4000-8000-0000000007B1", "00000000-0000-4000-8000-0000000007B2",
            "00000000-0000-4000-8000-0000000007B3",
        ])
        #expect(Set(builtIns.map(\.id)).count == 3)
        #expect(Set(builtIns.map { $0.name.lowercased() }).count == 3)
        let primaries: [ChannelMapping] = [ChannelMapping(channel: .low, sensitivity: .high),
                                           ChannelMapping(channel: .mid, sensitivity: .medium),
                                           ChannelMapping(channel: .transient, sensitivity: .high)]
        for (preset, primary) in zip(builtIns, primaries) {
            #expect(preset.isBuiltIn)
            #expect(preset.saved == Date(timeIntervalSinceReferenceDate: 0))
            #expect(preset.mappings.count == 3)
            #expect(preset.mapping(for: preset.world) == WorldMapping(
                primary: primary, light: ChannelMapping(channel: .overall, sensitivity: .medium)))
            for other in JourneyWorld.allCases where other != preset.world {
                #expect(preset.mapping(for: other) == WorldMapping.defaults(for: other))
            }
        }
        #expect(Set(builtIns.map(\.actionValues)).count == 3)
    }

    // MARK: Action values

    @Test func actionValuesLayout() {
        #expect(Self.sample().actionValues == [1, 2, 0, 3, 2, 4, 2, 0, 0, 1, 1, 2, 1, 5.5, 2, 1])
        #expect(JourneyPreset.builtIns[0].actionValues == [0, 0, 2, 4, 1, 1, 1, 4, 1, 3, 1, 4, 1, 3.5, 0, 0])
        #expect(JourneyPreset.builtIns[2].actionValues == [2, 0, 1, 4, 1, 1, 1, 4, 1, 3, 2, 4, 1, 2.5, 0, 1])
        #expect(JourneyPreset.builtIns.allSatisfy { $0.actionValues.count == JourneyPreset.actionValueCount })
        #expect(JourneyPreset.actionValueCount == 16)
    }

    @Test func fromActionValuesRoundTrips() throws {
        for preset in JourneyPreset.builtIns + [Self.sample()] {
            let read = try #require(JourneyPreset.fromActionValues(preset.actionValues))
            #expect(read.world == preset.world && read.mappings == preset.mappings)
            #expect(read.speedTarget == preset.speedTarget && read.easing == preset.easing)
            #expect(read.calmMotion == preset.calmMotion)
        }
        var offGrid = Self.sample().actionValues
        offGrid[13] = 5.3
        #expect(JourneyPreset.fromActionValues(offGrid)?.speedTarget == 5.5)
    }

    @Test func fromActionValuesRefusesBadValues() {
        let valid = Self.sample().actionValues
        #expect(JourneyPreset.fromActionValues([]) == nil)
        #expect(JourneyPreset.fromActionValues(Array(valid.prefix(15))) == nil)
        #expect(JourneyPreset.fromActionValues(valid + [0]) == nil)
        let bad: [(Int, Double)] = [
            (0, 3), (0, -1), (0, 0.5), (0, .nan),
            (1, 5), (2, 3), (3, 1.5), (4, -1), (9, .infinity), (12, 3),
            (13, .nan), (13, .infinity), (13, 0.4), (13, 7.1), (13, -2),
            (14, 3), (14, 0.5), (15, 2), (15, 0.5), (15, -1), (15, .nan),
        ]
        for (index, value) in bad {
            var values = valid
            values[index] = value
            #expect(JourneyPreset.fromActionValues(values) == nil, "index \(index) value \(value)")
        }
    }

    // MARK: File coding

    @Test func fileRoundTripIsEqualAndNotBuiltIn() throws {
        let preset = Self.sample()
        let data = try preset.fileData()
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix("{\"calm\":true,\"easing\":2,\"format\":1,"))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["calm", "easing", "format", "id", "mappings", "name", "saved", "speedTarget",
                                     "world"])
        let mappings = try #require(object["mappings"] as? [[String: Any]])
        #expect(mappings.count == 3)
        #expect(mappings.allSatisfy {
            Set($0.keys) == ["lightChannel", "lightSensitivity", "primaryChannel", "primarySensitivity"]
        })
        #expect(text.contains("{\"lightChannel\":3,\"lightSensitivity\":2,\"primaryChannel\":2,\"primarySensitivity\":0}"))
        let decoded = try JourneyPreset.decode(data, fileID: Self.fileID)
        #expect(decoded.isBuiltIn == false)
        let expected = JourneyPreset(id: preset.id, name: preset.name, saved: preset.saved, world: preset.world,
                                     mappings: preset.mappings, speedTarget: preset.speedTarget, easing: preset.easing,
                                     calmMotion: preset.calmMotion)
        #expect(decoded == expected)
        #expect(try decoded.fileData() == data)
        #expect(JourneyPreset.format == 1)
    }

    @Test func builtInRoundTripDropsTheFlag() throws {
        for preset in JourneyPreset.builtIns {
            let decoded = try JourneyPreset.decode(preset.fileData(), fileID: preset.id)
            #expect(decoded.isBuiltIn == false)
            #expect(decoded.actionValues == preset.actionValues && decoded.name == preset.name)
        }
    }

    @Test func newerFormatIsRefused() {
        var object = Self.validObject()
        object["format"] = 2
        #expect(throws: JourneyPreset.FileError.newer(2)) {
            try JourneyPreset.decode(Self.json(object), fileID: Self.fileID)
        }
        #expect(throws: JourneyPreset.FileError.newer(9)) {
            try JourneyPreset.decode(Self.json(["format": 9, "future": true]), fileID: Self.fileID)
        }
    }

    @Test func malformedFilesAreRefused() throws {
        let ok = try JourneyPreset.decode(Self.json(Self.validObject()), fileID: Self.fileID)
        #expect(ok.name == "Ok" && ok.mappings == WorldMapping.allDefaults && ok.speedTarget == 4)
        let other = UUID(uuidString: "00000000-0000-4000-8000-000000000403")!
        #expect(throws: JourneyPreset.FileError.malformed) {
            try JourneyPreset.decode(Self.json(Self.validObject()), fileID: other)
        }
        var variants: [[String: Any]] = []
        for (key, value) in [("world", 3 as Any), ("easing", 3), ("speedTarget", 7.5), ("speedTarget", 0.0),
                             ("speedTarget", "fast"), ("id", "not-a-uuid"), ("format", 0), ("calm", "yes"),
                             ("mappings", [Self.mappingObject(), Self.mappingObject()]),
                             ("mappings", [Self.mappingObject(), Self.mappingObject(), Self.mappingObject(5)]),
                             ("mappings", [Self.mappingObject(), Self.mappingObject(0, 3), Self.mappingObject()]),
                             ("mappings", [Self.mappingObject(), Self.mappingObject(0, 1, 9), Self.mappingObject()]),
                             ("mappings", [Self.mappingObject(), Self.mappingObject(0, 1, 4, -1),
                                           Self.mappingObject()])] {
            var object = Self.validObject()
            object[key] = value
            variants.append(object)
        }
        for key in ["calm", "easing", "id", "mappings", "name", "saved", "speedTarget", "world"] {
            var object = Self.validObject()
            object.removeValue(forKey: key)
            variants.append(object)
        }
        var missingInner = Self.validObject()
        missingInner["mappings"] = [Self.mappingObject(), ["primaryChannel": 0], Self.mappingObject()]
        variants.append(missingInner)
        for object in variants {
            #expect(throws: JourneyPreset.FileError.malformed) {
                try JourneyPreset.decode(Self.json(object), fileID: Self.fileID)
            }
        }
        for garbage in [Data(), Data("garbage".utf8), Data("[]".utf8), Data("{}".utf8)] {
            #expect(throws: JourneyPreset.FileError.malformed) {
                try JourneyPreset.decode(garbage, fileID: Self.fileID)
            }
        }
    }

    @Test func fileNameRoundTrip() {
        let name = JourneyPreset.fileName(for: Self.fileID)
        #expect(name == "journey-00000000-0000-4000-8000-000000000402.json")
        #expect(JourneyPreset.id(fromFileName: name) == Self.fileID)
        let builtIn = JourneyPreset.builtIns[0].id
        #expect(JourneyPreset.fileName(for: builtIn) == "journey-00000000-0000-4000-8000-0000000007b1.json")
        #expect(JourneyPreset.id(fromFileName: JourneyPreset.fileName(for: builtIn)) == builtIn)
        for bad in ["preset-00000000-0000-4000-8000-000000000402.json", "journey-00000000-0000-4000-8000-000000000402.txt",
                    "journey-.json", "journey-not-a-uuid-at-all-not-a-uuid-at-all.json", "journey-x.json", ""] {
            #expect(JourneyPreset.id(fromFileName: bad) == nil)
        }
    }
}
