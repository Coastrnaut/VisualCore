// AquariumConfigurationTests — feature 072 (A09-P05) T-A09-503 (FR-A09-501, 502; edge cases "Saving with an empty or
// very long name", "A saved file of a newer format"). Saved aquarium configurations, host-free and short: the JSON
// round trip (deterministic bytes), the name cleaning, `make` from a document, every validation refusal, the newer
// and damaged file decoding, and the exact action list of a sample configuration.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import DigitalAquariumCore

@Suite struct AquariumConfigurationTests {
    private let catalog = SpeciesCatalog.bundled
    private let id = UUID(uuidString: "00000000-0000-4000-8000-000000000501")!

    /// A valid sample: the second habitat with two pieces, bright lighting, the second decoration kind, ambient on.
    private func sample() throws -> AquariumConfiguration {
        try #require(catalog.habitats.count >= 2)
        try #require(catalog.decor.count >= 2)
        return AquariumConfiguration(id: id, name: "Reef corner", savedAt: Date(timeIntervalSinceReferenceDate: 1_000),
                                     habitatIndex: 1, lighting: 2, decorKind: 1, ambient: true,
                                     decor: [.init(kindId: catalog.decor[1].id, x: 4, y: 2.25, rotation: 0.5,
                                                   scale: 1.5),
                                             .init(kindId: catalog.decor[0].id, x: 12, y: 6.75, rotation: -1,
                                                   scale: 0.75)])
    }

    @Test func roundTripsThroughJSONWithDeterministicBytes() throws {
        let config = try sample()
        let data = try config.fileData()
        let decoded = try AquariumConfiguration.decode(data)
        #expect(decoded == config)
        #expect(try decoded.fileData() == data)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"ambient\":true,\"decor\":["), "sorted keys")
        #expect(text.contains("\"format\":1"))
    }

