// SchoolingTests — feature 069 (A09-P02) T-A09-204 (FR-A09-210; clarification 3; research D3; SC-A09-201,
// SC-A09-202). Schooling in the aquarium, host-free and short (each test well under 10 s): from the Reef starter
// habitat and seeds 1…20, after 1,800 steps (30 simulated seconds) the mean same-species distance is at most 60 % of
// its start and below the mean cross-species distance, and the heading agreement is at least 0.7, each for at least
// 18 of 20 seeds (the counts are printed in the expectation messages); the Kelp habitat is held to the same counts; the
// species tuning follows research D3; a lone fish gets no school force, keeps moving at half its cruise speed or more
// and stays inside; the forces do not depend on the fish order; coincident fish separate; advancing never changes
// plants, decor or lighting; and the school metrics are exact on small hand-made documents.
@testable import DigitalAquariumCore
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation

@Suite struct SchoolingTests {
    private let catalog = SpeciesCatalog.bundled

    /// The number of seeds 1…20 (starter habitat `habitat`, 1,800 steps) meeting SC-A09-201 and SC-A09-202.
    private func schoolingCounts(habitat: Int) throws -> (closer: Int, aligned: Int) {
        var closer = 0, aligned = 0
        for seed in 1...20 {
            var random = SeededRandom(seed: UInt64(seed))
            var doc = HabitatDocument.starter(habitat, catalog: catalog, random: &random)
            let start = try #require(SchoolMetrics.meanSameSpeciesDistance(doc))
            for _ in 0..<1_800 { AquariumSimulation.advance(&doc, catalog: catalog, random: &random) }
            let same = try #require(SchoolMetrics.meanSameSpeciesDistance(doc))
            let cross = try #require(SchoolMetrics.meanCrossSpeciesDistance(doc))
            if same <= 0.6 * start && same < cross { closer += 1 }
            if try #require(SchoolMetrics.headingAgreement(doc)) >= 0.7 { aligned += 1 }
        }
        return (closer, aligned)
    }

    @Test func reefFishSchoolWithinThirtySecondsForAtLeast18Of20Seeds() throws {
        let counts = try schoolingCounts(habitat: 0)
        #expect(counts.closer >= 18, "SC-A09-201: \(counts.closer) of 20 seeds closer")
        #expect(counts.aligned >= 18, "SC-A09-202: \(counts.aligned) of 20 seeds aligned")
    }

    @Test func kelpFishSchoolWithinThirtySecondsForAtLeast18Of20Seeds() throws {
        let counts = try schoolingCounts(habitat: 1)
        #expect(counts.closer >= 18, "SC-A09-201 (Kelp): \(counts.closer) of 20 seeds closer")
        #expect(counts.aligned >= 18, "SC-A09-202 (Kelp): \(counts.aligned) of 20 seeds aligned")
    }

    @Test func theSpeciesTuningFollowsResearchD3() throws {
        let species = try #require(catalog.species.first)
        let p = AquariumSimulation.parameters(for: species)
        #expect(p.neighbourRadius == 2.5)
        #expect(p.neighbourLimit == 6)
        #expect(abs(p.separationRadius - 1.6 * species.length) < 1e-12)
        #expect(p.separationWeight == 2.0 && p.alignmentWeight == 1.0 && p.cohesionWeight == 0.8)
        #expect(p.boundaryWeight == 3.0 && p.boundaryMargin == AquariumSimulation.margin && p.maxForce == 2.0)
    }

    /// A document of `fish` in the Reef habitat with the standard bounds.
    private func document(_ fish: [FishAgent]) -> HabitatDocument {
        HabitatDocument(habitatIndex: 0, habitatId: "reef", waterColor: RGBA(0, 0.4, 0.6), plants: [], fish: fish)
    }

