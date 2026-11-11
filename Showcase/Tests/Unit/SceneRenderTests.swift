// SceneRenderTests — feature 007 hosted pixel tests per scene (analyze remediation U1).
import CVisualCoreGL
import XCTest
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
@testable import Showcase

@MainActor
enum SceneTestSupport {
    /// Renders `frames` frames of a scene in a 64×32-point host and returns (pixels bottom-up, width, height, host).
    static func render(_ scene: ShowcaseRenderScene, frames: Int = 2, size: CGSize = CGSize(width: 64, height: 32)) throws
        -> (pixels: [UInt8], width: Int, height: Int, host: RenderHost) {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutIfNeeded()
        for _ in 0..<frames { _ = host.renderOneFrame(present: false) }
        return (host.readPixels(), host.pixelSize.width, host.pixelSize.height, host)
    }

    static func px(_ p: [UInt8], _ w: Int, _ x: Int, _ y: Int) -> SIMD4<Int> {
        let i = (y * w + x) * 4
        return SIMD4(Int(p[i]), Int(p[i + 1]), Int(p[i + 2]), Int(p[i + 3]))
    }

    static func settings(injectShaderError: Bool = false, reduceMotion: Bool = false) -> ShowcaseSettings {
        let d = UserDefaults(suiteName: "showcase.tests.\(UUID().uuidString)")!
        d.set(reduceMotion, forKey: "uitestReduceMotion")
        d.set(injectShaderError, forKey: "showcaseInjectShaderError")
        return ShowcaseSettings(defaults: d)
    }
}

@MainActor
final class SceneRenderTests: XCTestCase {
    func testGradientAndCheckerTextureAreVisible() throws {
        let scene = GradientTextureScene(settings: SceneTestSupport.settings())
        let r = try SceneTestSupport.render(scene)
        XCTAssertNil(scene.errorMessage)
        XCTAssertEqual(scene.status, "shader=gradient.frag texture=64x64")
        // Left half: saturated hue gradient.
        let left = SceneTestSupport.px(r.pixels, r.width, r.width / 4, r.height / 2)
        XCTAssertGreaterThan(max(left.x, left.y, left.z) - min(left.x, left.y, left.z), 100, "saturated color \(left)")
        // Right half: alternating light and dark checker cells along a row.
        let row = (r.width / 2 + 2..<r.width - 2).map { SceneTestSupport.px(r.pixels, r.width, $0, r.height / 2).x }
        XCTAssertTrue(row.contains { $0 > 200 } && row.contains { $0 < 70 }, "checker light and dark cells present")
        r.host.destroy()
        XCTAssertEqual(r.host.resources.stats.leaked, 0)
    }

    func testInjectedShaderErrorNamesFileAndLineAndRetryRecovers() throws {
        let scene = GradientTextureScene(settings: SceneTestSupport.settings(injectShaderError: true))
        let r = try SceneTestSupport.render(scene)
        let message = try XCTUnwrap(scene.errorMessage)
        XCTAssertTrue(message.hasPrefix("broken.frag:5:"), message)
        scene.retry()
        _ = r.host.renderOneFrame(present: false)
        XCTAssertNil(scene.errorMessage)
        XCTAssertEqual(scene.status, "shader=gradient.frag texture=64x64")
        r.host.destroy()
    }
}

@MainActor
final class AnimatedGeometryTests: XCTestCase {
    func testMeshesRenderAndAnimate() throws {
        let scene = AnimatedGeometryScene(settings: SceneTestSupport.settings())
        let r = try SceneTestSupport.render(scene, frames: 1)
        XCTAssertNil(scene.errorMessage)
        // Sample where the object centers project with the scene's camera (distance 6, pitch 0.25).
        let cam = OrbitCamera(distance: 6, pitch: 0.25), aspect = Double(r.width) / Double(r.height)
        func at(_ p: Vec3) -> SIMD4<Int> {
            let n = cam.project(p, aspect: aspect)
            return SceneTestSupport.px(r.pixels, r.width, Int((n.x + 1) / 2 * Double(r.width)), Int((n.y + 1) / 2 * Double(r.height)))
        }
        let cube = at(Vec3(-1.6, 0, 0)), sphere = at(Vec3(1.6, 0, 0))
        XCTAssertGreaterThan(cube.z, cube.x, "blue cube on the left \(cube)")
        XCTAssertGreaterThan(sphere.x, sphere.z, "orange sphere on the right \(sphere)")
        let spin0 = scene.spin
        for _ in 0..<10 { _ = r.host.renderOneFrame(present: false) }
        XCTAssertNotEqual(scene.spin, spin0, "the timeline advances")
        r.host.destroy()
        XCTAssertEqual(r.host.resources.stats.leaked, 0)
    }

    func testReduceMotionStopsSpinAndDragOrbits() throws {
        let scene = AnimatedGeometryScene(settings: SceneTestSupport.settings(reduceMotion: true))
        let r = try SceneTestSupport.render(scene, frames: 1)
        let spin0 = scene.spin
        for _ in 0..<10 { _ = r.host.renderOneFrame(present: false) }
        XCTAssertEqual(scene.spin, spin0)
        XCTAssertTrue(scene.status.hasSuffix("spin=off"))
        let yaw0 = scene.status
        scene.handle(PointerEvent(id: 1, phase: .began, location: Vec2(10, 10), timestamp: 0))
        scene.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(40, 10), timestamp: 0.1))
        scene.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(90, 10), timestamp: 0.2))
        XCTAssertNotEqual(scene.status, yaw0, "drag orbits the camera")
        r.host.destroy()
    }
}
