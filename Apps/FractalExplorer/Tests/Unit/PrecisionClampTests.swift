// PrecisionClampTests — feature 027 T-A03-207 (FR-A03-206, SC-A03-203; US4 AC1–AC3).
import FractalExplorerCore
import VisualCoreRendering
import VisualCoreMath
import XCTest
@testable import FractalExplorer

@MainActor
final class PrecisionClampTests: XCTestCase {
    private func model(bits: Int?) -> ExplorerModel {
        let m = ExplorerModel(size: Vec2(300, 400))
        m.close()
        m.mantissaBitsOverride = bits
        m.pixelsPerPointOverride = 3
        return m
    }

    func testRepeatedZoomInsStopAtTheClampWithNearAndReachedStates() {
        let m = model(bits: 23)
        var states: [ExplorerModel.PrecisionNotice] = []
        var lastZoom = 0.0
        for _ in 0..<60 {
            m.zoomIn()
            if states.last != m.notice { states.append(m.notice) }
            lastZoom = m.state.zoom
        }
        XCTAssertEqual(states, [.none, .near, .reached])
        // At |center| = 0.5 and 23 bits the smallest pixel step is 0.5 * 2^-23; the plane width across 300 pt at 3 px/pt:
        let minUnitsPerPoint = 0.5 / 8_388_608.0 * 3
        XCTAssertEqual(m.state.viewport.unitsPerPoint, minUnitsPerPoint, accuracy: minUnitsPerPoint * 1e-12)
        m.zoomIn()
        XCTAssertEqual(m.state.zoom, lastZoom, "zoom stops at the limit")
        XCTAssertEqual(m.notice.text, "Precision limit reached — zoom stops here")
        XCTAssertTrue(m.canvasDescription.hasSuffix("Precision limit reached — zoom stops here"))
        XCTAssertEqual(m.announcements, ["Near precision limit — details may blur", "Precision limit reached — zoom stops here"],
                       "one announcement per state change, not per zoom")
        m.zoomOut(); m.zoomOut(); m.zoomOut(); m.zoomOut(); m.zoomOut()
        XCTAssertEqual(m.notice, .none, "the banner goes away when reliable again")
        XCTAssertEqual(m.canvasDescription, m.state.spokenDescription)
    }

    func testFewerBitsClampEarlier() {
        let deep = model(bits: 23), shallow = model(bits: 10)
        for _ in 0..<60 { deep.zoomIn(); shallow.zoomIn() }
        XCTAssertGreaterThan(deep.state.zoom, shallow.state.zoom * 1000)
    }

    func testFallbackBitsWithoutAHost() {
        let m = model(bits: nil)
        XCTAssertNil(m.host)
        XCTAssertEqual(m.mantissaBits, 10, "no host: the conservative mediump assumption")
    }

    func testPinchCannotPassTheLimit() {
        let m = model(bits: 10)
        for _ in 0..<30 { m.apply(m.state.viewport.pinched(by: 10, anchor: Vec2(150, 200))) }
        XCTAssertEqual(m.notice, .reached)
        let minUnitsPerPoint = PrecisionAdvisor.minimumPixelStep(mantissaBits: 10, magnitude: max(abs(m.state.viewport.center.x), abs(m.state.viewport.center.y))) * 3
        XCTAssertGreaterThanOrEqual(m.state.viewport.unitsPerPoint, minUnitsPerPoint * (1 - 1e-12))
    }
}

// Feature 027 T-A03-209 (US4 AC3): the precision source and the fallback reason.
@MainActor
final class PrecisionSourceTests: XCTestCase {
    typealias P = RenderCapabilities.ShaderPrecision

    func testHighpMediumpAndNoReport() {
        XCTAssertEqual(ExplorerModel.precisionSource(highp: P(rangeMin: 127, rangeMax: 127, precisionBits: 23),
                                                     mediump: P(rangeMin: 15, rangeMax: 15, precisionBits: 10)),
                       "Shader precision: highp, 23 bits")
        XCTAssertEqual(ExplorerModel.precisionSource(highp: P(rangeMin: 0, rangeMax: 0, precisionBits: 0),
                                                     mediump: P(rangeMin: 15, rangeMax: 15, precisionBits: 10)),
                       "Shader precision: mediump, 10 bits — the graphics driver reported no usable highp floats")
        XCTAssertEqual(ExplorerModel.precisionSource(highp: nil, mediump: nil),
                       "Shader precision: assumed 10 bits — the graphics driver reported no usable highp or mediump float precision")
    }

    func testTheHostedModelReportsItsSource() {
        let m = ExplorerModel(size: Vec2(300, 400))
        defer { m.close() }
        if m.host == nil {
            XCTAssertTrue(m.precisionSource.hasPrefix("Shader precision: assumed 10 bits"))
        } else {
            XCTAssertTrue(m.precisionSource.hasPrefix("Shader precision: "), m.precisionSource)
            XCTAssertTrue(m.precisionSource.contains("\(m.mantissaBits) bits"), m.precisionSource)
        }
    }
}
