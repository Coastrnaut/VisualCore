// AquariumWordingTests — feature 071 (A09-P04) T-A09-404 (FR-A09-420, 421; SC-A09-405). The canvas description for
// both starter habitats (each species with its count), with no decor, with food, paused and at another lighting level;
// fish of species missing from the catalog counted under "unknown"; the word helpers; and the change sentences with
// their priority (habitat, food dropped, decoration added, decoration removed, paused or swimming) and their nil cases
// (first state, nothing announced changed, food eaten). Host-free and short.
// Feature 072 (A09-P05) T-A09-506 (FR-A09-510): ", ambient" before the final motion word only when ambient is on (the
// rest of the text unchanged); "Ambient on" and "Ambient off" with the lowest priority.
import DigitalAquariumCore
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation

@Suite struct AquariumWordingTests {
    private let catalog = SpeciesCatalog.bundled

    /// The starter document of habitat `index` with seed 1.
    private func starter(_ index: Int) -> HabitatDocument {
        var random = SeededRandom(seed: 1)
        return HabitatDocument.starter(index, catalog: catalog, random: &random)
    }

    private func fish(_ speciesId: String) -> FishAgent {
        FishAgent(speciesId: speciesId, position: Vec2(8, 5), velocity: Vec2(1, 0), heading: 0, animationPhase: 0)
    }

