// UnknownContentTests — feature 071 (A09-P04) T-A09-406 (FR-A09-430; SC-A09-406). Damaged or unknown content is
// refused with a named reason and never crashes, host-free and short. Catalogs: starting from the bundled catalog's
// JSON, each single mutation is refused with its reason and item while the rest is kept — a habitat naming an unknown
// species (`unknown-reference`), unsupported fish, plant and decor shapes (`unknown-shape`; a refused species also
// refuses every habitat naming it), a habitat naming an unknown decor kind (`unknown-reference`), a species missing a
// required field (`unknown-shape` for the shape or name, `invalid-number` for a number or colour) and a vent outside
// the tank or more than four vents (`invalid-number`); the unmodified JSON decodes with no refusal. Documents: a
// starter document whose fish species, plant kind or decor kind is replaced by an unknown id is refused by
// `validate(catalog:)` with the matching message and stays structurally valid without a catalog.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import DigitalAquariumCore

@Suite struct UnknownContentTests {
    private let catalog = SpeciesCatalog.bundled

    // MARK: - Catalog JSON helpers

    /// The bundled catalog as a mutable JSON object.
    private func bundledObject() throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: catalog.encoded()) as? [String: Any])
    }

    private func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The bundled catalog with a copy of the first item of `key`, changed by `changes` (nil removes a key), appended.
    private func appendingCopy(of key: String, _ changes: [String: Any?]) throws -> Data {
        var object = try bundledObject()
        var list = try #require(object[key] as? [[String: Any]])
        var item = list[0]
        for (name, value) in changes { item[name] = value }
        list.append(item)
        object[key] = list
        return try data(object)
    }

    /// The bundled catalog with the Reef habitat (the first) changed by `change`.
    private func changingReef(_ change: (inout [String: Any]) throws -> Void) throws -> Data {
        var object = try bundledObject()
        var habitats = try #require(object["habitats"] as? [[String: Any]])
        try change(&habitats[0])
        object["habitats"] = habitats
        return try data(object)
    }

    // MARK: - Catalogs

    @Test func theUnmodifiedJSONDecodesWithNoRefusal() throws {
        let (decoded, refused) = SpeciesCatalog.decode(try data(try bundledObject()))
        #expect(refused.isEmpty)
        #expect(decoded == catalog)
    }

    @Test func aHabitatNamingAnUnknownSpeciesIsRefused() throws {
        let json = try changingReef { reef in
            var species = try #require(reef["species"] as? [[String: Any]])
            species[0]["speciesId"] = "ghost-fish"
            reef["species"] = species
        }
        let (decoded, refused) = SpeciesCatalog.decode(json)
        #expect(refused == [CatalogRefusal(kind: .habitat, id: "reef", error: .unknownReference)])
        #expect(decoded.habitats.map(\.id) == ["kelp"])
        #expect(decoded.species == catalog.species && decoded.plants == catalog.plants)
        #expect(decoded.decor == catalog.decor)
    }

    @Test func aHabitatNamingAnUnknownPlantIsRefused() throws {
        let json = try changingReef { reef in
            var plants = try #require(reef["plants"] as? [[String: Any]])
            plants[0]["plantId"] = "glass-weed"
            reef["plants"] = plants
        }
        let (decoded, refused) = SpeciesCatalog.decode(json)
        #expect(refused == [CatalogRefusal(kind: .habitat, id: "reef", error: .unknownReference)])
        #expect(decoded.habitats.map(\.id) == ["kelp"])
    }

    @Test func unsupportedFishPlantAndDecorShapesAreRefusedAndTheRestKept() throws {
        let cases: [(key: String, id: String, shape: String, kind: CatalogItemKind)] = [
            ("species", "eel-fish", "eel", .species),
            ("plants", "cactus-plant", "cactus", .plant),
            ("decor", "pyramid-rock", "pyramid", .decor),
        ]
        for (key, id, shape, kind) in cases {
            let (decoded, refused) = SpeciesCatalog.decode(try appendingCopy(of: key, ["id": id, "shape": shape]))
            #expect(refused == [CatalogRefusal(kind: kind, id: id, error: .unknownShape)], "\(id)")
            #expect(decoded == catalog, "\(id)")
        }
    }

    @Test func aRefusedSpeciesAlsoRefusesEveryHabitatNamingIt() throws {
        var object = try bundledObject()
        var species = try #require(object["species"] as? [[String: Any]])
        let id = try #require(species[0]["id"] as? String)
        species[0]["shape"] = "eel"
        object["species"] = species
        let (decoded, refused) = SpeciesCatalog.decode(try data(object))
        let naming = catalog.habitats.filter { $0.species.contains { $0.speciesId == id } }.map(\.id)
        #expect(!naming.isEmpty)
        #expect(refused == [CatalogRefusal(kind: .species, id: id, error: .unknownShape)]
            + naming.map { CatalogRefusal(kind: .habitat, id: $0, error: .unknownReference) })
        #expect(decoded.species(id: id) == nil)
        #expect(decoded.habitats.map(\.id) == catalog.habitats.map(\.id).filter { !naming.contains($0) })
    }

    @Test func aHabitatNamingAnUnknownDecorKindIsRefused() throws {
        let json = try changingReef { reef in
            var decor = try #require(reef["decor"] as? [[String: Any]])
            decor[0]["decorId"] = "glass-castle"
            reef["decor"] = decor
        }
        let (decoded, refused) = SpeciesCatalog.decode(json)
        #expect(refused == [CatalogRefusal(kind: .habitat, id: "reef", error: .unknownReference)])
        #expect(decoded.habitats.map(\.id) == ["kelp"])
        #expect(decoded.decor == catalog.decor)
    }

    @Test func aSpeciesMissingARequiredFieldIsRefusedWithItsReason() throws {
        let cases: [(field: String, error: CatalogError)] = [
            ("shape", .unknownShape),
            ("name", .unknownShape),
            ("length", .invalidNumber),
            ("cruiseSpeed", .invalidNumber),
            ("maxSpeed", .invalidNumber),
            ("turnRate", .invalidNumber),
            ("bodyColor", .invalidNumber),
            ("finColor", .invalidNumber),
        ]
        for (field, error) in cases {
            let id = "no-\(field.lowercased())-fish"
            let (decoded, refused) = SpeciesCatalog.decode(try appendingCopy(of: "species", ["id": id, field: nil]))
            #expect(refused == [CatalogRefusal(kind: .species, id: id, error: error)], "\(field)")
            #expect(decoded == catalog, "\(field)")
        }
        // Without an id the item is refused by shape with an empty id.
        let (_, refused) = SpeciesCatalog.decode(try appendingCopy(of: "species", ["id": nil]))
        #expect(refused == [CatalogRefusal(kind: .species, id: "", error: .unknownShape)])
    }

    @Test func aVentOutsideTheTankOrTooManyVentsIsRefused() throws {
        let cases: [[Double]] = [[16.0], [0.2], [3.0, 15.9], [-1.0], [2.0, 4.0, 6.0, 8.0, 10.0]]
        for vents in cases {
            let (decoded, refused) = SpeciesCatalog.decode(try changingReef { $0["vents"] = vents })
            #expect(refused == [CatalogRefusal(kind: .habitat, id: "reef", error: .invalidNumber)], "\(vents)")
            #expect(decoded.habitats.map(\.id) == ["kelp"], "\(vents)")
        }
        // The edges and four vents are kept.
        let (_, refused) = SpeciesCatalog.decode(try changingReef { $0["vents"] = [0.5, 4.0, 9.0, 15.5] })
        #expect(refused.isEmpty)
    }

    // MARK: - Documents

    private func starter(_ index: Int, seed: UInt64 = 7) -> HabitatDocument {
        var random = SeededRandom(seed: seed)
        return HabitatDocument.starter(index, catalog: catalog, random: &random)
    }

    @Test(arguments: [0, 1]) func aDocumentWithAnUnknownSpeciesIsRefusedByValidation(index: Int) throws {
        var doc = starter(index)
        #expect(doc.validate(catalog: catalog).isEmpty)
        try #require(!doc.fish.isEmpty)
        doc.fish[0].speciesId = "ghost-fish"
        #expect(doc.validate(catalog: catalog) == ["fish 0 species ghost-fish is not in the catalog"])
        #expect(doc.validate().isEmpty)
    }

    @Test(arguments: [0, 1]) func aDocumentWithAnUnknownPlantKindIsRefusedByValidation(index: Int) throws {
        var doc = starter(index)
        try #require(!doc.plants.isEmpty)
        doc.plants[0].kindId = "glass-weed"
        #expect(doc.validate(catalog: catalog) == ["plant 0 kind glass-weed is not in the catalog"])
        #expect(doc.validate().isEmpty)
    }

    @Test(arguments: [0, 1]) func aDocumentWithAnUnknownDecorKindIsRefusedByValidation(index: Int) throws {
        var doc = starter(index)
        try #require(!doc.decor.isEmpty)
        doc.decor[0].kindId = "glass-castle"
        #expect(doc.validate(catalog: catalog) == ["decor 0 kind glass-castle is not in the catalog"])
        #expect(doc.validate().isEmpty)
    }

    @Test func aDocumentWithEveryKindUnknownNamesEachProblem() throws {
        var doc = starter(0)
        doc.fish[1].speciesId = "ghost-fish"
        doc.plants[1].kindId = "glass-weed"
        doc.decor[1].kindId = "glass-castle"
        #expect(doc.validate(catalog: catalog) == ["fish 1 species ghost-fish is not in the catalog",
                                                   "plant 1 kind glass-weed is not in the catalog",
                                                   "decor 1 kind glass-castle is not in the catalog"])
        #expect(doc.validate().isEmpty)
    }
}
