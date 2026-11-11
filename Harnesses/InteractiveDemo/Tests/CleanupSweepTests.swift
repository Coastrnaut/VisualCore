// CleanupSweepTests — feature 010 T-F906 (FR-F907): the InteractiveDemo scene goes through setup → frames (with
// spawned particles) → context loss → frames → destroy with zero leaked GPU resources.
import XCTest
import VisualCoreRendering
@testable import InteractiveDemo

@MainActor
final class CleanupSweepTests: XCTestCase {
    func testDemoSceneReleasesEverything() throws {
        let scene = DemoScene(model: DemoModel())
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 120, height: 200)
        host.view.layoutIfNeeded()
        for _ in 0..<10 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        host.recreateContext()
        for _ in 0..<10 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(host.resources.stats.leaked, 0, "after context loss")
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 0, "after destroy")
    }
}
