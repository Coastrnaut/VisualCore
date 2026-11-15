// HabitatMigrationTests — feature 069 (A09-P02) T-A09-203 (FR-A09-212; clarification 4; research D4; SC-A09-204).
// The habitat document's schema 2 and the migration from schema 1, host-free and short: a schema-1 JSON document (no
// `turn`, `rotation` or `scale`, no decor) decodes with the defaults, is refused until migrated, and
// `migrated(catalog:)` gives schema 2 with the habitat's starter decor while keeping fish, plants and lighting; a
// schema-1 document with decor keeps it (rotation 0, scale 1); a schema-2 document is unchanged; validation refuses
// scales 0.4 and 2.1, rotation 4, an unknown decor kind, decor outside the tank and a non-finite turn; a schema-2
// document round-trips identically; and the catalog decoder refuses bad decor kinds and spots while a catalog without
// decor keys still decodes.
// Feature 070 (A09-P03) T-A09-302 (FR-A09-320; research D3): schema 3 — schemas 1 and 2 (no `food` key) decode with
// no food and migrate to 3 (schema 2 keeps its decor, even none); a schema-2 document is refused until migrated; a
// schema-3 document with food round-trips identically; schema 4 is left alone.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import DigitalAquariumCore

@Suite struct HabitatMigrationTests {
    private let catalog = SpeciesCatalog.bundled

    private func starter(_ index: Int, seed: UInt64 = 5) -> HabitatDocument {
        var random = SeededRandom(seed: seed)
        return HabitatDocument.starter(index, catalog: catalog, random: &random)
    }

    private func encoded(_ doc: HabitatDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(doc)
    }

