// CoordinateTests — feature 006 T-F504 (FR-F501, SC-F501, spec US1 AC1/AC2, edge cases).
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

private func near(_ a: Vec2?, _ b: Vec2, _ eps: Double = 1e-9) -> Bool {
    guard let a else { return false }
    return abs(a.x - b.x) <= eps && abs(a.y - b.y) <= eps
}

@Test func phoneCenterMapsToNDCOriginAndPixels() {
    // AC1: 390×844 pt at scale 3, touch at (195, 422).
    let m = ViewMetrics(size: Vec2(390, 844), scale: 3)
    #expect(near(m.toNDC(Vec2(195, 422)), .zero))
    #expect(near(m.toPixels(Vec2(195, 422)), Vec2(585, 1266)))
    #expect(near(m.toNDC(Vec2(0, 0)), Vec2(-1, 1)), "top-left is NDC (-1, 1)")
    #expect(near(m.toNDC(Vec2(390, 844)), Vec2(1, -1)))
}

@Test func zoomedPannedCameraAtViewCenter() {
    // AC2: zoom 2, pan (10, 0) → view center is world (10, 0), and back within 0.001 pt.
    let m = ViewMetrics(size: Vec2(390, 844), scale: 3)
    let cam = Camera2D(center: Vec2(10, 0), zoom: 2)
    let center = Vec2(195, 422)
    let world = m.toWorld(center, camera: cam)
    #expect(near(world, Vec2(10, 0)))
    #expect(near(m.fromWorld(world!, camera: cam), center, 0.001))
}

@Test func roundTripsAcrossScalesAspectsAndCameras() {
    // SC-F501: all spaces, 3 scales × 4 aspect ratios × camera transforms, within 0.001 pt.
    let sizes = [Vec2(390, 844), Vec2(768, 1024), Vec2(500, 500), Vec2(1366, 768.375)]   // 9:19.5, 3:4, 1:1, 16:9
    let cams = [Camera2D(), Camera2D(center: Vec2(-250, 1e4), zoom: 0.1, rotation: 2.9),
                Camera2D(center: Vec2(3.3, -7.7), zoom: 100, rotation: -0.6)]
    var checked = 0
    for size in sizes {
        for scale in [1.0, 2.0, 3.0] {
            let m = ViewMetrics(size: size, scale: scale)
            for p in [Vec2(0, 0), Vec2(17.25, 300.5), size, size * 0.73] {
                #expect(near(m.fromPixels(m.toPixels(p)!), p, 0.001))
                #expect(near(m.fromNDC(m.toNDC(p)!), p, 0.001))
                #expect(near(m.fromCamera(m.toCamera(p)!), p, 0.001))
                for cam in cams {
                    #expect(near(m.fromWorld(m.toWorld(p, camera: cam)!, camera: cam), p, 0.001))
                    // The drawing matrix agrees with the point path.
                    let ndc = m.worldToNDC(camera: cam)!.apply(m.toWorld(p, camera: cam)!)
                    #expect(near(ndc, m.toNDC(p)!, 1e-6))
                    checked += 1
                }
            }
        }
    }
    #expect(checked == 4 * 3 * 4 * 3)
}

@Test func zeroSizeViewReturnsNil() {
    let m = ViewMetrics(size: .zero, scale: 3)
    #expect(m.toNDC(Vec2(1, 1)) == nil)
    #expect(m.toWorld(Vec2(1, 1), camera: Camera2D()) == nil)
    #expect(m.worldToNDC(camera: Camera2D()) == nil)
    #expect(ViewMetrics(size: Vec2(10, 10), scale: 0).toPixels(.zero) == nil)
    #expect(ViewMetrics(size: Vec2(.nan, 10), scale: 1).aspect == nil)
}

@Test func rotationUsesTheNewSize() {
    // Edge case: after rotation the next conversion uses the current size.
    var m = ViewMetrics(size: Vec2(390, 844), scale: 3)
    #expect(near(m.toNDC(Vec2(195, 422)), .zero))
    m.size = Vec2(844, 390)
    #expect(near(m.toNDC(Vec2(422, 195)), .zero))
    #expect(near(m.toNDC(Vec2(195, 422)), Vec2(195.0 / 422 - 1, 1 - 844.0 / 390)))
}
