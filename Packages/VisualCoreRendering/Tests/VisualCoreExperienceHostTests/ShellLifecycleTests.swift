// ShellLifecycleTests — feature 188 (UA-F02) T-U02-036 (US5 and the shell's part of US6; contract
// specs/188-ua-f02-experience-sdk/contracts/experience-host-api.md). Preparation off the main actor and its
// cancellation, failures of preparation, setup and drawing, what reaches the presenter in which state, the
// diagnostics in every state, and the rule that the shell refuses what the engine refuses, with the same error.
import XCTest
import VisualCoreRendering
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreTestSupport

@MainActor
final class ShellLifecycleTests: XCTestCase {
    // MARK: Preparation

    func testPrepareEndsInReadyWithTheStateOfTheSeed() async throws {
        let (presenter, shell) = makeSampleShell(NoFault.self)
        XCTAssertEqual(shell.state, .registered)
        XCTAssertEqual(shell.id, SampleExperience.id)
        try await shell.prepare(seed: 42, timeLimit: nil)
        XCTAssertEqual(shell.state, .ready)
        XCTAssertEqual(shell.engine.seed, 42)
        XCTAssertEqual(shell.engine.stepIndex, 0)
        var mirror = SampleEngine(id: SampleExperience.id)
        try await mirror.prepare(seed: 42)
        XCTAssertEqual(try shell.engine.digest(), try mirror.digest())
        XCTAssertEqual(presenter.drawCalls, 0)
        XCTAssertEqual(presenter.setupCalls, 0, "the shell never creates a render host")
    }

    /// The sample core cannot report its thread. What can be observed: while the slow preparation is pending,
    /// the main actor keeps running this test, and a cancellation is answered at once.
    func testPreparationRunsOffTheMainActorAndCancelPreparationEndsInInactiveWithinOneSecond() async throws {
        let (presenter, shell) = makeSampleShell(SlowPreparation.self)
        let pending = Task { @MainActor in
            await asyncRefusal { try await shell.prepare(seed: 7, timeLimit: nil) }
        }
        let started = await waitUntil { shell.state == .preparing }
        XCTAssertTrue(started, "the preparation started")
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(shell.state, .preparing, "the main actor is free while the core prepares")
        XCTAssertNil(shell.engine.core)

        let clock = ContinuousClock()
        let start = clock.now
        shell.cancelPreparation()
        XCTAssertEqual(shell.state, .inactive, "cancelPreparation answers at once")
        let outcome = await pending.value
        let elapsed = clock.now - start
        XCTAssertLessThan(elapsed, .seconds(1))
        XCTAssertTrue(outcome == .cancelled || outcome == .stalePreparation, "got \(String(describing: outcome))")
        XCTAssertEqual(shell.state, .inactive)

        // A late result changes nothing, and nothing is drawn afterwards.
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(shell.state, .inactive)
        XCTAssertNil(shell.engine.core)
        let host = try makeLaidOutHost(shell.scene)
        defer { host.destroy() }
        for _ in 0..<3 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(presenter.drawCalls, 0)
        // Calling it again, when nothing is being prepared, does nothing.
        shell.cancelPreparation()
        XCTAssertEqual(shell.state, .inactive)
    }

    func testCancellingTheCallersTaskCancelsThePreparation() async throws {
        let (presenter, shell) = makeSampleShell(SlowPreparation.self)
        let pending = Task { @MainActor in
            await asyncRefusal { try await shell.prepare(seed: 7, timeLimit: nil) }
        }
        let started = await waitUntil { shell.state == .preparing }
        XCTAssertTrue(started, "the preparation started")

        let clock = ContinuousClock()
        let start = clock.now
        pending.cancel()
        let outcome = await pending.value
        XCTAssertLessThan(clock.now - start, .seconds(1))
        XCTAssertTrue(outcome == .cancelled || outcome == .stalePreparation, "got \(String(describing: outcome))")
        XCTAssertEqual(shell.state, .inactive)
        XCTAssertNil(shell.engine.core)
        XCTAssertEqual(presenter.drawCalls, 0)
    }

    func testATimeLimitEndsTheSlowPreparationInFailed() async throws {
        let (_, shell) = makeSampleShell(SlowPreparation.self)
        let outcome = await asyncRefusal { try await shell.prepare(seed: 7, timeLimit: .milliseconds(50)) }
        XCTAssertEqual(outcome, .preparationTimedOut)
        XCTAssertEqual(shell.state, .failed)
        XCTAssertEqual(shell.diagnostics.lastError?.code, "experience.preparation-timeout")
    }

