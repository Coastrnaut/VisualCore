// OdysseyAudioTests — feature 055 (A07-P02) T-A07-205 (FR-A07-210, FR-A07-211, FR-A07-220, FR-A07-221; SC-A07-203,
// SC-A07-205; stories 1 and 3). Audio Odyssey's audio inside the one app's session host on the simulator, short runs
// only (each test under 10 s, frames of 1/60 s, no wall-clock assertion), with the permission and source doubles of
// Music Lab's tests (the microphone itself is never started): the demo signal lifts the tunnel's response off rest
// within 60 frames and keeps it inside its bounds and step limits; a loud low tone lifts ripple and brightness over
// several frames without moving the camera; two seconds of silence bring both back within 5 % of rest; Reduce Motion
// and Reduce Flashing narrow the ranges; source switches keep distance, speed and the host; denied or restricted access
// refuses the microphone with no request, keeps the demo playing and shows the Settings message; a not-determined
// permission is asked once and a refusal falls back to the demo; closing stops the source; and a schema-1 snapshot
// opens as the same journey with the demo signal.
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
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

/// A source double whose samples the test writes: `pump(amplitude:)` adds one frame's worth (800 samples at 48 kHz)
/// of an 80 Hz sine (inside the low band) with the given amplitude; 0 is silence.
@MainActor
private final class PumpSource: AudioSource {
    let label: String
    var sampleRate: Double { 48_000 }
    private(set) var state: AudioSourceState = .idle
    private var buffer: SampleRingBuffer?
    private var phase = 0.0
    private var block = [Float](repeating: 0, count: 800)

    init(_ label: String) { self.label = label }

    func start(into buffer: SampleRingBuffer) throws {
        self.buffer = buffer
        state = .running
    }

    func stop() {
        buffer = nil
        state = .idle
    }

    func pump(amplitude: Float) {
        guard let buffer else { return }
        let step = 2 * Double.pi * 80 / sampleRate
        for i in block.indices {
            block[i] = amplitude * Float(sin(phase))
            phase += step
        }
        phase = phase.truncatingRemainder(dividingBy: 2 * Double.pi)
        block.withUnsafeBufferPointer { buffer.write($0) }
    }
}

/// Every source double the factory made, in order.
@MainActor
private final class SourceLog {
    var made: [PumpSource] = []

    var factory: OdysseySourceFactory {
        OdysseySourceFactory(demo: { [unowned self] _ in record("demo") },
                             file: { [unowned self] _ in record("file") },
                             microphone: { [unowned self] _ in record("microphone") })
    }

    private func record(_ label: String) -> PumpSource {
        let source = PumpSource(label)
        made.append(source)
        return source
    }
}

@MainActor
final class OdysseyAudioTests: XCTestCase {
    private var id: ExperienceID { AudioOdysseyExperience.id ?? ExperienceID(rawValue: "a07.unknown")! }

