// FeedingTests — feature 070 (A09-P03) T-A09-303 (FR-A09-301, FR-A09-302, FR-A09-303; clarification 3; research D2;
// SC-A09-301, SC-A09-302). Food pellets, host-free and short (each test well under 10 s): a feed adds 3 pellets at
// x − 0.25, x, x + 0.25 clamped into the swim bounds; feeds 1–4 are accepted (3, 6, 9, 12 pellets) and the 5th is
// refused whole; pellets sink 0.5 units per second (60 steps → 0.5 units) and are removed at the floor; a fish eats
// exactly its nearest pellet within 0.5 × length + 0.15 (one per fish per step, unknown species none); the seek force
// points at the nearest pellet within 4 units with length 2.5 and is zero beyond; pellets out of seek range leave the
// fish exactly as without food; SC-A09-302: for seeds 1…20 a feed at the mean position of the Reef's first species is
// eaten from within 600 steps in at least 18 seeds (measured 2026-11-14: 20 of 20); and with repeated
// feeds, 20 seeds × 1,000 steps keep every fish inside the bounds at most at its maximum speed, every pellet inside the
// bounds and at most 12 pellets.
@testable import DigitalAquariumCore
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation

@Suite struct FeedingTests {
    private let catalog = SpeciesCatalog.bundled

    /// An empty Reef document with the standard bounds and the given fish and food.
    private func document(_ fish: [FishAgent] = [], food: [FoodPellet] = []) -> HabitatDocument {
        HabitatDocument(habitatIndex: 0, habitatId: "reef", waterColor: RGBA(0, 0.4, 0.6), plants: [], fish: fish,
                        food: food)
    }

    private func fish(_ species: FishSpecies, at position: Vec2) -> FishAgent {
        FishAgent(speciesId: species.id, position: position, velocity: Vec2(species.cruiseSpeed, 0), heading: 0,
                  animationPhase: 0)
    }

    @Test func theTuningFollowsResearchD2() {
        #expect(Feeding.maxPellets == 12 && Feeding.pelletsPerFeed == 3 && Feeding.spacing == 0.25)
        #expect(Feeding.sinkSpeed == 0.5 && Feeding.seekRange == 4.0 && Feeding.seekWeight == 2.5)
        #expect(Feeding.eatMargin == 0.15)
    }

    @Test func aFeedAddsThreePelletsAroundThePointClampedIntoTheBounds() {
        var doc = document()
        #expect(Feeding.canDrop(doc))
        #expect(Feeding.drop(at: Vec2(8, 5), into: &doc))
        #expect(doc.food.map(\.position) == [Vec2(7.75, 5), Vec2(8, 5), Vec2(8.25, 5)])
        #expect(Feeding.drop(at: Vec2(0.6, 9), into: &doc))
        #expect(doc.food.suffix(3).map(\.position) == [Vec2(0.5, 8.5), Vec2(0.6, 8.5), Vec2(0.85, 8.5)])
        #expect(Feeding.drop(at: Vec2(20, -1), into: &doc))
        #expect(doc.food.suffix(3).map(\.position) == [Vec2(15.5, 1.5), Vec2(15.5, 1.5), Vec2(15.5, 1.5)])
        #expect(Feeding.drop(at: Vec2(.nan, 4), into: &doc))
        #expect(doc.food.suffix(3).allSatisfy { $0.position.x == 8 && $0.position.y == 4 })
        #expect(doc.food.allSatisfy { doc.bounds.contains($0.position) })
        #expect(doc.validate(catalog: catalog).isEmpty)
    }

    @Test func theFifthFeedIsRefusedWhole() {
        var doc = document()
        for count in [3, 6, 9, 12] {
            #expect(Feeding.drop(at: Vec2(8, 8), into: &doc))
            #expect(doc.food.count == count)
        }
        #expect(!Feeding.canDrop(doc))
        let full = doc
        #expect(!Feeding.drop(at: Vec2(4, 4), into: &doc))
        #expect(doc == full)
        doc.food.removeLast()
        #expect(!Feeding.canDrop(doc))
        doc.food.removeLast(2)
        #expect(Feeding.canDrop(doc))
        #expect(Feeding.drop(at: Vec2(4, 4), into: &doc) && doc.food.count == 12)
    }

