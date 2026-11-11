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

    func testSnapshotLabelFormat() {
        var s = DiagnosticsSnapshot()
        s.frames = 12; s.fps = 59.6; s.state = "active"; s.generation = 2; s.liveResources = 3; s.liveBytes = 1024
        s.peakBytes = 2048; s.warnings = 1; s.leaked = 0
        XCTAssertEqual(s.label, "frames=12 fps=60 state=active gen=2 live=3 bytes=1024 peak=2048 warnings=1 leaked=0 error=none")
        s.error = "boom"
        XCTAssertTrue(s.label.hasSuffix("error=boom"))
    }
}