    func testAFailingPreparationEndsInFailedAndCanBePreparedAgain() async throws {
        let (presenter, shell) = makeSampleShell(FailingPreparation.self)
        let first = await asyncRefusal { try await shell.prepare(seed: 42, timeLimit: nil) }
        XCTAssertEqual(first?.code, "sample.broken")
        XCTAssertEqual(shell.state, .failed)
        XCTAssertEqual(shell.diagnostics.lastError?.code, "sample.broken")
        XCTAssertNil(shell.engine.core)

        // Preparing again is legal in failed: the preparation runs again (and, with this fault, fails again
        // with the core's own code, not with a refusal of the operation).
        let refusedBefore = shell.diagnostics.rejectedOperations
        let second = await asyncRefusal { try await shell.prepare(seed: 43, timeLimit: nil) }
        XCTAssertEqual(second?.code, "sample.broken")
        XCTAssertEqual(shell.state, .failed)
        XCTAssertEqual(shell.engine.seed, 43)
        XCTAssertEqual(shell.diagnostics.rejectedOperations, refusedBefore)
        XCTAssertEqual(presenter.drawCalls, 0)

        // And a failed experience can be left.
        try shell.beginDeactivation()
        try shell.finishDeactivation()
        XCTAssertEqual(shell.state, .inactive)
    }

    func testAfterAFailureTheSameShellPreparesAgainAndDraws() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        defer { host.destroy() }
        presenter.failsInDraw = true
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(shell.state, .failed)