    private func open(_ session: ExperienceSession, permission: any MicrophonePermission = PermissionDouble(.notDetermined),
                      factory: OdysseySourceFactory = .system, reduceMotion: Bool = false,
                      reduceFlashing: Bool = false, snapshot: ExperienceSnapshot? = nil) async throws
        -> ExperienceShell<OdysseyPresenter> {
        let id = self.id
        var made: ExperienceShell<OdysseyPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: snapshot, refusedSnapshotFails: snapshot != nil) {
            let shell = AudioOdysseyExperience.make(id: id, permission: permission, factory: factory,
                                                    reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        let shell = try XCTUnwrap(made)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        return shell
    }

    private func core(_ shell: ExperienceShell<OdysseyPresenter>) throws -> OdysseyCore {
        try XCTUnwrap(shell.engine.core)
    }

    /// Draws `count` frames; before each, `pump` (if any) writes that frame's samples. Returns the response after
    /// every frame and checks bounds and step limits on the way.
    @discardableResult
    private func frames(_ session: ExperienceSession, _ shell: ExperienceShell<OdysseyPresenter>, _ count: Int,
                        pump: (() -> Void)? = nil, file: StaticString = #filePath,
                        line: UInt = #line) throws -> [TunnelResponse] {
        let host = try XCTUnwrap(session.renderHost)
        var previous = shell.presenter.response
        var out: [TunnelResponse] = []
        for _ in 0..<count {
            pump?()
            XCTAssertTrue(host.renderOneFrame(present: false), file: file, line: line)
            let r = shell.presenter.response
            XCTAssertTrue(r.rippleRange.contains(r.ripple), "ripple \(r.ripple)", file: file, line: line)
            XCTAssertTrue(r.ambientRange.contains(r.ambient), "ambient \(r.ambient)", file: file, line: line)
            XCTAssertLessThanOrEqual(abs(r.ripple - previous.ripple), r.rippleStepLimit + 1e-12, file: file, line: line)
            XCTAssertLessThanOrEqual(abs(r.ambient - previous.ambient), r.ambientStepLimit + 1e-12, file: file,
                                     line: line)
            out.append(r)
            previous = r
        }
        return out
    }

    func testTheDemoSignalLiftsTheResponseWithinBoundsAndStepLimits() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        XCTAssertTrue(presenter.activeSource is DemoAudioSource, "the demo signal plays first, with no prompt")
        XCTAssertEqual(try core(shell).state.source, .demo)
        let rest = TunnelResponse(reduceMotion: false, reduceFlashing: false)
        var lifted = false
        for _ in 0..<60 {
            let r = try frames(session, shell, 1)[0]
            if r.ripple > rest.rippleRest || r.ambient > rest.ambientRest { lifted = true; break }
            try await Task.sleep(for: .milliseconds(5))     // lets the demo source's timer write
        }
        XCTAssertTrue(lifted, "the response left rest within 60 frames")
        try frames(session, shell, 30)
        XCTAssertTrue(shell.accessibilitySummary.contains("demo signal"), shell.accessibilitySummary)
        XCTAssertEqual(presenter.mirror.sourceName, "Demo signal")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testALoudLowToneRisesOverSeveralFramesAndSilenceReturnsToRest() async throws {
        let session = ExperienceSession()
        let log = SourceLog()
        let shell = try await open(session, factory: log.factory)
        let source = try XCTUnwrap(log.made.last)
        XCTAssertEqual(source.label, "demo")
        let rest = shell.presenter.response
        XCTAssertEqual(rest.ripple, rest.rippleRest)
        // A sudden loud onset: both rise, by at most the step limit per frame, and reach well above rest.
        let cameraBefore = try XCTUnwrap(shell.presenter.lastCamera)
        let loud = try frames(session, shell, 60) { source.pump(amplitude: 0.7) }
        let top = try XCTUnwrap(loud.last)
        XCTAssertGreaterThan(top.ripple, rest.rippleRest + 0.1, "ripple rose: \(top.ripple)")
        XCTAssertGreaterThan(top.ambient, rest.ambientRest + 0.1, "brightness rose: \(top.ambient)")
        XCTAssertGreaterThan(loud.prefix { $0.ripple < top.ripple - 1e-9 }.count, 3, "over several frames")
        XCTAssertGreaterThan(top.breathingScale, 1 + rest.rippleRest * TunnelResponse.breathingGain)
        // Audio never moves the camera: the rail camera depends on the flight alone.
        let core = try core(shell)
        let rail = try XCTUnwrap(shell.presenter.rail)
        let expected = OdysseyPresenter.camera(rail: rail, distance: core.state.distance,
                                               sway: core.flight.sway(limits: core.limits),
                                               origin: shell.presenter.rebase.origin)
        XCTAssertEqual(shell.presenter.lastCamera, expected)
        XCTAssertNotEqual(cameraBefore, expected, "the flight moved on meanwhile")
        // Two seconds of silence: back within 5 % of rest.
        let quiet = try frames(session, shell, 120) { source.pump(amplitude: 0) }
        let end = try XCTUnwrap(quiet.last)
        XCTAssertLessThanOrEqual(abs(end.ripple - end.rippleRest), 0.05 * end.rippleRest, "ripple \(end.ripple)")
        XCTAssertLessThanOrEqual(abs(end.ambient - end.ambientRest), 0.05 * end.ambientRest, "ambient \(end.ambient)")
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("sound response at rest."), shell.accessibilitySummary)
        session.close()
    }

    func testReduceMotionAndReduceFlashingNarrowTheResponse() async throws {
        let session = ExperienceSession()
        let log = SourceLog()
        let shell = try await open(session, factory: log.factory, reduceMotion: true, reduceFlashing: true)
        let source = try XCTUnwrap(log.made.last)
        let loud = try frames(session, shell, 90) { source.pump(amplitude: 1) }
        let top = try XCTUnwrap(loud.last)
        XCTAssertLessThanOrEqual(top.ripple, TunnelResponse.reducedRippleBounds.upperBound)
        XCTAssertLessThanOrEqual(top.ambient, TunnelResponse.reducedAmbientBounds.upperBound)
        XCTAssertEqual(top.ambientStepLimit, TunnelResponse.reducedAmbientStep)
        session.close()
    }