    /// `doc` written as schema 1 wrote it: schema 1, no fish `turn`, no decor `rotation` or `scale`, and the decor
    /// replaced by `decor` (default none).
    private func schemaOneJSON(_ doc: HabitatDocument, decor: [[String: Any]] = []) throws -> Data {
        var object = try #require(try JSONSerialization.jsonObject(with: encoded(doc)) as? [String: Any])
        let fish = try #require(object["fish"] as? [[String: Any]])
        object["schema"] = 1
        object["fish"] = fish.map { var f = $0; f["turn"] = nil; return f }
        object["decor"] = decor
        object["food"] = nil
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// `doc` written as schema 2 wrote it: schema 2 and no `food` key.
    private func schemaTwoJSON(_ doc: HabitatDocument) throws -> Data {
        var object = try #require(try JSONSerialization.jsonObject(with: encoded(doc)) as? [String: Any])
        object["schema"] = 2
        object["food"] = nil
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    @Test(arguments: [0, 1]) func aSchemaOneDocumentDecodesAndMigratesWithStarterDecor(index: Int) throws {
        var original = starter(index)
        original.lighting = 2
        let data = try schemaOneJSON(original)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(!text.contains("\"turn\"") && !text.contains("\"rotation\"") && !text.contains("\"scale\""))
        #expect(!text.contains("\"food\""))
        let old = try JSONDecoder().decode(HabitatDocument.self, from: data)
        #expect(old.schema == 1 && old.decor.isEmpty && old.food.isEmpty)
        #expect(old.fish.allSatisfy { $0.turn == 0 })
        #expect(old.validate(catalog: catalog).contains { $0.contains("schema 1") })
        let migrated = old.migrated(catalog: catalog)
        #expect(migrated.schema == HabitatDocument.currentSchema && migrated.schema == 3)
        #expect(migrated.food.isEmpty)
        #expect(migrated.decor == catalog.habitats[index].decor.map { DecorPlacement($0) })
        #expect(migrated.fish == original.fish)
        #expect(migrated.plants == original.plants)
        #expect(migrated.lighting == 2)
        #expect(migrated.waterColor == original.waterColor && migrated.bounds == original.bounds)
        #expect(migrated.habitatIndex == index && migrated.habitatId == original.habitatId)
        #expect(migrated == original)
        #expect(migrated.validate(catalog: catalog).isEmpty)
    }

    @Test func aLiteralSchemaOneDocumentWithDecorKeepsItsDecor() throws {
        let json = #"{"bounds":{"maxX":15.5,"maxY":8.5,"minX":0.5,"minY":1.5},"#
            + #""decor":[{"kindId":"flat-rock","position":{"x":4,"y":1.2}}],"#
            + #""fish":[{"animationPhase":1,"heading":0,"position":{"x":5,"y":4},"#
            + #""speciesId":"silver-slender-fish","velocity":{"x":1.4,"y":0}}],"#
            + #""habitatId":"kelp","habitatIndex":1,"lighting":0,"#
            + #""plants":[{"kindId":"tall-brown-ribbon","x":1.5}],"schema":1,"#
            + #""waterColor":{"a":1,"b":0.32,"g":0.3,"r":0.08}}"#
        let old = try JSONDecoder().decode(HabitatDocument.self, from: Data(json.utf8))
        #expect(old.decor == [DecorPlacement(kindId: "flat-rock", position: Vec2(4, 1.2), rotation: 0, scale: 1)])
        #expect(old.fish.map(\.turn) == [0])
        let migrated = old.migrated(catalog: catalog)
        #expect(migrated.schema == 3)
        #expect(migrated.decor == old.decor && migrated.food.isEmpty)
        #expect(migrated.fish == old.fish && migrated.plants == old.plants && migrated.lighting == 0)
        #expect(migrated.validate(catalog: catalog).isEmpty)
    }

    @Test func otherSchemasAreNotMigrated() {
        let current = starter(0)
        #expect(current.migrated(catalog: catalog) == current)
        var future = current
        future.schema = 4
        #expect(future.migrated(catalog: catalog) == future)
        #expect(future.validate(catalog: catalog).contains { $0.contains("schema 4") })
        var lost = current
        lost.schema = 1
        lost.decor = []
        lost.habitatIndex = 9
        let migrated = lost.migrated(catalog: catalog)
        #expect(migrated.schema == 3 && migrated.decor.isEmpty)
    }

    @Test(arguments: [0, 1]) func aSchemaTwoDocumentMigratesToThreeKeepingItsDecor(index: Int) throws {
        var original = starter(index, seed: 21)
        original.lighting = 0
        original.fish[0].turn = 0.5
        original.decor[0].rotation = 1.25
        original.decor.removeLast()
        let data = try schemaTwoJSON(original)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(!text.contains("\"food\""))
        let old = try JSONDecoder().decode(HabitatDocument.self, from: data)
        #expect(old.schema == 2 && old.food.isEmpty)
        #expect(old.validate(catalog: catalog) == ["schema 2 is not 3"])
        let migrated = old.migrated(catalog: catalog)
        #expect(migrated.schema == 3)
        #expect(migrated.decor == original.decor)
        #expect(migrated.food.isEmpty)
        #expect(migrated == original)
        #expect(migrated.validate(catalog: catalog).isEmpty)
        var bare = original
        bare.schema = 2
        bare.decor = []
        let kept = bare.migrated(catalog: catalog)
        #expect(kept.schema == 3 && kept.decor.isEmpty)
    }

    @Test func validationRefusesBadDecorAndTurn() {
        let valid = starter(0)
        #expect(valid.validate(catalog: catalog).isEmpty)
        var doc = valid
        doc.decor[0].scale = 0.4
        #expect(doc.validate() == ["decor 0 scale is outside 0.5…2.0"])
        doc = valid
        doc.decor[1].scale = 2.1
        #expect(doc.validate() == ["decor 1 scale is outside 0.5…2.0"])
        doc = valid
        doc.decor[0].scale = 0.5
        doc.decor[1].scale = 2.0
        doc.decor[2].rotation = -Double.pi
        #expect(doc.validate(catalog: catalog).isEmpty)
        doc = valid
        doc.decor[2].rotation = 4
        #expect(doc.validate() == ["decor 2 rotation is outside −π…π"])
        doc = valid
        doc.decor[0].rotation = .nan
        #expect(doc.validate() == ["decor 0 rotation is outside −π…π"])
        doc = valid
        doc.decor[0].kindId = "glass-castle"
        #expect(doc.validate().isEmpty)
        #expect(doc.validate(catalog: catalog) == ["decor 0 kind glass-castle is not in the catalog"])
        doc = valid
        doc.decor[1].position = Vec2(17, 1.2)
        #expect(doc.validate() == ["decor 1 is outside the tank"])
        doc = valid
        doc.fish[0].turn = .infinity
        #expect(doc.validate().contains { $0.contains("fish 0 has a non-finite number") })
        doc = valid
        doc.schema = 1
        #expect(doc.validate() == ["schema 1 is not 3"])
    }

    @Test func aSchemaThreeDocumentRoundTripsIdentically() throws {
        var doc = starter(1, seed: 77)
        doc.lighting = 0
        doc.fish[0].turn = 0.37
        doc.fish[1].turn = -1.25
        doc.decor[0].rotation = 2.75
        doc.decor[1].scale = 0.6
        doc.food = [FoodPellet(position: Vec2(6.75, 8.5)), FoodPellet(position: Vec2(7, 3.125))]
        let data = try encoded(doc)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"turn\"") && text.contains("\"rotation\"") && text.contains("\"scale\""))
        #expect(text.contains("\"food\""))
        let decoded = try JSONDecoder().decode(HabitatDocument.self, from: data)
        #expect(decoded == doc)
        #expect(try encoded(decoded) == data)
        #expect(decoded.validate(catalog: catalog).isEmpty)
    }

    // MARK: - Catalog decoder: decor kinds and spots

