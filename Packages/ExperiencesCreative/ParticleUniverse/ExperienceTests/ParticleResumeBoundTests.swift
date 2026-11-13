// ParticleResumeBoundTests — feature 037 (A04-P05) T-A04-502 (FR-A04-501 to FR-A04-503; research D3; SC-A04-501).
// Resume after a background gap through the one app's `ExperienceSession`: the first frame after a gap of any length
// advances at most `SceneSimulation.maxStepsPerFrame` (8) steps, later 1/60 s frames take the normal 2 steps at the
// core's 1/120 s step, a replay of the same history reaches the same digest (3 of 3), and a paused scene runs no
// simulation step for the gap. Short runs only (owner rule of 2026-11-13). Hosted by the VisualCore app.
//
// How the gap reaches the engine (the seam): the render host hands the shell a frame delta clamped to
// `FramePacing.maximumDelta` (0.1 s); `renderOneFrame` always hands 1/60 s; the shell's engine is `private(set)`. A
// 600 s delta therefore cannot travel through the host. The test takes the session's own engine after the real
// background → active transition (`ExperienceEngine` and `ParticleCore` are value types, so the copy carries the
// session's lifecycle, clock and core without touching the session) and advances it by 600 s — the exact call
// (`engine.advance(frame:)`) the shell makes in `sceneRender`. The host's clamp is asserted separately, so both
// paths a long gap can take are bounded.
import XCTest
import ParticleUniverseCore
@testable import ParticleUniverseExperience
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class ParticleResumeBoundTests: XCTestCase {
    private var id: ExperienceID { ParticleExperience.id ?? ExperienceID(rawValue: "a04.unknown")! }
    /// The gap: ten minutes of clock time (FR-A04-503).
    private let gap = 600.0
    /// The normal frame and the steps it takes at the core's step.
    private let frame = 1.0 / 60

    private func request(seed: UInt64 = ParticleCore.manifestSeed, snapshot: ExperienceSnapshot? = nil,
                         made: @escaping @MainActor (any Experience) -> Void = { _ in }) -> ExperienceOpenRequest {
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: seed, snapshot: snapshot, refusedSnapshotFails: snapshot != nil) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("pu-resume-\(UUID().uuidString)")
            let storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: "pu-resume-tests")!)
            let experience = ParticleExperience.make(id: id, storage: storage, reduceMotion: false, reduceFlashing: false)
            made(experience)
            return experience
        }
    }

    private func layOut(_ session: ExperienceSession) {
        guard let view = session.renderHost?.view else { return }
        view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
        view.layoutIfNeeded()
    }

    private func shell(_ experience: (any Experience)?) throws -> ExperienceShell<ParticlePresenter> {
        try XCTUnwrap(experience as? ExperienceShell<ParticlePresenter>)
    }

    /// Opens a playing scene with a placed force, draws a frame, goes to the background and comes back.
    private func openPlayAndResume(_ session: ExperienceSession, pause: Bool = false) async throws
        -> ExperienceShell<ParticlePresenter> {
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        layOut(session)
        let experience = try XCTUnwrap(made)
        XCTAssertTrue(experience.handle(control: "force.place", values: [0.7, 0.3]).isAccepted)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        if pause { XCTAssertTrue(experience.handle(control: "pause", values: []).isAccepted) }
        let shell = try shell(experience)
        let before = try shell.engine.digest().hex
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        session.setScenePhase(.active)
        XCTAssertEqual(shell.state, .active)
        XCTAssertEqual(try shell.engine.digest().hex, before, "no steps for the time away")
        return shell
    }

    func testTheCoreStepAndTheBoundAreWhatTheTestAssumes() {
        XCTAssertEqual(ExperienceEngine<ParticleCore>.stepDuration, SceneSimulation.step, accuracy: 1e-12)
        XCTAssertEqual(SceneSimulation.step, 1.0 / 120, accuracy: 1e-12)
        XCTAssertEqual(SceneSimulation.maxStepsPerFrame, 8)
        // The host's path: any gap reaches the shell as at most 0.1 s, which is 12 steps before the engine's cap.
        XCTAssertEqual(FramePacing.clampedDelta(gap), FramePacing.maximumDelta)
        XCTAssertGreaterThan(FramePacing.maximumDelta / SceneSimulation.step, Double(SceneSimulation.maxStepsPerFrame))
    }

    func testAResumeAfterTenMinutesTakesAtMostEightStepsThenNormalFrames() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await openPlayAndResume(session)
        let held = try shell.engine.digest().hex

        // The session's own engine after the real background → active transition, advanced by the 10-minute gap.
        var engine = shell.engine
        let start = engine.stepIndex
        let first = try engine.advance(frame: gap)
        print("A04-P05 resume: a \(Int(gap)) s frame after background → active took \(first) steps")
        XCTAssertLessThanOrEqual(first, SceneSimulation.maxStepsPerFrame)
        XCTAssertEqual(first, SceneSimulation.maxStepsPerFrame, "the cap, not a catch-up")
        XCTAssertEqual(engine.stepIndex, start + first)
        var normal: [Int] = []
        for _ in 0..<5 { normal.append(try engine.advance(frame: frame)) }
        print("A04-P05 resume: the next 1/60 s frames took \(normal) steps")
        XCTAssertEqual(normal, Array(repeating: 2, count: 5))
        XCTAssertEqual(try shell.engine.digest().hex, held, "the copy left the session's engine untouched")

        // The session itself: after the resume its 1/60 s frames take the normal 2 steps each (no carried time).
        var sessionSteps: [Int] = []
        for _ in 0..<5 {
            let before = shell.engine.stepIndex
            XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
            sessionSteps.append(shell.engine.stepIndex - before)
        }
        print("A04-P05 resume: the session's frames after the resume took \(sessionSteps) steps")
        XCTAssertEqual(sessionSteps, Array(repeating: 2, count: 5))
    }

    func testAReplayOfTheHistoryWithTheGapReachesTheSameDigestThreeTimes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await openPlayAndResume(session)
        var engine = shell.engine
        XCTAssertEqual(try engine.advance(frame: gap), SceneSimulation.maxStepsPerFrame)
        for _ in 0..<5 { try engine.advance(frame: frame) }
        XCTAssertTrue(engine.handle(control: "emitter.add", values: []).isAccepted)
        for _ in 0..<3 { try engine.advance(frame: frame) }
        let snapshot = try engine.snapshot()
        let digest = try engine.digest().hex
        for run in 1...3 {
            var fresh = ExperienceEngine<ParticleCore>(id: id)
            try await fresh.prepare(seed: ParticleCore.manifestSeed)
            try fresh.restore(snapshot)
            XCTAssertEqual(try fresh.digest().hex, digest, "run \(run) of 3")
        }
    }

    func testAPausedSceneRunsNoSimulationStepForTheGap() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await openPlayAndResume(session, pause: true)
        let core = try XCTUnwrap(shell.engine.core)
        XCTAssertFalse(core.playing)
        let simulationSteps = core.simulation.stepIndex
        let live = core.simulation.liveCount

        var engine = shell.engine
        _ = try engine.advance(frame: gap)
        let after = try XCTUnwrap(engine.core)
        print("A04-P05 resume: paused, the \(Int(gap)) s gap ran \(after.simulation.stepIndex - simulationSteps) "
              + "simulation steps")
        XCTAssertEqual(after.simulation.stepIndex, simulationSteps, "0 simulation steps for the gap while paused")
        XCTAssertEqual(after.simulation.liveCount, live)

        // The session's own frames while paused run no simulation step either.
        for _ in 0..<3 { XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false) }
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).simulation.stepIndex, simulationSteps)
    }
}
