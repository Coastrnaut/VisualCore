// SessionPhaseMemoryTests — feature 189 (UA-F03) T-U03-006 (US4 and US5; FR-U03-040 to FR-U03-053, FR-U03-070,
// FR-U03-071; SC-U03-005 to SC-U03-007; contract specs/189-ua-f03-experience-host/contracts/session-api.md).
// Scene phases (suspension with a snapshot, resumption without steps for the time away, a preparation that ends
// in the background), memory warnings below and above the memory-pressure limit, a forced context recreation,
// a snapshot sink that throws, and the session's own memory-warning observer.
// The helpers (`sampleRequest`, `SampleProbe`, `SnapshotLog`, `layOut`, …) are in SessionOpenCloseTests.swift.
import UIKit
import XCTest
import VisualCoreExperience
@testable import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreTestSupport

@MainActor
final class SessionPhaseMemoryTests: XCTestCase {
    /// The time away of SC-U03-005.
    private static let timeAway: Duration = .seconds(10)

    // MARK: Helpers

    /// A session with the healthy sample running, laid out, after `frames` frames and one `tone` action.
    private func runningSession(
        sink: ExperienceSession.SnapshotSink? = nil, memoryPressureLimit: Int? = nil, frames: Int = 3,
        file: StaticString = #filePath, line: UInt = #line
    ) async -> (session: ExperienceSession, probe: SampleProbe<NoFault>) {
        let session = ExperienceSession(snapshotSink: sink)
        let (request, probe) = sampleRequest(memoryPressureLimit: memoryPressureLimit)
        let result = await session.open(request)
        XCTAssertEqual(result, .running, file: file, line: line)
        layOut(session)
        for _ in 0..<frames { XCTAssertTrue(drawFrame(session), file: file, line: line) }
        XCTAssertEqual(session.experience?.handle(control: "tone", values: [0.5]), .accepted, file: file, line: line)
        XCTAssertTrue(drawFrame(session), file: file, line: line)
        return (session, probe)
    }

    /// Posts the system's memory warning, as UIKit does, on the main thread.
    private func postMemoryWarning() {
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }

    /// SC-U03-005 for one phase: suspension with one snapshot, `timeAway` away, resumption with 0 steps for the
    /// time away and an equal digest.
    private func checkSuspensionAndResumption(to away: ScenePhaseInput) async throws {
        let log = SnapshotLog()
        let (session, probe) = await runningSession(sink: log.sink)
        defer { session.close() }
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertEqual(host.state, .active)
        XCTAssertEqual(session.phase, .active)
        XCTAssertEqual(log.count, 0)
        let digest = try probe.digest()
        let steps = probe.stepIndex
        XCTAssertGreaterThan(steps, 0, "the experience ran steps before the suspension")

        session.setScenePhase(away)
        XCTAssertEqual(session.phase, away)
        XCTAssertEqual(session.state, .suspended)
        XCTAssertEqual(probe.shell?.state, .suspended, "the experience is suspended")
        XCTAssertEqual(host.state, .suspended, "the render host is paused")
        XCTAssertTrue(session.renderHost === host, "the render host is kept")
        XCTAssertEqual(session.hostsAlive, 1)
        XCTAssertEqual(log.count, 1, "one snapshot per suspension")
        XCTAssertEqual(log.snapshots.last?.digest, digest)
        XCTAssertEqual(log.snapshots.last?.stepIndex, steps)
        XCTAssertEqual(session.diagnostics.experienceDiagnostics?.state, .suspended)
        XCTAssertFalse(drawFrame(session), "a paused host draws no frame")

        // The same phase again, and the other phase that is not active, only store the phase.
        session.setScenePhase(away)
        let other: ScenePhaseInput = away == .background ? .inactive : .background
        session.setScenePhase(other)
        XCTAssertEqual(session.phase, other)
        XCTAssertEqual(session.state, .suspended)
        XCTAssertEqual(log.count, 1, "no second snapshot without a second suspension")
        session.setScenePhase(away)

        try await Task.sleep(for: Self.timeAway)
        XCTAssertEqual(session.state, .suspended)
        XCTAssertEqual(probe.stepIndex, steps, "no step while away")

        session.setScenePhase(.active)
        XCTAssertEqual(session.phase, .active)
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(probe.shell?.state, .active)
        XCTAssertEqual(host.state, .active)
        XCTAssertEqual(probe.stepIndex, steps, "0 steps for the time away")
        XCTAssertEqual(try probe.digest(), digest, "the digest is equal before and after")

        // The first frame after the return runs the steps of one frame (1/60 s), not of the time away, which
        // would fill the limit of 8 steps per frame.
        XCTAssertTrue(drawFrame(session))
        XCTAssertGreaterThan(probe.stepIndex, steps, "the experience runs again")
        XCTAssertLessThanOrEqual(probe.stepIndex - steps, 3, "no catching up on the time away")
        XCTAssertEqual(probe.shell?.diagnostics.droppedTime, 0, "no time was dropped, because none was added")
        XCTAssertTrue(sessionShowsState(session, probe))

        // A second suspension hands out a second snapshot.
        session.setScenePhase(away)
        XCTAssertEqual(session.state, .suspended)
        XCTAssertEqual(log.count, 2, "a snapshot at every suspension")
        XCTAssertEqual(log.snapshots.last?.digest, try probe.digest())
        session.setScenePhase(.active)
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
        XCTAssertEqual(session.diagnostics.sinkFailures, 0)
        XCTAssertEqual(session.diagnostics.failures, 0)
    }

