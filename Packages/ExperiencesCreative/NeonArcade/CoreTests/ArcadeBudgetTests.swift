// ArcadeBudgetTests — feature 079 (A10-P05) T-A10-502 (FR-A10-501; clarification 1; research D1; SC-A10-502). The
// three quality levels, host-free and short: each level's documented caps (glow 1.2/1.4/1.6 × radius, opacity
// 0.25/0.30/0.35, particles 48/128/256, pulse off/on/on); out-of-range levels are clamped; every cap is non-decreasing
// from level 0 to level 2; the glow alpha never exceeds the level's cap for any base and pulse offset (and level 0
// ignores the pulse); a burst scales by cap ÷ 256 and keeps at least 1 and at most the cap particles.
import Foundation
import Testing
import NeonArcadeCore

@Suite struct ArcadeBudgetTests {
    @Test func everyLevelHasItsDocumentedCaps() {
        #expect(ArcadeBudget.levels == 3)
        #expect(ArcadeBudget.all.map(\.level) == [0, 1, 2])
        #expect(ArcadeBudget.all.map(\.glowFactor) == [1.2, 1.4, 1.6])
        #expect(ArcadeBudget.all.map(\.glowOpacityCap) == [0.25, 0.30, 0.35])
        #expect(ArcadeBudget.all.map(\.particleCap) == [48, 128, 256])
        #expect(ArcadeBudget.all.map(\.pulse) == [false, true, true])
        #expect(ArcadeBudget.level(2).particleCap == ArcadeBudget.fullParticleCap)
    }

    @Test func levelsOutsideTheRangeAreClamped() {
        #expect(ArcadeBudget.level(-1) == ArcadeBudget.level(0))
        #expect(ArcadeBudget.level(Int.min) == ArcadeBudget.level(0))
        #expect(ArcadeBudget.level(3) == ArcadeBudget.level(2))
        #expect(ArcadeBudget.level(Int.max) == ArcadeBudget.level(2))
    }

    @Test func capsNeverFallFromLevelToLevel() {
        for level in 1..<ArcadeBudget.levels {
            let low = ArcadeBudget.level(level - 1), high = ArcadeBudget.level(level)
            #expect(low.glowFactor < high.glowFactor)
            #expect(low.glowOpacityCap < high.glowOpacityCap)
            #expect(low.particleCap < high.particleCap)
            #expect(!low.pulse || high.pulse)
        }
    }

    @Test func theGlowAlphaNeverExceedsTheCap() {
        let bases = [0.0, 0.1, 0.25, 0.35, 0.5, 1.0]
        let pulses = stride(from: -0.15, through: 0.15, by: 0.01).map { $0 } + [-1, 1, .nan, .infinity]
        for budget in ArcadeBudget.all {
            for base in bases {
                for pulse in pulses {
                    let alpha = budget.glowAlpha(base: base, pulse: pulse)
                    #expect(alpha >= 0 && alpha <= budget.glowOpacityCap)
                }
            }
        }
        // The presenter's base 0.35 with its full pulse: level 2 swings below the cap, levels 0 and 1 are held at it.
        #expect(ArcadeBudget.level(2).glowAlpha(base: 0.35, pulse: -0.15) == 0.35 - 0.15)
        #expect(ArcadeBudget.level(2).glowAlpha(base: 0.35, pulse: 0.15) == 0.35)
        #expect(ArcadeBudget.level(1).glowAlpha(base: 0.35, pulse: -0.15) == 0.35 - 0.15)
        #expect(ArcadeBudget.level(1).glowAlpha(base: 0.35, pulse: 0.15) == 0.30)
        // Level 0 does not pulse: the same alpha for every offset.
        #expect(ArcadeBudget.level(0).glowAlpha(base: 0.35, pulse: -0.15) == 0.25)
        #expect(ArcadeBudget.level(0).glowAlpha(base: 0.2, pulse: 0.15) == 0.2)
        #expect(ArcadeBudget.level(0).glowAlpha(base: 0.2, pulse: -0.15) == 0.2)
    }

    @Test func burstsScaleByTheCapAndKeepAtLeastOneParticle() {
        #expect(ArcadeBudget.level(2).burstCount(24) == 24)
        #expect(ArcadeBudget.level(1).burstCount(24) == 12)
        #expect(ArcadeBudget.level(0).burstCount(24) == 5)   // 24 × 48 / 256 = 4.5 → 5
        #expect(ArcadeBudget.level(0).burstCount(1) == 1)
        for budget in ArcadeBudget.all {
            #expect(budget.burstCount(0) == 0 && budget.burstCount(-3) == 0)
            for count in 1...600 {
                let n = budget.burstCount(count)
                #expect(n >= 1 && n <= budget.particleCap)
                #expect(n <= max(count, 1))
            }
        }
    }
}
