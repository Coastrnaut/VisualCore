// HabitatDocumentTests — feature 068 (A09-P01) T-A09-102 (FR-A09-101, FR-A09-111; clarification 2; SC-A09-101). The
// habitat document, host-free and short: both starter documents are valid with two species, 6…10 fish inside the swim
// bounds at cruise speed and 4…6 plants at the catalog positions; the same seed gives the same document; the index is
// clamped; the JSON round trip is identical; and validation names a non-finite or out-of-bounds fish, too many fish or
// plants, a lighting level outside 0…2, decor outside the tank, a wrong schema and an unknown species.
// Feature 069 (A09-P02) T-A09-203 (FR-A09-212): schema 2 — starters carry the habitat's starter decor and fish with
// turn 0, the decor draws no random numbers (the fish are those of a decor-free catalog), and validation names a decor
// kind missing from the catalog. Migration from schema 1 is in `HabitatMigrationTests`.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import DigitalAquariumCore

@Suite struct HabitatDocumentTests {
    private let catalog = SpeciesCatalog.bundled

    private func starter(_ index: Int, seed: UInt64 = 9) -> HabitatDocument {
        var random = SeededRandom(seed: seed)
        return HabitatDocument.starter(index, catalog: catalog, random: &random)
    }

    @Test(arguments: [0, 1]) func eachStarterIsAValidCompleteAquarium(index: Int) throws {
        let doc = starter(index)
        let habitat = catalog.habitats[index]
        #expect(doc.validate(catalog: catalog).isEmpty)
        #expect(doc.validate().isEmpty)
        #expect(doc.schema == 2 && doc.habitatIndex == index && doc.habitatId == habitat.id)
        #expect(doc.waterColor == habitat.waterColor)
        #expect(doc.bounds == SwimBounds(minX: 0.5, maxX: 15.5, minY: 1.5, maxY: 8.5))
        #expect(Set(doc.fish.map(\.speciesId)).count == 2)
        #expect((6...10).contains(doc.fish.count))
        #expect((4...6).contains(doc.plants.count))
        #expect(doc.plants == habitat.plants.map { PlantPlacement(kindId: $0.plantId, x: $0.x) })
        #expect(doc.decor == habitat.decor.map { DecorPlacement($0) })
        #expect(doc.decor.count == [3, 2][index])
        #expect(doc.fish.allSatisfy { $0.turn == 0 })
        #expect(doc.lighting == 1)
        for fish in doc.fish {
            let species = try #require(catalog.species(id: fish.speciesId))
            #expect(doc.bounds.contains(fish.position))
            #expect(abs(fish.velocity.length - species.cruiseSpeed) < 1e-12)
            #expect(abs(AquariumSimulation.wrappedAngle(fish.heading - atan2(fish.velocity.y, fish.velocity.x)))
                    < 1e-12)
            #expect(fish.animationPhase >= 0 && fish.animationPhase < 2 * Double.pi)
        }
    }

    @Test func theStarterTankAndBoundsMatchTheClarification() {
        #expect(SwimBounds.tankWidth == 16 && SwimBounds.tankHeight == 9)
        #expect(SwimBounds.standard.isValid)
        #expect(!SwimBounds(minX: 3, maxX: 2, minY: 1.5, maxY: 8.5).isValid)
        #expect(!SwimBounds(minX: 0.5, maxX: 17, minY: 1.5, maxY: 8.5).isValid)
        #expect(SwimBounds.standard.contains(Vec2(0.5, 8.5)))
        #expect(!SwimBounds.standard.contains(Vec2(0.49, 5)))
        #expect(!SwimBounds.standard.contains(Vec2(.nan, 5)))
    }

    @Test(arguments: [0, 1]) func theStarterDecorDrawsNoRandomNumbers(index: Int) {
        var bare = catalog
        for i in bare.habitats.indices { bare.habitats[i].decor = [] }
        var random = SeededRandom(seed: 9), bareRandom = SeededRandom(seed: 9)
        let doc = HabitatDocument.starter(index, catalog: catalog, random: &random)
        let plain = HabitatDocument.starter(index, catalog: bare, random: &bareRandom)
        #expect(doc.fish == plain.fish && doc.plants == plain.plants)
        #expect(plain.decor.isEmpty && !doc.decor.isEmpty)
        #expect(random.next() == bareRandom.next())
    }

    @Test func theSameSeedGivesTheSameStarterAndAnotherSeedDiffers() {
        #expect(starter(0, seed: 42) == starter(0, seed: 42))
        #expect(starter(1, seed: 42) == starter(1, seed: 42))
        #expect(starter(0, seed: 42) != starter(0, seed: 43))
    }

    @Test func theIndexIsClampedAndAnEmptyCatalogGivesAnEmptyDocument() {
        #expect(starter(-3).habitatIndex == 0)
        #expect(starter(7).habitatIndex == catalog.habitats.count - 1)
        var random = SeededRandom(seed: 1)
        let empty = HabitatDocument.starter(0, catalog: SpeciesCatalog(species: [], plants: [], habitats: []),
                                            random: &random)
        #expect(empty.fish.isEmpty && empty.plants.isEmpty)
        #expect(empty.validate().isEmpty)
    }

    @Test func theJSONRoundTripIsIdentical() throws {
        var doc = starter(1)
        doc.lighting = 2
        doc.decor = [DecorPlacement(kindId: "round-rock", position: Vec2(3, 0.8), rotation: -2.5, scale: 1.75)]
        doc.fish[0].turn = -0.42
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(doc)
        let decoded = try JSONDecoder().decode(HabitatDocument.self, from: data)
        #expect(decoded == doc)
        #expect(decoded.validate(catalog: catalog).isEmpty)
    }

    @Test func validationNamesEveryProblem() {
        let valid = starter(0)
        var doc = valid
        doc.fish[0].position = Vec2(.nan, 3)
        #expect(doc.validate().contains { $0.contains("non-finite") })
        doc = valid
        doc.fish[0].position = Vec2(15.6, 3)
        #expect(doc.validate().contains { $0.contains("outside the swim bounds") })
        doc = valid
        doc.fish = Array(repeating: valid.fish[0], count: HabitatDocument.maxFish + 1)
        #expect(doc.validate().contains { $0.contains("exceed 24") })
        doc = valid
        doc.plants = Array(repeating: valid.plants[0], count: HabitatDocument.maxPlants + 1)
        #expect(doc.validate().contains { $0.contains("exceed 12") })
        doc = valid
        doc.lighting = 3
        #expect(doc.validate().contains { $0.contains("lighting") })
        doc = valid
        doc.decor = [DecorPlacement(kindId: "stone", position: Vec2(20, 1))]
        #expect(doc.validate().contains { $0.contains("decor 0") })
        doc = valid
        doc.schema = 1
        #expect(doc.validate().contains { $0.contains("schema") })
        doc = valid
        doc.decor[0].kindId = "no-such-rock"
        #expect(doc.validate().isEmpty)
        #expect(doc.validate(catalog: catalog) == ["decor 0 kind no-such-rock is not in the catalog"])
        doc = valid
        doc.fish[0].speciesId = "no-such-fish"
        #expect(doc.validate().isEmpty)
        #expect(doc.validate(catalog: catalog).contains { $0.contains("no-such-fish") })
        doc = valid
        doc.fish[0].velocity = Vec2(10, 0)
        #expect(doc.validate(catalog: catalog).contains { $0.contains("maximum speed") })
    }
}
