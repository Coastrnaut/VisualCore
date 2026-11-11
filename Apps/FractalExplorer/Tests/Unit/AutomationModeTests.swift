// AutomationModeTests — feature 030 T-A03-505/T-A03-506 (FR-A03-502, FR-A03-503; US1, US2; SC-A03-503): the app's
// automation modes run against a VisualCore runner with a recorder instead of exiting, and write complete reports.
import FractalExplorerCore
import VisualCoreAutomation
import VisualCoreMath
import VisualCoreRendering
import XCTest
@testable import FractalExplorer

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
