// MicrophoneSourceTests — feature 047 T-A06-103 (FR-A06-104, FR-A06-105, FR-A06-107; gap G-MICPERMISSION): the
// microphone source starts only with granted permission and never prompts; the session mixes with other audio; the
// system permission maps its three values; the tap sink mixes to mono. Real input is not started on the simulator:
// the granted path with a live engine is checked in the device campaign. Each test runs well under 3 s.
import AVFAudio
import Foundation
import XCTest
import VisualCoreAudioDSP
@testable import VisualCoreAudio

/// A permission double with a fixed state that counts requests.
@MainActor
private final class PermissionDouble: MicrophonePermission {
    var state: MicrophonePermissionState
    var requestCount = 0
    var stateAfterRequest: MicrophonePermissionState

    init(_ state: MicrophonePermissionState, afterRequest: MicrophonePermissionState? = nil) {
        self.state = state
        self.stateAfterRequest = afterRequest ?? state
    }

    func request() async -> MicrophonePermissionState {
        requestCount += 1
        state = stateAfterRequest
        return state
    }
}

@MainActor
final class MicrophoneSourceTests: XCTestCase {
    private func assertStartThrows(_ permissionState: MicrophonePermissionState, _ expected: AudioSourceError,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let permission = PermissionDouble(permissionState)
        let source = MicrophoneAudioSource(permission: permission)
        let buffer = SampleRingBuffer(capacity: 4_096)
        XCTAssertThrowsError(try source.start(into: buffer), file: file, line: line) { error in
            XCTAssertEqual(error as? AudioSourceError, expected, file: file, line: line)
        }
        XCTAssertEqual(source.engineStartCount, 0, "no engine without permission", file: file, line: line)
        XCTAssertEqual(permission.requestCount, 0, "start never prompts", file: file, line: line)
        XCTAssertEqual(buffer.totalWritten, 0, file: file, line: line)
        guard case .failed = source.state else { return XCTFail("state \(source.state)", file: file, line: line) }
        source.stop()
    }

    func testDeniedThrowsPermissionDenied() { assertStartThrows(.denied, .permissionDenied) }
    func testRestrictedThrowsPermissionDenied() { assertStartThrows(.restricted, .permissionDenied) }
    func testNotDeterminedThrowsNotDetermined() { assertStartThrows(.notDetermined, .notDetermined) }

    func testRequestThenDeniedStillThrows() async {
        let permission = PermissionDouble(.notDetermined, afterRequest: .denied)
        let source = MicrophoneAudioSource(permission: permission)
        let result = await permission.request()
        XCTAssertEqual(result, .denied)
        XCTAssertEqual(permission.requestCount, 1)
        XCTAssertThrowsError(try source.start(into: SampleRingBuffer(capacity: 1_024))) { error in
            XCTAssertEqual(error as? AudioSourceError, .permissionDenied)
        }
        XCTAssertEqual(source.engineStartCount, 0)
    }

    // The granted path is not started here: it would open the simulator's real input route. Checked on devices.

    func testSessionMixesWithOtherAudio() {
        XCTAssertEqual(MicrophoneAudioSource.sessionCategory, .playAndRecord)
        XCTAssertTrue(MicrophoneAudioSource.sessionOptions.contains(.mixWithOthers))
        XCTAssertFalse(MicrophoneAudioSource.sessionOptions.contains(.duckOthers))
        XCTAssertEqual(MicrophoneAudioSource.tapFrames, 1_024)
    }

    func testSystemPermissionMapping() {
        XCTAssertEqual(SystemMicrophonePermission.map(.undetermined), .notDetermined)
        XCTAssertEqual(SystemMicrophonePermission.map(.denied), .denied)
        XCTAssertEqual(SystemMicrophonePermission.map(.granted), .granted)
        // Reading the live state never prompts and never yields `.restricted`.
        XCTAssertNotEqual(SystemMicrophonePermission().state, .restricted)
    }

    func testTapSinkMixesStereoToMono() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1_024))
        pcm.frameLength = 1_024
        let channels = try XCTUnwrap(pcm.floatChannelData)
        for i in 0..<1_024 {
            channels[0][i] = 1
            channels[1][i] = Float(i % 2)
        }
        let buffer = SampleRingBuffer(capacity: 4_096)
        MicrophoneTapSink(buffer: buffer).consume(pcm)
        XCTAssertEqual(buffer.totalWritten, 1_024)
        var out = [Float](repeating: 0, count: 1_024)
        XCTAssertEqual(buffer.latest(1_024, into: &out), 1_024)
        XCTAssertEqual(out[0], 0.5)
        XCTAssertEqual(out[1], 1)
    }
}
