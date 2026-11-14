// PrimitiveRendererTests — feature 006 T-F513 (FR-F506, FR-F508, FR-F512; US3 AC4). Simulator pixel tests.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

@MainActor
enum DrawHarness {
    /// Runs `body` inside scene setup with a fresh black size×size target bound; returns its pixels (rows bottom-up).
    static func pixels(size: Int = 32, keep: inout RenderHost?, _ body: @escaping (RenderContext) throws -> Void) throws -> [UInt8] {
        var out: [UInt8] = []
        let host = try RenderHost(scene: ProbeScene(setup: { ctx in
            let t = try ctx.resources.makeRenderTarget(width: size, height: size, label: "draw test")
            t.bind()
            vcglViewport(0, 0, GLsizei(size), GLsizei(size))
            vcglClearColor(0, 0, 0, 1)
            vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            try body(ctx)
            out = t.readPixels()
            ctx.resources.release(t)
        }))
        host.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        host.view.layoutIfNeeded()
        keep = host
        return out
    }

    /// Pixel (x, y) with y counted from the bottom row.
    static func px(_ p: [UInt8], _ size: Int, _ x: Int, _ y: Int) -> SIMD4<Int> {
        let i = (y * size + x) * 4
        return SIMD4(Int(p[i]), Int(p[i + 1]), Int(p[i + 2]), Int(p[i + 3]))
    }
}

/// A scene that draws a SceneNode tree with a PrimitiveRenderer (lifecycle tests).
@MainActor
final class PrimitiveScene: RenderScene {
    let root: SceneNode
    var camera = Camera2D()
    var renderer: PrimitiveRenderer?
    init(root: SceneNode) { self.root = root }
    func setup(_ context: RenderContext) throws { renderer = try PrimitiveRenderer(registry: context.resources) }
    func resize(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        vcglClearColor(0, 0, 0, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        let metrics = ViewMetrics(size: Vec2(Double(context.pixelWidth), Double(context.pixelHeight)), scale: 1)
        try renderer?.draw(root, camera: camera, metrics: metrics)
    }
    func teardown(_ context: RenderContext) { renderer?.release(); renderer = nil }
}

@MainActor
final class PrimitiveRendererTests: XCTestCase {
    private let metrics = ViewMetrics(size: Vec2(32, 32), scale: 1)
    private var host: RenderHost?

    func testRedCircleCoversCenterOnly() throws {
        // AC4: red circle r = 8 at the view center; center red, 12 px away background.
        let root = SceneNode(primitive: .circle(8), color: Vec4(1, 0, 0, 1))
        let p = try DrawHarness.pixels(keep: &host) { ctx in
            try PrimitiveRenderer(registry: ctx.resources).draw(root, camera: Camera2D(), metrics: self.metrics)
        }
        XCTAssertEqual(DrawHarness.px(p, 32, 16, 16), SIMD4(255, 0, 0, 255))
        XCTAssertEqual(DrawHarness.px(p, 32, 28, 16), SIMD4(0, 0, 0, 255))
        XCTAssertEqual(DrawHarness.px(p, 32, 16, 4), SIMD4(0, 0, 0, 255))
        XCTAssertEqual(DrawHarness.px(p, 32, 22, 16).x, 255, "6 px from the center is inside")
    }

    func testRectLineAndPolygonLandWhereExpected() throws {
        let root = SceneNode()
        root.add(SceneNode(position: Vec2(-8, 8), primitive: .rect(Vec2(8, 8)), color: Vec4(0, 1, 0, 1)))        // top-left
        root.add(SceneNode(primitive: .line(Vec2(-16, -10), Vec2(16, -10), width: 2), color: Vec4(0, 0, 1, 1))) // y = -10
        root.add(SceneNode(position: Vec2(8, 8), primitive: .polygon([Vec2(-4, -4), Vec2(4, -4), Vec2(4, 4), Vec2(0, 0), Vec2(-4, 4)]),
                           color: Vec4(1, 1, 0, 1)))   // concave "M"-like shape, top-right
        let p = try DrawHarness.pixels(keep: &host) { ctx in
            try PrimitiveRenderer(registry: ctx.resources).draw(root, camera: Camera2D(), metrics: self.metrics)
        }
        XCTAssertEqual(DrawHarness.px(p, 32, 8, 24), SIMD4(0, 255, 0, 255), "rect centered at world (-8, 8) = pixel (8, 24) from the bottom")
        XCTAssertEqual(DrawHarness.px(p, 32, 16, 6).z, 255, "line along world y = -10")
        XCTAssertEqual(DrawHarness.px(p, 32, 16, 10), SIMD4(0, 0, 0, 255))
        XCTAssertEqual(DrawHarness.px(p, 32, 24, 21), SIMD4(255, 255, 0, 255), "polygon body")
        XCTAssertEqual(DrawHarness.px(p, 32, 24, 27), SIMD4(0, 0, 0, 255), "polygon notch stays empty (ear clipping, not a fan)")
    }

