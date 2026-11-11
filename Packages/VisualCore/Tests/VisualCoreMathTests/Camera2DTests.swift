// Camera2DTests — feature 006 T-F503 (FR-F501).
import Foundation
import Testing
@testable import VisualCoreMath

@Test func zoomIsClamped() {
    #expect(Camera2D(zoom: 0.01).zoom == 0.1)
    var c = Camera2D(zoom: 1000)
    #expect(c.zoom == 100)
    c.zoom = .nan
    #expect(c.zoom == 1)
}

@Test func matrixAndInverseRoundTrip() {
    let c = Camera2D(center: Vec2(10, -3), zoom: 2.5, rotation: 0.4)
    for p in [Vec2(0, 0), Vec2(123.4, -56.7), Vec2(-1e4, 3e3)] {
        #expect(close(c.inverse.apply(c.matrix.apply(p)), p, 1e-9))
    }
    #expect(close(c.matrix.apply(Vec2(10, -3)), .zero), "center maps to the view center")
}

@Test func zoomAndPanAtViewCenter() {
    // Spec US1/AC2: zoom 2, panned (10, 0) world units → view center is world (10, 0).
    let c = Camera2D(center: Vec2(10, 0), zoom: 2)
    #expect(close(c.inverse.apply(.zero), Vec2(10, 0)))
    #expect(close(c.inverse.apply(Vec2(20, 0)), Vec2(20, 0)), "20 pt right at zoom 2 = 10 world units")
}

@Test func pinchZoomKeepsAnchorFixed() {
    var c = Camera2D(center: Vec2(5, 5), zoom: 1, rotation: 0.3)
    let anchor = Vec2(40, -25)
    let world = c.inverse.apply(anchor)
    c.zoom(by: 3, around: anchor)
    #expect(c.zoom == 3)
    #expect(close(c.inverse.apply(anchor), world, 1e-9))
    c.zoom(by: -1)
    #expect(c.zoom == 3, "invalid factor ignored")
}

@Test func panMovesContentWithFinger() {
    var c = Camera2D(zoom: 2, rotation: .pi / 2)
    let world = c.inverse.apply(Vec2(10, 10))
    c.pan(by: Vec2(6, -4))
    #expect(close(c.matrix.apply(world), Vec2(16, 6), 1e-9))
}
