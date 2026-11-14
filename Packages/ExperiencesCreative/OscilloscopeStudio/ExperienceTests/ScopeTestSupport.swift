// ScopeTestSupport — feature 061 (A08-P01) T-A08-105 (FR-A08-110, FR-A08-121). Shared test doubles and helpers of the
// Oscilloscope Studio experience tests: microphone permissions that are granted or denied and never show a prompt, a
// silent mono microphone double (the real microphone is never started), source factories with the real deterministic
// `TestSignalAudioSource` (its first 1,024 frames are written by `start`, so a 1 ms/div window is complete on the first
// frame without waiting), opening the experience in the one app's session host, drawing frames, measuring the periods
// in a window from its interpolated rising zero crossings, and reading the pixels of a frame.
// Feature 062 (A08-P02) T-A08-206: a factory whose "file" is a mono 1 kHz test signal (one channel, so XY falls back).
// Feature 063 (A08-P03) T-A08-303: `ScopeBlockSource`, a synchronous test-signal double that writes a fixed number of
// frames in `start` (8,192 by default, so a 4,096-frame spectrum is full at once) and more only through `advance(_:)`
// (source time moves without the wall clock), and `ScopeBlockSources`, the factory that hands them out and keeps them.
// Feature 064 (A08-P04) T-A08-403 / T-A08-404: `open` takes an optional experience storage (the preset store), a
// temporary storage maker, synthetic pointer events and `settle()`, which lets the presenter's deferred actions (the
// `freeze.set 0` after a source change) run.
import Foundation
import XCTest
@testable import OscilloscopeStudioExperience
import OscilloscopeStudioCore
import VisualCoreAudio
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreUI

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

/// An announcement sink that records what it is given (VoiceOver is never driven by tests).
@MainActor
final class ScopeRecordingSink: AnnouncementSink {
    /// Every announced text, oldest first.
    private(set) var texts: [String] = []
    func announce(_ text: String) { texts.append(text) }
}

/// An announcement sink that drops everything (the default of `ScopeTest.open`).
@MainActor
final class ScopeSilentSink: AnnouncementSink {
    func announce(_ text: String) {}
}

/// A silent microphone double (the two-channel microphone source of A08-P05): its route's channel count is set by a
/// test (1 by default), as a route change would set it.
@MainActor
final class ScopeQuietMicrophone: StereoAudioSource {
    var sampleRate: Double { 48_000 }
    /// The channel count of the simulated route (1 or 2).
    var channelCount: Int
    private(set) var state: AudioSourceState = .idle

    init(channelCount: Int = 1) { self.channelCount = channelCount }

    func start(into buffer: StereoSampleBuffer) throws { state = .running }
    func stop() { state = .idle }
}

/// A microphone double with samples: the stereo test signal (1 kHz and 1.5 kHz) behind a route channel count set by
/// a test, as a route change would set it (feature 065).
@MainActor
final class ScopeRouteMicrophone: StereoAudioSource {
    private let inner = TestSignalAudioSource(signal: TestSignal(waveform: .sine, frequency: 1_000, amplitude: 0.5,
                                                                  channelCount: 2, rightRatio: 1.5))
    /// The channel count of the simulated route (1 or 2).
    var channelCount = 2
    var sampleRate: Double { inner.sampleRate }
    var state: AudioSourceState { inner.state }

    func start(into buffer: StereoSampleBuffer) throws { try inner.start(into: buffer) }
    func stop() { inner.stop() }
}

/// A deterministic two-channel source double: renders its `TestSignal` synchronously, `initialFrames` frames in
/// `start(into:)` and `advance(_:)` frames on request; no timer, so source time moves only when a test says so.
@MainActor
final class ScopeBlockSource: StereoAudioSource {
    let sampleRate: Double
    let channelCount: Int
    private(set) var state: AudioSourceState = .idle
    /// The frames written since the last start.
    private(set) var framesWritten = 0

    private let initialSignal: TestSignal
    private var signal: TestSignal
    private let initialFrames: Int
    private var buffer: StereoSampleBuffer?
    private var left: [Float] = []
    private var right: [Float] = []