    // MARK: Phases (SC-U03-005)

    func testBackgroundSuspendsARunningSessionAndActiveResumesItWithoutStepsForTheTimeAway() async throws {
        try await checkSuspensionAndResumption(to: .background)
    }

    func testInactiveSuspendsARunningSessionAndActiveResumesItWithoutStepsForTheTimeAway() async throws {
        try await checkSuspensionAndResumption(to: .inactive)
    }

    func testAPreparationThatEndsInTheBackgroundGivesSuspendedAndRunsAfterActive() async throws {
        let log = SnapshotLog()
        let session = ExperienceSession(snapshotSink: log.sink)
        defer { session.close() }
        session.setScenePhase(.background)
        XCTAssertEqual(session.phase, .background)
        XCTAssertEqual(session.state, .idle)

        let (request, probe) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .suspended)
        XCTAssertEqual(session.state, .suspended)
        XCTAssertTrue(session.experience === probe.shell)
        XCTAssertEqual(probe.shell?.state, .ready, "an experience is not activated while the phase is not active")
        XCTAssertEqual(session.hostsAlive, 1)
        XCTAssertEqual(session.diagnostics.opens, 1)
        XCTAssertNil(session.diagnostics.timings.activate, "a stage that did not happen has no duration")
        XCTAssertNil(session.diagnostics.timings.firstFrame)
        XCTAssertNotNil(session.diagnostics.timings.prepare)
        XCTAssertNotNil(session.diagnostics.timings.createHost)
        let host = try XCTUnwrap(session.renderHost)
        layOut(session)
        XCTAssertEqual(host.state, .suspended, "the host is paused")
        XCTAssertFalse(drawFrame(session))
        XCTAssertEqual(probe.presenter?.drawCalls, 0)
        XCTAssertEqual(probe.stepIndex, 0)

        // Inactive is not active either.
        session.setScenePhase(.inactive)
        XCTAssertEqual(session.state, .suspended)
        XCTAssertEqual(probe.shell?.state, .ready)

        session.setScenePhase(.active)
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(probe.shell?.state, .active)
        XCTAssertEqual(host.state, .active)
        XCTAssertTrue(session.renderHost === host)
        XCTAssertNotNil(session.diagnostics.timings.activate)
        // The host has a surface by now, so the session drew the first frame itself when it activated.
        XCTAssertGreaterThanOrEqual(probe.presenter?.drawCalls ?? 0, 1)
        XCTAssertNotNil(session.diagnostics.timings.firstFrame)
        XCTAssertTrue(drawFrame(session))
        XCTAssertTrue(sessionShowsState(session, probe))
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
        XCTAssertEqual(session.diagnostics.failures, 0)