    @Test func newerAndDamagedFilesAreRecognised() throws {
        var object = try #require(JSONSerialization.jsonObject(with: sample().fileData()) as? [String: Any])
        object["format"] = 2
        object["decor"] = "changed in format 2"
        let newer = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(throws: AquariumConfiguration.FileError.newer(2)) { try AquariumConfiguration.decode(newer) }
        #expect(throws: AquariumConfiguration.FileError.malformed) {
            try AquariumConfiguration.decode(Data("{not json".utf8))
        }
        object["format"] = 1
        #expect(throws: AquariumConfiguration.FileError.malformed) {
            try AquariumConfiguration.decode(JSONSerialization.data(withJSONObject: object))
        }
    }

    @Test func namesAreCleaned() {
        #expect(AquariumConfiguration.cleanedName("") == "My aquarium")
        #expect(AquariumConfiguration.cleanedName("  \n\t ") == "My aquarium")
        #expect(AquariumConfiguration.cleanedName("  Kelp at dusk ") == "Kelp at dusk")
        let sixty = String(repeating: "a", count: 60), forty = String(repeating: "b", count: 40)
        #expect(AquariumConfiguration.cleanedName(sixty) == String(repeating: "a", count: 40))
        #expect(AquariumConfiguration.cleanedName(forty) == forty)
        // A cut that ends in a space is trimmed again.
        let spaced = String(repeating: "c", count: 39) + "  tail"
        #expect(AquariumConfiguration.cleanedName(spaced) == String(repeating: "c", count: 39))
        #expect(AquariumConfiguration.defaultName == "My aquarium")
        #expect(AquariumConfiguration.maxNameLength == 40)
        #expect(AquariumConfiguration.currentFormat == 1)
    }

    @Test func makeTakesTheDocumentsArrangement() throws {
        var random = SeededRandom(seed: 3)
        var doc = HabitatDocument.starter(1, catalog: catalog, random: &random)
        doc.lighting = 0
        doc.decor = [DecorPlacement(kindId: catalog.decor[0].id, position: Vec2(3, 4), rotation: 0.25, scale: 1.25)]
        let when = Date(timeIntervalSinceReferenceDate: 77)
        let config = AquariumConfiguration.make(document: doc, decorKind: 1, ambient: true, name: "  ", id: id,
                                                savedAt: when)
        #expect(config == AquariumConfiguration(id: id, name: "My aquarium", savedAt: when, habitatIndex: 1,
                                                lighting: 0, decorKind: 1, ambient: true,
                                                decor: [.init(kindId: catalog.decor[0].id, x: 3, y: 4,
                                                              rotation: 0.25, scale: 1.25)]))
        #expect(config.validate(catalog: catalog).isEmpty)
    }

    @Test func aValidSampleHasNoProblems() throws {
        #expect(try sample().validate(catalog: catalog).isEmpty)
        var empty = try sample()
        empty.decor = []
        #expect(empty.validate(catalog: catalog).isEmpty)
    }

    @Test func eachBrokenRuleIsRefused() throws {
        let base = try sample()
        let kind = catalog.decor[0].id
        let cases: [(String, (inout AquariumConfiguration) -> Void)] = [
            ("format", { $0.format = 2 }),
            ("empty name", { $0.name = "" }),
            ("long name", { $0.name = String(repeating: "n", count: 41) }),
            ("untrimmed name", { $0.name = " padded" }),
            ("habitat", { $0.habitatIndex = 99 }),
            ("negative habitat", { $0.habitatIndex = -1 }),
            ("lighting low", { $0.lighting = -1 }),
            ("lighting high", { $0.lighting = 3 }),
            ("decoration kind", { $0.decorKind = 99 }),
            ("too many pieces", { $0.decor = Array(repeating: .init(kindId: kind, x: 1, y: 1), count: 13) }),
            ("x outside", { $0.decor[0].x = 16.5 }),
            ("y outside", { $0.decor[0].y = -0.1 }),
            ("x not finite", { $0.decor[0].x = .nan }),
            ("y not finite", { $0.decor[0].y = .infinity }),
            ("rotation", { $0.decor[0].rotation = 3.5 }),
            ("rotation not finite", { $0.decor[0].rotation = .nan }),
            ("scale low", { $0.decor[0].scale = 0.4 }),
            ("scale high", { $0.decor[0].scale = 2.1 }),
            ("unknown kind", { $0.decor[1].kindId = "no-such-rock" }),
        ]
        for (label, breakIt) in cases {
            var broken = base
            breakIt(&broken)
            #expect(!broken.validate(catalog: catalog).isEmpty, "\(label) is refused")
        }
        // The limits themselves are accepted.
        var edges = base
        edges.name = String(repeating: "e", count: 40)
        edges.decor = Array(repeating: .init(kindId: kind, x: 16, y: 9, rotation: Double.pi, scale: 2), count: 12)
        edges.decor[0] = .init(kindId: kind, x: 0, y: 0, rotation: -Double.pi, scale: 0.5)
        #expect(edges.validate(catalog: catalog).isEmpty)
    }

    @Test func theActionListIsExact() throws {
        let config = try sample()
        let starter = min(catalog.habitats[1].decor.count, HabitatDocument.maxDecor)
        var expected: [(String, [Double])] = [("habitat.select", [1])]
        expected += Array(repeating: ("decor.remove", [0.0]), count: starter)
        expected += [("decor.kind", [1]), ("decor.place", [0.25, 0.25]), ("decor.turn", [0, 0.5, 1.5]),
                     ("decor.kind", [0]), ("decor.place", [0.75, 0.75]), ("decor.turn", [1, -1, 0.75]),
                     ("decor.kind", [1]), ("lighting.level", [2]), ("ambient.mode", [1])]
        let actions = config.actions(catalog: catalog)
        #expect(actions.map(\.control) == expected.map(\.0))
        #expect(actions.map(\.values) == expected.map(\.1))

        var off = config
        off.ambient = false
        off.decor = []
        off.habitatIndex = 0
        let first = min(catalog.habitats[0].decor.count, HabitatDocument.maxDecor)
        let short = off.actions(catalog: catalog)
        #expect(short.map(\.control) == ["habitat.select"] + Array(repeating: "decor.remove", count: first)
                + ["decor.kind", "lighting.level", "ambient.mode"])
        #expect(short.last?.values == [0])
    }
}
