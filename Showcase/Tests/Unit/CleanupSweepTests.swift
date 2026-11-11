// CleanupSweepTests — feature 010 T-F906 (FR-F907): every Showcase scene goes through setup → frames → context loss
// → frames → destroy with zero leaked GPU resources, with and without Reduce Flashing / post-processing.
import XCTest
import VisualCoreRendering
@testable import Showcase

@MainActor
final class CleanupSweepTests: XCTestCase {
    private func sweep(_ scene: ShowcaseRenderScene, id: String) throws {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 64, height: 48)
        host.view.layoutIfNeeded()
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false), "\(id) frame before loss") }
        let generation = host.resources.generation
        host.recreateContext()
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false), "\(id) frame after loss") }
        XCTAssertEqual(host.resources.generation, generation + 1, id)
        XCTAssertEqual(host.resources.stats.leaked, 0, "\(id): leaked after context loss")
        XCTAssertNil(scene.errorMessage, id)
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 0, "\(id): leaked after destroy")
    }

    func testEveryCatalogSceneReleasesEverything() throws {
        XCTAssertGreaterThanOrEqual(SceneCatalog.all.count, 5)
        for descriptor in SceneCatalog.all {
            try sweep(descriptor.make(SceneTestSupport.settings()), id: descriptor.id)
        }
    }

    func testEveryCatalogSceneReleasesEverythingWithReduceFlashingAndEffectsToggled() throws {
        for descriptor in SceneCatalog.all {
            let settings = SceneTestSupport.settings(reduceMotion: true)
            settings.reduceFlashing = true
            var scene = descriptor.make(settings)
            if let on = scene.effectsEnabled { scene.effectsEnabled = !on }
            try sweep(scene, id: descriptor.id + "+flashing")
        }
    }

    /// Control: the sweep's leak accounting really sees a scene that forgets to release a buffer.
    func testSweepDetectsALeakingScene() throws {
        final class LeakyScene: ShowcaseRenderScene {
            var status = "leaky"; var errorMessage: String?; var scale = 1.0
            private var buffer: GPUBuffer?
            func setup(_ c: RenderContext) throws { buffer = try c.resources.makeBuffer(bytes: 64, label: "leak") }
            func resize(_ c: RenderContext) {}
            func render(_ c: RenderContext, frame: FrameInfo) throws {}
            func teardown(_ c: RenderContext) {}   // forgets to release
        }
        let host = try RenderHost(scene: LeakyScene())
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 1)
    }
}