    /// The bundled catalog as a mutable JSON object.
    private func bundledObject() throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: catalog.encoded()) as? [String: Any])
    }

    private func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The bundled catalog with a copy of the first decor kind, changed by `changes` (nil removes a key), appended.
    private func appendingDecor(_ changes: [String: Any?]) throws -> Data {
        var object = try bundledObject()
        var list = try #require(object["decor"] as? [[String: Any]])
        var item = list[0]
        for (name, value) in changes { item[name] = value }
        list.append(item)
        object["decor"] = list
        return try data(object)
    }

    /// The bundled catalog with the Reef habitat's decor spots replaced by `spots`.
    private func reefDecor(_ spots: [[String: Any]]) throws -> Data {
        var object = try bundledObject()
        var habitats = try #require(object["habitats"] as? [[String: Any]])
        habitats[0]["decor"] = spots
        object["habitats"] = habitats
        return try data(object)
    }

    private func spot(_ id: String = "round-rock", x: Double = 3, y: Double = 1.2, rotation: Double = 0.5,
                      scale: Double = 1) -> [String: Any] {
        ["decorId": id, "position": ["x": x, "y": y], "rotation": rotation, "scale": scale]
    }

    @Test func badDecorKindsAreRefusedAndTheRestKept() throws {
        let cases: [([String: Any?], CatalogError)] = [
            (["id": "huge-rock", "size": 5.0], .invalidNumber),
            (["id": "tiny-rock", "size": 0.1], .invalidNumber),
            (["id": "pale-rock", "color": ["r": 2.0, "g": 0.5, "b": 0.5, "a": 1.0]], .invalidNumber),
            (["id": "pyramid", "shape": "pyramid"], .unknownShape),
            (["id": "shared-rock", "license": "GPL-3.0"], .unsupportedLicense),
            (["id": "anonymous-rock", "author": nil], .missingLicense),
            ([:], .unknownReference),
        ]
        for (changes, error) in cases {
            let (decoded, refused) = SpeciesCatalog.decode(try appendingDecor(changes))
            let id = (changes["id"] ?? nil) as? String ?? catalog.decor[0].id
            #expect(refused == [CatalogRefusal(kind: .decor, id: id, error: error)], "\(id)")
            #expect(decoded == catalog)
        }
    }

    @Test func badDecorSpotsRefuseTheirHabitat() throws {
        let cases: [([[String: Any]], CatalogError)] = [
            ([spot(scale: 3)], .invalidNumber),
            ([spot(scale: 0.4)], .invalidNumber),
            ([spot(rotation: 4)], .invalidNumber),
            ([spot(x: 20)], .invalidNumber),
            ([spot(y: -0.5)], .invalidNumber),
            (Array(repeating: spot(), count: HabitatDocument.maxDecor + 1), .invalidNumber),
            ([spot("glass-castle")], .unknownReference),
            ([["decorId": "round-rock", "position": ["x": 3, "y": 1.2], "scale": 1]], .invalidNumber),
            ([["position": ["x": 3, "y": 1.2], "rotation": 0, "scale": 1]], .unknownShape),
        ]
        for (spots, error) in cases {
            let (decoded, refused) = SpeciesCatalog.decode(try reefDecor(spots))
            #expect(refused == [CatalogRefusal(kind: .habitat, id: "reef", error: error)])
            #expect(decoded.habitats.map(\.id) == ["kelp"])
            #expect(decoded.decor == catalog.decor)
        }
        let full = Array(repeating: spot(), count: HabitatDocument.maxDecor)
        let (decoded, refused) = SpeciesCatalog.decode(try reefDecor(full))
        #expect(refused.isEmpty)
        #expect(decoded.habitats[0].decor.count == HabitatDocument.maxDecor)
    }

    @Test func aHabitatOfARefusedDecorKindIsRefusedToo() throws {
        var object = try bundledObject()
        var decor = try #require(object["decor"] as? [[String: Any]])
        decor[0]["license"] = "Proprietary"
        object["decor"] = decor
        let (decoded, refused) = SpeciesCatalog.decode(try data(object))
        #expect(refused == [CatalogRefusal(kind: .decor, id: "round-rock", error: .unsupportedLicense),
                            CatalogRefusal(kind: .habitat, id: "reef", error: .unknownReference),
                            CatalogRefusal(kind: .habitat, id: "kelp", error: .unknownReference)])
        #expect(decoded.decor.map(\.id) == ["flat-rock", "spiral-shell"])
        #expect(decoded.habitats.isEmpty)
    }

    @Test func aCatalogWithoutDecorKeysStillDecodes() throws {
        var object = try bundledObject()
        object["decor"] = nil
        var habitats = try #require(object["habitats"] as? [[String: Any]])
        for i in habitats.indices { habitats[i]["decor"] = nil }
        object["habitats"] = habitats
        let old = try data(object)
        var expected = catalog
        expected.decor = []
        for i in expected.habitats.indices { expected.habitats[i].decor = [] }
        let (decoded, refused) = SpeciesCatalog.decode(old)
        #expect(refused.isEmpty)
        #expect(decoded == expected)
        #expect(try JSONDecoder().decode(SpeciesCatalog.self, from: old) == expected)
        #expect(try JSONDecoder().decode(SpeciesCatalog.self, from: catalog.encoded()) == catalog)
    }
}
