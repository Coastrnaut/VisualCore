// SessionOpenCloseTests — feature 189 (UA-F03) T-U03-004 (US2; FR-U03-002 to FR-U03-006, FR-U03-010 to FR-U03-013;
// SC-U03-001, SC-U03-002; contract specs/189-ua-f03-experience-host/contracts/session-api.md). Opening and closing
// the sample through `ExperienceSession`: the result and the picture of an open, the order of a close, one render
// host at a time, 50 cycles without a live or leaked object, a deliberate leak, and snapshots at open.
// The helpers at the top are shared with SessionFailureTests and SessionPhaseMemoryTests. Test-only.
import UIKit
import XCTest
import VisualCoreExperience
@testable import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreTestSupport

// MARK: - Shared helpers of the three session test files

/// What a test keeps of the experiences a request's factory built: every typed shell, in the order of creation,
/// and what to do with a new presenter before the session sees it.
@MainActor
final class SampleProbe<Fault: SampleFault> {
    /// Every shell the factory built, oldest first.
    private(set) var shells: [ExperienceShell<SamplePresenter<Fault>>] = []
    /// Called with every new presenter before the factory returns (to set the failure switches).
    var configure: ((SamplePresenter<Fault>) -> Void)?
    /// Called at the start of every factory call, before anything is built.
    var onMake: (() -> Void)?

    /// How often the factory was called.
    var makes: Int { shells.count }
    /// The shell of the last factory call.
    var shell: ExperienceShell<SamplePresenter<Fault>>? { shells.last }
    /// The presenter of the last factory call.
    var presenter: SamplePresenter<Fault>? { shells.last?.presenter }

    /// The factory of the request.
    func make() -> any Experience {
        onMake?()
        let made = makeSampleShell(Fault.self)
        configure?(made.presenter)
        shells.append(made.shell)
        return made.shell
    }

    /// The digest of the last shell's state; throws without a shell or without a state.
    func digest() throws -> StateDigest {
        try XCTUnwrap(shell, "the factory was not called").engine.digest()
    }

    /// The step index of the last shell; -1 without a shell.
    var stepIndex: Int { shell?.engine.stepIndex ?? -1 }
}

/// An open request for the sample and the probe that sees what its factory builds.
@MainActor
func sampleRequest<Fault: SampleFault>(
    _ fault: Fault.Type, seed: UInt64 = 42, snapshot: ExperienceSnapshot? = nil,
    memoryPressureLimit: Int? = nil, timeLimit: Duration = .seconds(10),
    configure: ((SamplePresenter<Fault>) -> Void)? = nil, onMake: (() -> Void)? = nil
) -> (request: ExperienceOpenRequest, probe: SampleProbe<Fault>) {
    let probe = SampleProbe<Fault>()
    probe.configure = configure
    probe.onMake = onMake
    // The budget stays the default of the request (256 MiB in total, so the default limit is 128 MiB).
    let request = ExperienceOpenRequest(id: SampleExperience.id, seed: seed, snapshot: snapshot,
                                        memoryPressureLimit: memoryPressureLimit, timeLimit: timeLimit) {
        probe.make()
    }
    return (request, probe)
}

/// An open request for the healthy sample (no fault).
@MainActor
func sampleRequest(
    seed: UInt64 = 42, snapshot: ExperienceSnapshot? = nil, memoryPressureLimit: Int? = nil,
    timeLimit: Duration = .seconds(10), configure: ((SamplePresenter<NoFault>) -> Void)? = nil,
    onMake: (() -> Void)? = nil
) -> (request: ExperienceOpenRequest, probe: SampleProbe<NoFault>) {
    sampleRequest(NoFault.self, seed: seed, snapshot: snapshot, memoryPressureLimit: memoryPressureLimit,
                  timeLimit: timeLimit, configure: configure, onMake: onMake)
}

/// The error a `SnapshotLog` throws when a test asks its sink to fail.
struct SampleSinkError: Error, Equatable {}

