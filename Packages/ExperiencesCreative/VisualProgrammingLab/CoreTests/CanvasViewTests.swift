// CanvasViewTests — feature 167 (A23-P02) T-A23-204 (FR-A23-204; SC-A23-203; clarification Q3). The canvas view:
// the screen ↔ canvas round trip at several zooms and centres (canvas y down), the pinch anchored on the canvas point
// under the fingers and clamped to 0.5…2, the pan following the finger and clamped to ±4,096, the resize keeping centre
// and zoom, and non-finite input leaving the view unchanged. Synthetic data only.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualProgrammingLabCore

@Suite struct CanvasViewTests {
    private static let size = Vec2(800, 600)

    private static func near(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool {
        abs(a - b) <= tolerance * max(1, abs(a), abs(b))
    }

    private static func near(_ a: CanvasPoint, _ b: CanvasPoint) -> Bool { near(a.x, b.x) && near(a.y, b.y) }

    private static func near(_ a: Vec2, _ b: Vec2) -> Bool { near(a.x, b.x) && near(a.y, b.y) }

    @Test func defaults() {
        let view = CanvasView(size: Self.size)
        #expect(CanvasView.minZoom == 0.5)
        #expect(CanvasView.maxZoom == 2)
        #expect(CanvasView.centreBound == 4_096)
        #expect(view.zoom == 1)
        #expect(view.centre == CanvasPoint(x: 0, y: 0))
        #expect(view.size == Self.size)
        #expect(Self.near(view.screen(fromCanvas: CanvasPoint(x: 0, y: 0)), Vec2(400, 300)))
        // Canvas y grows down, like the screen.
        #expect(Self.near(view.screen(fromCanvas: CanvasPoint(x: 10, y: 20)), Vec2(410, 320)))
        #expect(Self.near(view.canvas(fromScreen: Vec2(0, 0)), CanvasPoint(x: -400, y: -300)))
    }

    @Test func roundTripAtSeveralZoomsAndCentres() {
        let centres = [CanvasPoint(x: 0, y: 0), CanvasPoint(x: 180, y: 120), CanvasPoint(x: -4_000, y: 3_500)]
        let screens = [Vec2(0, 0), Vec2(123.5, 456.25), Vec2(800, 600)]
        for zoom in [0.5, 0.75, 1, 1.5, 2] {
            for centre in centres {
                let view = CanvasView(size: Self.size, centre: centre, zoom: zoom)
                #expect(Self.near(view.zoom, zoom))
                #expect(Self.near(view.centre, centre))
                #expect(Self.near(view.screen(fromCanvas: centre), Vec2(400, 300)))
                for s in screens {
                    let c = view.canvas(fromScreen: s)
                    #expect(Self.near(view.screen(fromCanvas: c), s), "\(zoom) \(centre) \(s)")
                    #expect(Self.near(c.y - centre.y, (s.y - 300) / zoom), "\(zoom) \(centre) \(s)")
                }
            }
        }
    }

    @Test func initClampsAndReplacesInvalidValues() {
        #expect(CanvasView(size: Self.size, zoom: 5).zoom == 2)
        #expect(CanvasView(size: Self.size, zoom: 0.1).zoom == 0.5)
        #expect(CanvasView(size: Self.size, zoom: .nan).zoom == 1)
        #expect(CanvasView(size: Self.size, zoom: -1).zoom == 1)
        #expect(CanvasView(size: Self.size, centre: CanvasPoint(x: 9_000, y: -9_000)).centre
                    == CanvasPoint(x: 4_096, y: -4_096))
        #expect(CanvasView(size: Self.size, centre: CanvasPoint(x: .infinity, y: 3)).centre == CanvasPoint(x: 0, y: 0))
        #expect(CanvasView(size: Vec2(0, 600)).size == Vec2(1, 1))
    }

