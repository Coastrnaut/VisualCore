// MicrophoneRecoveryTests — feature 050 (A06-P04) T-A06-402 (FR-A06-402, FR-A06-403; SC-A06-402; gap G-INTERRUPTION;
// research D3, D4, D6b): with an injected capture double the microphone source pauses on interruption began, resumes
// on ended with permission or on `resume()`, rebuilds on route loss and media-services reset, fails with a reason when
// a restart fails or the permission was withdrawn, ignores events while idle or failed, follows a private notification
// center while running, and across 50 seeded random sequences never runs two captures and ends in the state the spec's
// table demands. No real microphone is opened; each test runs well under 2 s.
import Foundation
import XCTest
import AVFAudio
import VisualCoreAudioDSP
@testable import VisualCoreAudio

/// A permission double with a settable state (same pattern as `MicrophoneSourceTests`).
@MainActor
private final class RecoveryPermissionDouble: MicrophonePermission {
    var state: MicrophonePermissionState
    var requestCount = 0

    init(_ state: MicrophonePermissionState) { self.state = state }

    func request() async -> MicrophonePermissionState {
        requestCount += 1
        return state
    }
}

private struct CaptureDoubleError: Error {}

/// A capture double: counts starts and stops, fails the next start on request and records any overlap.
@MainActor
private final class CaptureDouble: MicrophoneCapture {
    var failNextStart = false
    var startCalls = 0
    var successfulStarts = 0
    var stopCalls = 0
    var running = false
    var overlaps = 0
    var lastBuffer: SampleRingBuffer?

    func start(into buffer: SampleRingBuffer) throws -> Double {
        startCalls += 1
        if failNextStart {
            failNextStart = false
            throw CaptureDoubleError()
        }
        if running { overlaps += 1 }
        running = true
        successfulStarts += 1
        lastBuffer = buffer
        return 44_100
    }

    func stop() {
        stopCalls += 1
        running = false
    }
}

/// Counts capture factory calls.
@MainActor
private final class BuildCounter {
    var count = 0
}

/// SplitMix64 (local, deterministic per seed).
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func below(_ bound: Int) -> Int { Int(next() % UInt64(bound)) }
}

@MainActor
final class MicrophoneRecoveryTests: XCTestCase {
    private var permission: RecoveryPermissionDouble!
    private var capture: CaptureDouble!
    private var buffer: SampleRingBuffer!

    override func setUp() async throws {
        permission = RecoveryPermissionDouble(.granted)
        capture = CaptureDouble()
        buffer = SampleRingBuffer(capacity: 4_096)
    }

    private func makeSource(center: NotificationCenter? = nil) -> MicrophoneAudioSource {
        let capture = self.capture!
        return MicrophoneAudioSource(permission: permission, makeCapture: { capture }, center: center)
    }

    private func runningSource(center: NotificationCenter? = nil) throws -> MicrophoneAudioSource {
        let source = makeSource(center: center)
        try source.start(into: buffer)
        XCTAssertEqual(source.state, .running)
        XCTAssertEqual(source.runningCaptures, 1)
        XCTAssertEqual(source.sampleRate, 44_100)
        return source
    }

    // MARK: Scenarios (FR-A06-402)

    func testBeganInterruptsAndStopsCapture() throws {
        let source = try runningSource()
        source.handle(.interruptionBegan)
        XCTAssertEqual(source.state, .interrupted)
        XCTAssertFalse(source.awaitsResume)
        XCTAssertFalse(capture.running)
        XCTAssertEqual(source.runningCaptures, 0)
    }

    func testEndedWithResumeRestartsIntoKeptBuffer() throws {
        let source = try runningSource()
        source.handle(.interruptionBegan)
        source.handle(.interruptionEnded(shouldResume: true))
        XCTAssertEqual(source.state, .running)
        XCTAssertFalse(source.awaitsResume)
        XCTAssertEqual(source.runningCaptures, 1)
        XCTAssertEqual(source.engineStartCount, 2)
        XCTAssertTrue(capture.lastBuffer === buffer, "restart reuses the kept buffer")
    }