/// A snapshot sink that keeps what it receives and can be told to throw.
@MainActor
final class SnapshotLog {
    /// Every snapshot the sink received, oldest first (also the ones it then refused by throwing).
    private(set) var snapshots: [ExperienceSnapshot] = []
    /// The sink throws after it recorded the snapshot.
    var fails = false
    /// Called for every snapshot, after it was recorded.
    var onSnapshot: (() -> Void)?

    /// How many snapshots arrived.
    var count: Int { snapshots.count }

    /// The sink to hand to `ExperienceSession(snapshotSink:)`.
    var sink: ExperienceSession.SnapshotSink {
        { [self] snapshot in
            snapshots.append(snapshot)
            onSnapshot?()
            if fails { throw SampleSinkError() }
        }
    }
}

/// Gives the session's render host a view of 64 × 64 points, so that a window surface exists. The session
/// creates the host only after the preparation; without a host this does nothing.
@MainActor
func layOut(_ session: ExperienceSession) {
    guard let view = session.renderHost?.view else { return }
    view.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
    view.layoutIfNeeded()
}

/// Draws one frame on the session's host without presenting it. False without a host or without a surface.
@MainActor
@discardableResult
func drawFrame(_ session: ExperienceSession) -> Bool {
    session.renderHost?.renderOneFrame(present: false) ?? false
}

/// Whether the centre pixel of the session's host shows the state of the probe's last shell.
@MainActor
func sessionShowsState<Fault: SampleFault>(_ session: ExperienceSession, _ probe: SampleProbe<Fault>) -> Bool {
    guard let host = session.renderHost, let shell = probe.shell else { return false }
    return centreShowsState(host, shell)
}

/// Starts `open` in a main-actor task, so that the test can act while the experience prepares.
@MainActor
func openInBackground(_ session: ExperienceSession,
                      _ request: ExperienceOpenRequest) -> Task<SessionOpenResult, Never> {
    Task { @MainActor in await session.open(request) }
}

/// The committed digest of the sample right after a preparation with `seed`; nil for a seed without one.
func goldenDigest(seed: UInt64) -> String? {
    SampleExperience.goldenDigests.first { $0.seed == seed }?.hex
}

/// Checks that the session holds nothing: idle, no experience, no host, no host alive.
@MainActor
func assertHoldsNothing(_ session: ExperienceSession, _ state: SessionState = .idle,
                        file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(session.state, state, file: file, line: line)
    XCTAssertNil(session.experience, file: file, line: line)
    XCTAssertNil(session.renderHost, file: file, line: line)
    XCTAssertEqual(session.hostsAlive, 0, file: file, line: line)
    XCTAssertEqual(session.diagnostics.state, state, file: file, line: line)
    XCTAssertNil(session.diagnostics.experience, file: file, line: line)
}

/// Checks that the last close took the seven steps in order and left 0 live and 0 leaked objects.
@MainActor
func assertClosedCleanly(_ session: ExperienceSession, file: StaticString = #filePath, line: UInt = #line) {
    let diagnostics = session.diagnostics
    XCTAssertEqual(diagnostics.lastCloseSteps, SessionCloseStep.order, file: file, line: line)
    XCTAssertEqual(diagnostics.lastCloseCounts?.objects, 0, "live objects after the close", file: file, line: line)
    XCTAssertEqual(diagnostics.lastCloseCounts?.leaked, 0, "leaked objects after the close", file: file, line: line)
    XCTAssertEqual(diagnostics.lastCloseCounts?.bytes, 0, "live bytes after the close", file: file, line: line)
}

// MARK: - Tests

@MainActor
final class SessionOpenCloseTests: XCTestCase {
    // MARK: Open

