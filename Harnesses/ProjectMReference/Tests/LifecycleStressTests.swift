// LifecycleStressTests — feature 008 T-F709 (US4, FR-F707, SC-F703): repeated suspend/resume, resizes and context
// recreations with the unmodified engine on the VisualCore host; continuous rendering, one engine per context
// generation, zero leaked VisualCore resources, engine released before its context.
import VisualCoreRendering
import XCTest
@testable import ProjectMReference

@MainActor
final class LifecycleStressTests: XCTestCase {
    private func renders(_ host: RenderHost, _ frames: Int = 2) -> Bool {
        (0..<frames).allSatisfy { _ in host.renderOneFrame(present: false) } && ImageDiff.litFraction(host.readPixels()) > 0.01
    }

    func testSuspendResumeResizeAndRecreation() throws {
        let scene = ProjectMScene(presetPath: HarnessSupport.preset("100-square.milk"))
        let host = try HarnessSupport.host(scene)
        XCTAssertTrue(renders(host, 5))
        // 20 suspend/resume cycles: the engine survives (no recreation) and keeps rendering.
        for i in 0..<20 {
            host.pause()
            XCTAssertEqual(host.state, .suspended, "cycle \(i)")
            host.resume()
            XCTAssertTrue(renders(host), "renders after resume \(i)")
        }
        XCTAssertEqual(scene.enginesCreated, 1, "suspend/resume keeps the engine")
        // 10 resizes, including rotation-like aspect swaps.
        let sizes: [(CGFloat, CGFloat)] = [(80, 40), (40, 80), (64, 64), (120, 60), (60, 120), (33, 77), (77, 33), (64, 48), (48, 64), (64, 64)]
        for (w, h) in sizes {
            host.view.frame = CGRect(x: 0, y: 0, width: w, height: h)
            host.view.layoutIfNeeded()
            XCTAssertTrue(renders(host), "renders at \(w)×\(h)")
            XCTAssertEqual(scene.viewports.last?.width, host.pixelSize.width)
            XCTAssertEqual(scene.viewports.last?.height, host.pixelSize.height)
        }
        // 3 context recreations: one new engine per generation.
        for i in 1...3 {
            host.recreateContext()
            XCTAssertTrue(renders(host), "renders after recreation \(i)")
            XCTAssertEqual(scene.engineGeneration, host.generation)
            XCTAssertEqual(host.resources.stats.leaked, 0, "no VisualCore leak after recreation \(i)")
        }
        XCTAssertEqual(scene.enginesCreated, 4, "1 initial + 3 recreations")
        XCTAssertNil(scene.lastError)
        // Destroy: engine released (in teardown, context current) and nothing leaked.
        host.destroy()
        XCTAssertFalse(scene.hasEngine)
        XCTAssertEqual(host.state, .destroyed)
        XCTAssertEqual(host.resources.stats.leaked, 0)
        XCTAssertGreaterThanOrEqual(scene.frames, 5 + 20 * 2 + 10 * 2 + 3 * 2)
    }
}
