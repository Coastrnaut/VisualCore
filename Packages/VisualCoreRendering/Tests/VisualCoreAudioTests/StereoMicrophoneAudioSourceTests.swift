// StereoMicrophoneAudioSourceTests — feature 065 (A08-P05) T-A08-502 (FR-A08-501; SC-A08-502; gap G-STEREOMIC;
// research D1): with an injected capture double the two-channel microphone reports 2 channels on a two-channel route
// and keeps left and right apart, reports 1 on a one-channel route, refuses denied, restricted and undetermined
// permission without building a capture (same errors and states as the mono source), stops on interruption and
// restarts on `resume()`, and rebuilds with the new channel count on a route change. The tap sink keeps channels 0
// and 1 apart and duplicates channel 0 on a one-channel buffer. No real microphone is opened; each test runs well
// under 2 s.
import AVFAudio
import Foundation
import XCTest
import VisualCoreAudioDSP
@testable import VisualCoreAudio

/// A permission double with a settable state that counts requests.
@MainActor
private final class StereoPermissionDouble: MicrophonePermission {
    var state: MicrophonePermissionState
    var requestCount = 0

    init(_ state: MicrophonePermissionState) { self.state = state }

    func request() async -> MicrophonePermissionState {
        requestCount += 1
        return state
    }
}

private struct StereoCaptureDoubleError: Error {}

/// A capture double: reports a configurable route, writes one recognisable block (left +0.25, right −0.75; channel 0
/// twice on a one-channel route) on start, counts starts and stops and records any overlap.
@MainActor
private final class StereoCaptureDouble: StereoMicrophoneCapture {
    var routeChannels = 2
    var failNextStart = false
    var startCalls = 0
    var stopCalls = 0
    var running = false
    var overlaps = 0
    var lastBuffer: StereoSampleBuffer?

    func start(into buffer: StereoSampleBuffer) throws -> (sampleRate: Double, channelCount: Int) {
        startCalls += 1
        if failNextStart {
            failNextStart = false
            throw StereoCaptureDoubleError()
        }
        if running { overlaps += 1 }
        running = true
        lastBuffer = buffer
        let channel0 = [Float](repeating: 0.25, count: 256)
        let channel1 = [Float](repeating: -0.75, count: 256)
        buffer.write(left: channel0, right: routeChannels == 2 ? channel1 : channel0)
        return (44_100, routeChannels)
    }

    func stop() {
        stopCalls += 1
        running = false
    }
}

/// Counts capture factory calls.
@MainActor
private final class StereoBuildCounter {
    var count = 0
}

@MainActor
final class StereoMicrophoneAudioSourceTests: XCTestCase {
    private var permission: StereoPermissionDouble!
    private var capture: StereoCaptureDouble!
    private var buffer: StereoSampleBuffer!

    override func setUp() async throws {
        permission = StereoPermissionDouble(.granted)
        capture = StereoCaptureDouble()
        buffer = StereoSampleBuffer(capacityFrames: 4_096)
    }

    private func makeSource(center: NotificationCenter? = nil) -> StereoMicrophoneAudioSource {
        let capture = self.capture!
        return StereoMicrophoneAudioSource(permission: permission, makeCapture: { capture }, center: center)
    }

    private func latest(_ count: Int) -> (left: [Float], right: [Float]) {
        var left = [Float](repeating: 0, count: count)
        var right = [Float](repeating: 0, count: count)
        XCTAssertEqual(buffer.latestFrames(count, left: &left, right: &right), count)
        return (left, right)
    }

    // MARK: Routes (SC-A08-502)

    func testTwoChannelRouteReportsTwoAndKeepsChannelsApart() throws {
        let source = makeSource()
        XCTAssertEqual(source.channelCount, 1, "1 until the first start")
        try source.start(into: buffer)
        XCTAssertEqual(source.state, .running)
        XCTAssertEqual(source.channelCount, 2)
        XCTAssertEqual(source.sampleRate, 44_100)
        XCTAssertEqual(source.runningCaptures, 1)
        let frames = latest(256)
        XCTAssertTrue(frames.left.allSatisfy { $0 == 0.25 })
        XCTAssertTrue(frames.right.allSatisfy { $0 == -0.75 })
        source.stop()
        XCTAssertEqual(source.state, .idle)
        XCTAssertFalse(capture.running)
    }

