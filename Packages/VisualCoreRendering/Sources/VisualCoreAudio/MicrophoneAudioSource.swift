// MicrophoneAudioSource — feature 047 T-A06-103 (FR-A06-104, FR-A06-105, FR-A06-107; gap G-MICPERMISSION): live
// input from AVAudioEngine's input node, started only with granted permission, mixed with other apps' audio. Gaps
// G-AUDIOSOURCE and G-FILESOURCE are closed by the sibling files.
import AVFAudio
import Foundation
import VisualCoreAudioDSP

/// A source that writes the microphone input, mixed to mono, into the ring buffer (FR-A06-104).
///
/// `start(into:)` checks the permission first and throws without touching the audio session or engine unless the
/// state is `.granted`; it never prompts (call `MicrophonePermission.request()` beforehand). The session uses
/// `.playAndRecord` with `.mixWithOthers`, so music the person is playing keeps playing (FR-A06-107). The engine is
/// created on start and released on stop, which also deactivates the session with `.notifyOthersOnDeactivation`, so
/// the microphone is not held after leaving (FR-A06-105). Nothing is recorded to disk.
@MainActor
public final class MicrophoneAudioSource: AudioSource {
    /// Requested tap size, in frames (a hint; the system may deliver other sizes).
    public static let tapFrames: AVAudioFrameCount = 1_024
    /// Audio session category used while running.
    public static let sessionCategory: AVAudioSession.Category = .playAndRecord
    /// Audio session mode used while running.
    public static let sessionMode: AVAudioSession.Mode = .default
    /// Audio session options used while running: mix with other apps' audio (FR-A06-107).
    public static let sessionOptions: AVAudioSession.CategoryOptions = [.mixWithOthers]

    /// Sample rate of the input node while running (48 kHz until the first start).
    public private(set) var sampleRate: Double = 48_000
    /// Current lifecycle state.
    public private(set) var state: AudioSourceState = .idle

    private let permission: any MicrophonePermission
    private var engine: AVAudioEngine?
    private var sink: MicrophoneTapSink?
    /// Number of times the engine was started (test hook for "no engine without permission").
    internal private(set) var engineStartCount = 0

    /// Creates a microphone source gated by `permission`.
    public init(permission: any MicrophonePermission) {
        self.permission = permission
    }

    isolated deinit { tearDown() }

    /// Starts capturing into `buffer`.
    /// - Throws: `AudioSourceError.notDetermined` when permission was never asked, `.permissionDenied` when denied or
    ///   restricted, `.engineFailed` when the session or engine cannot start (for example no input route).
    public func start(into buffer: SampleRingBuffer) throws {
        stop()
        switch permission.state {
        case .granted: break
        case .notDetermined:
            state = .failed("microphone permission not determined")
            throw AudioSourceError.notDetermined
        case .denied, .restricted:
            state = .failed("microphone permission denied")
            throw AudioSourceError.permissionDenied
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(Self.sessionCategory, mode: Self.sessionMode, options: Self.sessionOptions)
            try session.setActive(true)
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw AudioSourceError.engineFailed("no audio input available")
            }
            let sink = MicrophoneTapSink(buffer: buffer)
            input.installTap(onBus: 0, bufferSize: Self.tapFrames, format: format, block: Self.makeTapBlock(sink))
            engine.prepare()
            self.engine = engine
            self.sink = sink
            try engine.start()
            engineStartCount += 1
            sampleRate = format.sampleRate
            state = .running
        } catch {
            tearDown()
            let message = (error as? AudioSourceError).map { "\($0)" } ?? error.localizedDescription
            state = .failed(message)
            if let known = error as? AudioSourceError { throw known }
            throw AudioSourceError.engineFailed(message)
        }
    }

    /// Stops capturing: removes the tap, stops the engine and deactivates the session. Safe to call when idle.
    public func stop() {
        tearDown()
        if case .running = state { state = .idle }
    }

    private func tearDown() {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        sink = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Builds the tap block outside the main actor: the block runs on the audio render thread, so it must not
    /// inherit main-actor isolation.
    private nonisolated static func makeTapBlock(_ sink: MicrophoneTapSink) -> AVAudioNodeTapBlock {
        { pcm, _ in sink.consume(pcm) }
    }
}

/// The audio-thread side of the microphone source: mixes each tap buffer to mono into preallocated scratch and
/// writes it to the ring buffer. No allocation, lock or main-actor hop happens in `consume(_:)`; buffers larger than
/// the scratch are processed in slices.
final class MicrophoneTapSink: @unchecked Sendable {
    /// Scratch capacity in frames.
    static let scratchFrames = 16_384

    private let buffer: SampleRingBuffer
    private let scratch: UnsafeMutablePointer<Float>

    /// Creates a sink writing to `buffer`.
    init(buffer: SampleRingBuffer) {
        self.buffer = buffer
        scratch = .allocate(capacity: Self.scratchFrames)
        scratch.initialize(repeating: 0, count: Self.scratchFrames)
    }

    deinit { scratch.deallocate() }

    /// Mixes `pcm` to mono and writes it to the ring buffer. Called on the audio render thread.
    func consume(_ pcm: AVAudioPCMBuffer) {
        guard let channels = pcm.floatChannelData else { return }
        let frames = Int(pcm.frameLength)
        let count = Int(pcm.format.channelCount)
        guard frames > 0, count > 0 else { return }
        let scale = 1 / Float(count)
        let interleaved = pcm.format.isInterleaved
        var done = 0
        while done < frames {
            let slice = min(Self.scratchFrames, frames - done)
            for frame in 0..<slice {
                var sum: Float = 0
                let index = done + frame
                if interleaved {
                    for channel in 0..<count { sum += channels[0][index * count + channel] }
                } else {
                    for channel in 0..<count { sum += channels[channel][index] }
                }
                scratch[frame] = sum * scale
            }
            buffer.write(UnsafeBufferPointer(start: scratch, count: slice))
            done += slice
        }
    }
}
