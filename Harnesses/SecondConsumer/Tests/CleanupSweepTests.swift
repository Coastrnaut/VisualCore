// CleanupSweepTests — feature 010 T-F906 (FR-F907): Lumen Garden (the garden scene inside its EffectScene glow, as the
// app runs it) goes through setup → frames → context loss → frames → destroy with zero leaked GPU resources.
import XCTest
import VisualCoreEffects
import VisualCoreRendering
@testable import SecondConsumer

@MainActor
final class CleanupSweepTests: XCTestCase {
    private func sweep(_ scene: RenderScene, id: String) throws {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 120, height: 200)
        host.view.layoutIfNeeded()
        for _ in 0..<10 { XCTAssertTrue(host.renderOneFrame(present: false), id) }
        host.recreateContext()
        for _ in 0..<10 { XCTAssertTrue(host.renderOneFrame(present: false), id) }
        XCTAssertEqual(host.resources.stats.leaked, 0, "\(id): after context loss")
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 0, "\(id): after destroy")
    }

    func testGardenSceneReleasesEverything() throws {
        try sweep(GardenScene(), id: "garden")
    }

    func testGardenWithGlowReleasesEverything() throws {
        let effect = EffectScene(content: GardenScene(), graph: GardenModel.glow)
        effect.reduceFlashing = true
        try sweep(effect, id: "garden+glow")
        XCTAssertNil(effect.lastError)
    }
}
