// QualityWiringTests — feature 021 T-A02-308 (FR-A02-308; US4 AC1–AC3; edge case "tier change mid-stroke").
import FluidArtPlaygroundCore
import VisualCoreDiagnostics
import VisualCoreRendering
import XCTest
@testable import FluidArtPlayground

@MainActor
final class QualityWiringTests: XCTestCase {
    private final class Device {
        var thermal = FramePacing.Thermal.nominal
        var lowPower = false
        var now = 0.0
    }

    private func makeModel(_ device: Device) throws -> (PlaygroundModel, RenderHost) {
        let model = PlaygroundModel()
        model.deviceState = { (device.thermal, device.lowPower) }
        model.clock = { device.now }
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        host.view.layoutIfNeeded()
        model.scene.fixedDelta = 1.0 / 60
        return (model, host)
    }

    func testHotDeviceLowersIterationsFirstThenSplats() throws {
        let device = Device()
        let (model, host) = try makeModel(device)
        defer { model.close() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.tierName, "Full")
        XCTAssertEqual(model.scene.lastPressureIterations, 20)

        device.thermal = .serious
        device.now = 1
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.tierName, "Reduced")
        XCTAssertEqual(model.scene.lastPressureIterations, 10, "iterations drop first")

        // Mid-stroke: 20 splashes queued, then the next tier halves the splat cap; the queue is drained, not cleared.
        for _ in 0..<20 { model.addSplash() }
        device.now = 3.5
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.tierName, "Minimal")
        XCTAssertEqual(model.scene.lastPressureIterations, 5)
        XCTAssertEqual(model.scene.lastDrained, 8, "splat cap halved only at Minimal")
        XCTAssertNil(model.scene.lastError)
    }

    func testRecoveryAfterCalmAndLowPowerCeiling() throws {
        let device = Device()
        let (model, host) = try makeModel(device)
        defer { model.close() }
        device.lowPower = true
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.tierName, "Reduced", "Low Power ceiling")
        device.now = 40
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.tierName, "Reduced", "never above the ceiling while Low Power is on")
        device.lowPower = false
        device.now = 41
        XCTAssertTrue(host.renderOneFrame(present: false))
        device.now = 51
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.tierName, "Full", "10 s of calm steps back up")
        XCTAssertEqual(model.scene.lastPressureIterations, 20)
    }

    func testUserIterationsAreTheUpperBound() throws {
        let device = Device()
        let (model, host) = try makeModel(device)
        defer { model.close() }
        var c = model.configuration
        c.pressureIterations = 6
        model.configuration = c
        device.thermal = .critical
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.scene.lastPressureIterations, 3)
    }
}
