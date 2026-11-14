// JourneyRailTests — feature 054 (A07-P01) T-A07-103 (FR-A07-101, FR-A07-110; clarification 2). The seeded rail is
// valid for many seeds, keeps its radius of curvature at or above fast speed ÷ 45°/s (≈ 8.92), stays near the
// perturbed ellipse and is deterministic.
import Foundation
import Testing
import VisualCoreMath
import AudioOdysseyCore

@Suite struct JourneyRailTests {
    @Test func theRequiredRadiusCoversTheComfortRule() {
        let comfort = 7 / (45 * Double.pi / 180)
        #expect(abs(JourneyRail.comfortTurnRadius - comfort) < 1e-12)
        #expect(JourneyRail.requiredTurnRadius >= comfort)
    }

    @Test func railsOfTwentySeedsAreValidAndComfortable() {
        let comfort = 7 / (45 * Double.pi / 180)
        for seed in UInt64(0)..<20 {
            let rail = JourneyRail.make(seed: seed)
            #expect(rail.length.isFinite && rail.length > 400, "seed \(seed): length \(rail.length)")
            let radius = rail.minimumTurnRadius()
            #expect(radius >= comfort, "seed \(seed): radius \(radius)")
            #expect(radius >= JourneyRail.requiredTurnRadius, "seed \(seed): radius \(radius)")
            for d in stride(from: 0.0, to: rail.length, by: rail.length / 16) {
                let pose = rail.pose(at: d)
                #expect(pose.position.isFinite && abs(pose.direction.length - 1) < 1e-9, "seed \(seed) d \(d)")
            }
        }
    }

    @Test func controlPointsStayNearThePerturbedEllipse() {
        for seed in UInt64(0)..<20 {
            let points = JourneyRail.controlPoints(seed: seed)
            #expect(points.count == 12)
            for (k, p) in points.enumerated() {
                #expect(abs(p.y) <= 4, "seed \(seed) point \(k)")
                let e = ((p.x / 120) * (p.x / 120) + (p.z / 80) * (p.z / 80)).squareRoot()
                #expect(e >= 0.9 - 1e-12 && e <= 1.1 + 1e-12, "seed \(seed) point \(k): \(e)")
            }
        }
    }

    @Test func theRailIsDeterministicAndSeedDependent() {
        #expect(JourneyRail.make(seed: 5) == JourneyRail.make(seed: 5))
        #expect(JourneyRail.controlPoints(seed: 5) == JourneyRail.controlPoints(seed: 5))
        #expect(JourneyRail.controlPoints(seed: 5) != JourneyRail.controlPoints(seed: 6))
        let flat = JourneyRail.controlPoints(seed: 5, scale: 0)
        #expect(flat.allSatisfy { $0.y == 0 })
    }
}