    @Test func pinchKeepsTheCanvasPointUnderTheAnchor() {
        let view = CanvasView(size: Self.size, centre: CanvasPoint(x: 50, y: -20))
        let anchor = Vec2(620, 140)
        let fixed = view.canvas(fromScreen: anchor)
        for scale in [1.25, 1.5, 0.8, 0.6] {
            let pinched = view.pinched(by: scale, anchor: anchor)
            #expect(Self.near(pinched.zoom, scale), "\(scale)")
            #expect(Self.near(pinched.canvas(fromScreen: anchor), fixed), "\(scale)")
            #expect(pinched.size == view.size)
        }
    }

    @Test func pinchClampsAtHalfAndTwo() {
        let view = CanvasView(size: Self.size)
        let anchor = Vec2(100, 500)
        let fixed = view.canvas(fromScreen: anchor)
        let wide = view.pinched(by: 10, anchor: anchor)
        #expect(wide.zoom == 2)
        #expect(Self.near(wide.canvas(fromScreen: anchor), fixed))
        let narrow = view.pinched(by: 0.01, anchor: anchor)
        #expect(narrow.zoom == 0.5)
        #expect(Self.near(narrow.canvas(fromScreen: anchor), fixed))
        let again = wide.pinched(by: 3, anchor: anchor)
        #expect(again.zoom == 2)
        #expect(Self.near(again.centre, wide.centre))
        #expect(narrow.pinched(by: 0.5, anchor: anchor).zoom == 0.5)
    }

    @Test func panFollowsTheFinger() {
        let view = CanvasView(size: Self.size, centre: CanvasPoint(x: 10, y: 10), zoom: 2)
        let point = CanvasPoint(x: 30, y: 40)
        let before = view.screen(fromCanvas: point)
        let delta = Vec2(25, -60)
        let panned = view.panned(by: delta)
        #expect(Self.near(panned.screen(fromCanvas: point), before + delta))
        #expect(Self.near(panned.centre, CanvasPoint(x: 10 - 12.5, y: 10 + 30)))
        #expect(panned.zoom == view.zoom)
    }

    @Test func panIsClampedToTheBound() {
        let view = CanvasView(size: Self.size, centre: CanvasPoint(x: 4_000, y: -4_000))
        let far = view.panned(by: Vec2(-1_000, 1_000))
        #expect(far.centre == CanvasPoint(x: 4_096, y: -4_096))
        let back = CanvasView(size: Self.size, zoom: 0.5).panned(by: Vec2(1e6, -1e6))
        #expect(back.centre == CanvasPoint(x: -4_096, y: 4_096))
    }

    @Test func resizeKeepsCentreAndZoom() {
        let view = CanvasView(size: Self.size, centre: CanvasPoint(x: -75, y: 210), zoom: 1.5)
        let resized = view.resized(to: Vec2(600, 800))
        #expect(resized.size == Vec2(600, 800))
        #expect(resized.centre == view.centre)
        #expect(resized.zoom == view.zoom)
        #expect(Self.near(resized.screen(fromCanvas: view.centre), Vec2(300, 400)))
    }

    @Test func nonFiniteInputLeavesTheViewUnchanged() {
        let view = CanvasView(size: Self.size, centre: CanvasPoint(x: 12, y: -34), zoom: 1.25)
        #expect(view.pinched(by: .nan, anchor: Vec2(1, 1)) == view)
        #expect(view.pinched(by: .infinity, anchor: Vec2(1, 1)) == view)
        #expect(view.pinched(by: 0, anchor: Vec2(1, 1)) == view)
        #expect(view.pinched(by: -2, anchor: Vec2(1, 1)) == view)
        #expect(view.pinched(by: 1.5, anchor: Vec2(.nan, 1)) == view)
        #expect(view.panned(by: Vec2(.infinity, 0)) == view)
        #expect(view.panned(by: Vec2(0, .nan)) == view)
        #expect(view.resized(to: Vec2(.nan, 100)) == view)
        #expect(view.resized(to: Vec2(-5, 100)) == view)
        #expect(view.resized(to: Vec2(0, 0)) == view)
    }
}
