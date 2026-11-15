// SpeciesCatalogTests — feature 068 (A09-P01) T-A09-102 (FR-A09-102, FR-A09-103; clarification 3; SC-A09-103). The
// bundled catalog and its validating decoder, host-free and short: the bundled content (≥ 2 species, ≥ 2 plant kinds,
// the two starter habitats with two species, 6…10 fish and 4…6 plants, unique ids, descriptive names, author and
// license on every item), the sorted-key JSON round trip, and one crafted malformed item per refusal reason
// (missing-license, unsupported-license, unknown-shape, unknown-reference, invalid-number, too-many-fish), each refused
// with its name while every valid bundled item is kept; unreadable JSON is refused as a whole.
// Feature 069 (A09-P02) T-A09-203 (FR-A09-212): the bundled decor kinds (round-rock, flat-rock, spiral-shell; both
// shapes; MIT, project author) and the starter decor (Reef 3 pieces, Kelp 2, on the gravel, transforms in range). The
// decoder's decor refusals are in `HabitatMigrationTests`.
// Feature 071 (A09-P04) T-A09-402 (FR-A09-401): the bundled bubble vents (Reef [3.0, 12.5], Kelp [5.5, 10.0]), a
// habitat without a "vents" key decoding with none, and the decoder refusing five vents, a vent at 0.2 and a NaN vent
// (a non-number in JSON and a hand-built NaN) as `invalid-number`.
import Foundation
import Testing
import DigitalAquariumCore

@Suite struct SpeciesCatalogTests {
    private let catalog = SpeciesCatalog.bundled

