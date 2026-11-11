// SceneRenderTests — feature 007 hosted pixel tests per scene (analyze remediation U1).
import CVisualCoreGL
import XCTest
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreEffects
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

@MainActor
final class DistortionTests: XCTestCase {
    func testRippleFollowsTouchAndLeavesFarPixels() throws {
        let scene = DistortionScene(settings: SceneTestSupport.settings(reduceMotion: true))
        let r = try SceneTestSupport.render(scene, frames: 1, size: CGSize(width: 64, height: 64))
        scene.scale = Double(r.width) / 64
        XCTAssertNil(scene.errorMessage)
        XCTAssertEqual(scene.status, "touch=none")
        let before = r.host.readPixels()
        scene.handle(PointerEvent(id: 1, phase: .began, location: Vec2(32, 32), timestamp: 0))
        scene.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(20, 40), timestamp: 0.1))
        XCTAssertEqual(scene.status, "touch=20,40")
        XCTAssertEqual(scene.strength, 1)
        _ = r.host.renderOneFrame(present: false)
        let after = r.host.readPixels()
        // Compare a ring around the touch (view point (20, 40) → pixels, rows bottom-up) and a far corner.
        let s = Double(r.width) / 64
        let cx = Int(20 * s), cy = r.height - Int(40 * s)
        var changed = 0
        for dy in stride(from: -Int(10 * s), through: Int(10 * s), by: 2) {
            for dx in stride(from: -Int(10 * s), through: Int(10 * s), by: 2) {
                let x = cx + dx, y = cy + dy
                guard x >= 0, y >= 0, x < r.width, y < r.height else { continue }
                if SceneTestSupport.px(before, r.width, x, y) != SceneTestSupport.px(after, r.width, x, y) { changed += 1 }
            }
        }
        XCTAssertGreaterThan(changed, 10, "pixels near the finger are displaced")
        XCTAssertEqual(SceneTestSupport.px(before, r.width, r.width - 2, 1), SceneTestSupport.px(after, r.width, r.width - 2, 1),
                       "the far corner is unchanged")
        scene.handle(PointerEvent(id: 1, phase: .ended, location: Vec2(20, 40), timestamp: 0.2))
        XCTAssertEqual(scene.status, "touch=none")
        r.host.destroy()
        XCTAssertEqual(r.host.resources.stats.leaked, 0)
    }
}

@MainActor
final class ParticleSceneTests: XCTestCase {
    func testDragSpawnsAndPinchZooms() throws {
        let scene = ParticleShowcaseScene(settings: SceneTestSupport.settings())
        let r = try SceneTestSupport.render(scene, frames: 1, size: CGSize(width: 64, height: 64))
        scene.scale = Double(r.width) / 64
        XCTAssertNil(scene.errorMessage)
        XCTAssertEqual(scene.particleCount, 0)
        scene.handle(PointerEvent(id: 1, phase: .began, location: Vec2(32, 32), timestamp: 0))
        scene.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(40, 30), timestamp: 0.1))
        for _ in 0..<5 { _ = r.host.renderOneFrame(present: false) }
        XCTAssertGreaterThan(scene.particleCount, 0)
        XCTAssertTrue(scene.status.hasPrefix("particles="))
        scene.handle(PointerEvent(id: 1, phase: .ended, location: Vec2(40, 30), timestamp: 0.2))
        scene.handle(PointerEvent(id: 2, phase: .began, location: Vec2(22, 32), timestamp: 1))
        scene.handle(PointerEvent(id: 3, phase: .began, location: Vec2(42, 32), timestamp: 1))
        scene.handle(PointerEvent(id: 3, phase: .moved, location: Vec2(52, 32), timestamp: 1.1))
        scene.handle(PointerEvent(id: 2, phase: .moved, location: Vec2(12, 32), timestamp: 1.2))
        XCTAssertGreaterThan(scene.camera.zoom, 1.5, "pinch from 20 to 40 pt doubles the zoom")
        r.host.destroy()
        XCTAssertEqual(r.host.resources.stats.leaked, 0)
    }
}

@MainActor
final class PostProcessingTests: XCTestCase {
    private func meanAbsDiff(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return .infinity }
        return Double(zip(a, b).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }) / Double(a.count)
    }

    func testEffectChangesOutputAndOffMatchesContent() throws {
        let settings = SceneTestSupport.settings(reduceMotion: true)
        settings.reduceFlashing = false
        let scene = PostProcessingScene(settings: settings)
        let r = try SceneTestSupport.render(scene, frames: 2)
        XCTAssertNil(scene.errorMessage)
        XCTAssertEqual(scene.status, "passes=grade>glow>wave")
        XCTAssertEqual(scene.effect.renderer?.lastOrder, ["grade", "glow", "wave"])
        let on = r.host.readPixels()
        scene.effectsEnabled = false
        _ = r.host.renderOneFrame(present: false); _ = r.host.renderOneFrame(present: false)
        XCTAssertEqual(scene.status, "passes=off")
        let off = r.host.readPixels()
        let reference = try SceneTestSupport.render(AnimatedGeometryScene(settings: settings), frames: 2)
        XCTAssertGreaterThan(meanAbsDiff(on, off), 2, "the effect visibly changes the image")
        XCTAssertLessThan(meanAbsDiff(off, reference.pixels), 0.5, "effect off shows the content unchanged")
        scene.effectsEnabled = true
        _ = r.host.renderOneFrame(present: false)
        XCTAssertEqual(scene.status, "passes=grade>glow>wave", "toggling back restores the graph")
        r.host.destroy(); reference.host.destroy()
        XCTAssertEqual(r.host.resources.stats.leaked, 0)
    }

    func testReduceFlashingAppendsLimiter() throws {
        let settings = SceneTestSupport.settings()
        settings.reduceFlashing = true
        let scene = PostProcessingScene(settings: settings)
        let r = try SceneTestSupport.render(scene, frames: 2)
        XCTAssertEqual(scene.status, "passes=grade>glow>wave>\(EffectScene.flashLimitPassID)")
        r.host.destroy()
    }
}
