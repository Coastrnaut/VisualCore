// MeshRendererTests — feature 006 T-F517 (FR-F508, FR-F509; US4 independent test: a lit sphere).
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

@MainActor
final class MeshRendererTests: XCTestCase {
    private var host: RenderHost?

    func testLitSphereIsBrighterFacingTheLight() throws {
        var error = GLenum(1)
        let p = try DrawHarness.pixels(size: 64, keep: &host) { ctx in
            let r = try MeshRenderer(mesh: .uvSphere(segments: 48, rings: 24), registry: ctx.resources)
            r.lightDirection = Vec3(0, 0, 1)   // from the camera
            try r.draw(camera: OrbitCamera(distance: 3), aspect: 1, color: Vec4(1, 1, 1, 1))
            error = vcglGetError()
        }
        XCTAssertEqual(error, GLenum(GL_NO_ERROR))
        let center = DrawHarness.px(p, 64, 32, 32).x
        let limb = DrawHarness.px(p, 64, 32 + 17, 32).x     // near the edge: projected radius = tan(asin(1/3)) / tan(30°) × 32 ≈ 19.6 px
        let outside = DrawHarness.px(p, 64, 2, 2)
        XCTAssertGreaterThan(center, 240, "facing the light")
        XCTAssertLessThan(limb, center - 60, "grazing light at the limb is darker (\(limb) vs \(center))")
        XCTAssertGreaterThan(limb, 20, "still inside the sphere")
        XCTAssertEqual(outside, SIMD4(0, 0, 0, 255), "background outside")
    }

    func testCubeModelTransformAndAmbient() throws {
        let p = try DrawHarness.pixels(size: 32, keep: &host) { ctx in
            let r = try MeshRenderer(mesh: .cube(), registry: ctx.resources)
            r.lightDirection = Vec3(0, 0, -1)   // light from behind: only ambient on the front face
            r.ambient = 0.5
            try r.draw(model: .translation(Vec3(0.6, 0, 0)), camera: OrbitCamera(distance: 4), aspect: 1, color: Vec4(1, 0, 0, 1))
        }
        XCTAssertEqual(DrawHarness.px(p, 32, 20, 16).x, 128, accuracy: 2, "ambient-only front face, shifted right")
        XCTAssertEqual(DrawHarness.px(p, 32, 8, 16).x, 0, "left side empty")
    }

    func testRecreationAndTeardown() throws {
        final class Scene: RenderScene {
            var renderer: MeshRenderer?
            func setup(_ c: RenderContext) throws { renderer = try MeshRenderer(mesh: .uvSphere(), registry: c.resources) }
            func resize(_ c: RenderContext) {}
            func render(_ c: RenderContext, frame: FrameInfo) throws {
                vcglClearColor(0, 0, 0, 1); vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
                renderer?.lightDirection = Vec3(0, 0, 1)
                try renderer?.draw(camera: OrbitCamera(distance: 3), aspect: Double(c.pixelWidth) / Double(c.pixelHeight), color: Vec4(0, 1, 0, 1))
            }
            func teardown(_ c: RenderContext) { renderer?.release(); renderer = nil }
        }
        let host = try RenderHost(scene: Scene())
        host.view.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        host.view.layoutIfNeeded()
        let w = host.pixelSize.width, h = host.pixelSize.height
        func center() -> Int { Int(host.readPixels()[((h / 2) * w + w / 2) * 4 + 1]) }
        XCTAssertTrue(host.renderOneFrame(present: false)); XCTAssertGreaterThan(center(), 200)
        host.recreateContext()
        XCTAssertTrue(host.renderOneFrame(present: false)); XCTAssertGreaterThan(center(), 200)
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }
}
