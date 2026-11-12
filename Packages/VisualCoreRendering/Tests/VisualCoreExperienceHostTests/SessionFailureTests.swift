// SessionFailureTests — feature 189 (UA-F03) T-U03-005 (US1 and US3; FR-U03-020 to FR-U03-023, FR-U03-030 to
// FR-U03-032; SC-U03-003, SC-U03-004; contract specs/189-ua-f03-experience-host/contracts/session-api.md).
// The three failure kinds (preparation, setup, drawing) and the timeout, Retry and Back, the cancellation of a
// preparation 20 of 20 times, an open that is superseded by a newer one, and a preparation result that arrives
// after the close. The helpers (`sampleRequest`, `SampleProbe`, `layOut`, …) are in SessionOpenCloseTests.swift.
import XCTest
import VisualCoreExperience
@testable import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreTestSupport

/// A switch a test flips between two factory calls of one request (the cause of a failure is removed).
@MainActor
private final class Switch {
    var isOn: Bool
    init(_ isOn: Bool) { self.isOn = isOn }
}

@MainActor
final class SessionFailureTests: XCTestCase {
    // MARK: Helpers

    /// Checks the failed state: the failure with its stage and code in the view state and in the diagnostics,
    /// no experience, no render host and no live object.
    private func assertFailed(_ session: ExperienceSession, stage: SessionStage, code: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(session.state, .failed, file: file, line: line)
        XCTAssertEqual(session.failure?.stage, stage, file: file, line: line)
        XCTAssertEqual(session.failure?.code, code, file: file, line: line)
        XCTAssertFalse(session.failure?.message.isEmpty ?? true, "the failure has a text", file: file, line: line)
        let diagnostics = session.diagnostics
        XCTAssertEqual(diagnostics.state, .failed, file: file, line: line)
        XCTAssertEqual(diagnostics.lastFailure, session.failure, file: file, line: line)
        XCTAssertEqual(diagnostics.lastFailure?.stage, stage, file: file, line: line)
        XCTAssertEqual(diagnostics.lastFailure?.code, code, file: file, line: line)
        XCTAssertNil(session.renderHost, file: file, line: line)
        XCTAssertEqual(session.hostsAlive, 0, file: file, line: line)
        XCTAssertNil(session.message, file: file, line: line)
    }

    /// Checks that no GPU object of `probe`'s experience is live or leaked: the presenter holds no texture and,
    /// when a graphics context was seen, the experience's own counts are 0.
    private func assertNoLiveObject<Fault: SampleFault>(_ probe: SampleProbe<Fault>,
                                                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(probe.presenter?.texture, file: file, line: line)
        if let gpu = probe.shell?.diagnostics.gpu {
            XCTAssertEqual(gpu.objects, 0, "live objects", file: file, line: line)
            XCTAssertEqual(gpu.leaked, 0, "leaked objects", file: file, line: line)
        }
    }

