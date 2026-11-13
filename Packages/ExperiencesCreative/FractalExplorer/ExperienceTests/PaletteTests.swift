// PaletteTests — feature 027 T-A03-206 (FR-A03-203, SC-A03-204; US2 AC1–AC3).
import FractalExplorerCore
import VisualCoreMath
import VisualCoreParameters
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import FractalExplorerExperience

@MainActor
final class PaletteTests: XCTestCase {
    private func hosted(_ model: ExplorerModel) throws -> RenderHost {
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 120, height: 160)
        host.view.layoutIfNeeded()
        return host
    }

    func testEachPaletteReachesTheScene() throws {
        let model = ExplorerModel(size: Vec2(120, 160), system: SystemAccessibility())
        defer { model.close() }
        let host = try hosted(model)
        for id in ExplorerModel.paletteIDs {
            model.paletteID = id
            XCTAssertTrue(host.renderOneFrame(present: false))
            let expected = try XCTUnwrap(Palette.builtIn(id)).linearStops.map { SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z)) }
            XCTAssertEqual(model.scene.inner.palette, expected, id)
        }
        model.paletteID = "mono"
        XCTAssertEqual(model.paletteID, ExplorerModel.paletteIDs.last, "unoffered palettes are refused")
    }

    func testAnimationOffFreezesAndOnMovesTheColors() throws {
        let model = ExplorerModel(size: Vec2(120, 160), system: SystemAccessibility())
        defer { model.close() }
        let host = try hosted(model)
        model.animate = false
        XCTAssertTrue(host.renderOneFrame(present: false))
        let a = try host.renderOffscreen(width: 48, height: 64, time: 0)
        for _ in 0..<60 { XCTAssertTrue(host.renderOneFrame(present: false)) }   // one second at 1/60 s
        let b = try host.renderOffscreen(width: 48, height: 64, time: 0)
        XCTAssertEqual(a.rgba, b.rgba, "animation off: identical frames 1 s apart")
        model.animate = true
        for _ in 0..<60 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        let c = try host.renderOffscreen(width: 48, height: 64, time: 0)
        XCTAssertNotEqual(b.rgba, c.rgba, "animation on: the palette moved")
    }

    func testReduceMotionDefaultsAnimationOff() {
        let calm = ExplorerModel(size: Vec2(120, 160), system: SystemAccessibility(reduceMotion: true))
        defer { calm.close() }
        XCTAssertFalse(calm.animate)
        XCTAssertFalse(calm.scene.snapshot.animate)
        calm.animate = true
        XCTAssertTrue(calm.scene.snapshot.animate, "it can still be turned on explicitly")
        let normal = ExplorerModel(size: Vec2(120, 160), system: SystemAccessibility())
        defer { normal.close() }
        XCTAssertTrue(normal.animate)
    }
}