        presenter.failsInDraw = false
        try await shell.prepare(seed: 43, timeLimit: nil)
        XCTAssertEqual(shell.state, .ready)
        XCTAssertNil(shell.diagnostics.lastError)
        XCTAssertEqual(shell.engine.seed, 43)
        host.replaceScene(shell.scene)   // the host stopped drawing the failed scene; setting it again starts over
        let drawn = presenter.drawCalls
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(presenter.drawCalls, drawn + 1)
        XCTAssertTrue(centreShowsState(host, shell))
    }

    // MARK: Failures of setup and drawing

    func testSetupThatThrowsEndsInFailedAndTheLeaveStillEndsInInactive() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        presenter.failsInSetup = true
        let host = try makeLaidOutHost(shell.scene)
        XCTAssertEqual(presenter.setupCalls, 1)
        XCTAssertEqual(shell.state, .failed)
        XCTAssertEqual(shell.diagnostics.lastError?.code, "experience.setup-failed")
        XCTAssertFalse(shell.isSetUp)
        guard case .scene? = host.lastError else {
            return XCTFail("the error is rethrown to the host, got \(String(describing: host.lastError))")
        }
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(presenter.drawCalls, 0)

        try shell.beginDeactivation()
        XCTAssertEqual(shell.state, .deactivating)
        host.destroy()
        try shell.finishDeactivation()
        XCTAssertEqual(shell.state, .inactive)
        XCTAssertEqual(host.resources.stats.liveTotal, 0)
        XCTAssertEqual(host.resources.stats.leaked, 0)
        XCTAssertEqual(shell.diagnostics.gpu, GPUResourceCounts(objects: 0, bytes: 0, leaked: 0))
    }

    func testDrawThatThrowsEndsInFailedAndTheLeaveStillEndsInInactive() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        try shell.activate()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(shell.state, .active)

        presenter.failsInDraw = true
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(shell.state, .failed)
        XCTAssertEqual(shell.diagnostics.lastError?.code, "experience.draw-failed")
        guard case .scene? = host.lastError else {
            return XCTFail("the error is rethrown to the host, got \(String(describing: host.lastError))")
        }
        let drawn = presenter.drawCalls
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(presenter.drawCalls, drawn, "nothing is drawn in failed")
        XCTAssertGreaterThan(host.resources.stats.liveTotal, 0, "the texture lives until teardown")

        try shell.beginDeactivation()
        host.destroy()
        XCTAssertEqual(presenter.teardownCalls, 1)
        try shell.finishDeactivation()
        XCTAssertEqual(shell.state, .inactive)
        XCTAssertEqual(host.resources.stats.liveTotal, 0)
        XCTAssertEqual(host.resources.stats.leaked, 0)
        XCTAssertEqual(shell.diagnostics.gpu, GPUResourceCounts(objects: 0, bytes: 0, leaked: 0))
    }

    // MARK: What reaches the presenter

    func testAfterBeginDeactivationNoDrawReachesThePresenterAndTeardownStillDoes() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        try shell.activate()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(presenter.drawCalls, 1)
        let steps = shell.engine.stepIndex

        try shell.beginDeactivation()
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(presenter.drawCalls, 1)
        XCTAssertEqual(shell.engine.stepIndex, steps)
        XCTAssertEqual(presenter.teardownCalls, 0)

        host.destroy()
        XCTAssertEqual(presenter.teardownCalls, 1)
        try shell.finishDeactivation()
        XCTAssertEqual(shell.state, .inactive)
        XCTAssertEqual(presenter.drawCalls, 1)
    }

    func testInSuspendedFramesDrawAndRunNoStep() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        defer { host.destroy() }
        try shell.activate()
        for _ in 0..<2 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertGreaterThan(shell.engine.stepIndex, 0)

        try shell.suspend()
        XCTAssertEqual(shell.state, .suspended)
        let steps = shell.engine.stepIndex, digest = try shell.engine.digest(), drawn = presenter.drawCalls
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(presenter.drawCalls, drawn + 5)
        XCTAssertEqual(shell.engine.stepIndex, steps)
        XCTAssertEqual(try shell.engine.digest(), digest)
        XCTAssertTrue(centreShowsState(host, shell))

        try shell.resume()
        XCTAssertEqual(shell.state, .active)
        for _ in 0..<2 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertGreaterThan(shell.engine.stepIndex, steps)
    }

    // MARK: Diagnostics

    func testDiagnosticsHoldEveryItemInEachStateAndGPUCountsOnceAContextWasSeen() async throws {
        let (presenter, shell) = makeSampleShell(NoFault.self)

        var diagnostics = shell.diagnostics                       // registered
        XCTAssertEqual(diagnostics.experience, SampleExperience.id)
        XCTAssertEqual(diagnostics.state, .registered)
        XCTAssertNil(diagnostics.seed)
        XCTAssertEqual(diagnostics.stepIndex, 0)
        XCTAssertEqual(diagnostics.qualityTier, 0)
        XCTAssertNil(diagnostics.gpu, "no context was seen yet")
        XCTAssertNil(diagnostics.lastError)
        XCTAssertNil(diagnostics.digest)
        XCTAssertEqual(diagnostics.rejectedTransitions, 0)
        XCTAssertEqual(diagnostics.rejectedOperations, 0)
        XCTAssertEqual(diagnostics.acceptedActions, 0)
        XCTAssertEqual(diagnostics.rejectedActions, 0)
        XCTAssertEqual(diagnostics.droppedTime, 0)
        XCTAssertEqual(diagnostics.invalidFrames, 0)
        XCTAssertEqual(diagnostics, shell.engine.diagnostics(gpu: nil))

        try await shell.prepare(seed: 42, timeLimit: nil)
        diagnostics = shell.diagnostics                           // ready, still without a context
        XCTAssertEqual(diagnostics.state, .ready)
        XCTAssertEqual(diagnostics.seed, 42)
        XCTAssertEqual(diagnostics.digest, try shell.engine.digest())
        XCTAssertNil(diagnostics.gpu)

        let host = try makeLaidOutHost(shell.scene)
        diagnostics = shell.diagnostics                           // ready, with a context
        XCTAssertEqual(diagnostics.gpu?.objects, host.resources.stats.liveTotal)
        XCTAssertEqual(diagnostics.gpu?.bytes, host.resources.stats.totalBytes)
        XCTAssertEqual(diagnostics.gpu?.leaked, host.resources.stats.leaked)
        XCTAssertEqual(diagnostics.gpu?.objects, 1)

        try shell.activate()
        try shell.setQualityTier(2)
        XCTAssertEqual(shell.handle(control: "tone", values: [0.5]), .accepted)
        XCTAssertEqual(shell.handle(control: "tone", values: [2]), .rejected(.outOfRange(index: 0)))
        for _ in 0..<3 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        diagnostics = shell.diagnostics                           // active
        XCTAssertEqual(diagnostics.state, .active)
        XCTAssertEqual(diagnostics.stepIndex, shell.engine.stepIndex)
        XCTAssertGreaterThan(diagnostics.stepIndex, 0)
        XCTAssertEqual(diagnostics.qualityTier, 2)
        XCTAssertEqual(diagnostics.acceptedActions, 1)
        XCTAssertEqual(diagnostics.rejectedActions, 1)
        XCTAssertEqual(diagnostics.digest, try shell.engine.digest())
        XCTAssertEqual(diagnostics.gpu?.objects, 1)
        XCTAssertEqual(presenter.lastTier, 2)

        XCTAssertEqual(refusal { try shell.activate() }, .illegalOperation(.activate, in: .active))
        try shell.suspend()
        diagnostics = shell.diagnostics                           // suspended
        XCTAssertEqual(diagnostics.state, .suspended)
        XCTAssertEqual(diagnostics.rejectedOperations, 1)
        XCTAssertNotNil(diagnostics.digest)
        XCTAssertNotNil(diagnostics.gpu)

        try shell.beginDeactivation()
        diagnostics = shell.diagnostics                           // deactivating
        XCTAssertEqual(diagnostics.state, .deactivating)
        XCTAssertEqual(diagnostics.seed, 42)
        XCTAssertNotNil(diagnostics.gpu)

        host.destroy()
        try shell.finishDeactivation()
        diagnostics = shell.diagnostics                           // inactive
        XCTAssertEqual(diagnostics.state, .inactive)
        XCTAssertNil(diagnostics.digest)
        XCTAssertNil(diagnostics.lastError)
        XCTAssertEqual(diagnostics.gpu, GPUResourceCounts(objects: 0, bytes: 0, leaked: 0))
        XCTAssertEqual(diagnostics.experience, SampleExperience.id)
        XCTAssertFalse(try diagnostics.encoded().isEmpty)
    }

    func testDiagnosticsWhilePreparingAndAfterAFailure() async throws {
        let (_, slow) = makeSampleShell(SlowPreparation.self)
        let pending = Task { @MainActor in
            await asyncRefusal { try await slow.prepare(seed: 7, timeLimit: nil) }
        }
        let started = await waitUntil { slow.state == .preparing }
        XCTAssertTrue(started, "the preparation started")
        var diagnostics = slow.diagnostics                        // preparing
        XCTAssertEqual(diagnostics.state, .preparing)
        XCTAssertEqual(diagnostics.seed, 7)
        XCTAssertNil(diagnostics.digest)
        XCTAssertNil(diagnostics.gpu)
        XCTAssertNil(diagnostics.lastError)
        slow.cancelPreparation()
        _ = await pending.value

        let (presenter, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        defer { host.destroy() }
        presenter.failsInDraw = true
        XCTAssertTrue(host.renderOneFrame(present: false))
        diagnostics = shell.diagnostics                           // failed
        XCTAssertEqual(diagnostics.state, .failed)
        XCTAssertEqual(diagnostics.lastError?.code, "experience.draw-failed")
        XCTAssertFalse(diagnostics.lastError?.message.isEmpty ?? true)
        XCTAssertEqual(diagnostics.experience, SampleExperience.id)
        XCTAssertEqual(diagnostics.seed, 42)
        XCTAssertEqual(diagnostics.gpu?.objects, host.resources.stats.liveTotal)
        XCTAssertEqual(diagnostics.gpu?.leaked, 0)
        XCTAssertFalse(try diagnostics.encoded().isEmpty)
    }

    // MARK: Refusals

    private static let checkedOperations: [ExperienceOperation] =
        [.activate, .suspend, .resume, .snapshot, .restore, .reset, .setQualityTier, .shedCaches, .deactivate]

    private func shellRefusal(_ operation: ExperienceOperation, _ shell: SampleShell,
                              _ snapshot: ExperienceSnapshot) -> ExperienceError? {
        refusal {
            switch operation {
            case .activate: try shell.activate()
            case .suspend: try shell.suspend()
            case .resume: try shell.resume()
            case .snapshot: _ = try shell.snapshot()
            case .restore: try shell.restore(snapshot)
            case .reset: try shell.reset()
            case .setQualityTier: try shell.setQualityTier(1)
            case .shedCaches: try shell.shedCaches()
            case .deactivate: try shell.beginDeactivation()
            case .prepare, .update, .action: break
            }
        }
    }

    private func engineRefusal(_ operation: ExperienceOperation, _ engine: inout SampleEngine,
                               _ snapshot: ExperienceSnapshot) -> ExperienceError? {
        refusal {
            switch operation {
            case .activate: try engine.activate()
            case .suspend: try engine.suspend()
            case .resume: try engine.resume()
            case .snapshot: _ = try engine.snapshot()
            case .restore: try engine.restore(snapshot)
            case .reset: try engine.reset()
            case .setQualityTier: try engine.setQualityTier(1)
            case .shedCaches: try engine.shedCaches()
            case .deactivate: try engine.beginDeactivation()
            case .prepare, .update, .action: break
            }
        }
    }

    /// Calls every operation that is illegal in `state` on the shell and on a pure engine in the same state and
    /// compares the answers.
    private func checkRefusals(in state: ExperienceLifecycleState, _ shell: SampleShell, _ engine: inout SampleEngine,
                               _ snapshot: ExperienceSnapshot, _ presenter: SamplePresenter<NoFault>) async {
        XCTAssertEqual(shell.state, state)
        XCTAssertEqual(engine.lifecycle.state, state)
        let shed = presenter.shedCalls
        for operation in Self.checkedOperations where !ExperienceLifecycle.isLegal(operation, in: state) {
            let fromShell = shellRefusal(operation, shell, snapshot)
            let fromEngine = engineRefusal(operation, &engine, snapshot)
            XCTAssertEqual(fromShell, .illegalOperation(operation, in: state), "\(operation) in \(state)")
            XCTAssertEqual(fromShell, fromEngine, "\(operation) in \(state)")
            XCTAssertEqual(shell.state, state, "\(operation) in \(state)")
        }
        XCTAssertEqual(presenter.shedCalls, shed, "a refused shedding does not reach the presenter")
        if !ExperienceLifecycle.isLegal(.prepare, in: state) {
            let fromShell = await asyncRefusal { try await shell.prepare(seed: 1, timeLimit: nil) }
            var fromEngine: ExperienceError?
            do { try await engine.prepare(seed: 1) } catch { fromEngine = error }
            XCTAssertEqual(fromShell, .illegalOperation(.prepare, in: state), "prepare in \(state)")
            XCTAssertEqual(fromShell, fromEngine, "prepare in \(state)")
        }
        if state != .deactivating {
            let fromShell = refusal { try shell.finishDeactivation() }
            let fromEngine = refusal { try engine.finishDeactivation(gpu: nil) }
            XCTAssertNotNil(fromShell, "finishDeactivation in \(state)")
            XCTAssertEqual(fromShell, fromEngine, "finishDeactivation in \(state)")
        }
        if state != .active {
            let fromShell = shell.handle(control: "ping", values: [])
            XCTAssertEqual(fromShell, .rejected(.notActive(state)), "an action in \(state)")
            let fromEngine = engine.handle(control: "ping")
            XCTAssertEqual(fromShell, fromEngine)
        }
        XCTAssertEqual(shell.state, engine.lifecycle.state)
        XCTAssertEqual(shell.diagnostics.rejectedOperations, engine.lifecycle.rejectedOperations, "in \(state)")
        XCTAssertEqual(shell.diagnostics.rejectedTransitions, engine.lifecycle.rejectedTransitions, "in \(state)")
        XCTAssertEqual(shell.diagnostics.rejectedActions, engine.rejectedActions, "in \(state)")
    }

    func testEveryOperationRefusedByTheEngineIsRefusedByTheShellWithTheSameError() async throws {
        var donor = SampleEngine(id: SampleExperience.id)
        try await donor.prepare(seed: 42)
        let snapshot = try donor.snapshot()

        let (presenter, shell) = makeSampleShell(NoFault.self)
        var engine = SampleEngine(id: SampleExperience.id)
        await checkRefusals(in: .registered, shell, &engine, snapshot, presenter)

        try await shell.prepare(seed: 42, timeLimit: nil)
        try await engine.prepare(seed: 42)
        await checkRefusals(in: .ready, shell, &engine, snapshot, presenter)

        // A tier the experience did not declare is refused in the same way, and nothing changes.
        for tier in [3, -1] {
            let fromShell = refusal { try shell.setQualityTier(tier) }
            let fromEngine = refusal { try engine.setQualityTier(tier) }
            XCTAssertEqual(fromShell?.code, "experience.invalid-tier", "tier \(tier)")
            XCTAssertEqual(fromShell, fromEngine, "tier \(tier)")
            XCTAssertEqual(shell.engine.qualityTier, 0)
        }

        try shell.activate()
        try engine.activate()
        await checkRefusals(in: .active, shell, &engine, snapshot, presenter)

        try shell.suspend()
        try engine.suspend()
        await checkRefusals(in: .suspended, shell, &engine, snapshot, presenter)

        try shell.beginDeactivation()
        try engine.beginDeactivation()
        await checkRefusals(in: .deactivating, shell, &engine, snapshot, presenter)

        try shell.finishDeactivation()
        try engine.finishDeactivation(gpu: nil)
        await checkRefusals(in: .inactive, shell, &engine, snapshot, presenter)

        XCTAssertGreaterThan(shell.diagnostics.rejectedOperations, 0)
        XCTAssertEqual(presenter.drawCalls, 0)
        XCTAssertEqual(try? shell.engine.digest(), try? engine.digest())
    }
}
