// CostAndCapTests — feature 029 T-A03-406 (FR-A03-404, SC-A03-401; US1 AC1–AC3).
import FractalExplorerCore
import VisualCoreMath
import XCTest
@testable import FractalExplorerExperience

@MainActor
final class CostAndCapTests: XCTestCase {
    private func model() -> ExplorerModel {
        let m = ExplorerModel(size: Vec2(390, 844),
                              bookmarksDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("fe-cost-\(UUID().uuidString)"))
        m.pixelsPerPointOverride = 3
        return m
    }

    func testCostFollowsTheCapAndReachesTheScene() {
        let m = model()
        defer { m.close() }
        XCTAssertEqual(m.costText, "Render cost: 1× the default view (light)")
        m.doubleCap()
        XCTAssertEqual(m.cap, 400)
        XCTAssertEqual(m.costText, "Render cost: 2× the default view (light)")
        XCTAssertEqual(m.scene.snapshot.state.iterationCap, 400, "the new cap reaches the shader")
        XCTAssertTrue(m.canvasDescription.hasSuffix("400 iterations"))
        m.cap = 10_000
        XCTAssertEqual(m.costText, "Render cost: 50× the default view (heavy); may be slow on this device")
        m.halveCap(); m.halveCap(); m.halveCap(); m.halveCap(); m.halveCap(); m.halveCap(); m.halveCap(); m.halveCap()
        XCTAssertEqual(m.cap, 50)
        XCTAssertEqual(m.costText, "Render cost: 0.25× the default view (light)")
    }

    func testCostIsRelativeToTheSameCanvas() {
        let m = model()
        defer { m.close() }
        m.cap = 1_000
        let before = m.costText
        m.resize(to: Vec2(1024, 1366))
        XCTAssertEqual(m.costText, before, "the ratio is against the default cap on the same canvas")
        XCTAssertEqual(m.costText, "Render cost: 5× the default view (moderate)")
    }
}