        // From here on it is an ordinary running session.
        session.setScenePhase(.background)
        XCTAssertEqual(session.state, .suspended)
        XCTAssertEqual(probe.shell?.state, .suspended)
        XCTAssertEqual(log.count, 1)
        session.setScenePhase(.active)
        XCTAssertEqual(session.state, .running)
    }

    func testPhasesInIdleFailedAndMessageOnlyStoreThePhase() async throws {
        let log = SnapshotLog()
        let session = ExperienceSession(snapshotSink: log.sink)
        defer { session.close() }

        // Idle.
        for phase in [ScenePhaseInput.inactive, .background, .active] {
            session.setScenePhase(phase)
            XCTAssertEqual(session.phase, phase)
            assertHoldsNothing(session)
        }

        // Failed.
        let (failing, _) = sampleRequest(FailingPreparation.self)
        let failed = await session.open(failing)
        guard case .failed(let failure) = failed else { return XCTFail("got \(failed)") }
        for phase in [ScenePhaseInput.inactive, .background, .active] {
            session.setScenePhase(phase)
            XCTAssertEqual(session.phase, phase)
            XCTAssertEqual(session.state, .failed, "the failure view stays")
            XCTAssertEqual(session.failure, failure)
            XCTAssertNil(session.experience)
            XCTAssertEqual(session.hostsAlive, 0)
        }
        session.back()

        // Message.
        let (request, _) = sampleRequest(memoryPressureLimit: 0)
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        layOut(session)
        XCTAssertTrue(drawFrame(session))
        session.handleMemoryWarning()
        XCTAssertEqual(session.state, .message)
        let snapshots = log.count
        let text = session.message
        for phase in [ScenePhaseInput.inactive, .background, .active] {
            session.setScenePhase(phase)
            XCTAssertEqual(session.phase, phase)
            XCTAssertEqual(session.state, .message, "the message view stays")
            XCTAssertEqual(session.message, text)
            XCTAssertNil(session.experience, "nothing is activated")
            XCTAssertEqual(session.hostsAlive, 0)
        }
        XCTAssertEqual(log.count, snapshots, "no snapshot without an experience")
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0, "a stored phase is not a refused transition")
        session.back()
        assertHoldsNothing(session)
    }

    // MARK: Memory warnings (SC-U03-006)

    func testAMemoryWarningBelowTheLimitShedsCachesAndKeepsDigestAndState() async throws {
        let log = SnapshotLog()
        let (session, probe) = await runningSession(sink: log.sink)
        defer { session.close() }
        let host = session.renderHost
        let digest = try probe.digest()
        XCTAssertEqual(probe.presenter?.shedCalls, 0)

        session.handleMemoryWarning()
        XCTAssertEqual(probe.presenter?.shedCalls, 1, "the presenter was asked to shed its caches")
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(probe.shell?.state, .active)
        XCTAssertEqual(try probe.digest(), digest, "shedding does not change the state")
        XCTAssertTrue(session.renderHost === host)
        XCTAssertNil(session.message)
        XCTAssertEqual(log.count, 0, "no snapshot without a closure")
        XCTAssertEqual(session.diagnostics.memoryClosures, 0)
        XCTAssertEqual(session.diagnostics.closes, 0)

        // The session listens for the system's warning itself (FR-U03-044).
        postMemoryWarning()
        let heard = await waitUntil { probe.presenter?.shedCalls == 2 }
        XCTAssertTrue(heard, "the system's warning reached the session once: \(probe.presenter?.shedCalls ?? -1)")
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(try probe.digest(), digest)

        // The experience still draws from its state.
        XCTAssertTrue(drawFrame(session))
        XCTAssertTrue(sessionShowsState(session, probe))
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
    }

    func testAMemoryWarningWhileSuspendedShedsCachesWithoutActivation() async throws {
        let (session, probe) = await runningSession()
        defer { session.close() }
        session.setScenePhase(.background)
        XCTAssertEqual(session.state, .suspended)
        let digest = try probe.digest()

        session.handleMemoryWarning()
        XCTAssertEqual(probe.presenter?.shedCalls, 1)
        XCTAssertEqual(session.state, .suspended)
        XCTAssertEqual(probe.shell?.state, .suspended, "no activation")
        XCTAssertEqual(try probe.digest(), digest)
        XCTAssertEqual(session.diagnostics.memoryClosures, 0)
    }

    func testAMemoryWarningWithoutAnOpenExperienceDoesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        session.handleMemoryWarning()
        assertHoldsNothing(session)

        // While preparing there is no state to shed and nothing to close.
        let (slow, probe) = sampleRequest(SlowPreparation.self, memoryPressureLimit: 0)
        let pending = openInBackground(session, slow)
        let preparing = await waitUntil { session.state == .preparing }
        XCTAssertTrue(preparing)
        session.handleMemoryWarning()
        XCTAssertEqual(session.state, .preparing)
        XCTAssertEqual(probe.presenter?.shedCalls, 0)
        XCTAssertNil(session.message)
        session.close()
        let result = await pending.value
        XCTAssertEqual(result, .cancelled)
        XCTAssertEqual(session.diagnostics.memoryClosures, 0)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
    }

    func testAMemoryWarningAboveTheLimitHandsOutASnapshotClosesAndEndsInMessage() async throws {
        let log = SnapshotLog()
        // A limit of 0 bytes is raised to the rule's minimum of 1 byte; the sample's 1 × 1 texture has 4.
        let (session, probe) = await runningSession(sink: log.sink, memoryPressureLimit: 0)
        defer { session.close() }
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertGreaterThan(host.resources.stats.totalBytes, 1, "the session is above its limit")
        let digest = try probe.digest()

        session.handleMemoryWarning()
        XCTAssertEqual(session.state, .message)
        XCTAssertEqual(session.message, SessionStrings.text(.memoryMessage), "the memory text")
        XCTAssertFalse(session.message?.isEmpty ?? true)
        XCTAssertNil(session.failure, "a memory closure is not a failure")
        XCTAssertNil(session.experience)
        XCTAssertNil(session.renderHost)
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertEqual(host.state, .destroyed)
        XCTAssertEqual(probe.presenter?.shedCalls, 1, "caches are shed before the rule is applied")
        XCTAssertEqual(log.count, 1, "one snapshot handed out")
        XCTAssertEqual(log.snapshots.first?.digest, digest, "the snapshot holds the state at the closure")
        XCTAssertEqual(log.snapshots.first?.experience, SampleExperience.id)
        assertClosedCleanly(session)
        XCTAssertEqual(probe.shell?.state, .inactive)
        XCTAssertNil(probe.presenter?.texture)
        let diagnostics = session.diagnostics
        XCTAssertEqual(diagnostics.state, .message)
        XCTAssertEqual(diagnostics.memoryClosures, 1)
        XCTAssertEqual(diagnostics.closes, 1, "a memory closure is a full close")
        XCTAssertEqual(diagnostics.failures, 0)
        XCTAssertEqual(diagnostics.rejectedTransitions, 0)

        // A second warning in the message state does nothing.
        session.handleMemoryWarning()
        XCTAssertEqual(session.state, .message)
        XCTAssertEqual(session.diagnostics.memoryClosures, 1)
        XCTAssertEqual(log.count, 1)

        session.back()
        assertHoldsNothing(session)
        XCTAssertNil(session.message, "the message is cleared from the view state")
        XCTAssertEqual(session.diagnostics.memoryClosures, 1)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)

        // The snapshot that was handed out opens the experience where it was.
        let saved = try XCTUnwrap(log.snapshots.first)
        let (again, againProbe) = sampleRequest(snapshot: saved)
        let reopened = await session.open(again)
        XCTAssertEqual(reopened, .running)
        XCTAssertEqual(try againProbe.digest(), digest)
        XCTAssertNil(session.lastRestoreRefusal)
    }

    // MARK: Context recreation (SC-U03-007)

    func testRecreateContextKeepsDigestAndCentrePixelAndCountsOneRecreation() async throws {
        let (session, probe) = await runningSession()
        defer { session.close() }
        let host = try XCTUnwrap(session.renderHost)
        let shell = try XCTUnwrap(probe.shell)
        let core = try XCTUnwrap(shell.engine.core)
        let pixelBefore = centrePixel(of: host)
        XCTAssertTrue(pixelsMatch(pixelBefore, expectedPixel(for: core)), "got \(pixelBefore)")
        XCTAssertLessThanOrEqual(abs(pixelBefore.b - 128), 2, "the tone of 0.5 is part of the picture")
        let digest = try probe.digest()
        let generation = host.generation
        XCTAssertEqual(probe.presenter?.setupCalls, 1)

        session.recreateContext()
        XCTAssertEqual(session.diagnostics.contextRecreations, 1)
        XCTAssertEqual(session.state, .running)
        XCTAssertNil(session.failure)
        XCTAssertTrue(session.renderHost === host, "the same render host with a new context")
        XCTAssertEqual(session.hostsAlive, 1)
        XCTAssertGreaterThan(host.generation, generation)
        XCTAssertEqual(host.state, .active)
        XCTAssertEqual(probe.presenter?.teardownCalls, 1)
        XCTAssertEqual(probe.presenter?.setupCalls, 2, "the scene was set up again in the new context")
        XCTAssertEqual(shell.state, .active)
        XCTAssertEqual(try probe.digest(), digest, "the digest is equal")

        // The experience draws again from its state: the same colour within 2 of 255.
        XCTAssertTrue(drawFrame(session))
        let pixelAfter = centrePixel(of: host)
        XCTAssertTrue(pixelsMatch(pixelAfter, pixelBefore, tolerance: 2), "before \(pixelBefore), after \(pixelAfter)")
        XCTAssertTrue(sessionShowsState(session, probe))
        XCTAssertEqual(session.diagnostics.failures, 0)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)

        // And the close after a recreation leaves nothing behind.
        session.close()
        assertHoldsNothing(session)
        assertClosedCleanly(session)
    }

    func testRecreateContextWithoutAnOpenExperienceDoesNothing() {
        let session = ExperienceSession()
        session.recreateContext()
        assertHoldsNothing(session)
        XCTAssertEqual(session.diagnostics.contextRecreations, 0)
        XCTAssertNil(session.failure)
    }

    // MARK: Snapshot sink (FR-U03-070)

    func testASinkThatThrowsIsCountedAndStopsNeitherSuspensionNorClose() async throws {
        let log = SnapshotLog()
        log.fails = true
        let (session, probe) = await runningSession(sink: log.sink)
        defer { session.close() }
        XCTAssertNil(session.lastSinkFailure)

        session.setScenePhase(.background)
        XCTAssertEqual(session.state, .suspended, "the suspension went on")
        XCTAssertEqual(probe.shell?.state, .suspended)
        XCTAssertEqual(log.count, 1, "the sink was called")
        XCTAssertEqual(session.diagnostics.sinkFailures, 1)
        XCTAssertEqual(session.lastSinkFailure?.code, SessionFailure.sinkFailedCode)
        XCTAssertNil(session.failure, "a sink failure is recorded, not shown as a failure view")

        session.setScenePhase(.active)
        XCTAssertEqual(session.state, .running)
        XCTAssertTrue(drawFrame(session))
        XCTAssertTrue(sessionShowsState(session, probe))

        session.close()
        assertHoldsNothing(session)
        assertClosedCleanly(session)
        XCTAssertEqual(log.count, 2)
        XCTAssertEqual(session.diagnostics.sinkFailures, 2)
        XCTAssertEqual(session.lastSinkFailure?.code, SessionFailure.sinkFailedCode)
        XCTAssertEqual(session.diagnostics.closes, 1)
        XCTAssertNil(session.failure)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)

        // The session stays usable, also for a memory closure with the failing sink.
        let (request, _) = sampleRequest(memoryPressureLimit: 0)
        let reopened = await session.open(request)
        XCTAssertEqual(reopened, .running)
        layOut(session)
        XCTAssertTrue(drawFrame(session))
        session.handleMemoryWarning()
        XCTAssertEqual(session.state, .message)
        XCTAssertEqual(session.diagnostics.sinkFailures, 3)
        assertClosedCleanly(session)
    }

    func testWithoutASinkSnapshotsAreDroppedAndNothingIsCounted() async throws {
        let (session, _) = await runningSession()
        session.setScenePhase(.inactive)
        XCTAssertEqual(session.state, .suspended)
        session.setScenePhase(.active)
        session.close()
        assertHoldsNothing(session)
        assertClosedCleanly(session)   // `handOutSnapshot` is a recorded step also without a sink
        XCTAssertEqual(session.diagnostics.sinkFailures, 0)
        XCTAssertNil(session.lastSinkFailure)
    }

    // MARK: Memory-warning observer (FR-U03-044)

    func testTheSessionHasOneMemoryWarningObserverAndRemovesItWhenReleased() async throws {
        var session: ExperienceSession? = ExperienceSession()
        weak var released = session
        XCTAssertNotNil(session?.memoryObserver, "the session registered its observer")
        let (request, probe) = sampleRequest()
        let result = await session?.open(request)
        XCTAssertEqual(result, .running)

        // Exactly one observer: one system warning sheds once.
        postMemoryWarning()
        let heard = await waitUntil { probe.presenter?.shedCalls ?? 0 >= 1 }
        XCTAssertTrue(heard)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(probe.presenter?.shedCalls, 1, "one observer, one call per warning")

        // Released while an experience is open: the observer is removed and the render host goes with it.
        session = nil
        let gone = await waitUntil { released == nil }
        XCTAssertTrue(gone, "the session was released")
        let tornDown = await waitUntil { probe.presenter?.teardownCalls == 1 }
        XCTAssertTrue(tornDown, "the render host of a released session is destroyed")
        XCTAssertNil(probe.presenter?.texture)

        postMemoryWarning()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(probe.presenter?.shedCalls, 1, "no warning reaches a released session")
    }
}
