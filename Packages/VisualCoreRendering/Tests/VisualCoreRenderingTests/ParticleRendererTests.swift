// ParticleRendererTests — feature 006 T-F514 (FR-F507, FR-F508). Simulator pixel tests.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
import XCTest
@testable import VisualCoreRendering

@MainActor
final class ParticleRendererTests: XCTestCase {
    private let metrics = ViewMetrics(size: Vec2(32, 32), scale: 1)
    private var host: RenderHost?

    func testInstancesLandAtTheirPositionsWithColor() throws {
        let particles = [ParticleInstance(position: .zero, size: 10, color: Vec4(1, 0, 0, 1)),
                         ParticleInstance(position: Vec2(10, 0), size: 4, color: Vec4(0, 0, 1, 1))]
        var drawn = 0
        let p = try DrawHarness.pixels(keep: &host) { ctx in
            let r = try ParticleRenderer(registry: ctx.resources)
            try r.draw(particles, camera: Camera2D(), metrics: self.metrics)
            drawn = r.lastInstanceCount
        }
        XCTAssertEqual(drawn, 2)
        XCTAssertEqual(DrawHarness.px(p, 32, 16, 16), SIMD4(255, 0, 0, 255), "red particle at the center")
        XCTAssertEqual(DrawHarness.px(p, 32, 26, 16).z, 255, "blue particle 10 px right")
        XCTAssertEqual(DrawHarness.px(p, 32, 16, 24), SIMD4(0, 0, 0, 255), "nothing 8 px above the 5 px-radius particle")
        XCTAssertEqual(DrawHarness.px(p, 32, 16, 28).w, 255)
    }

    func testTenThousandInstancesFromTheSimulation() throws {
        var ps = ParticleSystem(seed: 1)
        ps.emitters = [Emitter(rate: 0, lifetime: 10...10, speed: 0...30, startSize: 2, endSize: 2,
                               startColor: Vec4(0, 1, 0, 1), endColor: Vec4(0, 1, 0, 1))]
        ps.burst(10_000)
        ps.step(1.0 / 120)
        XCTAssertEqual(ps.aliveCount, 10_000)
        var drawn = 0, error = GLenum(0)
        let p = try DrawHarness.pixels(keep: &host) { ctx in
            let r = try ParticleRenderer(registry: ctx.resources)
            try r.draw(ps.instances(), camera: Camera2D(), metrics: self.metrics)
            drawn = r.lastInstanceCount
            error = vcglGetError()
        }
        XCTAssertEqual(drawn, 10_000)
        XCTAssertEqual(error, GLenum(GL_NO_ERROR))
        XCTAssertGreaterThan(DrawHarness.px(p, 32, 16, 16).y, 200, "the burst covers the center")
    }

    func testEmptyAndZoomedDraws() throws {
        var drawn = -1
        let p = try DrawHarness.pixels(keep: &host) { ctx in
            let r = try ParticleRenderer(registry: ctx.resources)
            try r.draw([], camera: Camera2D(), metrics: self.metrics)
            drawn = r.lastInstanceCount
            try r.draw([ParticleInstance(position: Vec2(4, 0), size: 2, color: Vec4(1, 1, 1, 1))], camera: Camera2D(zoom: 2), metrics: self.metrics)
        }
        XCTAssertEqual(drawn, 0)
        XCTAssertEqual(DrawHarness.px(p, 32, 24, 16).x, 255, "world x = 4 at zoom 2 is 8 px right")
        XCTAssertEqual(DrawHarness.px(p, 32, 20, 16).x, 0)
    }

    func testRecreationAndTeardown() throws {
        final class Scene: RenderScene {
            var renderer: ParticleRenderer?
            func setup(_ c: RenderContext) throws { renderer = try ParticleRenderer(registry: c.resources) }
            func resize(_ c: RenderContext) {}
            func render(_ c: RenderContext, frame: FrameInfo) throws {
                vcglClearColor(0, 0, 0, 1); vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
                try renderer?.draw([ParticleInstance(position: .zero, size: 8, color: Vec4(1, 0, 0, 1))], camera: Camera2D(),
                                   metrics: ViewMetrics(size: Vec2(Double(c.pixelWidth), Double(c.pixelHeight)), scale: 1))
            }
            func teardown(_ c: RenderContext) { renderer?.release(); renderer = nil }
        }
        let host = try RenderHost(scene: Scene())
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        host.view.layoutIfNeeded()
        let w = host.pixelSize.width, h = host.pixelSize.height
        func center() -> Int { Int(host.readPixels()[((h / 2) * w + w / 2) * 4]) }
        XCTAssertTrue(host.renderOneFrame(present: false)); XCTAssertEqual(center(), 255)
        host.recreateContext()
        XCTAssertTrue(host.renderOneFrame(present: false)); XCTAssertEqual(center(), 255)
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }
}