    @Test func aLoneFishWandersAtHalfCruiseOrMoreAndStaysInside() throws {
        let species = try #require(catalog.species.first)
        var doc = document([FishAgent(speciesId: species.id, position: Vec2(8, 5),
                                      velocity: Vec2(species.cruiseSpeed, 0), heading: 0, animationPhase: 0)])
        #expect(AquariumSimulation.forces(doc, catalog: catalog) == [.zero])
        var random = SeededRandom(seed: 21)
        var travelled = 0.0, slow = 0, outside = 0
        for _ in 0..<1_800 {
            let before = doc.fish[0].position
            AquariumSimulation.advance(&doc, catalog: catalog, random: &random)
            let fish = doc.fish[0]
            travelled += fish.position.distance(to: before)
            if fish.velocity.length < 0.5 * species.cruiseSpeed * (1 - 1e-12) { slow += 1 }
            if !doc.bounds.contains(fish.position) { outside += 1 }
        }
        #expect(slow == 0)
        #expect(outside == 0)
        #expect(travelled >= 0.5 * species.cruiseSpeed * 30 * 0.9)
        #expect(doc.validate(catalog: catalog).isEmpty)
    }

    @Test(arguments: 1...5) func theForcesDoNotDependOnTheFishOrder(seed: Int) throws {
        var random = SeededRandom(seed: UInt64(seed))
        var doc = HabitatDocument.starter(seed % 2, catalog: catalog, random: &random)
        for _ in 0..<300 { AquariumSimulation.advance(&doc, catalog: catalog, random: &random) }
        var reversed = doc
        reversed.fish.reverse()
        let forward = AquariumSimulation.forces(doc, catalog: catalog)
        let backward = Array(AquariumSimulation.forces(reversed, catalog: catalog).reversed())
        #expect(forward.count == doc.fish.count)
        #expect(forward.contains { $0 != .zero })
        for (a, b) in zip(forward, backward) { #expect((a - b).length < 1e-12) }
    }

    @Test func coincidentFishSeparate() throws {
        let species = try #require(catalog.species.first)
        let fish = FishAgent(speciesId: species.id, position: Vec2(8, 5), velocity: Vec2(0, species.cruiseSpeed),
                             heading: Double.pi / 2, animationPhase: 0)
        var doc = document([fish, fish])
        let forces = AquariumSimulation.forces(doc, catalog: catalog)
        #expect(forces[0].x > 0 && forces[1].x < 0)
        var random = SeededRandom(seed: 9)
        for _ in 0..<60 { AquariumSimulation.advance(&doc, catalog: catalog, random: &random) }
        #expect(doc.fish[0].position.distance(to: doc.fish[1].position) > 0.5)
    }

    @Test func advancingNeverChangesPlantsDecorOrLighting() {
        var random = SeededRandom(seed: 2)
        var doc = HabitatDocument.starter(0, catalog: catalog, random: &random)
        doc.lighting = 2
        let (plants, decor, water) = (doc.plants, doc.decor, doc.waterColor)
        #expect(!decor.isEmpty)
        for _ in 0..<120 { AquariumSimulation.advance(&doc, catalog: catalog, random: &random) }
        #expect(doc.plants == plants)
        #expect(doc.decor == decor)
        #expect(doc.lighting == 2)
        #expect(doc.waterColor == water)
    }

    @Test func theSchoolMetricsAreExactOnSmallDocuments() {
        func fish(_ id: String, _ x: Double, _ y: Double, heading: Double) -> FishAgent {
            FishAgent(speciesId: id, position: Vec2(x, y), velocity: Vec2(cos(heading), sin(heading)),
                      heading: heading, animationPhase: 0)
        }
        let doc = document([fish("a", 1, 2, heading: 0), fish("a", 4, 6, heading: Double.pi / 2),
                            fish("b", 1, 6, heading: 1)])
        #expect(SchoolMetrics.meanSameSpeciesDistance(doc) == 5)
        #expect(abs((SchoolMetrics.meanCrossSpeciesDistance(doc) ?? 0) - 3.5) < 1e-12)
        #expect(abs((SchoolMetrics.headingAgreement(doc) ?? 0) - 0.5.squareRoot()) < 1e-12)
        let single = document([fish("a", 1, 2, heading: 0), fish("b", 3, 2, heading: 2)])
        #expect(SchoolMetrics.meanSameSpeciesDistance(single) == nil)
        #expect(SchoolMetrics.headingAgreement(single) == nil)
        #expect(SchoolMetrics.meanCrossSpeciesDistance(single) == 2)
        #expect(SchoolMetrics.meanCrossSpeciesDistance(document([])) == nil)
    }
}
