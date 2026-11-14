// MusicLabRecoveryTests — feature 050 (A06-P04) T-A06-407 (FR-A06-410; US1 AC1–4). The status line and the recovery
// button inside the one app's session host on the simulator, with a resumable microphone double whose state the test
// drives (system interruptions cannot be produced on the simulator; the source's own reactions are tested in
// VisualCoreAudioTests): live, paused by the system, Resume after an end without permission to resume, stopped with Use
// demo signal; the demo source stays live.
import XCTest
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import VisualCoreMusicLabExperience
import VisualCoreMusicLabCore
import VisualCoreRendering

@MainActor
private final class GrantedPermission: MicrophonePermission {
    var state: MicrophonePermissionState { .granted }
    func request() async -> MicrophonePermissionState { .granted }
}

/// A microphone double whose state the test sets.
@MainActor
private final class ResumableDouble: ResumableAudioSource {
    var sampleRate: Double { 48_000 }
    var state: AudioSourceState = .idle
    var awaitsResume = false
    private(set) var resumes = 0

    func start(into buffer: SampleRingBuffer) throws { state = .running }
    func stop() { state = .idle }
    func resume() {
        resumes += 1
        awaitsResume = false
        state = .running
    }
}

@MainActor
final class MusicLabRecoveryTests: XCTestCase {
    private var id: ExperienceID { VisualCoreMusicLabExperience.id ?? ExperienceID(rawValue: "a06.unknown")! }

    private func open(_ session: ExperienceSession, microphone: ResumableDouble) async throws
        -> ExperienceShell<MusicLabPresenter> {
        let id = self.id
        let factory = MusicLabSourceFactory(demo: { DemoAudioSource(signal: $0) },
                                            file: { _ in throw AudioSourceError.undecodable("unused") },
                                            microphone: { _ in microphone })
        var made: ExperienceShell<MusicLabPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = VisualCoreMusicLabExperience.make(id: id, permission: GrantedPermission(), factory: factory)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        return try XCTUnwrap(made)
    }

    private func frame(_ session: ExperienceSession) {
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
    }

    func testTheDemoIsLive() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, microphone: ResumableDouble())
        frame(session)
        XCTAssertEqual(shell.presenter.mirror.statusLine, "Demo signal — live")
        XCTAssertEqual(shell.presenter.mirror.recovery, .none)
        session.close()
    }

    func testPausedThenResumeThenStoppedWithUseDemo() async throws {
        let session = ExperienceSession()
        let microphone = ResumableDouble()
        let shell = try await open(session, microphone: microphone)
        let presenter = shell.presenter
        let chosen = await presenter.chooseMicrophone()
        XCTAssertTrue(chosen.isAccepted)
        frame(session)
        XCTAssertTrue(presenter.activeSource === microphone)
        XCTAssertEqual(presenter.mirror.statusLine, "Microphone — live")

        // Interruption began: paused, no button (it may still resume by itself).
        microphone.state = .interrupted
        frame(session)
        XCTAssertEqual(presenter.mirror.statusLine, "Microphone — paused by the system")
        XCTAssertEqual(presenter.mirror.recovery, .none)
        XCTAssertNil(presenter.mirror.message)

        // Ended without permission to resume: Resume is offered and restarts.
        microphone.awaitsResume = true
        frame(session)
        XCTAssertEqual(presenter.mirror.recovery, .resume)
        presenter.resumeSource()
        XCTAssertEqual(microphone.resumes, 1)
        frame(session)
        XCTAssertEqual(presenter.mirror.statusLine, "Microphone — live")
        XCTAssertEqual(presenter.mirror.recovery, .none)

        // A rebuild that failed: stopped, Use demo signal switches to the demo.
        microphone.state = .failed("no audio input available")
        frame(session)
        XCTAssertEqual(presenter.mirror.statusLine, "Microphone — stopped")
        XCTAssertEqual(presenter.mirror.recovery, .useDemo)
        XCTAssertNotNil(presenter.mirror.message)
        presenter.useDemo()
        frame(session)
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.source, .demo)
        XCTAssertEqual(presenter.mirror.statusLine, "Demo signal — live")
        XCTAssertEqual(presenter.mirror.recovery, .none)
        session.close()
    }
}
