// ExplorerModelTests — feature 026 T-A03-104, feature 027 T-A03-204 (FR-A03-101, FR-A03-106, FR-A03-201; analyze G1).
import FractalExplorerCore
import VisualCoreMath
import VisualCoreRendering
import XCTest
@testable import FractalExplorerExperience

@MainActor
final class ExplorerModelTests: XCTestCase {
    private func hosted(_ model: ExplorerModel) throws -> RenderHost {
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        host.view.layoutIfNeeded()
        return host
    }

    func testGPUSceneIsHostedAndFollowsTheState() throws {
        let model = ExplorerModel(size: Vec2(300, 400))
        defer { model.close() }
        let host = try hosted(model)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertFalse(model.usingFallback)
        XCTAssertNil(model.preview, "no CPU preview while the GPU works")
        XCTAssertGreaterThan(model.scene.frames, 0)
        model.state.mode = .julia
        XCTAssertEqual(model.scene.snapshot.state.mode, .julia)
        XCTAssertTrue(model.explanation.contains("seed"))
        XCTAssertTrue(model.state.spokenDescription.hasPrefix("Julia set for seed −0.8 + 0.156i"))
        model.resize(to: Vec2(600, 400))
        XCTAssertEqual(model.scene.snapshot.state.viewport.size, Vec2(600, 400))
        XCTAssertEqual(model.state.viewport.center, .zero, "resize keeps the center")
        XCTAssertEqual(model.state.zoom, 1, accuracy: 1e-12, "resize keeps the zoom (width across the shorter side)")
        model.close()
        XCTAssertNil(model.host)
    }

    func testShaderFailureShowsTheCPUFallback() async throws {
        let model = ExplorerModel(size: Vec2(300, 300), fragment: "this is not GLSL")
        defer { model.close() }
        XCTAssertTrue(model.usingFallback)
        XCTAssertNotNil(model.scene.errorMessage)
        await model.waitForPreview()
        XCTAssertNotNil(model.image, "the CPU preview stands in")
        model.state.mode = .julia
        await model.waitForPreview()
        XCTAssertEqual(model.preview?.requestID, model.requestID)
    }

    func testContextLossKeepsTheView() throws {
        let model = ExplorerModel(size: Vec2(300, 400))
        defer { model.close() }
        let host = try hosted(model)
        model.state.viewport = model.state.viewport.pinched(by: 8, anchor: Vec2(100, 100))
        let view = model.state.viewport
        XCTAssertTrue(host.renderOneFrame(present: false))
        host.recreateContext()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.state.viewport, view)
        XCTAssertEqual(model.scene.snapshot.state.viewport, view)
        XCTAssertNil(model.scene.errorMessage)
    }

    func testStaleResultsAreDropped() async {
        let model = ExplorerModel(size: Vec2(300, 300))
        defer { model.close() }
        model.refresh()
        await model.waitForPreview()
        let old = FractalPreview.render(model.state, maxSide: 8, requestID: model.requestID - 1)
        model.deliver(old)
        XCTAssertEqual(model.droppedResults, 1)
        for _ in 0..<5 { model.refresh() }
        await model.waitForPreview()
        XCTAssertEqual(model.preview?.requestID, model.requestID, "only the newest request is shown")
    }
}
