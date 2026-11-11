// GardenTests — feature 009 T-F804 (FR-F803, FR-F804, SC-F803; US1 AC1–AC5; edge cases spacing/capacity).
import Foundation
import Testing
import VisualCoreMath
@testable import GardenKit

private func grow(_ g: inout Garden, seconds: Double) {
    for _ in 0..<Int((seconds * 120).rounded()) { g.step(1.0 / 120) }
}

@Test func plantingSpacingAndCounts() {
    // AC1 + edge case minimum spacing.
    var g = Garden(seed: 1)
    #expect(g.plant(at: Vec2(0, 0)) == .planted(0))
    #expect(g.plant(at: Vec2(100, 0)) == .planted(1))
    #expect(g.plant(at: Vec2(0, 100)) == .planted(2))
    #expect(g.plantedCount == 3)
    #expect(g.plant(at: Vec2(39, 0)) == .tooClose, "closer than 40 to an existing flower")
    #expect(g.plant(at: Vec2(40, 0)) == .planted(3), "exactly 40 is allowed")
}

@Test func growthReachesBloomAfterFourSeconds() {
    // AC2
    var g = Garden(seed: 1)
    _ = g.plant(at: .zero)
    #expect(g.flowers[0].stage == .seed)
    grow(&g, seconds: 1)
    #expect(g.flowers[0].stage == .growing)
    grow(&g, seconds: 2.9)
    #expect(g.bloomingCount == 0)
    grow(&g, seconds: 0.2)
    #expect(g.flowers[0].stage == .bloom)
    #expect(g.bloomingCount == 1)
    #expect(g.flowers[0].growth == 1)
}

@Test func harvestingScoresOnlyBlooms() {
    // AC3 + AC5
    var g = Garden(seed: 1)
    _ = g.plant(at: .zero)
    _ = g.plant(at: Vec2(200, 0))
    grow(&g, seconds: 2)
    #expect(g.tap(at: Vec2(5, 5)) == .notReady, "a growing seed is not harvested")
    #expect(g.score == 0)
    grow(&g, seconds: 2.5)
    #expect(g.tap(at: Vec2(20, -20)) == .harvested(0), "within 30 of the bloom")
    #expect(g.score == 1)
    #expect(g.flowers[0].stage == .harvested)
    #expect(g.plantedCount == 1)
    #expect(g.tap(at: Vec2(0, 0)) == .nothing, "already harvested")
    #expect(g.tap(at: Vec2(500, 500)) == .nothing)
}

@Test func interactPlantsOrHarvests() {
    var g = Garden(seed: 2)
    #expect(g.interact(at: .zero) == .planted(0))
    #expect(g.interact(at: Vec2(10, 0)) == .notReady, "tapping a growing flower does not plant on top")
    grow(&g, seconds: 4.1)
    #expect(g.interact(at: Vec2(10, 0)) == .harvested(0))
    #expect(g.interact(at: Vec2(10, 0)) == .planted(1), "the harvested spot can be replanted")
}

@Test func capacityAndHarvestedSlotReuse() {
    var g = Garden(seed: 3)
    for i in 0..<24 { #expect(g.plant(at: Vec2(Double(i % 6) * 50, Double(i / 6) * 50)) == .planted(i)) }
    #expect(g.plant(at: Vec2(1000, 1000)) == .full)
    grow(&g, seconds: 4.1)
    #expect(g.tap(at: Vec2(0, 0)) == .harvested(0))
    #expect(g.plant(at: Vec2(1000, 1000)) == .planted(24), "harvested slot reused")
    #expect(g.flowers.count == 24)
    #expect(g.flowers.contains { $0.id == 24 && $0.position == Vec2(1000, 1000) })
}

@Test func breezeFollowsDragAndDecays() {
    // AC4
    var g = Garden(seed: 4)
    g.drag(velocity: Vec2(200, 0))
    #expect(g.breeze.x > 0 && g.breeze.y == 0)
    let start = g.breeze.x
    grow(&g, seconds: 1)
    #expect(abs(g.breeze.x - start * exp(-1)) < start * 0.02, "1 s time constant")
    g.drag(velocity: Vec2(0, 1e6))
    #expect(g.breeze.length <= Garden.maxBreeze + 1e-9)
}

@Test func deterministicReplay() {
    func run(_ seed: UInt64) -> [Double] {
        var g = Garden(seed: seed)
        for i in 0..<10 { _ = g.interact(at: Vec2(Double(i) * 60, 0)) }
        grow(&g, seconds: 5)
        for i in 0..<10 { _ = g.interact(at: Vec2(Double(i) * 60, 0)) }
        return g.flowers.map(\.hue) + [Double(g.score)]
    }
    #expect(run(9) == run(9))
    #expect(run(9) != run(10))
}
