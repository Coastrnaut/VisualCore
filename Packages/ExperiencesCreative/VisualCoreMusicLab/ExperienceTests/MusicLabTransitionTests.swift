// MusicLabTransitionTests — feature 051 (A06-P05) T-A06-509 (FR-A06-514; SC-A06-505). The phase regression fixture:
// interruptions, resume, background and foreground, a stopped source and the switch back, each followed by a rendered
// frame — every frame renders (except while in the background, where the host draws nothing and resumes afterwards), the source ends live, and closing leaves no render host and no running source.
import UIKit
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

@MainActor
private final class ResumableDouble: ResumableAudioSource {
    var sampleRate: Double { 48_000 }
    var state: AudioSourceState = .idle
    var awaitsResume = false
    func start(into buffer: SampleRingBuffer) throws { state = .running }
    func stop() { state = .idle }
    func resume() {
        awaitsResume = false
        state = .running
    }
}

@MainActor
final class MusicLabTransitionTests: XCTestCase {
    func testTransitionsNeverWedgeRenderingOrTheSource() async throws {
        let id = try XCTUnwrap(VisualCoreMusicLabExperience.id)
        let microphone = ResumableDouble()
        let factory = MusicLabSourceFactory(demo: { DemoAudioSource(signal: $0) },
                                            file: { _ in throw AudioSourceError.undecodable("unused") },
                                            microphone: { _ in microphone })
        var made: ExperienceShell<MusicLabPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = VisualCoreMusicLabExperience.make(id: id, permission: GrantedPermission(), factory: factory)
            made = shell
            return shell
        }
        let session = ExperienceSession()
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        let shell = try XCTUnwrap(made)
        let presenter = shell.presenter
        let host = try XCTUnwrap(session.renderHost)
        func frame(_ step: String) {
            XCTAssertTrue(host.renderOneFrame(present: false), "frame after \(step)")
        }

        let chosen = await presenter.chooseMicrophone()
        XCTAssertTrue(chosen.isAccepted)
        frame("microphone")
        microphone.state = .interrupted
        frame("interruption began")
        microphone.awaitsResume = true
        frame("ended without resume")
        XCTAssertEqual(presenter.mirror.recovery, .resume)
        presenter.resumeSource()
        frame("resume")
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        // The host draws nothing while in the background (no GPU work there); it must draw again on return.
        XCTAssertFalse(host.renderOneFrame(present: false), "no frame in the background")
        XCTAssertEqual(microphone.state, .idle, "capture stops in the background")
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        frame("foreground")
        XCTAssertEqual(microphone.state, .running, "the source restarts on return")
        microphone.state = .failed("media services were reset")
        frame("failed")
        XCTAssertEqual(presenter.mirror.recovery, .useDemo)
        presenter.useDemo()
        frame("use demo")
        let again = await presenter.chooseMicrophone()
        XCTAssertTrue(again.isAccepted)
        frame("microphone again")
        XCTAssertEqual(presenter.mirror.statusLine, "Microphone — live")

        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertEqual(microphone.state, .idle)
        XCTAssertNil(presenter.activeSource)
    }
}