    @Test func theReefStarterIsDescribedWithSpeciesCounts() {
        #expect(AquariumWording.description(document: starter(0), catalog: catalog, paused: false)
            == "Digital Aquarium: Reef, 7 fish of 2 species (4 Orange striped fish and 3 Blue fish with yellow tail), "
            + "5 plants, 3 decorations, no food, lighting soft, swimming.")
    }

    @Test func theKelpStarterIsDescribedWithSpeciesCounts() {
        #expect(AquariumWording.description(document: starter(1), catalog: catalog, paused: false)
            == "Digital Aquarium: Kelp, 8 fish of 2 species (5 Silver slender fish and 3 Gold round fish), "
            + "6 plants, 2 decorations, no food, lighting soft, swimming.")
    }

    @Test func emptyDecorFoodPausedAndLightingAreDescribed() {
        var doc = starter(0)
        doc.decor = []
        doc.food = [FoodPellet(position: Vec2(7.75, 6)), FoodPellet(position: Vec2(8, 6)),
                    FoodPellet(position: Vec2(8.25, 6))]
        doc.lighting = 2
        #expect(AquariumWording.description(document: doc, catalog: catalog, paused: true)
            == "Digital Aquarium: Reef, 7 fish of 2 species (4 Orange striped fish and 3 Blue fish with yellow tail), "
            + "5 plants, 0 decorations, 3 food pellets, lighting bright, paused.")
        doc.decor = [DecorPlacement(kindId: "round-rock", position: Vec2(3, 1.2))]
        doc.food = [FoodPellet(position: Vec2(8, 6))]
        doc.plants = [PlantPlacement(kindId: "red-fan-plant", x: 4)]
        doc.lighting = 0
        #expect(AquariumWording.description(document: doc, catalog: catalog, paused: false)
            == "Digital Aquarium: Reef, 7 fish of 2 species (4 Orange striped fish and 3 Blue fish with yellow tail), "
            + "1 plant, 1 decoration, 1 food pellet, lighting dim, swimming.")
    }

    @Test func ambientIsSaidBeforeTheMotionWordOnlyWhenOn() {
        let plain = AquariumWording.description(document: starter(0), catalog: catalog, paused: false)
        #expect(AquariumWording.description(document: starter(0), catalog: catalog, paused: false, ambient: false)
            == plain)
        #expect(AquariumWording.description(document: starter(0), catalog: catalog, paused: false, ambient: true)
            == "Digital Aquarium: Reef, 7 fish of 2 species (4 Orange striped fish and 3 Blue fish with yellow tail), "
            + "5 plants, 3 decorations, no food, lighting soft, ambient, swimming.")
        #expect(AquariumWording.description(document: starter(1), catalog: catalog, paused: true, ambient: true)
            == "Digital Aquarium: Kelp, 8 fish of 2 species (5 Silver slender fish and 3 Gold round fish), "
            + "6 plants, 2 decorations, no food, lighting soft, ambient, paused.")
    }

    @Test func unknownSpeciesAreCountedTogetherUnderUnknown() {
        let doc = HabitatDocument(habitatIndex: 0, habitatId: "reef", waterColor: RGBA(0, 0.4, 0.6), plants: [],
                                  fish: [fish("mystery-fish"), fish("orange-striped-fish"), fish("other-fish"),
                                         fish("mystery-fish")])
        #expect(AquariumWording.description(document: doc, catalog: catalog, paused: false)
            == "Digital Aquarium: Reef, 4 fish of 2 species (3 unknown and 1 Orange striped fish), 0 plants, "
            + "0 decorations, no food, lighting soft, swimming.")
        let single = HabitatDocument(habitatIndex: 7, habitatId: "reef", waterColor: RGBA(0, 0.4, 0.6), plants: [],
                                     fish: [fish("gold-round-fish")])
        #expect(AquariumWording.description(document: single, catalog: catalog, paused: false)
            == "Digital Aquarium: Aquarium, 1 fish of 1 species (1 Gold round fish), 0 plants, 0 decorations, "
            + "no food, lighting soft, swimming.")
    }

    @Test func theWordHelpersMatchThePhase03Text() {
        #expect(AquariumWording.fishWords(1) == "1 fish" && AquariumWording.fishWords(7) == "7 fish")
        #expect(AquariumWording.plantWords(1) == "1 plant" && AquariumWording.plantWords(5) == "5 plants")
        #expect(AquariumWording.decorWords(1) == "1 decoration" && AquariumWording.decorWords(0) == "0 decorations")
        #expect(AquariumWording.foodWords(0) == "no food" && AquariumWording.foodWords(1) == "1 food pellet"
            && AquariumWording.foodWords(12) == "12 food pellets")
        #expect(AquariumWording.lightingName(0) == "dim" && AquariumWording.lightingName(2) == "bright"
            && AquariumWording.lightingName(9) == "soft")
        #expect(AquariumWording.joined([]) == "" && AquariumWording.joined(["A"]) == "A"
            && AquariumWording.joined(["A", "B"]) == "A and B")
        #expect(AquariumWording.joined(["A", "B", "C"]) == "A, B and C")
    }

    @Test func theStateCarriesHabitatCountsAndMotion() {
        let state = AquariumWording.state(document: starter(1), catalog: catalog, paused: true)
        #expect(state == AquariumWordingState(habitatId: "kelp", habitatName: "Kelp", foodCount: 0, decorCount: 2,
                                              paused: true))
        #expect(!state.ambient)
        let ambient = AquariumWording.state(document: starter(1), catalog: catalog, paused: true, ambient: true)
        #expect(ambient == AquariumWordingState(habitatId: "kelp", habitatName: "Kelp", foodCount: 0, decorCount: 2,
                                                paused: true, ambient: true))
    }

    // MARK: - Change sentences

    private let reef = AquariumWordingState(habitatId: "reef", habitatName: "Reef", foodCount: 0, decorCount: 3,
                                            paused: false)

    private func changed(_ edit: (inout AquariumWordingState) -> Void) -> AquariumWordingState {
        var copy = reef
        edit(&copy)
        return copy
    }

    @Test func noSentenceForTheFirstStateOrAnUnchangedOne() {
        #expect(AquariumWording.change(from: nil, to: reef) == nil)
        #expect(AquariumWording.change(from: reef, to: reef) == nil)
    }

    @Test func eatenFoodIsNotAnnounced() {
        let fed = changed { $0.foodCount = 3 }
        #expect(AquariumWording.change(from: fed, to: changed { $0.foodCount = 2 }) == nil)
        #expect(AquariumWording.change(from: fed, to: reef) == nil)
    }

    @Test func eachChangeHasItsSentence() {
        #expect(AquariumWording.change(from: reef, to: changed { $0.habitatId = "kelp"; $0.habitatName = "Kelp" })
            == "Habitat Kelp")
        #expect(AquariumWording.change(from: reef, to: changed { $0.foodCount = 3 }) == "Food dropped")
        #expect(AquariumWording.change(from: reef, to: changed { $0.decorCount = 4 }) == "Decoration added")
        #expect(AquariumWording.change(from: reef, to: changed { $0.decorCount = 2 }) == "Decoration removed")
        #expect(AquariumWording.change(from: reef, to: changed { $0.paused = true }) == "Paused")
        #expect(AquariumWording.change(from: changed { $0.paused = true }, to: reef) == "Swimming")
        #expect(AquariumWording.change(from: reef, to: changed { $0.ambient = true }) == "Ambient on")
        #expect(AquariumWording.change(from: changed { $0.ambient = true }, to: reef) == "Ambient off")
    }

    @Test func theSentencesFollowThePriority() {
        let all = changed {
            $0.habitatId = "kelp"; $0.habitatName = "Kelp"; $0.foodCount = 3; $0.decorCount = 2; $0.paused = true
        }
        #expect(AquariumWording.change(from: reef, to: all) == "Habitat Kelp")
        let fedAndAdded = changed { $0.foodCount = 3; $0.decorCount = 4; $0.paused = true }
        #expect(AquariumWording.change(from: reef, to: fedAndAdded) == "Food dropped")
        #expect(AquariumWording.change(from: reef, to: changed { $0.decorCount = 4; $0.paused = true })
            == "Decoration added")
        #expect(AquariumWording.change(from: reef, to: changed { $0.decorCount = 2; $0.paused = true })
            == "Decoration removed")
        #expect(AquariumWording.change(from: reef, to: changed { $0.foodCount = 0; $0.paused = true }) == "Paused")
        let eatenAndPaused = changed { $0.foodCount = 1; $0.paused = true }
        #expect(AquariumWording.change(from: changed { $0.foodCount = 3 }, to: eatenAndPaused) == "Paused")
        #expect(AquariumWording.change(from: reef, to: changed { $0.paused = true; $0.ambient = true }) == "Paused")
        #expect(AquariumWording.change(from: reef, to: changed { $0.decorCount = 4; $0.ambient = true })
            == "Decoration added")
        #expect(AquariumWording.change(from: changed { $0.foodCount = 3 }, to: changed { $0.foodCount = 1
            $0.ambient = true }) == "Ambient on", "eaten food is silent, ambient still announced")
    }
}
