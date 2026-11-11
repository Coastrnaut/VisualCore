// ExplorerModelTests — feature 026 T-A03-104 (FR-A03-101, FR-A03-106; US1, US4).
import FractalExplorerCore
import VisualCoreMath
import XCTest
@testable import FractalExplorer

@MainActor
final class ExplorerModelTests: XCTestCase {
    func testDefaultStateAndPreview() async {
        let model = ExplorerModel(size: Vec2(300, 300))
        XCTAssertEqual(model.state.mode, .mandelbrot)
        await model.waitForPreview()
        let p = try? XCTUnwrap(model.preview)
        XCTAssertEqual(p?.width, 160)
        XCTAssertNotNil(model.image)
        XCTAssertTrue(model.explanation.contains("Mandelbrot"))
    }

    func testModeSwitchUpdatesExplanationDescriptionAndPreview() async {
        let model = ExplorerModel(size: Vec2(300, 300))
        await model.waitForPreview()
        let mandelbrot = model.preview?.rgba
        model.state.mode = .julia
        XCTAssertTrue(model.explanation.contains("seed"))
        XCTAssertTrue(model.state.spokenDescription.hasPrefix("Julia set for seed −0.8 + 0.156i"))
        await model.waitForPreview()
        XCTAssertNotEqual(model.preview?.rgba, mandelbrot, "a different picture")
    }

    func testStaleResultsAreDropped() async {
        let model = ExplorerModel(size: Vec2(300, 300))
        await model.waitForPreview()
        let old = FractalPreview.render(model.state, maxSide: 8, requestID: model.requestID - 1)
        model.deliver(old)
        XCTAssertEqual(model.droppedResults, 1)
        XCTAssertNotEqual(model.preview?.requestID, old.requestID)
        for _ in 0..<5 { model.state.iterationCap += 10 }   // five quick requests
        await model.waitForPreview()
        XCTAssertEqual(model.preview?.requestID, model.requestID, "only the newest request is shown")
    }
}
