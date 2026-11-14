// MusicLabSessionTests — feature 047 (A06-P01) T-A06-104 (FR-A06-101–105, FR-A06-121, FR-A06-122; SC-A06-105). The
// A06 adapter inside the one app's session host on the simulator, short runs only (each test well under 5 s): the demo
// source's 440 Hz tone is drawn as exactly the ring buffer's newest samples, which are the demo signal's own samples;
// a permission double that is denied or restricted makes the core refuse the microphone with no request and the demo
// kept, one that is not determined is asked once and a refusal falls back to the demo; closing stops the source; and
// five rapid source switches end with only the last source running. The microphone itself is never started (doubles).
import XCTest
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import VisualCoreMusicLabExperience
import VisualCoreMusicLabCore
import VisualCoreRendering

/// A microphone permission double: a fixed state and the answer the one request gives.
@MainActor
private final class PermissionDouble: MicrophonePermission {
    var state: MicrophonePermissionState
    let answer: MicrophonePermissionState
    private(set) var requests = 0

    init(_ state: MicrophonePermissionState, answer: MicrophonePermissionState? = nil) {
        self.state = state
        self.answer = answer ?? state
    }

    func request() async -> MicrophonePermissionState {
        requests += 1
        state = answer
        return answer
    }
}

/// A source double that only records whether it runs.
@MainActor
private final class SourceDouble: AudioSource {
    let label: String
    var sampleRate: Double { 48_000 }
    private(set) var state: AudioSourceState = .idle

    init(_ label: String) { self.label = label }

    func start(into buffer: SampleRingBuffer) throws { state = .running }
    func stop() { state = .idle }
}

/// Every source double the factory made, in order.
@MainActor
private final class SourceLog {
    var made: [SourceDouble] = []

    /// A factory whose three kinds are doubles recorded here.
    var factory: MusicLabSourceFactory {
        MusicLabSourceFactory(demo: { [unowned self] _ in record("demo") },
                              file: { [unowned self] _ in record("file") },
                              microphone: { [unowned self] _ in record("microphone") })
    }

    private func record(_ label: String) -> SourceDouble {
        let source = SourceDouble(label)
        made.append(source)
        return source
    }
}

@MainActor
final class MusicLabSessionTests: XCTestCase {
    private var id: ExperienceID { VisualCoreMusicLabExperience.id ?? ExperienceID(rawValue: "a06.unknown")! }

