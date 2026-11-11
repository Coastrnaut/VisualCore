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
        XCTAssertEqual(report.frames, 1, "launch stops at the first presented frame")
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

    // MARK: feature 023 T-A02-502 (FR-A02-508)

    func testSeedParsing() {
        XCTAssertEqual(AutomationRunner.requestedSeed(environment: [:]), 1)
        XCTAssertEqual(AutomationRunner.requestedSeed(environment: ["VISUALCORE_AUTORUN_SEED": "0"]), 1)
        XCTAssertEqual(AutomationRunner.requestedSeed(environment: ["VISUALCORE_AUTORUN_SEED": "abc"]), 1)
        XCTAssertEqual(AutomationRunner.requestedSeed(environment: ["VISUALCORE_AUTORUN_SEED": "-4"]), 1)
        XCTAssertEqual(AutomationRunner.requestedSeed(environment: ["VISUALCORE_AUTORUN_SEED": "7"]), 7)
        XCTAssertEqual(AutomationRunner.requestedSeed(environment: ["VISUALCORE_AUTORUN_SEED": "18446744073709551615"]), .max)
    }

    func testPassingCheckKeepsPassAndAddsTheNote() throws {
        let r = runner()
        var calls = 0
        r.postRunCheck = { calls += 1; return nil }
        r.checkNote = { "digest=abc" }
        let report = r.run(mode: "smoke", frames: 5)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(report.result, "pass")
        XCTAssertEqual(report.message, "digest=abc")
        XCTAssertEqual(codes, [0])
        XCTAssertEqual(try decode(r), report)
    }

    func testFailingCheckFailsTheRun() throws {
        let r = runner()
        r.postRunCheck = { "dye not finite at (3, 4)" }
        r.checkNote = { "unused" }
        let report = r.run(mode: "lifecycle", frames: 50)
        XCTAssertEqual(report.result, "fail")
        XCTAssertEqual(report.message, "dye not finite at (3, 4)")
        XCTAssertEqual(report.leaked, 0, "frame data is kept")
        XCTAssertEqual(codes, [1])
    }

    func testCheckNotCalledForUnknownMode() {
        let r = runner()
        var calls = 0
        r.postRunCheck = { calls += 1; return "x" }
        let report = r.run(mode: "bogus")
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(report.result, "error")
        XCTAssertEqual(codes, [2])
    }
}