    /// The bundled catalog as a mutable JSON object.
    private func bundledObject() throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: catalog.encoded()) as? [String: Any])
    }

    /// The bundled catalog with `item` appended to the list `key`, as JSON data.
    private func appending(_ item: [String: Any], to key: String) throws -> Data {
        var object = try bundledObject()
        var list = try #require(object[key] as? [Any])
        list.append(item)
        object[key] = list
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// A copy of the first bundled item of `key` with `changes` applied (nil removes a key).
    private func variant(of key: String, _ changes: [String: Any?]) throws -> [String: Any] {
        let object = try bundledObject()
        var item = try #require((object[key] as? [Any])?.first as? [String: Any])
        for (name, value) in changes { item[name] = value }
        return item
    }

    @Test func theBundledCatalogHasTwoStarterHabitatsOfTwoSpeciesEach() {
        #expect(catalog.species.count >= 2)
        #expect(catalog.plants.count >= 2)
        #expect(Set(catalog.plants.map(\.shape)) == Set(PlantShape.allCases))
        #expect(catalog.habitats.map(\.name) == ["Reef", "Kelp"])
        for habitat in catalog.habitats {
            #expect(Set(habitat.species.map(\.speciesId)).count == 2)
            #expect((6...10).contains(habitat.fishCount))
            #expect((4...6).contains(habitat.plants.count))
            #expect(habitat.species.allSatisfy { catalog.species(id: $0.speciesId) != nil })
            #expect(habitat.plants.allSatisfy { catalog.plant(id: $0.plantId) != nil })
        }
        let ids = catalog.species.map(\.id) + catalog.plants.map(\.id) + catalog.decor.map(\.id)
            + catalog.habitats.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func theBundledDecorIsThreeKindsWithStarterPiecesOnTheGravel() throws {
        #expect(catalog.decor.map(\.id) == ["round-rock", "flat-rock", "spiral-shell"])
        #expect(catalog.decor.map(\.name) == ["Round rock", "Flat rock", "Spiral shell"])
        #expect(Set(catalog.decor.map(\.shape)) == Set(DecorShape.allCases))
        #expect(catalog.habitats.map(\.decor.count) == [3, 2])
        for kind in catalog.decor {
            #expect(CatalogDecoder.check(kind) == nil, "\(kind.id)")
            #expect(kind.author == SpeciesCatalog.projectAuthor && kind.license == "MIT")
            #expect(DecorKind.sizeRange.contains(kind.size))
            #expect(catalog.decor(id: kind.id) == kind)
        }
        #expect(catalog.decor(id: "no-such-rock") == nil)
        for habitat in catalog.habitats {
            #expect(habitat.decor.count <= HabitatDocument.maxDecor)
            for spot in habitat.decor {
                #expect(catalog.decor(id: spot.decorId) != nil, "\(spot.decorId)")
                #expect(CatalogDecoder.isValid(spot))
                #expect((1.0...1.6).contains(spot.position.y))
                #expect(spot.position.x > 0 && spot.position.x < SwimBounds.tankWidth)
                #expect(DecorSpot.rotationRange.contains(spot.rotation))
                #expect(DecorSpot.scaleRange.contains(spot.scale))
            }
            #expect(Set(habitat.decor.map(\.rotation)).count == habitat.decor.count)
        }
    }

    @Test func everyBundledItemIsValidWithAuthorAndLicense() {
        for species in catalog.species {
            #expect(CatalogDecoder.check(species) == nil, "\(species.id)")
            #expect(species.author == SpeciesCatalog.projectAuthor && species.license == "MIT")
            #expect(species.cruiseSpeed <= species.maxSpeed && species.maxSpeed <= 4)
            #expect(SpeciesCatalog.lengthRange.contains(species.length))
        }
        for plant in catalog.plants {
            #expect(CatalogDecoder.check(plant) == nil, "\(plant.id)")
            #expect(plant.author == SpeciesCatalog.projectAuthor && plant.license == "MIT")
        }
        let speciesIds = Set(catalog.species.map(\.id)), plantIds = Set(catalog.plants.map(\.id))
        let decorIds = Set(catalog.decor.map(\.id))
        for habitat in catalog.habitats {
            let known = CatalogDecoder.check(habitat, speciesIds: speciesIds, plantIds: plantIds, decorIds: decorIds)
            #expect(known == nil, "\(habitat.id)")
            let unknown = CatalogDecoder.check(habitat, speciesIds: speciesIds, plantIds: plantIds, decorIds: [])
            #expect(unknown == .unknownReference)
            #expect(habitat.author == SpeciesCatalog.projectAuthor && habitat.license == "MIT")
        }
    }

    @Test func theJSONRoundTripsWithSortedKeysAndNoRefusal() throws {
        let data = catalog.encoded()
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"decor\":[{\"author\":\"VisualCore project\""))
        let (decoded, refused) = SpeciesCatalog.decode(data)
        #expect(refused.isEmpty)
        #expect(decoded == catalog)
        #expect(decoded.encoded() == data)
    }

    @Test func theReasonNamesAreExact() {
        #expect(CatalogError.allCases.map(\.rawValue) == ["missing-license", "unsupported-license", "unknown-shape",
                                                         "unknown-reference", "invalid-number", "too-many-fish"])
    }

    @Test func aSpeciesWithoutLicenseIsRefusedAndTheRestKept() throws {
        let item = try variant(of: "species", ["id": "no-license-fish", "license": nil])
        let (decoded, refused) = SpeciesCatalog.decode(try appending(item, to: "species"))
        #expect(refused == [CatalogRefusal(kind: .species, id: "no-license-fish", error: .missingLicense)])
        #expect(decoded == catalog)
    }

    @Test func aMissingAuthorIsAMissingLicenseRecord() throws {
        let item = try variant(of: "plants", ["id": "no-author-plant", "author": ""])
        let (decoded, refused) = SpeciesCatalog.decode(try appending(item, to: "plants"))
        #expect(refused == [CatalogRefusal(kind: .plant, id: "no-author-plant", error: .missingLicense)])
        #expect(decoded == catalog)
    }

    @Test func anUnsupportedLicenseIsRefusedAndTheRestKept() throws {
        let item = try variant(of: "plants", ["id": "copyleft-plant", "license": "GPL-3.0"])
        let (decoded, refused) = SpeciesCatalog.decode(try appending(item, to: "plants"))
        #expect(refused == [CatalogRefusal(kind: .plant, id: "copyleft-plant", error: .unsupportedLicense)])
        #expect(decoded == catalog)
    }

    @Test func anUnknownShapeIsRefusedAndTheRestKept() throws {
        let item = try variant(of: "species", ["id": "octagon-fish", "shape": "octagon"])
        let (decoded, refused) = SpeciesCatalog.decode(try appending(item, to: "species"))
        #expect(refused == [CatalogRefusal(kind: .species, id: "octagon-fish", error: .unknownShape)])
        #expect(decoded == catalog)
    }

    @Test func aHabitatNamingAnUnknownSpeciesIsRefusedAndTheRestKept() throws {
        let entries: [[String: Any]] = [["speciesId": "no-such-fish", "count": 3]]
        let item = try variant(of: "habitats", ["id": "lost-habitat", "species": entries])
        let (decoded, refused) = SpeciesCatalog.decode(try appending(item, to: "habitats"))
        #expect(refused == [CatalogRefusal(kind: .habitat, id: "lost-habitat", error: .unknownReference)])
        #expect(decoded == catalog)
    }

    @Test func aRepeatedIdIsRefusedAsUnknownReference() throws {
        let item = try variant(of: "species", [:])
        let (decoded, refused) = SpeciesCatalog.decode(try appending(item, to: "species"))
        #expect(refused == [CatalogRefusal(kind: .species, id: catalog.species[0].id, error: .unknownReference)])
        #expect(decoded == catalog)
    }

    @Test func anOutOfRangeNumberIsRefusedAndTheRestKept() throws {
        let long = try variant(of: "species", ["id": "giant-fish", "length": 99.0])
        let (decoded, refused) = SpeciesCatalog.decode(try appending(long, to: "species"))
        #expect(refused == [CatalogRefusal(kind: .species, id: "giant-fish", error: .invalidNumber)])
        #expect(decoded == catalog)
        let tall = try variant(of: "plants", ["id": "sunken-plant", "height": -1.0])
        #expect(SpeciesCatalog.decode(try appending(tall, to: "plants")).refused
                == [CatalogRefusal(kind: .plant, id: "sunken-plant", error: .invalidNumber)])
        let fast = try variant(of: "species", ["id": "rocket-fish", "maxSpeed": 9.0])
        #expect(SpeciesCatalog.decode(try appending(fast, to: "species")).refused
                == [CatalogRefusal(kind: .species, id: "rocket-fish", error: .invalidNumber)])
    }

    @Test func tooManyFishIsRefusedAndTheRestKept() throws {
        let speciesId = catalog.species[0].id
        let item = try variant(of: "habitats", ["id": "crowded-habitat",
                                                "species": [["speciesId": speciesId, "count": 30]] as [[String: Any]]])
        let (decoded, refused) = SpeciesCatalog.decode(try appending(item, to: "habitats"))
        #expect(refused == [CatalogRefusal(kind: .habitat, id: "crowded-habitat", error: .tooManyFish)])
        #expect(decoded == catalog)
    }

    @Test func aHabitatOfARefusedSpeciesIsRefusedToo() throws {
        var object = try bundledObject()
        var species = try #require(object["species"] as? [[String: Any]])
        species[0]["license"] = "Proprietary"
        object["species"] = species
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let (decoded, refused) = SpeciesCatalog.decode(data)
        #expect(refused.contains(CatalogRefusal(kind: .species, id: catalog.species[0].id,
                                                error: .unsupportedLicense)))
        #expect(refused.contains(CatalogRefusal(kind: .habitat, id: "reef", error: .unknownReference)))
        #expect(decoded.species.count == catalog.species.count - 1)
        #expect(decoded.habitats.map(\.id) == ["kelp"])
    }

    @Test func unreadableJSONIsRefusedAsAWhole() {
        let (decoded, refused) = SpeciesCatalog.decode(Data("not json".utf8))
        #expect(decoded == SpeciesCatalog(species: [], plants: [], habitats: []))
        #expect(refused == [CatalogRefusal(kind: .catalog, id: "catalog", error: .unknownShape)])
    }

    @Test func theBundledHabitatsHaveTwoVentsEach() throws {
        let reef = try #require(catalog.habitats.first { $0.id == "reef" })
        let kelp = try #require(catalog.habitats.first { $0.id == "kelp" })
        #expect(reef.vents == [3.0, 12.5])
        #expect(kelp.vents == [5.5, 10.0])
        #expect(StarterHabitat.maxVents == 4)
        #expect(StarterHabitat.ventRange == 0.5...15.5)
    }

    @Test func aHabitatWithoutVentsDecodesWithNone() throws {
        let item = try variant(of: "habitats", ["id": "still-habitat", "vents": nil])
        let (decoded, refused) = SpeciesCatalog.decode(try appending(item, to: "habitats"))
        #expect(refused.isEmpty)
        #expect(decoded.habitats.last?.id == "still-habitat")
        #expect(decoded.habitats.last?.vents == [])
        var object = try bundledObject()
        var habitats = try #require(object["habitats"] as? [[String: Any]])
        habitats[0]["vents"] = nil
        object["habitats"] = habitats
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(try JSONDecoder().decode(SpeciesCatalog.self, from: data).habitats[0].vents == [])
    }

    @Test func badVentsAreRefusedAsInvalidNumbers() throws {
        let cases: [(String, Any)] = [("five-vents", [1.0, 4.0, 7.0, 10.0, 13.0]), ("edge-vent", [0.2, 8.0]),
                                      ("nan-vent", ["NaN"]), ("far-vent", [15.6])]
        for (id, vents) in cases {
            let item = try variant(of: "habitats", ["id": id, "vents": vents])
            let (decoded, refused) = SpeciesCatalog.decode(try appending(item, to: "habitats"))
            #expect(refused == [CatalogRefusal(kind: .habitat, id: id, error: .invalidNumber)], "\(id)")
            #expect(decoded == catalog)
        }
        let notAList = try variant(of: "habitats", ["id": "odd-vents", "vents": 3.0])
        #expect(SpeciesCatalog.decode(try appending(notAList, to: "habitats")).refused
                == [CatalogRefusal(kind: .habitat, id: "odd-vents", error: .unknownShape)])
        var habitat = catalog.habitats[0]
        let speciesIds = Set(catalog.species.map(\.id)), plantIds = Set(catalog.plants.map(\.id))
        #expect(CatalogDecoder.check(habitat, speciesIds: speciesIds, plantIds: plantIds) == nil)
        for vents in [[Double.nan], [Double.infinity], [0.2], [1, 2, 3, 4, 5]] {
            habitat.vents = vents
            #expect(CatalogDecoder.check(habitat, speciesIds: speciesIds, plantIds: plantIds) == .invalidNumber)
        }
        habitat.vents = [0.5, 15.5, 8, 8]
        #expect(CatalogDecoder.check(habitat, speciesIds: speciesIds, plantIds: plantIds) == nil)
    }
}