    func testOneChannelRouteReportsOne() throws {
        capture.routeChannels = 1
        let source = makeSource()
        try source.start(into: buffer)
        XCTAssertEqual(source.channelCount, 1)
        let frames = latest(256)
        XCTAssertEqual(frames.left, frames.right, "one-channel route writes the same samples to both channels")
    }

    func testRouteChangeRebuildsWithNewChannelCount() throws {
        let source = makeSource()
        try source.start(into: buffer)
        XCTAssertEqual(source.channelCount, 2)
        capture.routeChannels = 1
        source.handle(.routeLost)
        XCTAssertEqual(source.state, .running)
        XCTAssertEqual(source.channelCount, 1)
        XCTAssertEqual(capture.stopCalls, 1)
        XCTAssertEqual(source.engineStartCount, 2)
        capture.routeChannels = 2
        source.handleNewRoute()
        XCTAssertEqual(source.state, .running)
        XCTAssertEqual(source.channelCount, 2)
        XCTAssertEqual(source.engineStartCount, 3)
        XCTAssertEqual(source.runningCaptures, 1)
        XCTAssertEqual(capture.overlaps, 0)
        XCTAssertTrue(capture.lastBuffer === buffer, "rebuild reuses the kept buffer")
    }

    func testNewRouteNotificationOnPrivateCenterRebuildsWhileRunningOnly() throws {
        let center = NotificationCenter()
        let source = makeSource(center: center)
        try source.start(into: buffer)
        capture.routeChannels = 1
        let newDevice = [AVAudioSessionRouteChangeReasonKey:
                            NSNumber(value: AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue)]
        center.post(name: AVAudioSession.routeChangeNotification, object: nil, userInfo: newDevice)
        pump { source.channelCount == 1 }
        XCTAssertEqual(source.channelCount, 1)
        XCTAssertEqual(source.engineStartCount, 2)
        source.stop()
        center.post(name: AVAudioSession.routeChangeNotification, object: nil, userInfo: newDevice)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(source.state, .idle, "observer dropped on stop")
        XCTAssertEqual(source.engineStartCount, 2)
    }

    func testRouteChangeReasonMapping() {
        func info(_ reason: AVAudioSession.RouteChangeReason) -> [AnyHashable: Any] {
            [AVAudioSessionRouteChangeReasonKey: NSNumber(value: reason.rawValue)]
        }
        XCTAssertTrue(StereoMicrophoneAudioSource.isNewDevice(info(.newDeviceAvailable)))
        XCTAssertFalse(StereoMicrophoneAudioSource.isNewDevice(info(.oldDeviceUnavailable)))
        XCTAssertFalse(StereoMicrophoneAudioSource.isNewDevice(info(.categoryChange)))
        XCTAssertFalse(StereoMicrophoneAudioSource.isNewDevice(nil))
    }

    // MARK: Permission (same errors and states as MicrophoneAudioSource)

    private func assertRefused(_ state: MicrophonePermissionState, _ expected: AudioSourceError, reason: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        permission.state = state
        let capture = self.capture!
        let built = StereoBuildCounter()
        let source = StereoMicrophoneAudioSource(permission: permission, makeCapture: {
            built.count += 1
            return capture
        }, center: nil)
        XCTAssertThrowsError(try source.start(into: buffer), file: file, line: line) { error in
            XCTAssertEqual(error as? AudioSourceError, expected, file: file, line: line)
        }
        XCTAssertEqual(source.state, .failed(reason), file: file, line: line)
        XCTAssertEqual(built.count, 0, "no capture without permission", file: file, line: line)
        XCTAssertEqual(source.engineStartCount, 0, file: file, line: line)
        XCTAssertEqual(permission.requestCount, 0, "start never prompts", file: file, line: line)
        XCTAssertEqual(buffer.totalFrames, 0, file: file, line: line)
    }

    func testDeniedIsRefusedWithoutCapture() {
        assertRefused(.denied, .permissionDenied, reason: "microphone permission denied")
    }

    func testRestrictedIsRefusedWithoutCapture() {
        assertRefused(.restricted, .permissionDenied, reason: "microphone permission denied")
    }

    func testUndeterminedIsRefusedWithoutCapture() {
        assertRefused(.notDetermined, .notDetermined, reason: "microphone permission not determined")
    }

    func testStartFailureThrowsEngineFailed() {
        let source = makeSource()
        capture.failNextStart = true
        XCTAssertThrowsError(try source.start(into: buffer)) { error in
            guard case .engineFailed = error as? AudioSourceError else { return XCTFail("error \(error)") }
        }
        guard case .failed = source.state else { return XCTFail("state \(source.state)") }
        XCTAssertEqual(source.runningCaptures, 0)
    }