    @Test func pelletsSinkHalfAUnitPerSecond() {
        var doc = document(food: [FoodPellet(position: Vec2(8, 8)), FoodPellet(position: Vec2(3, 5))])
        for _ in 0..<60 {
            let result = Feeding.step(&doc, catalog: catalog, dt: AquariumSimulation.step)
            #expect(result.eaten == 0 && result.floored == 0)
        }
        #expect(abs(doc.food[0].position.y - 7.5) < 1e-9 && doc.food[0].position.x == 8)
        #expect(abs(doc.food[1].position.y - 4.5) < 1e-9 && doc.food[1].position.x == 3)
    }

    @Test func pelletsAtOrBelowTheFloorAreRemoved() {
        let floor = SwimBounds.standard.minY
        var doc = document(food: [FoodPellet(position: Vec2(2, floor + 0.004)), FoodPellet(position: Vec2(3, 4)),
                                  FoodPellet(position: Vec2(4, floor + 0.009))])
        var result = Feeding.step(&doc, catalog: catalog, dt: AquariumSimulation.step)
        #expect(result.eaten == 0 && result.floored == 1)
        #expect(doc.food.map(\.position.x) == [3, 4])
        result = Feeding.step(&doc, catalog: catalog, dt: AquariumSimulation.step)
        #expect(result.floored == 1 && doc.food.map(\.position.x) == [3])
        var settled = document(food: [FoodPellet(position: Vec2(5, 3))])
        var steps = 0
        while !settled.food.isEmpty && steps < 1_000 {
            Feeding.step(&settled, catalog: catalog, dt: AquariumSimulation.step)
            steps += 1
        }
        #expect((179...181).contains(steps), "\(steps) steps to sink 1.5 units")
    }

    @Test func aFishEatsExactlyItsNearestPelletWithinReach() throws {
        let species = try #require(catalog.species.first)
        let reach = 0.5 * species.length + Feeding.eatMargin
        let near = FoodPellet(position: Vec2(5 + 0.5 * reach, 5))
        let edge = FoodPellet(position: Vec2(5, 5 + 0.95 * reach))
        let far = FoodPellet(position: Vec2(5 + 1.05 * reach, 5))
        var doc = document([fish(species, at: Vec2(5, 5))], food: [edge, near, far])
        var result = Feeding.step(&doc, catalog: catalog, dt: 0)
        #expect(result.eaten == 1 && result.floored == 0)
        #expect(doc.food == [edge, far])
        result = Feeding.step(&doc, catalog: catalog, dt: 0)
        #expect(result.eaten == 1 && doc.food == [far])
        result = Feeding.step(&doc, catalog: catalog, dt: 0)
        #expect(result.eaten == 0 && doc.food == [far])
        // Two fish each eat one; a fish of an unknown species eats none.
        var stranger = fish(species, at: Vec2(10, 5))
        stranger.speciesId = "no-such-fish"
        var pair = document([fish(species, at: Vec2(5, 5)), fish(species, at: Vec2(5, 5)), stranger],
                            food: [near, near, near, FoodPellet(position: Vec2(10, 5))])
        result = Feeding.step(&pair, catalog: catalog, dt: 0)
        #expect(result.eaten == 2 && pair.food == [near, FoodPellet(position: Vec2(10, 5))])
    }

    @Test func theSeekForcePointsAtTheNearestPelletWithinFourUnits() throws {
        let species = try #require(catalog.species.first)
        let swimmer = fish(species, at: Vec2(8, 5))
        #expect(Feeding.seekForce(for: swimmer, food: []) == .zero)
        let force = Feeding.seekForce(for: swimmer, food: [FoodPellet(position: Vec2(8, 7)),
                                                           FoodPellet(position: Vec2(5, 5))])
        #expect(force == Vec2(0, 2.5))
        let diagonal = Feeding.seekForce(for: swimmer, food: [FoodPellet(position: Vec2(10, 7))])
        #expect(abs(diagonal.length - Feeding.seekWeight) < 1e-12 && abs(diagonal.x - diagonal.y) < 1e-12)
        #expect(Feeding.seekForce(for: swimmer, food: [FoodPellet(position: Vec2(12.01, 5))]) == .zero)
        #expect(Feeding.seekForce(for: swimmer, food: [FoodPellet(position: Vec2(12, 5))]).x == 2.5)
        #expect(Feeding.seekForce(for: swimmer, food: [FoodPellet(position: Vec2(.nan, 5))]) == .zero)
        // Ties go to the lower index.
        let tie = Feeding.seekForce(for: swimmer, food: [FoodPellet(position: Vec2(6, 5)),
                                                         FoodPellet(position: Vec2(10, 5))])
        #expect(tie.x == -2.5)
        // The seek is added to the school force and the sum stays within the force cap.
        var doc = document([swimmer], food: [FoodPellet(position: Vec2(8, 8))])
        let forces = AquariumSimulation.forces(doc, catalog: catalog)
        #expect(forces[0].y > 0 && forces[0].length <= 2.0 + 1e-12)
        doc.food = []
        #expect(AquariumSimulation.forces(doc, catalog: catalog) == [.zero])
    }

