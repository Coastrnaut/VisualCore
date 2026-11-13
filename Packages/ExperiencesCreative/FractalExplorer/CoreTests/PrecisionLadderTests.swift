// PrecisionLadderTests — feature 030 T-A03-504 (FR-A03-502, SC-A03-502; US1; analyze I1).
import Foundation
import Testing
import VisualCoreMath
@testable import FractalExplorerCore

@Suite struct PrecisionLadderTests {
    func step(_ i: Int, _ level: PrecisionMode.Level, clamped: Bool = false, _ agreement: Double) -> PrecisionLadder.Step {
        PrecisionLadder.Step(index: i, zoom: pow(4, Double(i)), level: level, clamped: clamped, agreement: agreement)
    }

    @Test func clampBeforeTheBreakdownPasses() {
        let v = PrecisionLadder.verdict([step(0, .reliable, 1), step(1, .reliable, 0.995), step(2, .nearLimit, 0.97),
                                         step(3, .beyondLimit, clamped: true, 0.6)])
        #expect(v.pass)
        #expect(v.clampStep == 3)
        #expect(v.breakdownStep == 2, "a near-limit step may blur: recorded, not judged")
        #expect(v.minReliableAgreement == 0.995)
    }

    @Test func aReliableStepBelowTheThresholdFails() {
        let v = PrecisionLadder.verdict([step(0, .reliable, 1), step(1, .reliable, 0.95), step(2, .beyondLimit, clamped: true, 0.5)])
        #expect(!v.pass)
        #expect(v.reason.hasPrefix("step 1 is reliable"))
    }

    @Test func breakdownWithoutAClampFails() {
        let v = PrecisionLadder.verdict([step(0, .reliable, 1), step(1, .nearLimit, 0.9)])
        #expect(!v.pass)
        #expect(v.clampStep == nil)
        #expect(v.breakdownStep == 1)
    }

    @Test func noBreakdownWithinTheLadderPasses() {
        let v = PrecisionLadder.verdict([step(0, .reliable, 1), step(1, .reliable, 1), step(2, .nearLimit, 1)])
        #expect(v.pass)
        #expect(v.breakdownStep == nil)
        #expect(v.clampStep == nil)
    }

    @Test func zoomsStopBeforeTheViewportScaleLimit() {
        let z = PrecisionLadder.zooms(canvas: Vec2(390, 844))
        #expect(z.first == 1)
        #expect(z.count < PrecisionLadder.maxSteps, "4^23 at 390 pt is finer than 1e-15 per point")
        let last = PrecisionLadder.canvasViewport(zoom: z.last!, canvas: Vec2(390, 844))
        #expect(!last.wasClamped)
    }

    @Test func patchHasTheCanvasPixelStep() {
        let full = PrecisionLadder.canvasViewport(zoom: 1024, canvas: Vec2(390, 844))
        let patch = PrecisionLadder.patchViewport(zoom: 1024, canvas: Vec2(390, 844), pixelsPerPoint: 3)
        #expect(patch.center == full.center)
        #expect(patch.unitsPerPoint == full.unitsPerPoint)
        #expect(abs(patch.size.x * 3 - 64) < 1e-9)
    }

    @Test func clampFollowsTheAdvisor() {
        let canvas = Vec2(390, 844)
        #expect(!PrecisionLadder.isClamped(zoom: 1, canvas: canvas, mantissaBits: 23, pixelsPerPoint: 3))
        let z23 = PrecisionLadder.zooms(canvas: canvas).first { PrecisionLadder.isClamped(zoom: $0, canvas: canvas, mantissaBits: 23, pixelsPerPoint: 3) }
        let z10 = PrecisionLadder.zooms(canvas: canvas).first { PrecisionLadder.isClamped(zoom: $0, canvas: canvas, mantissaBits: 10, pixelsPerPoint: 3) }
        #expect(z10 != nil && z23 != nil && z10! < z23!)
    }
}
