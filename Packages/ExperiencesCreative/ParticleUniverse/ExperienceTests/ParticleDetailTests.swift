// ParticleDetailTests — feature 037 A04-P05 T-A04-506 (US2; FR-A04-510 to FR-A04-512; research D2). The presenter's
// frame-budget monitor through the one app's session host on the simulator: a lower drawn detail changes only the drawn
// count and never the simulation, the drawn tier is the coarser of the host's and the monitor's, and frames drawn
// while paused do not move the monitor. Short runs only. Hosted by the VisualCore app.
import XCTest
import ParticleUniverseCore
@testable import ParticleUniverseExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class ParticleDetailTests: XCTestCase {
    private var id: ExperienceID { ParticleExperience.id ?? ExperienceID(rawValue: "a04.unknown")! }
    /// A frame time over 1.2× the 1/60 s budget.
    private let slowFrame = 1.0 / 30

    private func request(made: @escaping @MainActor (any Experience) -> Void) -> ExperienceOpenRequest {
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: ParticleCore.manifestSeed, snapshot: nil, refusedSnapshotFails: false) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("pu-detail-\(UUID().uuidString)")
            let storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: "pu-detail-tests")!)
            let experience = ParticleExperience.make(id: id, storage: storage, reduceMotion: false, reduceFlashing: false)
            made(experience)
            return experience
        }
    }

    /// Opens a session, lays out its canvas and returns the shell.
    private func open(_ session: ExperienceSession) async throws -> ExperienceShell<ParticlePresenter> {
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        return try XCTUnwrap(made as? ExperienceShell<ParticlePresenter>)
    }

    private func render(_ session: ExperienceSession, frames: Int) {
        for _ in 0..<frames { XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false) }
    }

    /// One scripted run; `slowFramesFirst` slow frame times reach the monitor before the frames are drawn.
    private func run(slowFramesFirst: Int) async throws -> (digest: String, tier: Int, drawn: Int, expected: Int) {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await open(session)
        XCTAssertTrue(shell.handle(control: "force.place", values: [0.6, 0.4]).isAccepted)
        for _ in 0..<slowFramesFirst { shell.presenter.detail.record(frameTime: slowFrame) }
        render(session, frames: 60)
        let core = try XCTUnwrap(shell.engine.core)
        return (try shell.engine.digest().hex, shell.presenter.drawnTier, shell.presenter.drawnCount,
                core.instances(tier: shell.presenter.drawnTier).count)
    }

    func testALowerDrawnDetailLeavesTheSimulationUnchanged() async throws {
        let full = try await run(slowFramesFirst: 0)
        let lowered = try await run(slowFramesFirst: 2 * FrameBudgetMonitor.slowWindow)
        XCTAssertEqual(full.tier, 0)
        XCTAssertEqual(lowered.tier, 2, "two full windows of slow frames: two tiers down")
        XCTAssertEqual(full.drawn, full.expected)
        XCTAssertEqual(lowered.drawn, lowered.expected, "the drawn count follows the monitor's tier")
        XCTAssertLessThanOrEqual(lowered.drawn, full.drawn)
        XCTAssertEqual(lowered.digest, full.digest, "the detail never changes the simulation (FR-A04-510)")
    }

    func testTheHostTierWinsOverAFinerMonitorTier() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await open(session)
        try shell.setQualityTier(2)
        render(session, frames: 3)
        XCTAssertEqual(shell.presenter.detail.tier, 0)
        XCTAssertEqual(shell.presenter.drawnTier, 2, "host tier 2 with the monitor at 0 draws at 2 (FR-A04-511)")
        let core = try XCTUnwrap(shell.engine.core)
        XCTAssertEqual(shell.presenter.drawnCount, core.instances(tier: 2).count)

        for _ in 0..<(3 * FrameBudgetMonitor.slowWindow) { shell.presenter.detail.record(frameTime: slowFrame) }
        render(session, frames: 1)
        XCTAssertEqual(shell.presenter.drawnTier, 3, "the coarser tier wins either way")
    }

    func testFramesDrawnWhilePausedDoNotMoveTheMonitor() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await open(session)
        // Most of a window of slow frames, then a pause: the frames drawn while paused clear the window.
        for _ in 0..<100 { shell.presenter.detail.record(frameTime: slowFrame) }
        XCTAssertTrue(shell.handle(control: "pause").isAccepted)
        render(session, frames: 1)
        XCTAssertEqual(shell.engine.core?.playing, false)
        var cleared = shell.presenter.detail
        cleared.restart()
        render(session, frames: 30)
        XCTAssertEqual(shell.presenter.detail, cleared, "nothing recorded while paused (FR-A04-512)")
        XCTAssertEqual(shell.presenter.detail.tier, 0)

        // Back to play: the 100 slow frames before the pause are forgotten, so 30 more do not complete a window.
        XCTAssertTrue(shell.handle(control: "play").isAccepted)
        render(session, frames: 1)
        XCTAssertEqual(shell.engine.core?.playing, true)
        for _ in 0..<30 { shell.presenter.detail.record(frameTime: slowFrame) }
        XCTAssertEqual(shell.presenter.detail.tier, 0)
    }

    /// T-A04-516 (FR-A04-510, clarification 1): the budget follows the interval of the host's target timestamps; a
    /// change of more than 10% rebuilds the monitor at the same tier, a smaller one keeps it.
    func testTheBudgetFollowsTheHostsFrameInterval() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await open(session)
        let presenter = shell.presenter
        XCTAssertEqual(presenter.detail.budget, 1.0 / 60, "1/60 s before any interval is seen")
        for _ in 0..<(2 * FrameBudgetMonitor.slowWindow) { presenter.detail.record(frameTime: slowFrame) }
        XCTAssertEqual(presenter.detail.tier, 2)

        let start = 1_000.0
        for i in 0..<4 { presenter.noteFrameTarget(index: 1_000 + i, target: start + Double(i) / 120) }
        XCTAssertEqual(presenter.detail.budget, 1.0 / 120, accuracy: 1e-9, "a 120 Hz display")
        XCTAssertEqual(presenter.detail.tier, 2, "rebuilt at the same tier")

        // A step 5% shorter is within 10%: the monitor is kept, windows and all.
        presenter.detail.record(frameTime: slowFrame)
        let kept = presenter.detail
        presenter.noteFrameTarget(index: 1_004, target: start + 3.0 / 120 + 0.95 / 120)
        XCTAssertEqual(presenter.detail, kept)

        // Slow frames against the new budget: 1/60 s is twice 1/120 s, so a window of them steps down.
        for _ in 0..<FrameBudgetMonitor.slowWindow { presenter.detail.record(frameTime: 1.0 / 60) }
        XCTAssertEqual(presenter.detail.tier, 3)
    }
}
