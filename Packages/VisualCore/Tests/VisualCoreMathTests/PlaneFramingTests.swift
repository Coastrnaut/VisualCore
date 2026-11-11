// PlaneFramingTests — feature 028 T-A03-301 (FR-A03-301, SC-A03-301, SC-A03-302; contract framing-library-bookmarks).
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct PlaneFramingTests {
    static let sizes = [Vec2(320, 568), Vec2(568, 320), Vec2(390, 844), Vec2(1024, 1366), Vec2(1366, 1024)]

    struct LCG { var s: UInt64; mutating func next() -> Double { s = s &* 6364136223846793005 &+ 1442695040888963407; return Double(s >> 11) / Double(1 << 53) } }

    @Test func roundTripKeepsCenterExactlyAndSpanWithin1e12() {
        var r = LCG(s: 42)
        for _ in 0..<100 {
            let center = Vec2(r.next() * 4 - 2, r.next() * 4 - 2)
            let span = pow(10, -12 + r.next() * 14)
            let f = PlaneFraming(center: center, span: span)
            for size in Self.sizes {
                let back = PlaneFraming(f.viewport(size: size))
                #expect(back.center == center)
                #expect(abs(back.span - span) <= 1e-12 * span)
            }
        }
    }

    @Test func portraitToLandscapeKeepsCenterSpanAndSquarePixels() {
        let portrait = PlaneViewport.framing(width: 3, center: Vec2(-0.75, 0.1), size: Vec2(390, 844))
        let landscape = PlaneFraming(portrait).viewport(size: Vec2(844, 390))
        #expect(landscape.center == portrait.center)
        #expect(abs(landscape.unitsPerPoint * 390 - 3) < 1e-12 * 3)
        // One scale for both axes: equal screen distances map to equal plane distances in x and y.
        let a = landscape.plane(fromScreen: Vec2(0, 0)), b = landscape.plane(fromScreen: Vec2(100, 100))
        #expect(abs(abs(b.x - a.x) - abs(b.y - a.y)) < 1e-12)
    }

    @Test func invalidValuesFallBack() {
        #expect(PlaneFraming(center: Vec2(.nan, 1), span: 2).center == .zero)
        #expect(PlaneFraming(center: .zero, span: 0).span == 1)
        #expect(PlaneFraming(center: .zero, span: -3).span == 1)
        #expect(PlaneFraming(center: .zero, span: .infinity).span == 1)
        #expect(PlaneFraming(center: .zero, span: 2).viewport(size: Vec2(0, .nan)).size == Vec2(1, 1))
    }

    @Test func codableRoundTripAndValidationOnDecode() throws {
        let f = PlaneFraming(center: Vec2(-0.743643887037151, 0.131825904205330), span: 1.5e-9)
        let data = try JSONEncoder().encode(f)
        #expect(try JSONDecoder().decode(PlaneFraming.self, from: data) == f)
        let bad = Data(#"{"center":{"x":1,"y":2},"span":-1}"#.utf8)
        #expect(try JSONDecoder().decode(PlaneFraming.self, from: bad).span == 1)
    }

    @Test func clampedViewportReportsTheClampedSpan() {
        let tiny = PlaneFraming(center: .zero, span: 1e-20).viewport(size: Vec2(100, 100))
        #expect(tiny.wasClamped)
        #expect(PlaneFraming(tiny).span == PlaneViewport.minUnitsPerPoint * 100)
    }

    @Test func viewportMatchesFraming() {
        let v = PlaneViewport.framing(width: 4, center: Vec2(-0.5, 0), size: Vec2(300, 400))
        #expect(PlaneFraming(center: Vec2(-0.5, 0), span: 4).viewport(size: Vec2(300, 400)) == v)
    }
}