    @Test(arguments: 1...3) func pelletsOutOfRangeLeaveTheFishExactlyAsWithoutFood(seed: Int) {
        var random = SeededRandom(seed: UInt64(seed))
        var plain = HabitatDocument.starter(0, catalog: catalog, random: &random)
        // Keep every fish in the left half and the pellet at the far right, far beyond the seek range.
        for i in plain.fish.indices { plain.fish[i].position.x = min(plain.fish[i].position.x, 6) }
        var fed = plain
        fed.food = [FoodPellet(position: Vec2(15.5, 8.5))]
        var a = random, b = random
        for _ in 0..<60 {
            AquariumSimulation.advance(&plain, catalog: catalog, random: &a)
            AquariumSimulation.advance(&fed, catalog: catalog, random: &b)
        }
        #expect(fed.fish.allSatisfy { $0.position.distance(to: fed.food[0].position) > Feeding.seekRange })
        #expect(fed.fish == plain.fish)
        #expect(fed.food.count == 1 && abs(fed.food[0].position.y - 8.0) < 1e-9)
    }

    /// The pellets eaten (not removed at the floor) in one advance: removed pellets minus those that sink to the floor
    /// this step (a pellet eaten while also reaching the floor is not counted, so the count never overstates).
    private func eatenInAdvance(_ doc: inout HabitatDocument, random: inout SeededRandom) -> Int {
        let floor = doc.bounds.minY
        let before = doc.food.count
        let sinking = doc.food.filter { $0.position.y - Feeding.sinkSpeed * AquariumSimulation.step <= floor }.count
        AquariumSimulation.advance(&doc, catalog: catalog, random: &random)
        return max(0, before - doc.food.count - sinking)
    }

    @Test func aFeedBesideTheReefSchoolIsEatenForAtLeast18Of20Seeds() throws {
        let reef = catalog.habitats[0]
        let firstSpecies = try #require(reef.species.first?.speciesId)
        var fedSeeds = 0
        for seed in 1...20 {
            var random = SeededRandom(seed: UInt64(seed))
            var doc = HabitatDocument.starter(0, catalog: catalog, random: &random)
            for _ in 0..<300 { AquariumSimulation.advance(&doc, catalog: catalog, random: &random) }
            let school = doc.fish.filter { $0.speciesId == firstSpecies }.map(\.position)
            try #require(!school.isEmpty)
            let mean = school.reduce(Vec2.zero, +) / Double(school.count)
            #expect(Feeding.drop(at: mean, into: &doc))
            var eaten = 0
            for _ in 0..<600 where eaten == 0 { eaten += eatenInAdvance(&doc, random: &random) }
            if eaten > 0 { fedSeeds += 1 }
        }
        #expect(fedSeeds >= 18, "SC-A09-302: \(fedSeeds) of 20 seeds ate")
    }

    @Test func boundsAndSpeedHoldWithRepeatedFeeds() throws {
        var violations = 0, accepted = 0, refused = 0, eaten = 0
        for seed in 1...20 {
            var random = SeededRandom(seed: UInt64(seed))
            var doc = HabitatDocument.starter(seed % 2, catalog: catalog, random: &random)
            for step in 0..<1_000 {
                if step % 50 == 0 {
                    let target = doc.fish[step / 50 % doc.fish.count].position
                    let dropped = Feeding.drop(at: Vec2(target.x, target.y + 1), into: &doc)
                    if dropped { accepted += 1 } else { refused += 1 }
                }
                eaten += eatenInAdvance(&doc, random: &random)
                if doc.food.count > Feeding.maxPellets { violations += 1 }
                if !doc.food.allSatisfy({ doc.bounds.contains($0.position) }) { violations += 1 }
                for fish in doc.fish {
                    let species = try #require(catalog.species(id: fish.speciesId))
                    if !doc.bounds.contains(fish.position) { violations += 1 }
                    if fish.velocity.length > species.maxSpeed * (1 + 1e-9) { violations += 1 }
                }
            }
            #expect(doc.validate(catalog: catalog).isEmpty)
        }
        #expect(violations == 0)
        #expect(accepted > 0 && eaten > 0, "\(accepted) feeds accepted, \(refused) refused, \(eaten) pellets eaten")
    }
}
