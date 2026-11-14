// AquariumSimulationTests — feature 068 (A09-P01) T-A09-102 (FR-A09-110, FR-A09-111; clarification 1; SC-A09-101,
// SC-A09-102). The bounded wander, host-free and short: the step is 1/60 s; the same seed and steps give the same
// document (and a different seed a different one); over 10,000 steps from each of 20 seeds (alternating the two starter
// habitats) no fish position lies outside the swim bounds and no speed exceeds the species maximum, and the document
// stays valid; a fish at each corner heading outward turns back and stays inside after one step; speed eases to
// cruise; the heading follows the velocity; a fish of an unknown species is only clamped.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import DigitalAquariumCore

@Suite struct AquariumSimulationTests {
    private let catalog = SpeciesCatalog.bundled

    /// The starter `index` from `seed`, advanced `steps` times with the same generator.
    private func run(_ index: Int, seed: UInt64, steps: Int) -> (HabitatDocument, SeededRandom) {
        var random = SeededRandom(seed: seed)
        var doc = HabitatDocument.starter(index, catalog: catalog, random: &random)
        for _ in 0..<steps { AquariumSimulation.advance(&doc, catalog: catalog, random: &random) }
        return (doc, random)
    }

    @Test func theStepIsOneSixtiethOfASecond() {
        #expect(AquariumSimulation.step == 1.0 / 60)
    }

    @Test func theSameSeedGivesTheSameDocumentAfterTheSameSteps() {
        let (a, randomA) = run(0, seed: 77, steps: 600)
        let (b, randomB) = run(0, seed: 77, steps: 600)
        #expect(a == b)
        #expect(randomA == randomB)
        #expect(run(0, seed: 78, steps: 600).0 != a)
        #expect(run(0, seed: 77, steps: 0).0 != a)
    }

    @Test func restoringTheGeneratorStateContinuesTheSameRun() throws {
        let (half, random) = run(1, seed: 5, steps: 300)
        var restored = try SeededRandom(restoring: random.state)
        var doc = half
        for _ in 0..<300 { AquariumSimulation.advance(&doc, catalog: catalog, random: &restored) }
        #expect(doc == run(1, seed: 5, steps: 600).0)
    }

    @Test(arguments: 0..<20) func fishNeverLeaveTheBoundsNorExceedTheirMaximumSpeed(seed: Int) throws {
        var random = SeededRandom(seed: UInt64(seed) &* 0x9E37_79B9 &+ 1)
        var doc = HabitatDocument.starter(seed % 2, catalog: catalog, random: &random)
        let maxSpeeds = try doc.fish.map { try #require(catalog.species(id: $0.speciesId)).maxSpeed }
        var outside = 0, tooFast = 0
        for _ in 0..<10_000 {
            AquariumSimulation.advance(&doc, catalog: catalog, random: &random)
            for (fish, maxSpeed) in zip(doc.fish, maxSpeeds) {
                if !doc.bounds.contains(fish.position) { outside += 1 }
                if !(fish.velocity.length <= maxSpeed * (1 + 1e-12)) { tooFast += 1 }
            }
        }
        #expect(outside == 0)
        #expect(tooFast == 0)
        #expect(doc.validate(catalog: catalog).isEmpty)
    }

    @Test func aFishAtACornerHeadingOutwardTurnsBackAndStaysInside() throws {
        let species = try #require(catalog.species.first)
        let b = SwimBounds.standard
        let corners: [(Vec2, Vec2)] = [(Vec2(b.minX, b.minY), Vec2(-1, -1)), (Vec2(b.maxX, b.minY), Vec2(1, -1)),
                                       (Vec2(b.minX, b.maxY), Vec2(-1, 1)), (Vec2(b.maxX, b.maxY), Vec2(1, 1))]
        for (seed, (corner, outward)) in corners.enumerated() {
            let velocity = outward.normalized * species.maxSpeed
            var doc = HabitatDocument(habitatIndex: 0, habitatId: "reef", waterColor: RGBA(0, 0.4, 0.6),
                                      plants: [],
                                      fish: [FishAgent(speciesId: species.id, position: corner, velocity: velocity,
                                                       heading: atan2(velocity.y, velocity.x), animationPhase: 0)])
            var random = SeededRandom(seed: UInt64(seed))
            AquariumSimulation.advance(&doc, catalog: catalog, random: &random)
            let fish = doc.fish[0]
            #expect(b.contains(fish.position))
            #expect(fish.velocity.dot(outward) < 0, "corner \(seed) still heads outward")
            #expect(fish.velocity.x * outward.x < 0 && fish.velocity.y * outward.y < 0)
            #expect(abs(AquariumSimulation.wrappedAngle(fish.heading - atan2(fish.velocity.y, fish.velocity.x)))
                    < 1e-12)
            #expect(fish.velocity.length <= species.maxSpeed * (1 + 1e-12))
        }
    }

    @Test func speedEasesTowardCruise() throws {
        let species = try #require(catalog.species.first)
        var doc = HabitatDocument(habitatIndex: 0, habitatId: "reef", waterColor: RGBA(0, 0.4, 0.6), plants: [],
                                  fish: [FishAgent(speciesId: species.id, position: Vec2(8, 5),
                                                   velocity: Vec2(species.maxSpeed, 0), heading: 0,
                                                   animationPhase: 0)])
        var random = SeededRandom(seed: 3)
        for _ in 0..<120 { AquariumSimulation.advance(&doc, catalog: catalog, random: &random) }
        let speed = doc.fish[0].velocity.length
        #expect(speed < species.maxSpeed)
        #expect(abs(speed - species.cruiseSpeed) < 0.2 * (species.maxSpeed - species.cruiseSpeed))
        #expect(doc.fish[0].animationPhase > 0)
    }

    @Test func aFishOfAnUnknownSpeciesIsOnlyClamped() {
        var doc = HabitatDocument(habitatIndex: 0, habitatId: "reef", waterColor: RGBA(0, 0.4, 0.6), plants: [],
                                  fish: [FishAgent(speciesId: "no-such-fish", position: Vec2(20, -3),
                                                   velocity: Vec2(1, 0), heading: 0, animationPhase: 0)])
        var random = SeededRandom(seed: 3)
        let before = random
        AquariumSimulation.advance(&doc, catalog: catalog, random: &random)
        #expect(doc.fish[0].position == Vec2(15.5, 1.5))
        #expect(random == before)
    }
}
