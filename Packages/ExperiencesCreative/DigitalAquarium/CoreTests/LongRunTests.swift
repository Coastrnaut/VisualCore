// LongRunTests — feature 072 (A09-P05) T-A09-502 (FR-A09-530; clarification 5; research D5; SC-A09-504). A long run of
// 10,000 steps for each of 3 seeds, a feed every 100 steps at a point inside the bounds (refusals ignored), plain and
// ambient: at every 50th step the fish count is the starting count, there are at most 12 pellets, at most 48 bubbles
// for the habitat's vents and exactly 24 motes. Longer runs belong to the device campaign (short-test rule).
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import DigitalAquariumCore

@Suite struct LongRunTests {
    private let catalog = SpeciesCatalog.bundled

    @Test(arguments: [(1, false), (2, true), (3, false)])
    func countsStayWithinTheirLimitsOverTenThousandSteps(seed: Int, ambient: Bool) throws {
        var random = SeededRandom(seed: UInt64(seed) &* 0x5851_F42D &+ 7)
        var doc = HabitatDocument.starter(seed % 2, catalog: catalog, random: &random)
        let fishCount = doc.fish.count
        let vents = try #require(catalog.habitats.indices.contains(doc.habitatIndex)
            ? catalog.habitats[doc.habitatIndex].vents : nil)
        var accepted = 0, samples = 0, violations: [String] = []
        let b = doc.bounds
        for step in 0..<10_000 {
            if step % 100 == 0 {
                let x = b.minX + (b.maxX - b.minX) * Double((step / 100) % 7 + 1) / 8
                let y = b.minY + (b.maxY - b.minY) * 0.8
                if Feeding.drop(at: Vec2(x, y), into: &doc) { accepted += 1 }
            }
            AquariumSimulation.advance(&doc, catalog: catalog, random: &random, ambient: ambient)
            if step % 50 == 0 {
                samples += 1
                if doc.fish.count != fishCount { violations.append("fish \(doc.fish.count) at \(step)") }
                if doc.food.count > 12 { violations.append("food \(doc.food.count) at \(step)") }
                let bubbles = WaterEffects.bubbles(step: step, vents: vents, reduceMotion: false).count
                if bubbles > 48 { violations.append("bubbles \(bubbles) at \(step)") }
                let motes = WaterEffects.motes(step: step, reduceMotion: false).count
                if motes != 24 { violations.append("motes \(motes) at \(step)") }
            }
        }
        #expect(samples == 200)
        #expect(accepted > 0)
        #expect(violations.isEmpty, "\(violations.prefix(5))")
        #expect(doc.validate(catalog: catalog).isEmpty)
    }
}