    func testEndedWithoutResumeWaitsForResume() throws {
        let source = try runningSource()
        source.handle(.interruptionBegan)
        XCTAssertFalse(source.awaitsResume)
        source.handle(.interruptionEnded(shouldResume: false))
        XCTAssertEqual(source.state, .interrupted)
        XCTAssertTrue(source.awaitsResume)
        XCTAssertEqual(source.runningCaptures, 0)
        source.resume()
        XCTAssertEqual(source.state, .running)
        XCTAssertFalse(source.awaitsResume)
        XCTAssertEqual(source.runningCaptures, 1)
    }

    func testRouteLostAndMediaResetWhileRunningRebuild() throws {
        let source = try runningSource()
        source.handle(.routeLost)
        XCTAssertEqual(source.state, .running)
        XCTAssertEqual(capture.stopCalls, 1)
        XCTAssertEqual(source.engineStartCount, 2)
        source.handle(.mediaServicesReset)
        XCTAssertEqual(source.state, .running)
        XCTAssertEqual(capture.stopCalls, 2)
        XCTAssertEqual(source.engineStartCount, 3)
        XCTAssertEqual(source.runningCaptures, 1)
        XCTAssertEqual(capture.overlaps, 0)
    }

    func testRouteLostWhileInterruptedKeepsInterrupted() throws {
        let source = try runningSource()
        source.handle(.interruptionBegan)
        source.handle(.interruptionEnded(shouldResume: false))
        source.handle(.routeLost)
        source.handle(.mediaServicesReset)
        XCTAssertEqual(source.state, .interrupted)
        XCTAssertTrue(source.awaitsResume)
        XCTAssertEqual(source.engineStartCount, 1)
    }

    func testRestartFailureEndsFailed() throws {
        let source = try runningSource()
        capture.failNextStart = true
        source.handle(.routeLost)
        guard case .failed(let reason) = source.state else { return XCTFail("state \(source.state)") }
        XCTAssertFalse(reason.isEmpty)
        XCTAssertEqual(source.runningCaptures, 0)
        XCTAssertFalse(source.awaitsResume)
        // Failed: further events and resume are ignored.
        source.handle(.interruptionEnded(shouldResume: true))
        source.handle(.mediaServicesReset)
        source.resume()
        XCTAssertEqual(source.state, .failed(reason))
        XCTAssertEqual(capture.startCalls, 2)
    }

    func testResumeFailureEndsFailed() throws {
        let source = try runningSource()
        source.handle(.interruptionBegan)
        source.handle(.interruptionEnded(shouldResume: false))
        capture.failNextStart = true
        source.resume()
        guard case .failed = source.state else { return XCTFail("state \(source.state)") }
        XCTAssertFalse(source.awaitsResume)
        XCTAssertEqual(source.runningCaptures, 0)
    }

    func testRestartRechecksPermission() throws {
        let source = try runningSource()
        source.handle(.interruptionBegan)
        permission.state = .denied
        source.handle(.interruptionEnded(shouldResume: true))
        XCTAssertEqual(source.state, .failed("microphone permission denied"))
        XCTAssertEqual(capture.startCalls, 1, "no capture without permission")
        XCTAssertEqual(permission.requestCount, 0, "never prompts")
    }

    func testEventsWhileIdleAreIgnored() {
        let source = makeSource()
        for event: AudioSessionEvent in [.interruptionBegan, .interruptionEnded(shouldResume: true), .routeLost,
                                         .mediaServicesReset] {
            source.handle(event)
        }
        source.resume()
        XCTAssertEqual(source.state, .idle)
        XCTAssertEqual(capture.startCalls, 0)
        XCTAssertEqual(source.engineStartCount, 0)
    }

    func testResumeWhileRunningAndEndedWhileRunningDoNothing() throws {
        let source = try runningSource()
        source.resume()
        source.handle(.interruptionEnded(shouldResume: true))
        XCTAssertEqual(source.state, .running)
        XCTAssertEqual(source.engineStartCount, 1)
    }

    func testStopFromInterruptedGoesIdle() throws {
        let source = try runningSource()
        source.handle(.interruptionBegan)
        source.handle(.interruptionEnded(shouldResume: false))
        source.stop()
        XCTAssertEqual(source.state, .idle)
        XCTAssertFalse(source.awaitsResume)
        source.resume()
        XCTAssertEqual(source.state, .idle)
    }