    func testANewSessionIsIdleAndHoldsNothing() {
        let session = ExperienceSession()
        assertHoldsNothing(session)
        XCTAssertEqual(session.phase, .active)
        XCTAssertNil(session.failure)
        XCTAssertNil(session.message)
        let diagnostics = session.diagnostics
        XCTAssertEqual(diagnostics.opens, 0)
        XCTAssertEqual(diagnostics.closes, 0)
        XCTAssertEqual(diagnostics.failures, 0)
        XCTAssertEqual(diagnostics.rejectedTransitions, 0)
        XCTAssertNil(diagnostics.lastFailure)
        XCTAssertNil(diagnostics.experienceDiagnostics)
        XCTAssertTrue(diagnostics.lastCloseSteps.isEmpty)
    }

    func testOpeningTheSampleEndsInRunningWithItsPictureAndTheStageTimings() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(probe.makes, 1, "the session builds one experience per open")
        XCTAssertTrue(session.experience === probe.shell, "the session publishes the experience the factory built")
        XCTAssertEqual(probe.shell?.state, .active)
        XCTAssertEqual(probe.shell?.engine.seed, 42)
        XCTAssertEqual(try probe.digest().hex, goldenDigest(seed: 42))
        XCTAssertNotNil(session.renderHost)
        XCTAssertEqual(session.hostsAlive, 1)
        XCTAssertNil(session.failure)
        XCTAssertNil(session.message)
        XCTAssertNil(session.lastRestoreRefusal)
        XCTAssertEqual(probe.presenter?.setupCalls, 1, "the host the session created set the scene up once")

        // The session's host has no size until the test lays it out; the picture is read from a frame drawn then.
        layOut(session)
        XCTAssertTrue(drawFrame(session))
        XCTAssertTrue(sessionShowsState(session, probe), "the centre pixel shows the state")
        XCTAssertGreaterThanOrEqual(probe.presenter?.drawCalls ?? 0, 1)

