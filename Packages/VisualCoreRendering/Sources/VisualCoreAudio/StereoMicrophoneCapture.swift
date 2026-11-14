// StereoMicrophoneCapture — feature 065 (A08-P05) T-A08-502 (FR-A08-501; SC-A08-502; gap G-STEREOMIC; research D1):
// the capture seam of the two-channel microphone source. `SystemStereoMicrophoneCapture` configures the audio session
// exactly like the mono `SystemMicrophoneCapture` (same category, mode and options), taps the input node and keeps
// channels 0 and 1 apart, or duplicates channel 0 into both buffer channels on a one-channel route. Tests inject a
// double so routes and interruptions are exercised without the real microphone. Contract
// specs/065-os-p05-routes-accuracy/contracts/api.md.
import AVFAudio
import Foundation
import VisualCoreAudioDSP

/// One capture engine writing two-channel microphone frames into a `StereoSampleBuffer` (internal seam, research D1).
@MainActor
protocol StereoMicrophoneCapture: AnyObject {
    /// Configures the session, starts the engine and writes left and right frames into `buffer`.
    /// - Returns: the sample rate of the delivered frames, in hertz, and the number of distinct channels the route
    ///   delivers (1, written to both buffer channels, or 2).
    /// - Throws: when the capture cannot start; nothing stays running after a throw.
    func start(into buffer: StereoSampleBuffer) throws -> (sampleRate: Double, channelCount: Int)
    /// Stops the engine and releases the session. Safe to call when not running.
    func stop()
}

/// The system capture: `AVAudioSession` with `MicrophoneAudioSource`'s category, mode and options, an `AVAudioEngine`
/// whose input node is tapped by a `StereoMicrophoneTapSink`, torn down with `.notifyOthersOnDeactivation`.
@MainActor
final class SystemStereoMicrophoneCapture: StereoMicrophoneCapture {
    private var engine: AVAudioEngine?
    private var sink: StereoMicrophoneTapSink?

    /// Creates an idle capture; nothing touches the audio session until `start(into:)`.
    init() {}

    isolated deinit { tearDown() }

    /// Starts a new engine into `buffer` (stopping any previous one first).
    func start(into buffer: StereoSampleBuffer) throws -> (sampleRate: Double, channelCount: Int) {
        tearDown()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(MicrophoneAudioSource.sessionCategory, mode: MicrophoneAudioSource.sessionMode,
                                    options: MicrophoneAudioSource.sessionOptions)
            try session.setActive(true)
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw AudioSourceError.engineFailed("no audio input available")
            }
            let sink = StereoMicrophoneTapSink(buffer: buffer)
            input.installTap(onBus: 0, bufferSize: MicrophoneAudioSource.tapFrames, format: format,
                             block: Self.makeTapBlock(sink))
            engine.prepare()
            self.engine = engine
            self.sink = sink
            try engine.start()
            return (format.sampleRate, min(Int(format.channelCount), 2))
        } catch {
            tearDown()
            throw error
        }
    }

    /// Removes the tap, stops the engine and deactivates the session. Safe to call when idle.
    func stop() { tearDown() }

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
    private nonisolated static func makeTapBlock(_ sink: StereoMicrophoneTapSink) -> AVAudioNodeTapBlock {
        { pcm, _ in sink.consume(pcm) }
    }
}

/// The audio-thread side of the two-channel microphone: copies channels 0 and 1 of each tap buffer (or channel 0
/// twice on a one-channel route) into preallocated scratch and writes them to the stereo buffer. No allocation, lock
/// or main-actor hop happens in `consume(_:)`; buffers larger than the scratch are processed in slices.
final class StereoMicrophoneTapSink: @unchecked Sendable {
    /// Scratch capacity in frames, per channel.
    static let scratchFrames = 16_384

    private let buffer: StereoSampleBuffer
    private let left: UnsafeMutablePointer<Float>
    private let right: UnsafeMutablePointer<Float>

    /// Creates a sink writing to `buffer`.
    init(buffer: StereoSampleBuffer) {
        self.buffer = buffer
        left = .allocate(capacity: Self.scratchFrames)
        left.initialize(repeating: 0, count: Self.scratchFrames)
        right = .allocate(capacity: Self.scratchFrames)
        right.initialize(repeating: 0, count: Self.scratchFrames)
    }

    deinit {
        left.deallocate()
        right.deallocate()
    }

    /// Writes channels 0 and 1 of `pcm` (channel 0 to both on a one-channel buffer) to the stereo buffer. Called on
    /// the audio render thread.
    func consume(_ pcm: AVAudioPCMBuffer) {
        // vc:hot-path begin
        guard let channels = pcm.floatChannelData else { return }
        let frames = Int(pcm.frameLength)
        let count = Int(pcm.format.channelCount)
        guard frames > 0, count > 0 else { return }
        let second = count > 1 ? 1 : 0
        let interleaved = pcm.format.isInterleaved
        var done = 0
        while done < frames {
            let slice = min(Self.scratchFrames, frames - done)
            for frame in 0..<slice {
                let index = done + frame
                if interleaved {
                    left[frame] = channels[0][index * count]
                    right[frame] = channels[0][index * count + second]
                } else {
                    left[frame] = channels[0][index]
                    right[frame] = channels[second][index]
                }
            }
            buffer.write(left: UnsafeBufferPointer(start: left, count: slice),
                         right: UnsafeBufferPointer(start: right, count: slice))
            done += slice
        }
        // vc:hot-path end
    }
}
