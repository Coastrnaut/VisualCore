// AutomationTests — feature 023 T-A02-510 (FR-A02-508; US5 AC1; spec clarifications 1–2). The same wiring as
// AppAutomation.root: one VisualCore host for the unhosted test-mode model, the runner with the app's post-run check
// and note, and a recorder instead of exiting.
import FluidArtPlaygroundCore
import VisualCoreAutomation
import VisualCoreRendering
import XCTest
@testable import FluidArtPlaygroundExperience

@MainActor
final class AutomationTests: XCTestCase {
    private var dir: URL!
    private var codes: [Int32] = []

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("fap-automation-\(UUID().uuidString)")
        codes = []
    }

    private func run(mode: String, frames: Int, seed: UInt64, check: ((PlaygroundModel) -> String?)? = nil)
        throws -> (AutomationReport, PlaygroundModel) {
        let model = AppAutomation.makeModel(seed: seed)
        XCTAssertNil(model.host, "the model is unhosted: AutomationView's host is the only one")
        let host = try RenderHost(scene: model.effects)
        host.view.frame = CGRect(origin: .zero, size: AppAutomation.canvas)
        host.view.layoutIfNeeded()
        defer { host.destroy() }
        let runner = AutomationRunner(host: host, bundleID: "dev.visualcore.FluidArtPlayground.tests", outputDirectory: dir) { [weak self] in
            self?.codes.append($0)
        }
        runner.postRunCheck = { (check ?? AppAutomation.check)(model) }
        runner.checkNote = { AppAutomation.note(model) }
        let report = runner.run(mode: mode, frames: frames)
        let data = try Data(contentsOf: try XCTUnwrap(runner.lastReportURL))
        XCTAssertEqual(try JSONDecoder().decode(AutomationReport.self, from: data), report)
        return (report, model)
    }

    /// Smoke: the scripted fluid runs, the check passes and the report carries the digest.
    func testSmokePassesWithDigest() throws {
        let (report, model) = try run(mode: "smoke", frames: 60, seed: 7)
        XCTAssertEqual(report.result, "pass", report.message ?? "")
        XCTAssertEqual(codes, [0])
        XCTAssertEqual(report.frames, 60)
        let message = try XCTUnwrap(report.message)
        XCTAssertTrue(message.hasPrefix("digest="), message)
        XCTAssertTrue(message.contains("steps=60"), message)
        XCTAssertTrue(message.contains("rebuilds=0"), message)
        XCTAssertGreaterThan(model.scene.appliedSplats, 0)
        print("automation smoke: \(message)")
    }

    /// Same seed, same digest; the digest is the simulation state, not the screen.
    func testSmokeDigestIsDeterministic() throws {
        let a = try run(mode: "smoke", frames: 30, seed: 5).0.message ?? ""
        let b = try run(mode: "smoke", frames: 30, seed: 5).0.message ?? ""
        let c = try run(mode: "smoke", frames: 30, seed: 6).0.message ?? ""
        XCTAssertEqual(a.split(separator: " ").first, b.split(separator: " ").first)
        XCTAssertNotEqual(a.split(separator: " ").first, c.split(separator: " ").first)
    }

    /// Lifecycle: pause, resume and context recreation rebuild from the seed; no leaks, and the check still passes.
    func testLifecycleRebuildsAndPasses() throws {
        let (report, model) = try run(mode: "lifecycle", frames: 60, seed: 9)
        XCTAssertEqual(report.result, "pass", report.message ?? "")
        XCTAssertEqual(report.leaked, 0)
        XCTAssertGreaterThanOrEqual(model.scene.rebuildCount, 2, "context recreated during the run")
        XCTAssertTrue(report.message?.contains("rebuilds=\(model.scene.rebuildCount)") ?? false,
                      "the report records the rebuilds: \(report.message ?? "")")
    }

    /// An injected bad check fails the run with its message and exit code 1.
    func testFailingCheckFailsTheRun() throws {
        let (report, _) = try run(mode: "smoke", frames: 5, seed: 1, check: { _ in "dye not finite at (1, 2)" })
        XCTAssertEqual(report.result, "fail")
        XCTAssertEqual(report.message, "dye not finite at (1, 2)")
        XCTAssertEqual(codes, [1])
    }
}