        let diagnostics = session.diagnostics
        XCTAssertEqual(diagnostics.state, .running)
        XCTAssertEqual(diagnostics.experience, SampleExperience.id)
        XCTAssertEqual(diagnostics.experienceDiagnostics?.state, .active)
        XCTAssertEqual(diagnostics.experienceDiagnostics?.seed, 42)
        XCTAssertEqual(diagnostics.opens, 1)
        XCTAssertEqual(diagnostics.failures, 0)
        XCTAssertEqual(diagnostics.rejectedTransitions, 0)
        for (name, value) in [("prepare", diagnostics.timings.prepare), ("createHost", diagnostics.timings.createHost),
                              ("activate", diagnostics.timings.activate)] {
            XCTAssertNotNil(value, "the stage \(name) has a duration")
            XCTAssertGreaterThanOrEqual(value ?? -1, 0, "the duration of \(name) is not negative")
        }
        // The fourth timing is taken at the first frame that is really drawn while running. The host of this
        // test got its size after `open` (edge case "missing surface"), so that is the frame drawn above.
        XCTAssertNotNil(diagnostics.timings.firstFrame, "the first frame has a duration once a frame was drawn")
        XCTAssertGreaterThanOrEqual(diagnostics.timings.firstFrame ?? -1, 0)
        XCTAssertNoThrow(try diagnostics.encoded(), "the diagnostics can be written into an evidence file")
    }

    func testWithoutASurfaceTheSessionRunsAndDrawsAsSoonAsOneExists() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        XCTAssertEqual(probe.presenter?.drawCalls, 0, "no frame is drawn without a surface")
        XCTAssertFalse(drawFrame(session))
        XCTAssertEqual(session.state, .running)
        XCTAssertNil(session.diagnostics.timings.firstFrame, "the first-frame time is not recorded without a frame")
        layOut(session)
        XCTAssertTrue(drawFrame(session))
        XCTAssertEqual(probe.presenter?.drawCalls, 1)
        XCTAssertNotNil(session.diagnostics.timings.firstFrame)
        XCTAssertTrue(sessionShowsState(session, probe))
    }

    // MARK: Close

    func testCloseTakesTheSevenStepsInOrderHandsOutOneSnapshotAndLeavesNoObject() async throws {
        let log = SnapshotLog()
        let session = ExperienceSession(snapshotSink: log.sink)
        let (request, probe) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        layOut(session)
        XCTAssertTrue(drawFrame(session))
        XCTAssertEqual(log.count, 0, "no snapshot before a suspension or a close")
        let digest = try probe.digest()
        let steps = probe.stepIndex

        session.close()
        assertHoldsNothing(session)
        assertClosedCleanly(session)
        XCTAssertEqual(log.count, 1, "one snapshot per close")
        XCTAssertEqual(log.snapshots.first?.experience, SampleExperience.id)
        XCTAssertEqual(log.snapshots.first?.seed, 42)
        XCTAssertEqual(log.snapshots.first?.digest, digest, "the snapshot holds the state at the close")
        XCTAssertEqual(log.snapshots.first?.stepIndex, steps)
        XCTAssertEqual(probe.presenter?.teardownCalls, 1)
        XCTAssertNil(probe.presenter?.texture)
        XCTAssertEqual(probe.shell?.state, .inactive)
        let diagnostics = session.diagnostics
        XCTAssertEqual(diagnostics.closes, 1)
        XCTAssertEqual(diagnostics.failures, 0)
        XCTAssertEqual(diagnostics.sinkFailures, 0)
        XCTAssertEqual(diagnostics.rejectedTransitions, 0)
        XCTAssertNil(diagnostics.lastFailure)
        XCTAssertNil(session.failure)
    }

    func testClosingWhenIdleAndClosingTwiceDoNothing() async throws {
        let log = SnapshotLog()
        let session = ExperienceSession(snapshotSink: log.sink)
        session.close()
        session.close()
        assertHoldsNothing(session)
        XCTAssertEqual(session.diagnostics.closes, 0)
        XCTAssertTrue(session.diagnostics.lastCloseSteps.isEmpty)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0, "closing when idle is not an error")
        XCTAssertEqual(log.count, 0)

        let (request, probe) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        session.close()
        let afterFirst = session.diagnostics
        session.close()
        session.close()
        assertHoldsNothing(session)
        XCTAssertEqual(session.diagnostics, afterFirst, "a second close changes nothing")
        XCTAssertEqual(session.diagnostics.closes, 1)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
        XCTAssertEqual(log.count, 1)
        XCTAssertEqual(probe.presenter?.teardownCalls, 1)
    }

    // MARK: One experience and one render host at a time (SC-U03-001)

    func testOpeningBWhileARunsClosesACompletelyBeforeBsFactoryIsCalled() async throws {
        var events: [String] = []
        var hostsSeen: [Int] = []
        let log = SnapshotLog()
        let session = ExperienceSession(snapshotSink: log.sink)
        defer { session.close() }
        log.onSnapshot = {
            events.append("snapshot")
            hostsSeen.append(session.hostsAlive)
        }

        let (requestA, probeA) = sampleRequest(seed: 1, onMake: {
            events.append("make A")
            hostsSeen.append(session.hostsAlive)
        })
        // What the session looked like at the moment B's factory was called.
        var stateOfAAtMakeB: ExperienceLifecycleState?
        var teardownsOfAAtMakeB = -1
        var hostsAtMakeB = -1
        var closeStepsAtMakeB: [SessionCloseStep] = []
        var closeCountsAtMakeB: GPUResourceCounts?
        let (requestB, probeB) = sampleRequest(seed: 2, onMake: {
            events.append("make B")
            hostsSeen.append(session.hostsAlive)
            stateOfAAtMakeB = probeA.shell?.state
            teardownsOfAAtMakeB = probeA.presenter?.teardownCalls ?? -1
            hostsAtMakeB = session.hostsAlive
            closeStepsAtMakeB = session.diagnostics.lastCloseSteps
            closeCountsAtMakeB = session.diagnostics.lastCloseCounts
        })

        let first = await session.open(requestA)
        XCTAssertEqual(first, .running)
        layOut(session)
        XCTAssertTrue(drawFrame(session))
        hostsSeen.append(session.hostsAlive)
        let hostOfA = session.renderHost

        let second = await session.open(requestB)
        XCTAssertEqual(second, .running)
        hostsSeen.append(session.hostsAlive)

        XCTAssertEqual(events, ["make A", "snapshot", "make B"], "A is closed before B is built")
        XCTAssertEqual(stateOfAAtMakeB, .inactive, "A's leave was finished")
        XCTAssertEqual(teardownsOfAAtMakeB, 1, "A's GPU objects were released")
        XCTAssertEqual(hostsAtMakeB, 0, "A's render host was destroyed")
        XCTAssertEqual(closeStepsAtMakeB, SessionCloseStep.order)
        XCTAssertEqual(closeCountsAtMakeB?.objects, 0)
        XCTAssertEqual(closeCountsAtMakeB?.leaked, 0)
        XCTAssertEqual(hostOfA?.state, .destroyed)
        XCTAssertLessThanOrEqual(hostsSeen.max() ?? 0, 1, "never more than one render host: \(hostsSeen)")

        XCTAssertEqual(session.state, .running)
        XCTAssertTrue(session.experience === probeB.shell)
        XCTAssertFalse(session.renderHost === hostOfA, "B got its own render host")
        XCTAssertEqual(session.hostsAlive, 1)
        XCTAssertEqual(probeB.shell?.engine.seed, 2)
        XCTAssertEqual(probeA.makes, 1)
        XCTAssertEqual(probeB.makes, 1)
        XCTAssertEqual(session.diagnostics.opens, 2)
        XCTAssertEqual(session.diagnostics.closes, 1)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
        layOut(session)
        XCTAssertTrue(drawFrame(session))
        XCTAssertTrue(sessionShowsState(session, probeB))
    }

    func testOpeningBWhileAPreparesCancelsAAndCreatesNoHostForIt() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (requestA, probeA) = sampleRequest(SlowPreparation.self)
        var stateOfAAtMakeB: ExperienceLifecycleState?
        var hostsAtMakeB = -1
        let (requestB, probeB) = sampleRequest(onMake: {
            stateOfAAtMakeB = probeA.shell?.state
            hostsAtMakeB = session.hostsAlive
        })

        let pending = openInBackground(session, requestA)
        let preparing = await waitUntil { session.state == .preparing }
        XCTAssertTrue(preparing, "A is preparing")
        XCTAssertEqual(session.hostsAlive, 0, "no render host while preparing")
        XCTAssertNil(session.renderHost)

        let second = await session.open(requestB)
        XCTAssertEqual(second, .running)
        let first = await pending.value
        XCTAssertEqual(first, .superseded)
        XCTAssertEqual(stateOfAAtMakeB, .inactive, "A's preparation was cancelled before B was built")
        XCTAssertEqual(hostsAtMakeB, 0)
        XCTAssertEqual(probeA.presenter?.setupCalls, 0, "no render host was created for A")
        XCTAssertEqual(probeA.presenter?.drawCalls, 0)
        XCTAssertEqual(session.state, .running)
        XCTAssertTrue(session.experience === probeB.shell)
        XCTAssertEqual(session.hostsAlive, 1)
        // The replaced preparation counts as cancelled and its open as superseded; only B's open succeeded.
        XCTAssertEqual(session.diagnostics.cancelledPreparations, 1)
        XCTAssertEqual(session.diagnostics.supersededOpens, 1)
        XCTAssertEqual(session.diagnostics.opens, 1)
        XCTAssertEqual(session.diagnostics.closes, 0)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
    }

    func testOpeningWhileFailedStartsFreshWithOneHost() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (requestA, _) = sampleRequest(FailingPreparation.self)
        let first = await session.open(requestA)
        guard case .failed = first else { return XCTFail("got \(first)") }
        XCTAssertEqual(session.state, .failed)
        XCTAssertEqual(session.hostsAlive, 0)

        var hostsAtMakeB = -1
        var stateAtMakeB: SessionState?
        let (requestB, probeB) = sampleRequest(onMake: {
            hostsAtMakeB = session.hostsAlive
            stateAtMakeB = session.state
        })
        let second = await session.open(requestB)
        XCTAssertEqual(second, .running)
        XCTAssertEqual(hostsAtMakeB, 0)
        XCTAssertEqual(stateAtMakeB, .preparing, "failed → preparing, then the experience is built")
        XCTAssertEqual(session.state, .running)
        XCTAssertNil(session.failure, "the failure view is gone")
        XCTAssertTrue(session.experience === probeB.shell)
        XCTAssertEqual(session.hostsAlive, 1)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
    }

    func testOpeningWhileAMessageIsShownStartsFreshWithOneHost() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (requestA, probeA) = sampleRequest(memoryPressureLimit: 0)
        let first = await session.open(requestA)
        XCTAssertEqual(first, .running)
        layOut(session)   // the limit of 0 becomes 1 byte; the sample's texture (4 bytes) is above it
        XCTAssertTrue(drawFrame(session))
        session.handleMemoryWarning()
        XCTAssertEqual(session.state, .message)
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertEqual(probeA.shell?.state, .inactive)

        var hostsAtMakeB = -1
        let (requestB, probeB) = sampleRequest(onMake: { hostsAtMakeB = session.hostsAlive })
        let second = await session.open(requestB)
        XCTAssertEqual(second, .running)
        XCTAssertEqual(hostsAtMakeB, 0)
        XCTAssertEqual(session.state, .running)
        XCTAssertNil(session.message, "the message view is gone")
        XCTAssertTrue(session.experience === probeB.shell)
        XCTAssertEqual(session.hostsAlive, 1)
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
    }

    // MARK: Cycles (SC-U03-002)

    func testFiftyOpenAndCloseCyclesLeaveNoObjectAndUseEqualBytesWhileRunning() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        var bytesWhileRunning: [Int] = []
        for cycle in 1...50 {
            let (request, probe) = sampleRequest()
            let result = await session.open(request)
            XCTAssertEqual(result, .running, "cycle \(cycle)")
            XCTAssertEqual(session.hostsAlive, 1, "cycle \(cycle)")
            layOut(session)
            XCTAssertTrue(drawFrame(session), "cycle \(cycle)")
            XCTAssertTrue(sessionShowsState(session, probe), "cycle \(cycle)")
            bytesWhileRunning.append(session.renderHost?.resources.stats.totalBytes ?? -1)

            session.close()
            let counts = session.diagnostics.lastCloseCounts
            XCTAssertEqual(counts?.objects, 0, "live objects after cycle \(cycle)")
            XCTAssertEqual(counts?.leaked, 0, "leaked objects after cycle \(cycle)")
            XCTAssertEqual(session.diagnostics.lastCloseSteps, SessionCloseStep.order, "cycle \(cycle)")
            XCTAssertEqual(session.state, .idle, "cycle \(cycle)")
            XCTAssertEqual(session.hostsAlive, 0, "cycle \(cycle)")
            XCTAssertEqual(probe.shell?.state, .inactive, "cycle \(cycle)")
        }
        XCTAssertEqual(bytesWhileRunning.count, 50)
        XCTAssertGreaterThan(bytesWhileRunning.first ?? 0, 0, "the sample's texture is counted while running")
        XCTAssertEqual(bytesWhileRunning.first, bytesWhileRunning.last, "live bytes in cycle 1 and in cycle 50")
        XCTAssertEqual(Set(bytesWhileRunning).count, 1, "live bytes while running: \(bytesWhileRunning)")
        let diagnostics = session.diagnostics
        XCTAssertEqual(diagnostics.opens, 50)
        XCTAssertEqual(diagnostics.closes, 50)
        XCTAssertEqual(diagnostics.failures, 0)
        XCTAssertEqual(diagnostics.rejectedTransitions, 0)
        XCTAssertNil(diagnostics.lastFailure)
    }

    /// Edge case "rapid open and close": even rounds close a running experience at once, odd rounds close while
    /// the open is still under way (a cancelled preparation, or a full close when the open was already done).
    func testTwentyOpensAndClosesInARowLeaveTheSessionIdleWithNoObject() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        for round in 0..<20 {
            let (request, probe) = sampleRequest(seed: UInt64(round))
            if round.isMultiple(of: 2) {
                let result = await session.open(request)
                XCTAssertEqual(result, .running, "round \(round)")
                session.close()
            } else {
                let pending = openInBackground(session, request)
                _ = await waitUntil { session.state != .idle }
                session.close()
                let result = await pending.value
                XCTAssertTrue(result == .cancelled || result == .running, "round \(round): got \(result)")
            }
            XCTAssertEqual(session.state, .idle, "round \(round)")
            XCTAssertEqual(session.hostsAlive, 0, "round \(round)")
            XCTAssertNil(session.renderHost, "round \(round)")
            XCTAssertNil(session.experience, "round \(round)")
            XCTAssertEqual(probe.shell?.state, .inactive, "round \(round)")
            XCTAssertNil(probe.presenter?.texture, "round \(round)")
        }
        // A late result of a cancelled preparation changes nothing.
        try await Task.sleep(for: .milliseconds(50))
        assertHoldsNothing(session)
        let diagnostics = session.diagnostics
        XCTAssertEqual(diagnostics.lastCloseCounts?.objects, 0)
        XCTAssertEqual(diagnostics.lastCloseCounts?.leaked, 0)
        // `opens` counts the opens that reached running or suspended; each of them was closed in full.
        XCTAssertEqual(diagnostics.opens, diagnostics.closes)
        XCTAssertGreaterThanOrEqual(diagnostics.opens, 10)
        XCTAssertEqual(diagnostics.closes + diagnostics.cancelledPreparations, 20,
                       "every open ended in a full close or in a cancelled preparation")
        XCTAssertEqual(diagnostics.failures, 0)
        XCTAssertEqual(diagnostics.rejectedTransitions, 0)
    }

    // MARK: Leak (FR-U03-011, FR-U03-023)

    func testAPresenterThatKeepsItsTextureIsRecordedAsALeakAndTheSessionStaysUsable() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (leaking, leakingProbe) = sampleRequest(configure: { $0.keepsTextureOnTeardown = true })
        let first = await session.open(leaking)
        XCTAssertEqual(first, .running)
        layOut(session)
        XCTAssertTrue(drawFrame(session))

        session.close()
        assertHoldsNothing(session)
        let diagnostics = session.diagnostics
        XCTAssertEqual(diagnostics.lastFailure?.code, "experience.gpu-leak")
        XCTAssertEqual(diagnostics.lastFailure?.stage, .close)
        XCTAssertEqual(diagnostics.failures, 1, "the leak is counted")
        XCTAssertEqual(diagnostics.closes, 1)
        XCTAssertEqual(diagnostics.lastCloseSteps, SessionCloseStep.order, "a failing close still takes every step")
        let counts = try XCTUnwrap(diagnostics.lastCloseCounts)
        XCTAssertGreaterThan(counts.objects + counts.leaked, 0, "the registry reports the kept texture")
        XCTAssertEqual(leakingProbe.presenter?.teardownCalls, 1)
        XCTAssertNotNil(leakingProbe.presenter?.texture)
        XCTAssertNil(session.failure, "a failure while closing is recorded, not shown")

        let (healthy, healthyProbe) = sampleRequest()
        let second = await session.open(healthy)
        XCTAssertEqual(second, .running)
        layOut(session)
        XCTAssertTrue(drawFrame(session))
        XCTAssertTrue(sessionShowsState(session, healthyProbe))
        session.close()
        assertHoldsNothing(session)
        assertClosedCleanly(session)
        XCTAssertEqual(session.diagnostics.lastFailure?.code, "experience.gpu-leak", "the record of the leak stays")
        XCTAssertEqual(session.diagnostics.failures, 1)
    }

    // MARK: Snapshots at open (FR-U03-005)

    /// A snapshot of the sample after `frames` frames and one `tone` action, with the digest of that state.
    private func donorSnapshot(seed: UInt64, frames: Int) async throws -> (snapshot: ExperienceSnapshot,
                                                                           digest: StateDigest) {
        let log = SnapshotLog()
        let session = ExperienceSession(snapshotSink: log.sink)
        let (request, probe) = sampleRequest(seed: seed)
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        layOut(session)
        for _ in 0..<frames { XCTAssertTrue(drawFrame(session)) }
        XCTAssertEqual(session.experience?.handle(control: "tone", values: [0.5]), .accepted)
        let digest = try probe.digest()
        session.close()
        XCTAssertEqual(log.count, 1)
        return (try XCTUnwrap(log.snapshots.first), digest)
    }

    func testAnOpenWithASnapshotRestoresIt() async throws {
        let donor = try await donorSnapshot(seed: 42, frames: 5)
        XCTAssertEqual(donor.snapshot.digest, donor.digest)
        XCTAssertNotEqual(donor.digest.hex, goldenDigest(seed: 42), "the donor's state differs from a fresh one")
        XCTAssertGreaterThan(donor.snapshot.stepIndex, 0)

        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = sampleRequest(seed: 42, snapshot: donor.snapshot)
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        XCTAssertEqual(try probe.digest(), donor.digest, "the restored state has the donor's digest")
        XCTAssertEqual(probe.stepIndex, donor.snapshot.stepIndex)
        XCTAssertNil(session.lastRestoreRefusal)
        XCTAssertNil(session.failure)
        XCTAssertEqual(session.diagnostics.failures, 0)
        layOut(session)
        // The picture is compared with the core before a frame runs steps on it and after: tone 0.5 in both.
        XCTAssertEqual(probe.shell?.engine.core?.tone, 0.5)
        XCTAssertTrue(drawFrame(session))
        XCTAssertTrue(sessionShowsState(session, probe))
    }

    func testAnOpenWithASnapshotOfAnotherExperienceOpensFreshAndRecordsTheRefusal() async throws {
        let donor = try await donorSnapshot(seed: 42, frames: 5)
        let otherID = try XCTUnwrap(ExperienceID(rawValue: "a98.other-sample"))
        let foreign = try ExperienceSnapshot(experience: otherID, schemaVersion: donor.snapshot.schemaVersion,
                                             seed: donor.snapshot.seed, stepIndex: donor.snapshot.stepIndex,
                                             digest: donor.snapshot.digest,
                                             payload: Data(donor.snapshot.payload.utf8))

        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = sampleRequest(seed: 42, snapshot: foreign)
        let result = await session.open(request)
        XCTAssertEqual(result, .running, "a refused snapshot does not stop the opening")
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(session.lastRestoreRefusal?.code, "snapshot.wrong-experience")
        XCTAssertEqual(try probe.digest().hex, goldenDigest(seed: 42), "the experience opened fresh")
        XCTAssertEqual(probe.stepIndex, 0)
        XCTAssertNil(session.failure, "the refusal is recorded, not shown as a failure")
        XCTAssertEqual(probe.shell?.state, .active)
        layOut(session)
        XCTAssertTrue(drawFrame(session))
        XCTAssertTrue(sessionShowsState(session, probe))

        // The next open without a snapshot has no refusal to report.
        let (plain, _) = sampleRequest(seed: 42)
        let second = await session.open(plain)
        XCTAssertEqual(second, .running)
        XCTAssertNil(session.lastRestoreRefusal, "the refusal belongs to the open that caused it")
    }
}