    func testCameraZoomDoublesSizeAndAlphaIsPremultiplied() throws {
        let root = SceneNode(primitive: .circle(4), color: Vec4(1, 1, 1, 0.5))
        let p = try DrawHarness.pixels(keep: &host) { ctx in
            try PrimitiveRenderer(registry: ctx.resources).draw(root, camera: Camera2D(zoom: 2), metrics: self.metrics)
        }
        let inside = DrawHarness.px(p, 32, 22, 16), outside = DrawHarness.px(p, 32, 26, 16)
        XCTAssertEqual(inside.x, 128, accuracy: 2, "half-transparent white over black")
        XCTAssertEqual(outside.x, 0)
    }

    func testSegmentsAndTriangulationBounds() {
        XCTAssertEqual(PrimitiveRenderer.segments(radius: 1e6, pointsPerUnit: 1), 128)
        XCTAssertEqual(PrimitiveRenderer.segments(radius: 0.1, pointsPerUnit: 1), 12)
        XCTAssertEqual(PrimitiveRenderer.segments(radius: .infinity, pointsPerUnit: 1), 12)
        XCTAssertEqual(PrimitiveRenderer.earClip([Vec2(0, 0), Vec2(1, 0), Vec2(1, 1), Vec2(0, 1)]).count, 6)
        XCTAssertEqual(PrimitiveRenderer.earClip([Vec2(0, 1), Vec2(1, 1), Vec2(1, 0), Vec2(0, 0)]).count, 6, "clockwise input")
        XCTAssertTrue(PrimitiveRenderer.triangles(.line(.zero, .zero, width: 3), pointsPerUnit: 1).isEmpty)
    }

    /// Feature 062 (A08-P02) T-A08-204 (FR-A08-202, 203; SC-A08-202): a polyline of N points is one batch of
    /// 2 (N − 1) triangles for its non-zero segments, and its pixels equal the same segments drawn as `.line` nodes.
    func testPolylineIsOneBatchAndMatchesItsSegments() throws {
        let points = [Vec2(-14, -8), Vec2(-6, 9), Vec2(0, -11), Vec2(0, -11), Vec2(7, 6), Vec2(14, -3)]
        XCTAssertEqual(PrimitiveRenderer.triangles(.polyline(points, width: 2), pointsPerUnit: 1).count / 3, 2 * 4,
                       "five segments, one of zero length skipped")
        XCTAssertTrue(PrimitiveRenderer.triangles(.polyline([Vec2(1, 1)], width: 2), pointsPerUnit: 1).isEmpty)
        XCTAssertTrue(PrimitiveRenderer.triangles(.polyline([], width: 2), pointsPerUnit: 1).isEmpty)

        let strip = SceneNode(primitive: .polyline(points, width: 2), color: Vec4(0, 1, 0, 1))
        var stripTriangles = 0
        let a = try DrawHarness.pixels(keep: &host) { ctx in
            let renderer = try PrimitiveRenderer(registry: ctx.resources)
            try renderer.draw(strip, camera: Camera2D(), metrics: self.metrics)
            stripTriangles = renderer.lastTriangleCount
        }
        XCTAssertEqual(stripTriangles, 8, "one batch: the strip's triangles only")
        let segments = SceneNode()
        for (p, q) in zip(points, points.dropFirst()) where p != q {
            segments.add(SceneNode(primitive: .line(p, q, width: 2), color: Vec4(0, 1, 0, 1)))
        }
        let b = try DrawHarness.pixels(keep: &host) { ctx in
            try PrimitiveRenderer(registry: ctx.resources).draw(segments, camera: Camera2D(), metrics: self.metrics)
        }
        var covered = 0, differing = 0
        for y in 0..<32 {
            for x in 0..<32 {
                let pa = DrawHarness.px(a, 32, x, y), pb = DrawHarness.px(b, 32, x, y)
                if pa.y > 0 || pb.y > 0 { covered += 1 }
                if pa != pb { differing += 1 }
            }
        }
        XCTAssertGreaterThan(covered, 60, "the strip covers pixels")
        XCTAssertLessThanOrEqual(Double(differing), Double(covered) * 0.01, "\(differing) of \(covered) pixels differ")
    }

    func testRecreationRebuildsAndTeardownLeaksNothing() throws {
        let scene = PrimitiveScene(root: SceneNode(primitive: .circle(6), color: Vec4(1, 0, 0, 1)))
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        let w = host.pixelSize.width, h = host.pixelSize.height
        func center() -> Int { let px = host.readPixels(); return Int(px[((h / 2) * w + w / 2) * 4]) }
        XCTAssertEqual(center(), 255)
        host.recreateContext()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(center(), 255, "rebuilt after recreation")
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }
}
