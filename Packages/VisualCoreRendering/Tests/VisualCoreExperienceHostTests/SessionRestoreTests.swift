// SessionRestoreTests — feature 191 (UA-F05) T-U05-013 and T-U05-020 (US1, US5; FR-U05-010, FR-U05-023,
// FR-U05-030, FR-U05-031, FR-U05-051). `ExperienceSession.checkpoint()` and an open whose request sets
// `refusedSnapshotFails`: a snapshot the experience refuses ends the open as a failure of the stage `restore`,
// before a render host exists and without a call of the sink; without the flag the open goes on as before.
// The helpers (`sampleRequest`, `SnapshotLog`, `layOut`, `drawFrame`) are in SessionOpenCloseTests.swift.
import XCTest
import VisualCoreExperience
@testable import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreTestSupport

@MainActor
final class SessionRestoreTests: XCTestCase {
    // MARK: Helpers

    /// A snapshot of the sample after `frames` frames and one `tone` action.
    private func donorSnapshot(seed: UInt64 = 42, frames: Int = 5) async throws -> ExperienceSnapshot {
        let log = SnapshotLog()
        let session = ExperienceSession(snapshotSink: log.sink)
        let (request, _) = sampleRequest(seed: seed)
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        layOut(session)
        for _ in 0..<frames { XCTAssertTrue(drawFrame(session)) }
        XCTAssertEqual(session.experience?.handle(control: "tone", values: [0.5]), .accepted)
        session.close()
        return try XCTUnwrap(log.snapshots.first)
    }

    /// `donor` with another schema version or another digest; the checksum is that of the same payload.
    private func variant(of donor: ExperienceSnapshot, schema: Int? = nil,
                         digest: StateDigest? = nil) throws -> ExperienceSnapshot {
        try ExperienceSnapshot(experience: donor.experience, schemaVersion: schema ?? donor.schemaVersion,
                               seed: donor.seed, stepIndex: donor.stepIndex, digest: digest ?? donor.digest,
                               payload: Data(donor.payload.utf8))
    }

    /// The three snapshots only the experience can refuse, with the code of each refusal.
    private func refusedSnapshots() async throws -> [(name: String, snapshot: ExperienceSnapshot, code: String)] {
        let donor = try await donorSnapshot()
        let zero = try XCTUnwrap(StateDigest(hex: String(repeating: "0", count: 64)))
        return [
            ("newer schema", try variant(of: donor, schema: 99), "snapshot.newer-schema"),
            ("no migration", try variant(of: donor, schema: 0), "snapshot.missing-migration"),
            ("other digest", try variant(of: donor, digest: zero), "snapshot.state-mismatch"),
        ]
    }

    /// The sample request with a snapshot and the flag.
    private func restoreRequest(_ snapshot: ExperienceSnapshot, fails: Bool)
        -> (request: ExperienceOpenRequest, probe: SampleProbe<NoFault>) {
        var (request, probe) = sampleRequest(seed: snapshot.seed, snapshot: snapshot)
        request.refusedSnapshotFails = fails
        return (request, probe)
    }

    // MARK: checkpoint()

    func testCheckpointHandsTheSnapshotToTheSinkWhileRunningAndWhileSuspended() async throws {
        let log = SnapshotLog()
        let session = ExperienceSession(snapshotSink: log.sink)
        let (request, probe) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        layOut(session)
        for _ in 0..<3 { XCTAssertTrue(drawFrame(session)) }
        XCTAssertEqual(log.count, 0, "nothing is handed out while running without a checkpoint")

        session.checkpoint()
        XCTAssertEqual(log.count, 1)
        let running = try probe.digest()
        XCTAssertEqual(log.snapshots.last?.digest, running)
        XCTAssertEqual(log.snapshots.last?.stepIndex, probe.stepIndex)
        XCTAssertEqual(session.state, .running, "a checkpoint changes no state")

        session.setScenePhase(.background)
        XCTAssertEqual(session.state, .suspended)
        XCTAssertEqual(log.count, 2, "the suspension hands out its own snapshot")
        session.checkpoint()
        XCTAssertEqual(log.count, 3, "a checkpoint while suspended")
        XCTAssertEqual(log.snapshots.last?.digest, running)

        session.close()
        XCTAssertEqual(log.count, 4, "the close hands out the last one")
        XCTAssertEqual(session.diagnostics.sinkFailures, 0)
    }

    func testCheckpointDoesNothingWhenIdlePreparingOrFailed() async throws {
        let log = SnapshotLog()
        let session = ExperienceSession(snapshotSink: log.sink)
        session.checkpoint()
        XCTAssertEqual(log.count, 0, "idle")

        // Preparing: the factory runs inside `open`, before the preparation ends.
        var duringPreparation = -1
        let (request, _) = sampleRequest(onMake: { [weak session] in
            session?.checkpoint()
            duringPreparation = log.count
        })
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        XCTAssertEqual(duringPreparation, 0, "preparing")
        session.close()
        let afterClose = log.count
        XCTAssertEqual(afterClose, 1)

        // Failed: a refused snapshot with the flag.
        let newer = try variant(of: try XCTUnwrap(log.snapshots.first), schema: 99)
        let (failing, _) = restoreRequest(newer, fails: true)
        let failed = await session.open(failing)
        guard case .failed = failed else { return XCTFail("expected a failure, got \(failed)") }
        XCTAssertEqual(session.state, .failed)
        session.checkpoint()
        XCTAssertEqual(log.count, afterClose, "failed")
        session.close()
        session.checkpoint()
        XCTAssertEqual(log.count, afterClose, "idle again")
    }