    private func request(permission: any MicrophonePermission, factory: MusicLabSourceFactory = .system,
                         made: @escaping @MainActor (ExperienceShell<MusicLabPresenter>) -> Void)
        -> ExperienceOpenRequest {
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = VisualCoreMusicLabExperience.make(id: id, permission: permission, factory: factory)
            made(shell)
            return shell
        }
    }

    private func open(_ session: ExperienceSession, permission: any MicrophonePermission,
                      factory: MusicLabSourceFactory = .system) async throws -> ExperienceShell<MusicLabPresenter> {
        var made: ExperienceShell<MusicLabPresenter>?
        let opened = await session.open(request(permission: permission, factory: factory) { made = $0 })
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        let shell = try XCTUnwrap(made)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        return shell
    }

    func testTheDemoToneIsDrawnAsTheRingBuffersNewestSamples() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, permission: PermissionDouble(.notDetermined))
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "demo.mode", values: [1]).isAccepted)
        let host = try XCTUnwrap(session.renderHost)
        // Let the demo source write at least two drawn windows (bounded: 1 s at most).
        for _ in 0..<100 where presenter.ring.totalWritten < 2 * MusicLabPresenter.drawnSampleCount {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertGreaterThanOrEqual(presenter.ring.totalWritten, MusicLabPresenter.drawnSampleCount)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let drawn = presenter.lastDrawnSamples
        XCTAssertEqual(drawn.count, MusicLabPresenter.drawnSampleCount)

        // The drawn samples are the ring buffer's newest samples (exactly, when nothing was written since the draw).
        var latest = [Float](repeating: 0, count: MusicLabPresenter.drawnSampleCount)
        let count = presenter.ring.latest(MusicLabPresenter.drawnSampleCount, into: &latest)
        if presenter.ring.totalWritten == presenter.lastDrawnTotalWritten {
            XCTAssertEqual(Array(latest.prefix(count)), drawn)
        }

        // …and a window of the demo signal itself (same seed, 440 Hz tone), rendered here in one go.
        let state = try XCTUnwrap(shell.engine.core).state
        let total = presenter.ring.totalWritten
        var signal = DemoSignal(seed: state.demoSeed, mode: .tone440, sampleRate: 48_000)
        var reference = [Float](repeating: 0, count: total)
        reference.withUnsafeMutableBufferPointer { signal.render(into: $0) }
        let n = drawn.count
        let match = (n...total).reversed().first { end in
            reference[end - n] == drawn[0] && Array(reference[(end - n)..<end]) == drawn
        }
        XCTAssertNotNil(match, "the drawn samples are a window of the 440 Hz demo signal")

        let pixels = host.readPixels()
        let size = host.pixelSize
        XCTAssertTrue(FrameChecks.isNonBlank(pixels, width: size.width, height: size.height))
        for probe in shell.frameProbes {
            XCTAssertEqual(FrameChecks.probe(probe, rgba: pixels, width: size.width, height: size.height)?.rawValue,
                           probe.expected, probe.name)
        }
        let summary = shell.accessibilitySummary
        XCTAssertTrue(summary.hasPrefix("Music Lab: Demo signal, level "), summary)
        XCTAssertFalse(summary.contains("level quiet"), summary)
        XCTAssertEqual(presenter.mirror.status, "Demo signal")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testAccessOffRefusesTheMicrophoneWithoutARequestAndKeepsTheDemo() async throws {
        for access in [MicrophonePermissionState.denied, .restricted] {
            let session = ExperienceSession()
            let permission = PermissionDouble(access)
            let shell = try await open(session, permission: permission)
            let presenter = shell.presenter
            let demo = try XCTUnwrap(presenter.activeSource)
            let result = await presenter.chooseMicrophone()
            XCTAssertEqual(result, .rejected(.rule(code: MusicLabRule.permissionDenied)), "\(access)")
            XCTAssertEqual(permission.requests, 0, "\(access): no request")
            XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.source, .demo)
            XCTAssertTrue(presenter.activeSource === demo, "\(access): the demo keeps playing")
            XCTAssertEqual(demo.state, .running)
            XCTAssertEqual(presenter.mirror.message, MusicLabPresenter.deniedMessage)
            XCTAssertTrue(presenter.mirror.showsSettingsLink)
            session.close()
        }
    }

    func testANotDeterminedPermissionIsAskedOnceAndARefusalFallsBackToTheDemo() async throws {
        let session = ExperienceSession()
        let permission = PermissionDouble(.notDetermined, answer: .denied)
        let shell = try await open(session, permission: permission)
        let result = await shell.presenter.chooseMicrophone()
        XCTAssertTrue(result.isAccepted, "accepted as requesting")
        XCTAssertEqual(permission.requests, 1)
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.source, .demo)
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.permission, .denied)
        XCTAssertTrue(shell.presenter.mirror.showsSettingsLink)
        // A second choice is refused by the rule and asks no more.
        let again = await shell.presenter.chooseMicrophone()
        XCTAssertEqual(again, .rejected(.rule(code: MusicLabRule.permissionDenied)))
        XCTAssertEqual(permission.requests, 1)
        session.close()
    }

    func testClosingStopsTheSource() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, permission: PermissionDouble(.notDetermined))
        let source = try XCTUnwrap(shell.presenter.activeSource)
        XCTAssertEqual(source.state, .running)
        session.close()
        XCTAssertEqual(source.state, .idle)
        XCTAssertNil(shell.presenter.activeSource)
        XCTAssertFalse(shell.presenter.isLive)
    }

    func testFiveRapidSwitchesEndWithOnlyTheLastSourceRunning() async throws {
        let session = ExperienceSession()
        let log = SourceLog()
        let shell = try await open(session, permission: PermissionDouble(.granted), factory: log.factory)
        let presenter = shell.presenter
        XCTAssertEqual(log.made.map(\.label), ["demo"])
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("music-lab-switch.wav")
        // Five source switches, no frame in between: microphone, file, demo, microphone, then the demo again after its
        // mode was set to the 1 kHz tone (index 2) while the microphone ran.
        let microphone = await presenter.chooseMicrophone()
        XCTAssertTrue(microphone.isAccepted)
        XCTAssertTrue(presenter.chooseFile(url: file))
        XCTAssertTrue(shell.handle(control: "source.demo").isAccepted)
        let microphoneAgain = await presenter.chooseMicrophone()
        XCTAssertTrue(microphoneAgain.isAccepted)
        XCTAssertTrue(shell.handle(control: "demo.mode", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "source.demo").isAccepted)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        let last = try XCTUnwrap(log.made.last)
        XCTAssertEqual(last.label, "demo")
        XCTAssertTrue(presenter.activeSource === last)
        XCTAssertEqual(presenter.activeKey, .demo(seed: 7, mode: 2))
        XCTAssertEqual(log.made.filter { $0.state == .running }.count, 1, "only the last source runs")
        XCTAssertEqual(last.state, .running)
        session.close()
        XCTAssertTrue(log.made.allSatisfy { $0.state == .idle })
    }
}
