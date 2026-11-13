// AutomationModeTests — feature 030 T-A03-505/T-A03-506 (FR-A03-502, FR-A03-503; US1, US2; SC-A03-503): the app's
// automation modes run against a VisualCore runner with a recorder instead of exiting, and write complete reports.
import FractalExplorerCore
import VisualCoreAutomation
import VisualCoreMath
import VisualCoreRendering
import XCTest
@testable import FractalExplorerExperience

@MainActor
final class AutomationModeTests: XCTestCase {
    private var dir: URL!
    private var codes: [Int32] = []
    private var host: RenderHost!
    private var model: ExplorerModel!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("fe-automation-\(UUID().uuidString)")
        codes = []
        model = AppAutomation.makeModel()
        host = try RenderHost(scene: model.scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.layoutIfNeeded()
    }

    override func tearDown() async throws {
        host.destroy()
        try? FileManager.default.removeItem(at: dir)
    }

    private func runner() -> AutomationRunner {
        let r = AutomationRunner(host: host, bundleID: "dev.visualcore.FractalExplorer", outputDirectory: dir) { [weak self] in self?.codes.append($0) }
        let m = model!
        r.postRunCheck = { AppAutomation.check(m) }
        r.appModes = AppAutomation.appModes(m).mapValues { mode in { host, report, frames in mode(m.scene, host, &report, frames) } }
        return r
    }

    func testPrecisionModeWritesACompleteReport() throws {
        let r = runner()
        let report = r.run(mode: "precision")
        XCTAssertEqual(report.result, "pass", report.message ?? "")
        let m = try XCTUnwrap(report.measurements)
        for key in ["highpBits", "mediumpBits", "mantissaBitsUsed", "maxRenderSize", "steps", "clampStep", "breakdownStep",
                    "clampZoom", "breakdownZoom", "minReliableAgreement", "pixelsPerPoint"] {
            XCTAssertNotNil(m[key], key)
        }
        XCTAssertGreaterThan(m["steps"] ?? 0, 10)
        XCTAssertGreaterThanOrEqual(m["minReliableAgreement"] ?? 0, 0.99)
        XCTAssertNotNil(report.details?["ladder"])
        XCTAssertTrue(report.details?["fallback"]?.hasPrefix("Shader precision: ") == true)
        XCTAssertEqual(codes, [0])
        let decoded = try JSONDecoder().decode(AutomationReport.self, from: Data(contentsOf: try XCTUnwrap(r.lastReportURL)))
        XCTAssertEqual(decoded, report)
        print("precision rehearsal (simulator, not device evidence): \(m) \(report.details ?? [:])")
    }

    func testBuiltInSmokeRunsTheExplorerScene() {
        let report = runner().run(mode: "smoke", frames: 10)
        XCTAssertEqual(report.result, "pass", report.message ?? "")
        XCTAssertEqual(report.frames, 10)
    }
}

// Feature 030 T-A03-506 (FR-A03-503; US2): the tour mode with a frame cap (as VISUALCORE_AUTORUN_FRAMES would give).
@MainActor
final class TourModeTests: XCTestCase {
    func testTourModeCapturesEveryStopAndLeavesNoFile() throws {
        let model = AppAutomation.makeModel()
        let host = try RenderHost(scene: model.scene)
        defer { host.destroy() }
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.layoutIfNeeded()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fe-tour-mode-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        var codes: [Int32] = []
        let runner = AutomationRunner(host: host, bundleID: "dev.visualcore.FractalExplorer", outputDirectory: dir) { codes.append($0) }
        runner.appModes = AppAutomation.appModes(model, tourFrameCap: 30)
            .mapValues { mode in { host, report, frames in mode(model.scene, host, &report, frames) } }
        let report = runner.run(mode: "tour")
        XCTAssertEqual(report.result, "pass", report.message ?? "")
        XCTAssertEqual(codes, [0])
        XCTAssertEqual(report.frames, 90, "30 frames per tour")
        XCTAssertNotNil(report.frameTimeMs)
        let m = try XCTUnwrap(report.measurements)
        XCTAssertEqual(m["tours"], 3)
        XCTAssertEqual(m["stops"], 9, "every stop is captured even when the frames are capped")
        XCTAssertGreaterThanOrEqual(m["minStopAgreement"] ?? 0, 0.99)
        XCTAssertEqual(m["captureLongEdge"], 1024)
        for key in ["thermalStart", "thermalEnd", "lowPowerStart", "lowPowerEnd", "agreement.seahorse", "agreement.elephant", "agreement.mini"] {
            XCTAssertNotNil(report.details?[key], key)
        }
        XCTAssertEqual(StillCapture.folder(named: "AutomationCaptures").fileCount, 0)
        print("tour rehearsal (simulator, not device evidence): \(m) \(report.frameTimeMs.map { "\($0)" } ?? "")")
    }
}
