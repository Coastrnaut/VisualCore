// AquariumBudgetTests — feature 072 (A09-P05) T-A09-502 (FR-A09-510, FR-A09-520; clarification 4; research D4). The
// three quality levels and ambient drawing: every level × ambient gives the documented budget, out-of-range tiers are
// clamped, each level draws no more than the level above in every component, and ambient never draws more.
import Testing
import DigitalAquariumCore

@Suite struct AquariumBudgetTests {
    private func b(_ bubbles: Int, _ motes: Int, _ octaves: Int) -> AquariumBudget {
        AquariumBudget(bubblesPerVent: bubbles, motes: motes, causticsOctaves: octaves)
    }

    @Test func everyLevelAndAmbientGiveTheDocumentedBudget() {
        #expect(AquariumBudget.levels == 3)
        #expect(AquariumBudget.budget(tier: 0, ambient: false) == b(24, 24, 2))
        #expect(AquariumBudget.budget(tier: 1, ambient: false) == b(12, 12, 1))
        #expect(AquariumBudget.budget(tier: 2, ambient: false) == b(6, 6, 0))
        #expect(AquariumBudget.budget(tier: 0, ambient: true) == b(12, 12, 2))
        #expect(AquariumBudget.budget(tier: 1, ambient: true) == b(12, 12, 1))
        #expect(AquariumBudget.budget(tier: 2, ambient: true) == b(6, 6, 0))
    }

    @Test func tiersOutsideTheLevelsAreClamped() {
        #expect(AquariumBudget.budget(tier: -1, ambient: false) == AquariumBudget.budget(tier: 0, ambient: false))
        #expect(AquariumBudget.budget(tier: Int.min, ambient: true) == AquariumBudget.budget(tier: 0, ambient: true))
        #expect(AquariumBudget.budget(tier: 3, ambient: false) == AquariumBudget.budget(tier: 2, ambient: false))
        #expect(AquariumBudget.budget(tier: Int.max, ambient: true) == AquariumBudget.budget(tier: 2, ambient: true))
    }

    @Test(arguments: [false, true]) func eachLevelDrawsNoMoreThanTheLevelAbove(ambient: Bool) {
        for tier in 1..<AquariumBudget.levels {
            let upper = AquariumBudget.budget(tier: tier - 1, ambient: ambient)
            let lower = AquariumBudget.budget(tier: tier, ambient: ambient)
            #expect(lower.bubblesPerVent <= upper.bubblesPerVent)
            #expect(lower.motes <= upper.motes)
            #expect(lower.causticsOctaves <= upper.causticsOctaves)
        }
    }

    @Test func ambientNeverDrawsMoreAndHalvesTheFullLevel() {
        for tier in 0..<AquariumBudget.levels {
            let plain = AquariumBudget.budget(tier: tier, ambient: false)
            let ambient = AquariumBudget.budget(tier: tier, ambient: true)
            #expect(ambient.bubblesPerVent <= plain.bubblesPerVent)
            #expect(ambient.motes <= plain.motes)
            #expect(ambient.causticsOctaves <= plain.causticsOctaves)
        }
        let full = AquariumBudget.budget(tier: 0, ambient: false)
        let ambient = AquariumBudget.budget(tier: 0, ambient: true)
        #expect(ambient.bubblesPerVent * 2 <= full.bubblesPerVent)
        #expect(ambient.motes * 2 <= full.motes)
    }

    @Test func theFullLevelMatchesTheWaterEffectsDefaults() {
        let full = AquariumBudget.budget(tier: 0, ambient: false)
        #expect(full.bubblesPerVent == WaterEffects.bubblesPerVent)
        #expect(full.motes == WaterEffects.moteCount)
    }
}
