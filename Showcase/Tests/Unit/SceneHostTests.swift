// SceneHostTests — feature 007 T-F604 (FR-F607, FR-F608, SC-F605): diagnostics label, context loss, release.
import CVisualCoreGL
import XCTest
import VisualCoreRendering
import VisualCoreScenes
@testable import Showcase

@MainActor
final class ClearTestScene: ShowcaseRenderScene {
    var status = "clear"
    var errorMessage: String?
    var scale = 1.0
    var setups = 0
    private var buffer: GPUBuffer?
    func setup(_ c: RenderContext) throws { setups += 1; buffer = try c.resources.makeBuffer(bytes: 256, label: "probe") }
    func resize(_ c: RenderContext) {}
    func render(_ c: RenderContext, frame: FrameInfo) throws {
        vcglClearColor(0, 0, 1, 1); vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }
    func teardown(_ c: RenderContext) { if let buffer { c.resources.release(buffer) }; buffer = nil }
}

@MainActor
final class SceneHostTests: XCTestCase {
    func testDiagnosticsContextLossAndClose() throws {
        let scene = ClearTestScene()
        let sh = SceneHost(scene: scene)
        let host = try XCTUnwrap(sh.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        sh.sample()
        XCTAssertTrue(sh.snapshot.label.hasPrefix("frames="))
        XCTAssertTrue(sh.snapshot.label.hasSuffix("error=none"), sh.snapshot.label)
        XCTAssertEqual(sh.status, "clear")
        XCTAssertGreaterThanOrEqual(sh.snapshot.liveResources, 1)
        let gen = sh.snapshot.generation
        sh.simulateContextLoss()
        XCTAssertTrue(host.renderOneFrame(present: false))
        sh.sample()
        XCTAssertEqual(sh.snapshot.generation, gen + 1)
        XCTAssertEqual(scene.setups, 2, "the scene rebuilt its resources")
        XCTAssertEqual(sh.snapshot.leaked, 0)
        sh.close()
        XCTAssertEqual(sh.snapshot.state, "destroyed")
        XCTAssertEqual(sh.snapshot.leaked, 0, "teardown released everything")
    }

    // T-F615 (spec edge case): a host that cannot be created yields a visible, readable error, not a blank canvas.
    func testRenderingUnavailableIsReported() {
        struct NoRenderer: Error, CustomStringConvertible { var description: String { "no OpenGL ES 3.0 configuration" } }
        let sh = SceneHost(scene: ClearTestScene()) { _ in throw NoRenderer() }
        XCTAssertNil(sh.host)
        XCTAssertEqual(sh.unavailableMessage, "Rendering unavailable: no OpenGL ES 3.0 configuration")
        XCTAssertTrue(sh.snapshot.label.hasSuffix("error=Rendering unavailable: no OpenGL ES 3.0 configuration"))
        sh.close()
    }

    // T-F616 (FR-F607, US4 AC1): the overlay refreshes from its own timer at least twice per second.
    func testDiagnosticsRefreshAtLeastTwicePerSecond() throws {
        let scene = ClearTestScene()
        let sh = SceneHost(scene: scene)
        XCTAssertEqual(sh.status, "clear")
        var changes: [Date] = []
        let start = Date()
        for i in 1...3 {
            scene.status = "tick \(i)"
            let deadline = Date().addingTimeInterval(0.5)
            while sh.status != scene.status && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
            XCTAssertEqual(sh.status, "tick \(i)", "picked up within 0.5 s without a manual sample")
            changes.append(Date())
        }
        XCTAssertLessThan(changes.last!.timeIntervalSince(start), 1.5)
        sh.close()
    }

    func testSnapshotLabelFormat() {
        var s = DiagnosticsSnapshot()
        s.frames = 12; s.fps = 59.6; s.state = "active"; s.generation = 2; s.liveResources = 3; s.liveBytes = 1024
        s.peakBytes = 2048; s.warnings = 1; s.leaked = 0
        XCTAssertEqual(s.label, "frames=12 fps=60 state=active gen=2 live=3 bytes=1024 peak=2048 warnings=1 leaked=0 error=none")
        s.error = "boom"
        XCTAssertTrue(s.label.hasSuffix("error=boom"))
    }
}
