// DrawingBudgetTests — feature 086 (A11-P05) T-A11-502 (FR-A11-520; clarification 4; research D3). The three quality
// levels' drawing budgets and the level choice: coils 8/6/4, circle segments 33/24/16, hatch spacing 0.12 m / 0.2 m /
// none, arrowheads at every level; Low Power Mode draws level 2; otherwise the host tier clamped to 0…2.
import Foundation
import Testing
import PhysicsPlaygroundCore

@Suite struct DrawingBudgetTests {
    @Test func theThreeLevelsHaveTheStatedDetail() {
        #expect(DrawingBudget.count == 3 && DrawingBudget.levels.count == 3)
        #expect(DrawingBudget.levels.map(\.coils) == [8, 6, 4])
        #expect(DrawingBudget.levels.map(\.circleSegments) == [33, 24, 16])
        #expect(DrawingBudget.levels.map(\.hatchSpacing) == [0.12, 0.2, nil])
        #expect(DrawingBudget.levels.allSatisfy { $0.arrowheads })
        #expect(DrawingBudget.budget(level: -3) == DrawingBudget.levels[0])
        #expect(DrawingBudget.budget(level: 9) == DrawingBudget.levels[2])
    }

    @Test func lowPowerDrawsTheLightestLevelOtherwiseTheClampedTier() {
        #expect((-2...5).map { DrawingBudget.level(tier: $0, lowPower: false) } == [0, 0, 0, 1, 2, 2, 2, 2])
        #expect((-2...5).allSatisfy { DrawingBudget.level(tier: $0, lowPower: true) == 2 })
    }
}
