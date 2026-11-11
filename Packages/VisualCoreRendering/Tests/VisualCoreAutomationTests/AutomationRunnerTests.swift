// AutomationRunnerTests — feature 010 T-F903 (FR-F914, SC-F905): every mode writes a schema-1 report and terminates
// with the right code; unknown modes error out instead of hanging. Runs in Debug (DEBUG is set for tests).
import Foundation
import XCTest
@testable import VisualCoreAutomation
import VisualCoreRendering

@MainActor
final class AutomationRunnerTests: XCTestCase {
    private var host: RenderHost!
    private var dir: URL!
    private var codes: [Int32] = []

    override func setUp() async throws {
        host = try RenderHost(scene: ClearColorScene(red: 0.2, green: 0.4, blue: 0.6))
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        host.view.layoutIfNeeded()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("automation-\(UUID().uuidString)")
        codes = []
    }

    override func tearDown() async throws { host.destroy() }

    private func runner() -> AutomationRunner {
        AutomationRunner(host: host, bundleID: "dev.visualcore.tests", outputDirectory: dir) { [weak self] in self?.codes.append($0) }
    }

    private func decode(_ r: AutomationRunner) throws -> AutomationReport {
        try JSONDecoder().decode(AutomationReport.self, from: Data(contentsOf: try XCTUnwrap(r.lastReportURL)))
    }

    func testSmokeReportsFrameTimes() throws {
        let r = runner()
        let report = r.run(mode: "smoke", frames: 20)
        XCTAssertEqual(report.result, "pass")
        XCTAssertEqual(report.frames, 20)
        let stats = try XCTUnwrap(report.frameTimeMs)
        XCTAssertLessThanOrEqual(stats.min, stats.median)
        XCTAssertLessThanOrEqual(stats.median, stats.p95)
        XCTAssertLessThanOrEqual(stats.p95, stats.max)
        XCTAssertEqual(codes, [0])
        XCTAssertEqual(try decode(r), report)
        XCTAssertEqual(report.schema, 1)
        XCTAssertFalse(report.deviceModel.isEmpty)
        XCTAssertTrue(r.lastReportURL!.lastPathComponent.hasPrefix("visualcore-automation-smoke-"))
    }

    func testLaunchReportsTimeToFirstFrame() throws {
        let report = runner().run(mode: "launch")
        XCTAssertEqual(report.result, "pass")
        XCTAssertNotNil(report.timeToFirstFrameMs)
        XCTAssertGreaterThan(report.frames, 0)
        XCTAssertEqual(codes, [0])
    }

    func testLifecycleCyclesWithoutLeaks() throws {
        let report = runner().run(mode: "lifecycle", frames: 60)
        XCTAssertEqual(report.result, "pass", report.message ?? "")
        XCTAssertEqual(report.cycles, 6)
        XCTAssertEqual(report.leaked, 0)
        XCTAssertEqual(report.frames, 6)
    }

    func testUnknownModeWritesAnErrorAndExitsNonZero() throws {
        let r = runner()
        let report = r.run(mode: "bogus")
        XCTAssertEqual(report.result, "error")
        XCTAssertTrue(report.message?.contains("unknown mode 'bogus'") ?? false)
        XCTAssertEqual(codes, [2])
        XCTAssertEqual(try decode(r).result, "error")
    }

    func testEnvironmentParsing() {
        XCTAssertEqual(AutomationRunner.requestedMode(environment: ["VISUALCORE_AUTORUN": "smoke"]), "smoke")
        XCTAssertNil(AutomationRunner.requestedMode(environment: [:]))
        XCTAssertNil(AutomationRunner.requestedMode(environment: ["VISUALCORE_AUTORUN": ""]))
        XCTAssertEqual(AutomationRunner.requestedFrames(environment: [:]), 120)
        XCTAssertEqual(AutomationRunner.requestedFrames(environment: ["VISUALCORE_AUTORUN_FRAMES": "50000"]), 10_000)
        XCTAssertEqual(AutomationRunner.requestedFrames(environment: ["VISUALCORE_AUTORUN_FRAMES": "-3"]), 1)
    }

    func testFrameTimeStats() {
        XCTAssertNil(FrameTimeStats(samples: []))
        let s = FrameTimeStats(samples: Array(1...20).map(Double.init))!
        XCTAssertEqual(s.min, 1); XCTAssertEqual(s.max, 20); XCTAssertEqual(s.median, 10.5); XCTAssertEqual(s.p95, 19)
    }
}