    func testSourceSwitchesKeepDistanceSpeedAndTheHost() async throws {
        let session = ExperienceSession()
        let log = SourceLog()
        let shell = try await open(session, permission: PermissionDouble(.granted), factory: log.factory)
        let presenter = shell.presenter
        try frames(session, shell, 60)
        let host = try XCTUnwrap(session.renderHost)
        let before = try core(shell).state
        XCTAssertGreaterThan(before.distance, 0)
        func check(_ label: String) throws {
            let state = try core(shell).state
            XCTAssertEqual(state.distance, before.distance, label)
            XCTAssertEqual(state.speed, before.speed, label)
            XCTAssertEqual(session.hostsAlive, 1, label)
            XCTAssertTrue(session.renderHost === host, "\(label): the same drawing context")
        }
        let microphone = await presenter.chooseMicrophone()
        XCTAssertTrue(microphone.isAccepted)
        XCTAssertEqual(try core(shell).state.source, .microphone)
        XCTAssertEqual(log.made.last?.label, "microphone")
        try check("microphone")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("odyssey-switch.wav")
        XCTAssertTrue(presenter.chooseFile(url: file))
        XCTAssertEqual(try core(shell).state.source, .file)
        XCTAssertEqual(presenter.mirror.sourceName, "odyssey-switch.wav")
        XCTAssertTrue(shell.accessibilitySummary.contains("odyssey-switch.wav"), shell.accessibilitySummary)
        try check("file")
        XCTAssertTrue(shell.handle(control: "source.demo").isAccepted)
        try check("demo")
        XCTAssertEqual(log.made.filter { $0.state == .running }.count, 1, "only the last source runs")
        XCTAssertEqual(log.made.last?.label, "demo")
        XCTAssertTrue(presenter.activeSource === log.made.last)
        // The flight continues from where it was.
        try frames(session, shell, 10)
        XCTAssertGreaterThan(try core(shell).state.distance, before.distance)
        session.close()
        XCTAssertTrue(log.made.allSatisfy { $0.state == .idle }, "closing stops every source")
        XCTAssertNil(presenter.activeSource)
    }

    func testDeniedAccessRefusesTheMicrophoneKeepsTheDemoAndShowsTheWayToSettings() async throws {
        for access in [MicrophonePermissionState.denied, .restricted] {
            let session = ExperienceSession()
            let permission = PermissionDouble(access)
            let log = SourceLog()
            let shell = try await open(session, permission: permission, factory: log.factory)
            let presenter = shell.presenter
            let demo = try XCTUnwrap(presenter.activeSource)
            let result = await presenter.chooseMicrophone()
            XCTAssertEqual(result, .rejected(.rule(code: OdysseyRule.permissionDenied)), "\(access)")
            XCTAssertEqual(permission.requests, 0, "\(access): no request")
            XCTAssertEqual(try core(shell).state.source, .demo)
            XCTAssertTrue(presenter.activeSource === demo, "\(access): the demo keeps playing")
            XCTAssertEqual(demo.state, .running)
            XCTAssertEqual(presenter.mirror.message, OdysseyPresenter.deniedMessage)
            XCTAssertTrue(presenter.mirror.showsSettingsLink)
            XCTAssertEqual(log.made.map(\.label), ["demo"], "\(access): no microphone source was made")
            try frames(session, shell, 10)
            XCTAssertEqual(session.hostsAlive, 1)
            session.close()
        }
    }

    func testANotDeterminedPermissionIsAskedOnceAndARefusalFallsBackToTheDemo() async throws {
        let session = ExperienceSession()
        let permission = PermissionDouble(.notDetermined, answer: .denied)
        let log = SourceLog()
        let shell = try await open(session, permission: permission, factory: log.factory)
        let result = await shell.presenter.chooseMicrophone()
        XCTAssertTrue(result.isAccepted, "accepted as requesting")
        XCTAssertEqual(permission.requests, 1)
        XCTAssertEqual(try core(shell).state.source, .demo)
        XCTAssertEqual(try core(shell).permission, .denied)
        XCTAssertTrue(shell.presenter.mirror.showsSettingsLink)
        let again = await shell.presenter.chooseMicrophone()
        XCTAssertEqual(again, .rejected(.rule(code: OdysseyRule.permissionDenied)))
        XCTAssertEqual(permission.requests, 1)
        session.close()
    }

    func testASchemaOneSnapshotOpensAsTheSameJourneyWithTheDemoSignal() async throws {
        let example = try XCTUnwrap(OdysseyCore.schemaOneExample())
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(snapshot.schemaVersion, 1)
        let session = ExperienceSession()
        let shell = try await open(session, snapshot: snapshot)
        let state = try core(shell).state
        XCTAssertEqual(state.source, .demo)
        XCTAssertEqual(state.world, .landscape)
        XCTAssertEqual(state.speedChoice, .fast)
        XCTAssertTrue(shell.presenter.activeSource is DemoAudioSource)
        session.close()
    }
}