    func testASinkThatThrowsAtACheckpointIsCountedAndStopsNothing() async throws {
        let log = SnapshotLog()
        log.fails = true
        let session = ExperienceSession(snapshotSink: log.sink)
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        layOut(session)
        session.checkpoint()
        session.checkpoint()
        XCTAssertEqual(log.count, 2)
        XCTAssertEqual(session.diagnostics.sinkFailures, 2)
        XCTAssertEqual(session.lastSinkFailure?.code, SessionFailure.sinkFailedCode)
        XCTAssertEqual(session.state, .running)
        XCTAssertTrue(drawFrame(session), "the experience goes on")
        log.fails = false
        session.close()
        XCTAssertEqual(session.state, .idle)
    }

    // MARK: refusedSnapshotFails

    func testARefusedSnapshotFailsTheOpenAtTheRestoreStageBeforeAnyHost() async throws {
        for item in try await refusedSnapshots() {
            let log = SnapshotLog()
            let session = ExperienceSession(snapshotSink: log.sink)
            let (request, probe) = restoreRequest(item.snapshot, fails: true)
            let result = await session.open(request)
            guard case .failed(let failure) = result else {
                XCTFail("\(item.name): expected a failure, got \(result)")
                continue
            }
            XCTAssertEqual(failure.stage, .restore, item.name)
            XCTAssertEqual(failure.failure.code, item.code, item.name)
            XCTAssertEqual(session.state, .failed, item.name)
            XCTAssertEqual(session.failure, failure, item.name)
            XCTAssertEqual(session.lastRestoreRefusal?.code, item.code, item.name)
            XCTAssertNil(session.renderHost, "\(item.name): no render host")
            XCTAssertEqual(session.hostsAlive, 0, item.name)
            XCTAssertNil(session.experience, item.name)
            XCTAssertEqual(probe.makes, 1, "\(item.name): the factory was called once")
            XCTAssertEqual(log.count, 0, "\(item.name): the sink was not called")

            // A retry fails the same way and still hands out nothing.
            let again = await session.retry()
            XCTAssertEqual(again, .failed(failure), item.name)
            XCTAssertEqual(probe.makes, 2, item.name)
            XCTAssertEqual(session.hostsAlive, 0, item.name)
            XCTAssertEqual(log.count, 0, item.name)

            session.close()
            XCTAssertEqual(session.state, .idle, item.name)
            XCTAssertEqual(log.count, 0, "\(item.name): closing a failed session hands out nothing")
        }
    }

    func testWithoutTheFlagARefusedSnapshotIsRecordedAndTheOpenGoesOn() async throws {
        for item in try await refusedSnapshots() {
            let session = ExperienceSession()
            let (request, probe) = restoreRequest(item.snapshot, fails: false)
            let result = await session.open(request)
            XCTAssertEqual(result, .running, item.name)
            XCTAssertEqual(session.lastRestoreRefusal?.code, item.code, item.name)
            XCTAssertEqual(probe.stepIndex, 0, "\(item.name): the fresh state")
            XCTAssertEqual(session.hostsAlive, 1, item.name)
            session.close()
        }
    }

    func testAValidSnapshotRestoresDigestSeedAndStepWithTheFlagSet() async throws {
        let donor = try await donorSnapshot(seed: 7, frames: 9)
        let log = SnapshotLog()
        let session = ExperienceSession(snapshotSink: log.sink)
        let (request, probe) = restoreRequest(donor, fails: true)
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        XCTAssertNil(session.lastRestoreRefusal)
        let digest = try probe.digest()
        XCTAssertEqual(digest, donor.digest)
        XCTAssertEqual(probe.stepIndex, donor.stepIndex)
        session.checkpoint()
        XCTAssertEqual(log.snapshots.last?.seed, 7)
        XCTAssertEqual(log.snapshots.last?.digest, donor.digest)
        XCTAssertEqual(log.snapshots.last?.stepIndex, donor.stepIndex)
        session.close()
    }

    // MARK: Migration through an open (T-U05-020)

    func testAVersionOneSnapshotRestoresThroughAnOpenAndIsHandedOutInTheCurrentSchema() async throws {
        let old = try ExperienceSnapshot(data: SampleExperience.snapshotV1(seed: 42))
        XCTAssertEqual(old.schemaVersion, 1)
        let log = SnapshotLog()
        let session = ExperienceSession(snapshotSink: log.sink)
        let (request, probe) = restoreRequest(old, fails: true)
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        XCTAssertNil(session.lastRestoreRefusal)
        let digest = try probe.digest()
        XCTAssertEqual(digest.hex, SampleExperience.snapshotV1Digest)
        session.checkpoint()
        let handed = try XCTUnwrap(log.snapshots.last)
        XCTAssertEqual(handed.schemaVersion, SampleExperienceCore<NoFault>.migrations.currentVersion)
        XCTAssertEqual(handed.digest.hex, SampleExperience.snapshotV1Digest)
        XCTAssertEqual(handed.experience, SampleExperience.id)
        session.close()
    }
}
