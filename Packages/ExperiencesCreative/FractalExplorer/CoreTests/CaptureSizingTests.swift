// CaptureSizingTests — feature 029 T-A03-407 (FR-A03-405; US2 AC1; spec 029 clarification 1).
import Testing
import VisualCoreMath
@testable import FractalExplorerCore

@Suite struct CaptureSizingTests {
    let size = Vec2(390, 844)

    @Test func shallowViewsGetTheRequestedSize() {
        let v = PlaneViewport.framing(width: 4, center: Vec2(-0.5, 0), size: size)
        let r = CaptureSizing.longEdge(viewport: v, pixelsPerPoint: 3, mantissaBits: 23)
        #expect(r.longEdge == 4096)
        #expect(!r.limited)
    }

    @Test func deepViewsAreLimitedByPrecision() {
        // Span across the long edge = 3000 float32 steps at |center| = 0.75: at most 3000 pixels carry real detail.
        let minStep = PrecisionAdvisor.minimumPixelStep(mantissaBits: 23, magnitude: 0.75)
        let v = PlaneViewport(center: Vec2(-0.75, 0.1), unitsPerPoint: 3000 * minStep / 844, size: size)
        let r = CaptureSizing.longEdge(viewport: v, pixelsPerPoint: 3, mantissaBits: 23)
        #expect(r.longEdge == 3000 - 3000 % 2)
        #expect(r.limited)
        #expect(Double(r.longEdge) <= 3000)
    }

    @Test func neverBelowTheCanvasPixels() {
        let minStep = PrecisionAdvisor.minimumPixelStep(mantissaBits: 10, magnitude: 0.75)
        let v = PlaneViewport(center: Vec2(-0.75, 0.1), unitsPerPoint: minStep, size: size)
        let r = CaptureSizing.longEdge(viewport: v, pixelsPerPoint: 3, mantissaBits: 10)
        #expect(r.longEdge == 2532)
        #expect(r.limited)
    }

    @Test func evenAndAtLeastTwo() {
        let v = PlaneViewport.framing(width: 4, center: .zero, size: Vec2(1, 1))
        let r = CaptureSizing.longEdge(requested: 5, viewport: v, pixelsPerPoint: 1, mantissaBits: 23)
        #expect(r.longEdge == 4)
        #expect(!r.limited)
    }
}