    /// Opens the healthy sample on `session` and checks that it runs and draws (SC-U03-003).
    private func assertHealthyOpenRuns(_ session: ExperienceSession,
                                       file: StaticString = #filePath, line: UInt = #line) async {
        let (request, probe) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running, file: file, line: line)
        XCTAssertEqual(session.state, .running, file: file, line: line)
        XCTAssertNil(session.failure, "the failure view is gone", file: file, line: line)
        XCTAssertEqual(session.hostsAlive, 1, file: file, line: line)
        layOut(session)
        XCTAssertTrue(drawFrame(session), file: file, line: line)
        XCTAssertTrue(sessionShowsState(session, probe), file: file, line: line)
    }

    // MARK: The three failure kinds (SC-U03-003)

    func testAFailingPreparationEndsInFailedAndTheHealthySampleOpensAfterwards() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = sampleRequest(FailingPreparation.self)
        let result = await session.open(request)
        guard case .failed(let failure) = result else { return XCTFail("got \(result)") }
        XCTAssertEqual(failure.stage, .prepare)
        XCTAssertEqual(failure.code, "sample.broken", "codes of the experience contract are passed through")
        XCTAssertEqual(session.failure, failure)
        assertFailed(session, stage: .prepare, code: "sample.broken")
        assertNoLiveObject(probe)
        XCTAssertEqual(probe.presenter?.setupCalls, 0, "no render host was created")
        XCTAssertEqual(probe.presenter?.drawCalls, 0)
        XCTAssertEqual(session.diagnostics.failures, 1)
        XCTAssertEqual(session.diagnostics.opens, 0, "a failed open is not counted as an open")
        XCTAssertNil(session.diagnostics.lastCloseCounts, "no render host existed, so no counts were read")
        XCTAssertNil(session.diagnostics.timings.createHost, "a stage that did not happen has no duration")

        await assertHealthyOpenRuns(session)
        XCTAssertEqual(session.diagnostics.failures, 1)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
    }

    func testAPresenterThatThrowsInSetupEndsInFailedAndTheHealthySampleOpensAfterwards() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = sampleRequest(configure: { $0.failsInSetup = true })
        let result = await session.open(request)
        guard case .failed(let failure) = result else { return XCTFail("got \(result)") }
        XCTAssertEqual(failure.stage, .setup)
        XCTAssertEqual(failure.code, "experience.setup-failed")
        assertFailed(session, stage: .setup, code: "experience.setup-failed")
        assertNoLiveObject(probe)
        XCTAssertEqual(probe.presenter?.setupCalls, 1)
        XCTAssertEqual(probe.presenter?.drawCalls, 0, "nothing is drawn after a failed setup")
        XCTAssertNotEqual(probe.shell?.state, .active, "a failed experience is not activated")
        // The host existed for a moment; the session destroyed it and read its counts.
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.leaked, 0)
        XCTAssertEqual(session.diagnostics.failures, 1)

        await assertHealthyOpenRuns(session)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
    }

    func testAPresenterThatThrowsInDrawEndsInFailedAndTheHealthySampleOpensAfterwards() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = sampleRequest(configure: { $0.failsInDraw = true })
        // Without a surface no frame is drawn inside `open`, so the open itself succeeds; the failure appears
        // with the first frame after the layout, through the render host's error observer.
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        let host = try XCTUnwrap(session.renderHost)
        layOut(session)
        host.renderOneFrame(present: false)
        let failed = await waitUntil { session.state == .failed }
        XCTAssertTrue(failed, "the draw error reached the session; state \(session.state)")
        assertFailed(session, stage: .draw, code: "experience.draw-failed")
        XCTAssertEqual(probe.presenter?.drawCalls, 1, "a failed scene is not drawn again")
        XCTAssertEqual(probe.presenter?.teardownCalls, 1, "the host was destroyed with the scene torn down")
        XCTAssertEqual(host.state, .destroyed)
        assertNoLiveObject(probe)
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.leaked, 0)
        XCTAssertEqual(session.diagnostics.failures, 1)

        await assertHealthyOpenRuns(session)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
    }

    // MARK: Timeout (FR-U03-022)

    func testTheSlowSampleWithATimeLimitOf100MillisecondsFailsWithTheTimeoutCode() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = sampleRequest(SlowPreparation.self, timeLimit: .milliseconds(100))
        let clock = ContinuousClock()
        let start = clock.now
        let result = await session.open(request)
        let elapsed = clock.now - start
        guard case .failed(let failure) = result else { return XCTFail("got \(result)") }
        XCTAssertEqual(failure.stage, .prepare)
        XCTAssertEqual(failure.code, "experience.preparation-timeout")
        XCTAssertGreaterThanOrEqual(elapsed, .milliseconds(100))
        XCTAssertLessThan(elapsed, .seconds(5), "the time limit ended the preparation of about 60 seconds")
        assertFailed(session, stage: .prepare, code: "experience.preparation-timeout")
        assertNoLiveObject(probe)
        XCTAssertEqual(probe.presenter?.setupCalls, 0)

        await assertHealthyOpenRuns(session)
    }

    // MARK: Retry and Back (FR-U03-021)

    func testRetryAfterTheCauseIsRemovedRunsWithTheSameSeed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let broken = Switch(true)
        let (request, probe) = sampleRequest(seed: 1_000, configure: { $0.failsInSetup = broken.isOn })
        let first = await session.open(request)
        guard case .failed = first else { return XCTFail("got \(first)") }
        assertFailed(session, stage: .setup, code: "experience.setup-failed")

        // Retry with the cause still there fails again, with a new experience from the same request.
        let second = await session.retry()
        guard case .failed = second else { return XCTFail("got \(second)") }
        assertFailed(session, stage: .setup, code: "experience.setup-failed")
        XCTAssertEqual(probe.makes, 2)
        XCTAssertEqual(session.diagnostics.failures, 2)

        broken.isOn = false
        let third = await session.retry()
        XCTAssertEqual(third, .running)
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(probe.makes, 3, "every retry builds a new experience")
        XCTAssertTrue(session.experience === probe.shell)
        XCTAssertEqual(probe.shell?.engine.seed, 1_000, "the retry uses the seed of the failed request")
        XCTAssertEqual(try probe.digest().hex, goldenDigest(seed: 1_000))
        XCTAssertNil(session.failure, "the failure view is gone")
        XCTAssertEqual(session.hostsAlive, 1)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
        layOut(session)
        XCTAssertTrue(drawFrame(session))
        XCTAssertTrue(sessionShowsState(session, probe))
    }

    func testRetryOutsideFailedIsRefusedWithoutEffect() async throws {
        let session = ExperienceSession()
        defer { session.close() }

        // Idle: nothing to retry.
        let idleBefore = session.diagnostics
        _ = await session.retry()
        assertHoldsNothing(session)
        XCTAssertEqual(session.diagnostics.opens, idleBefore.opens)

        // Running: the experience stays as it is.
        let (request, probe) = sampleRequest()
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        let digest = try probe.digest()
        let host = session.renderHost
        let runningBefore = session.diagnostics
        _ = await session.retry()
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(probe.makes, 1, "no new experience was built")
        XCTAssertTrue(session.experience === probe.shell)
        XCTAssertTrue(session.renderHost === host)
        XCTAssertEqual(try probe.digest(), digest)
        XCTAssertEqual(session.diagnostics.opens, runningBefore.opens)
        XCTAssertEqual(session.diagnostics.closes, runningBefore.closes)
        XCTAssertEqual(session.hostsAlive, 1)
        session.close()

        // Idle after a close (the last request exists, but the session did not fail).
        _ = await session.retry()
        assertHoldsNothing(session)
        XCTAssertEqual(probe.makes, 1)

        // Preparing: one preparation at a time.
        let (slow, slowProbe) = sampleRequest(SlowPreparation.self)
        let pending = openInBackground(session, slow)
        let preparing = await waitUntil { session.state == .preparing }
        XCTAssertTrue(preparing)
        _ = await session.retry()
        XCTAssertEqual(session.state, .preparing)
        XCTAssertEqual(slowProbe.makes, 1)
        XCTAssertEqual(session.hostsAlive, 0)
        session.close()
        let cancelled = await pending.value
        XCTAssertEqual(cancelled, .cancelled)

        // After Back the failure is gone from view and cannot be retried.
        let (failing, failingProbe) = sampleRequest(FailingPreparation.self)
        let failed = await session.open(failing)
        guard case .failed = failed else { return XCTFail("got \(failed)") }
        session.back()
        _ = await session.retry()
        assertHoldsNothing(session)
        XCTAssertEqual(failingProbe.makes, 1)
    }

    func testBackMakesTheSessionIdleAndKeepsTheFailureInTheDiagnostics() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, _) = sampleRequest(FailingPreparation.self)
        let result = await session.open(request)
        guard case .failed(let failure) = result else { return XCTFail("got \(result)") }

        session.back()
        assertHoldsNothing(session)
        XCTAssertNil(session.failure, "the failure is cleared from the view state")
        XCTAssertEqual(session.diagnostics.lastFailure, failure, "and stays in the diagnostics")
        XCTAssertEqual(session.diagnostics.failures, 1)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)

        // Back when idle does nothing; close in failed behaves as Back.
        session.back()
        assertHoldsNothing(session)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
        let again = await session.open(request)
        guard case .failed = again else { return XCTFail("got \(again)") }
        session.close()
        assertHoldsNothing(session)
        XCTAssertNil(session.failure)
        XCTAssertEqual(session.diagnostics.lastFailure, failure)
        XCTAssertEqual(session.diagnostics.failures, 2)

        await assertHealthyOpenRuns(session)
    }

    func testBackWhileRunningChangesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        session.back()
        XCTAssertEqual(session.state, .running)
        XCTAssertTrue(session.experience === probe.shell)
        XCTAssertEqual(session.hostsAlive, 1)
        XCTAssertEqual(probe.shell?.state, .active)
    }

    // MARK: Cancellation (SC-U03-004)

    func testClosingTheSlowSample50MillisecondsAfterOpenCancelsIt20Of20Times() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let clock = ContinuousClock()
        for round in 1...20 {
            let (request, probe) = sampleRequest(SlowPreparation.self, seed: UInt64(round))
            let pending = openInBackground(session, request)
            try await Task.sleep(for: .milliseconds(50))
            XCTAssertEqual(session.state, .preparing, "round \(round)")
            XCTAssertEqual(probe.makes, 1, "round \(round)")

            let start = clock.now
            session.close()
            XCTAssertEqual(session.state, .idle, "round \(round): the close answers at once")
            let result = await pending.value
            let elapsed = clock.now - start
            XCTAssertEqual(result, .cancelled, "round \(round)")
            XCTAssertLessThan(elapsed, .seconds(1), "round \(round)")

            XCTAssertEqual(session.state, .idle, "round \(round)")
            XCTAssertNil(session.experience, "round \(round)")
            XCTAssertNil(session.renderHost, "round \(round): no render host for a cancelled preparation")
            XCTAssertEqual(session.hostsAlive, 0, "round \(round)")
            XCTAssertNil(session.failure, "round \(round): a cancellation is not a failure")
            // A render host runs the scene's setup when it is created: 0 setups also means 0 hosts.
            XCTAssertEqual(probe.presenter?.setupCalls, 0, "round \(round)")
            XCTAssertEqual(probe.presenter?.drawCalls, 0, "round \(round)")
            XCTAssertEqual(probe.presenter?.controlsCalls, 0, "round \(round)")
            XCTAssertEqual(probe.presenter?.shedCalls, 0, "round \(round)")
            XCTAssertEqual(probe.shell?.engine.acceptedActions, 0, "round \(round)")
            XCTAssertEqual(probe.shell?.engine.rejectedActions, 0, "round \(round)")
            XCTAssertEqual(probe.shell?.state, .inactive, "round \(round)")
            XCTAssertNil(probe.shell?.engine.core, "round \(round)")

            let diagnostics = session.diagnostics
            XCTAssertEqual(diagnostics.cancelledPreparations, round)
            XCTAssertEqual(diagnostics.lastCloseSteps, SessionCloseStep.cancelOrder, "round \(round)")
            XCTAssertEqual(diagnostics.failures, 0, "round \(round)")
            XCTAssertEqual(diagnostics.rejectedTransitions, 0, "round \(round)")
        }
        XCTAssertEqual(session.diagnostics.opens, 0, "no open reached running or suspended")
        XCTAssertEqual(session.diagnostics.closes, 0, "a cancelled preparation is not a full close")
        XCTAssertNil(session.diagnostics.lastFailure)

        // The session is usable afterwards.
        await assertHealthyOpenRuns(session)
    }

    // MARK: Superseded open (FR-U03-004, FR-U03-030)

    func testOpeningTheHealthySampleWhileTheSlowOnePreparesSupersedesTheFirst() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (slow, slowProbe) = sampleRequest(SlowPreparation.self, seed: 7)
        let (healthy, healthyProbe) = sampleRequest(seed: 42)

        let pending = openInBackground(session, slow)
        let preparing = await waitUntil { session.state == .preparing }
        XCTAssertTrue(preparing, "the slow sample is preparing")

        let clock = ContinuousClock()
        let start = clock.now
        let second = await session.open(healthy)
        XCTAssertEqual(second, .running)
        let first = await pending.value
        XCTAssertEqual(first, .superseded)
        XCTAssertLessThan(clock.now - start, .seconds(5), "the newer open did not wait for the slow preparation")

        XCTAssertEqual(session.state, .running)
        XCTAssertTrue(session.experience === healthyProbe.shell)
        XCTAssertEqual(session.diagnostics.experience, SampleExperience.id)
        XCTAssertEqual(try healthyProbe.digest().hex, goldenDigest(seed: 42))
        XCTAssertEqual(session.hostsAlive, 1)
        XCTAssertNil(session.failure)
        XCTAssertEqual(session.diagnostics.supersededOpens, 1)
        XCTAssertEqual(session.diagnostics.cancelledPreparations, 1, "the replaced preparation was cancelled")
        XCTAssertEqual(session.diagnostics.opens, 1, "only the newer open reached running")
        XCTAssertEqual(session.diagnostics.failures, 0)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)

        // What the superseded open built was released without reaching a render host.
        XCTAssertEqual(slowProbe.shell?.state, .inactive)
        XCTAssertNil(slowProbe.shell?.engine.core)
        XCTAssertEqual(slowProbe.presenter?.setupCalls, 0)
        XCTAssertEqual(slowProbe.presenter?.drawCalls, 0)
        layOut(session)
        XCTAssertTrue(drawFrame(session))
        XCTAssertTrue(sessionShowsState(session, healthyProbe))
    }

    // MARK: Late result (FR-U03-031)

    /// The healthy sample prepares in a few milliseconds. The test closes the session as soon as it sees the
    /// state preparing, so the preparation's result (a finished state, or the cancellation) arrives after the
    /// close. A round in which the preparation was already over when the test looked is repeated.
    func testAPreparationResultThatArrivesAfterTheCloseChangesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        var caught = 0
        for round in 1...40 where caught < 5 {
            let (request, probe) = sampleRequest(seed: UInt64(round))
            let pending = openInBackground(session, request)
            while session.state == .idle, probe.makes == 0 { await Task.yield() }
            guard session.state == .preparing else {
                _ = await pending.value
                session.close()
                continue
            }
            caught += 1
            session.close()
            XCTAssertEqual(session.state, .idle)
            let result = await pending.value
            XCTAssertEqual(result, .cancelled, "round \(round)")

            try await Task.sleep(for: .milliseconds(100))   // time for a late result to arrive
            assertHoldsNothing(session)
            XCTAssertNil(session.failure, "round \(round)")
            XCTAssertEqual(probe.presenter?.setupCalls, 0, "round \(round)")
            XCTAssertEqual(probe.presenter?.drawCalls, 0, "round \(round)")
            XCTAssertEqual(probe.shell?.state, .inactive, "round \(round)")
            XCTAssertNil(probe.shell?.engine.core, "round \(round): the late result was discarded")
            XCTAssertEqual(session.diagnostics.failures, 0, "round \(round)")
            XCTAssertEqual(session.diagnostics.rejectedTransitions, 0, "round \(round)")
        }
        XCTAssertGreaterThan(caught, 0, "no round caught the session while it was preparing")

        // The slow sample: its result after the close is the cancellation, at the latest 10 ms later.
        let (slow, slowProbe) = sampleRequest(SlowPreparation.self)
        let pending = openInBackground(session, slow)
        let preparing = await waitUntil { session.state == .preparing }
        XCTAssertTrue(preparing)
        session.close()
        try await Task.sleep(for: .milliseconds(100))
        assertHoldsNothing(session)
        let result = await pending.value
        XCTAssertEqual(result, .cancelled)
        assertHoldsNothing(session)
        XCTAssertEqual(slowProbe.presenter?.setupCalls, 0)
        XCTAssertEqual(session.diagnostics.failures, 0)
    }
}
