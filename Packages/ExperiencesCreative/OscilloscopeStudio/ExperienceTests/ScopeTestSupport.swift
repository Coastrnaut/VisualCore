// ScopeTestSupport — feature 061 (A08-P01) T-A08-105 (FR-A08-110, FR-A08-121). Shared test doubles and helpers of the
// Oscilloscope Studio experience tests: microphone permissions that are granted or denied and never show a prompt, a
// silent mono microphone double (the real microphone is never started), source factories with the real deterministic
// `TestSignalAudioSource` (its first 1,024 frames are written by `start`, so a 1 ms/div window is complete on the first
// frame without waiting), opening the experience in the one app's session host, drawing frames, measuring the periods
// in a window from its interpolated rising zero crossings, and reading the pixels of a frame.
import Foundation
import XCTest
@testable import OscilloscopeStudioExperience
import OscilloscopeStudioCore
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// A microphone permission with a fixed answer that never asks the system.
@MainActor
final class ScopeFixedPermission: MicrophonePermission {
    /// The answer.
    let answer: MicrophonePermissionState
    /// How often `request()` was called.
    private(set) var requests = 0

    init(_ answer: MicrophonePermissionState) { self.answer = answer }

    var state: MicrophonePermissionState { answer }
    func request() async -> MicrophonePermissionState {
        requests += 1
        return answer
    }
}

/// A silent mono source double standing in for the microphone.
@MainActor
final class ScopeQuietMicrophone: AudioSource {
    var sampleRate: Double { 48_000 }
    private(set) var state: AudioSourceState = .idle

    func start(into buffer: SampleRingBuffer) throws { state = .running }
    func stop() { state = .idle }
}

@MainActor
enum ScopeTest {
    /// The experience id `a08.oscilloscope-studio`.
    static var id: ExperienceID { OscilloscopeStudioExperience.id ?? ExperienceID(rawValue: "a08.unknown")! }

    /// The real test-signal source, a file source that refuses every file as undecodable and a silent microphone.
    static var sources: ScopeSourceFactory {
        ScopeSourceFactory(testSignal: { TestSignalAudioSource(signal: $0) },
                           file: { _ in throw AudioSourceError.undecodable("test double") },
                           microphone: { _ in ScopeQuietMicrophone() })
    }

    /// Like `sources`, but every test signal is a flat line (amplitude 0, two channels).
    static var flatSources: ScopeSourceFactory {
        ScopeSourceFactory(testSignal: { _ in
                               TestSignalAudioSource(signal: TestSignal(waveform: .sine, amplitude: 0, channelCount: 2))
                           },
                           file: { _ in throw AudioSourceError.undecodable("test double") },
                           microphone: { _ in ScopeQuietMicrophone() })
    }

    /// Opens Oscilloscope Studio in `session` (seed 7) with `permission` and `factory`, lays the view out at `size`
    /// points and draws one frame.
    static func open(_ session: ExperienceSession, permission: MicrophonePermissionState = .granted,
                     factory: ScopeSourceFactory? = nil,
                     size: CGSize = CGSize(width: 160, height: 120)) async throws -> ExperienceShell<ScopePresenter> {
        let id = self.id
        let sources = factory ?? self.sources
        let access = ScopeFixedPermission(permission)
        var made: ExperienceShell<ScopePresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = OscilloscopeStudioExperience.make(id: id, permission: access, factory: sources)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(origin: .zero, size: size)
            view.layoutIfNeeded()
        }
        let shell = try XCTUnwrap(made)
        try frames(session, 1)
        return shell
    }

    /// Draws `count` frames back to back.
    static func frames(_ session: ExperienceSession, _ count: Int) throws {
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<count { XCTAssertTrue(host.renderOneFrame(present: false)) }
    }

    /// Draws a frame about every 16 ms until `done` holds or `limit` frames were drawn; returns whether it held.
    static func frames(_ session: ExperienceSession, until done: () -> Bool, limit: Int = 60) async throws -> Bool {
        for _ in 0..<limit {
            if done() { return true }
            try frames(session, 1)
            try await Task.sleep(for: .milliseconds(16))
        }
        return done()
    }

    /// The periods in `samples`: the window length divided by the mean distance of its rising zero crossings
    /// (interpolated between the samples around each crossing); nil with fewer than two crossings.
    static func measuredPeriods(_ samples: [Float]) -> Double? {
        var crossings: [Double] = []
        for i in 1..<max(samples.count, 1) where samples[i - 1] < 0 && samples[i] >= 0 {
            let a = Double(samples[i - 1]), b = Double(samples[i])
            crossings.append(Double(i - 1) + (-a) / (b - a))
        }
        guard crossings.count >= 2, let first = crossings.first, let last = crossings.last, last > first else {
            return nil
        }
        let period = (last - first) / Double(crossings.count - 1)
        return Double(samples.count) / period
    }

    /// The pixels of a freshly drawn frame with its width and height.
    static func picture(_ session: ExperienceSession) throws -> (rgba: [UInt8], width: Int, height: Int) {
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let size = host.pixelSize
        return (host.readPixels(), size.width, size.height)
    }

    /// The number of pixels whose RGB differs by more than 16 in some channel.
    static func differingPixels(_ a: [UInt8], _ b: [UInt8]) -> Int {
        guard a.count == b.count else { return max(a.count, b.count) / 4 }
        var count = 0
        var i = 0
        while i + 3 < a.count {
            if abs(Int(a[i]) - Int(b[i])) > 16 || abs(Int(a[i + 1]) - Int(b[i + 1])) > 16
                || abs(Int(a[i + 2]) - Int(b[i + 2])) > 16 { count += 1 }
            i += 4
        }
        return count
    }
}