    func testStartFailureThrowsEngineFailed() {
        let source = makeSource()
        capture.failNextStart = true
        XCTAssertThrowsError(try source.start(into: buffer)) { error in
            guard case .engineFailed = error as? AudioSourceError else { return XCTFail("error \(error)") }
        }
        guard case .failed = source.state else { return XCTFail("state \(source.state)") }
        XCTAssertEqual(source.runningCaptures, 0)
        XCTAssertEqual(source.engineStartCount, 0)
    }

    func testDeniedStartNeverBuildsCapture() {
        permission.state = .denied
        let capture = self.capture!
        let built = BuildCounter()
        let source = MicrophoneAudioSource(permission: permission, makeCapture: {
            built.count += 1
            return capture
        }, center: nil)
        XCTAssertThrowsError(try source.start(into: buffer))
        XCTAssertEqual(built.count, 0)
        XCTAssertEqual(source.engineStartCount, 0)
    }

    func testMonitorOnPrivateCenterDrivesSourceWhileRunningOnly() throws {
        let center = NotificationCenter()
        let source = try runningSource(center: center)
        center.post(name: AVAudioSession.interruptionNotification, object: nil,
                    userInfo: [AVAudioSessionInterruptionTypeKey: NSNumber(value: AVAudioSession.InterruptionType
                        .began.rawValue)])
        pump { source.state == .interrupted }
        XCTAssertEqual(source.state, .interrupted)
        source.stop()
        center.post(name: AVAudioSession.interruptionNotification, object: nil,
                    userInfo: [AVAudioSessionInterruptionTypeKey: NSNumber(value: AVAudioSession.InterruptionType
                        .ended.rawValue),
                               AVAudioSessionInterruptionOptionKey: NSNumber(value: AVAudioSession.InterruptionOptions
                                   .shouldResume.rawValue)])
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(source.state, .idle, "monitor dropped on stop")
        XCTAssertEqual(source.engineStartCount, 1)
    }

    private func pump(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(1)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    // MARK: Seeded random sequences (FR-A06-403; SC-A06-402)

    private enum ModelState: Equatable { case running, interrupted, failed }

    func testFiftySeededSequencesNeverRunTwoCaptures() throws {
        for seed in UInt64(1)...50 {
            var random = SplitMix64(seed: seed)
            permission = RecoveryPermissionDouble(.granted)
            capture = CaptureDouble()
            buffer = SampleRingBuffer(capacity: 1_024)
            let source = try runningSource()
            var model = ModelState.running
            var awaits = false
            var pendingFail = false

            /// The model of one restart attempt (consumes a pending failure like the double does).
            func modelStart() -> ModelState {
                if pendingFail { pendingFail = false; return .failed }
                return .running
            }

            for step in 0..<40 {
                if random.below(10) == 0 {
                    capture.failNextStart = true
                    pendingFail = true
                }
                let op = random.below(7)
                switch op {
                case 0:
                    source.handle(.interruptionBegan)
                    if model == .running || model == .interrupted { model = .interrupted; awaits = false }
                case 1:
                    source.handle(.interruptionEnded(shouldResume: true))
                    if model == .interrupted { model = modelStart(); awaits = false }
                case 2:
                    source.handle(.interruptionEnded(shouldResume: false))
                    if model == .interrupted { awaits = true }
                case 3, 4:
                    source.handle(op == 3 ? .routeLost : .mediaServicesReset)
                    if model == .running { model = modelStart() }
                case 5:
                    source.resume()
                    if model == .interrupted { model = modelStart(); awaits = false }
                default:
                    // Occasionally the person starts the microphone again (also the way out of `.failed`).
                    _ = try? source.start(into: buffer)
                    model = modelStart()
                    awaits = false
                }
                let context = "seed \(seed) step \(step) op \(op)"
                XCTAssertLessThanOrEqual(source.runningCaptures, 1, context)
                XCTAssertEqual(capture.overlaps, 0, context)
                XCTAssertEqual(source.runningCaptures, model == .running ? 1 : 0, context)
                XCTAssertEqual(capture.running, model == .running, context)
                XCTAssertEqual(source.awaitsResume, awaits, context)
                switch (model, source.state) {
                case (.running, .running), (.interrupted, .interrupted), (.failed, .failed): break
                default: XCTFail("\(context): model \(model), source \(source.state)")
                }
            }
            source.stop()
            XCTAssertEqual(source.runningCaptures, 0, "seed \(seed)")
        }
    }
}