    init(signal: TestSignal, initialFrames: Int = 8_192) {
        initialSignal = signal
        self.signal = signal
        self.initialFrames = initialFrames
        sampleRate = signal.sampleRate
        channelCount = signal.channelCount
    }

    func start(into buffer: StereoSampleBuffer) throws {
        self.buffer = buffer
        signal = initialSignal
        framesWritten = 0
        state = .running
        advance(initialFrames)
    }

    func stop() {
        buffer = nil
        state = .idle
    }

    /// Renders and writes the next `frames` frames in blocks of 1,024 (nothing while stopped).
    func advance(_ frames: Int) {
        guard let buffer else { return }
        var remaining = frames
        while remaining > 0 {
            let n = min(remaining, 1_024)
            signal.render(frames: n, left: &left, right: &right)
            buffer.write(left: left, right: channelCount == 2 ? right : left)
            remaining -= n
            framesWritten += n
        }
    }
}

/// A source factory whose test signals are `ScopeBlockSource`s writing `initialFrames` at start; keeps every source it
/// made so a test can advance the running one.
@MainActor
final class ScopeBlockSources {
    let initialFrames: Int
    /// Every test-signal source made, oldest first.
    private(set) var made: [ScopeBlockSource] = []

    init(initialFrames: Int = 8_192) { self.initialFrames = initialFrames }

    /// The newest source made.
    var last: ScopeBlockSource? { made.last }

    /// The factory: block test signals, files refused as undecodable, a silent microphone.
    var factory: ScopeSourceFactory {
        ScopeSourceFactory(testSignal: { [self] signal in
                               let source = ScopeBlockSource(signal: signal, initialFrames: initialFrames)
                               made.append(source)
                               return source
                           },
                           file: { _ in throw AudioSourceError.undecodable("test double") },
                           microphone: { _ in ScopeQuietMicrophone() })
    }
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

    /// Like `sources`, but every picked file opens as the one-channel 1 kHz sine at amplitude 0.5 (a mono source for
    /// the XY fallback; no file is read).
    static var monoFileSources: ScopeSourceFactory {
        ScopeSourceFactory(testSignal: { TestSignalAudioSource(signal: $0) },
                           file: { _ in
                               TestSignalAudioSource(signal: TestSignal(waveform: .sine, frequency: 1_000,
                                                                        amplitude: 0.5, channelCount: 1))
                           },
                           microphone: { _ in ScopeQuietMicrophone() })
    }

    /// Opens Oscilloscope Studio in `session` (seed 7) with `permission` and `factory`, lays the view out at `size`
    /// points and draws one frame.
    static func open(_ session: ExperienceSession, permission: MicrophonePermissionState = .granted,
                     factory: ScopeSourceFactory? = nil, storage: ExperienceStorage? = nil,
                     size: CGSize = CGSize(width: 160, height: 120),
                     announcementSink: (any AnnouncementSink)? = nil,
                     voiceOverRunning: (@MainActor () -> Bool)? = nil) async throws -> ExperienceShell<ScopePresenter> {
        let id = self.id
        let sources = factory ?? self.sources
        let access = ScopeFixedPermission(permission)
        var made: ExperienceShell<ScopePresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = OscilloscopeStudioExperience.make(id: id, permission: access, factory: sources,
                                                          storage: storage, announcementSink: announcementSink ?? ScopeSilentSink(),
                                                          voiceOverRunning: voiceOverRunning ?? { false })
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

    /// A fresh experience storage in a temporary directory with its own defaults suite; `cleanUp` removes both.
    nonisolated static func temporaryStorage() throws -> (storage: ExperienceStorage, cleanUp: @Sendable () -> Void) {
        let suite = "dev.visualcore.a08-p04.presets.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        let storage = ExperienceStorage(id: ExperienceID(rawValue: "a08.preset-test")!, root: root, defaults: defaults)
        return (storage, {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        })
    }

    /// A pointer event at (`x`, `y`) view points.
    static func touch(_ id: Int, _ phase: PointerPhase, _ x: Double, _ y: Double, at time: Double = 0) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: Vec2(x, y), timestamp: time)
    }

    /// Lets tasks the presenter scheduled on the main actor run.
    static func settle() async {
        for _ in 0..<10 { await Task.yield() }
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