    // MARK: Interruptions (as MicrophoneAudioSource)

    func testInterruptionStopsAndResumeRestarts() throws {
        let source = makeSource()
        try source.start(into: buffer)
        source.handle(.interruptionBegan)
        XCTAssertEqual(source.state, .interrupted)
        XCTAssertFalse(capture.running)
        XCTAssertEqual(source.runningCaptures, 0)
        source.handle(.interruptionEnded(shouldResume: false))
        XCTAssertEqual(source.state, .interrupted)
        XCTAssertTrue(source.awaitsResume)
        source.handleNewRoute()
        XCTAssertEqual(source.engineStartCount, 1, "a new route while interrupted does not restart")
        capture.routeChannels = 1
        source.resume()
        XCTAssertEqual(source.state, .running)
        XCTAssertFalse(source.awaitsResume)
        XCTAssertEqual(source.runningCaptures, 1)
        XCTAssertEqual(source.channelCount, 1, "restart reports the current route")
        XCTAssertEqual(capture.overlaps, 0)
    }

    func testInterruptionEndedWithResumeRestarts() throws {
        let source = makeSource()
        try source.start(into: buffer)
        source.handle(.interruptionBegan)
        source.handle(.interruptionEnded(shouldResume: true))
        XCTAssertEqual(source.state, .running)
        XCTAssertEqual(source.engineStartCount, 2)
    }

    func testRestartRechecksPermission() throws {
        let source = makeSource()
        try source.start(into: buffer)
        source.handle(.interruptionBegan)
        permission.state = .denied
        source.resume()
        XCTAssertEqual(source.state, .failed("microphone permission denied"))
        XCTAssertEqual(capture.startCalls, 1)
        XCTAssertEqual(source.runningCaptures, 0)
    }

    func testEventsWhileIdleAreIgnored() {
        let source = makeSource()
        for event: AudioSessionEvent in [.interruptionBegan, .interruptionEnded(shouldResume: true), .routeLost,
                                         .mediaServicesReset] {
            source.handle(event)
        }
        source.handleNewRoute()
        source.resume()
        XCTAssertEqual(source.state, .idle)
        XCTAssertEqual(capture.startCalls, 0)
    }

    // MARK: Tap sink

    func testTapSinkKeepsChannelsApartAndDuplicatesMono() throws {
        let layout = try XCTUnwrap(AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | 3))
        let stereo = AVAudioFormat(standardFormatWithSampleRate: 48_000, channelLayout: layout)
        let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: stereo, frameCapacity: 512))
        pcm.frameLength = 512
        let channels = try XCTUnwrap(pcm.floatChannelData)
        for i in 0..<512 {
            channels[0][i] = Float(i)
            channels[1][i] = -Float(i)
            channels[2][i] = 99
        }
        StereoMicrophoneTapSink(buffer: buffer).consume(pcm)
        XCTAssertEqual(buffer.totalFrames, 512)
        var frames = latest(512)
        XCTAssertEqual(frames.left[7], 7)
        XCTAssertEqual(frames.right[7], -7, "channel 1, not channel 2")

        let mono = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let monoPCM = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: 256))
        monoPCM.frameLength = 256
        let monoChannels = try XCTUnwrap(monoPCM.floatChannelData)
        for i in 0..<256 { monoChannels[0][i] = Float(i) * 0.5 }
        StereoMicrophoneTapSink(buffer: buffer).consume(monoPCM)
        frames = latest(256)
        XCTAssertEqual(frames.left, frames.right)
        XCTAssertEqual(frames.left[10], 5)

        let interleaved = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                                                      channels: 2, interleaved: true))
        let interleavedPCM = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: interleaved, frameCapacity: 128))
        interleavedPCM.frameLength = 128
        let samples = try XCTUnwrap(interleavedPCM.floatChannelData)
        for i in 0..<128 {
            samples[0][2 * i] = 1
            samples[0][2 * i + 1] = -1
        }
        StereoMicrophoneTapSink(buffer: buffer).consume(interleavedPCM)
        frames = latest(128)
        XCTAssertTrue(frames.left.allSatisfy { $0 == 1 })
        XCTAssertTrue(frames.right.allSatisfy { $0 == -1 })
    }

    private func pump(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(1)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}
