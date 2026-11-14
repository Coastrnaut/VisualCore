// MicrophoneCapture — feature 050 (A06-P04) T-A06-402 (FR-A06-402, FR-A06-403; gap G-INTERRUPTION; research D3): the
// capture seam of the microphone source. `SystemMicrophoneCapture` holds the audio session, engine and tap code that
// feature 047 (T-A06-103; FR-A06-104, FR-A06-105, FR-A06-107) kept inside `MicrophoneAudioSource`, unchanged in
// behaviour; tests inject a double so interruptions are exercised without the real microphone.
import AVFAudio
import Foundation
import VisualCoreAudioDSP

/// One capture engine writing microphone samples into a ring buffer (internal seam, research D3).
@MainActor
protocol MicrophoneCapture: AnyObject {
    /// Configures the session, starts the engine and writes mono samples into `buffer`.
    /// - Returns: the sample rate of the delivered samples, in hertz.
    /// - Throws: when the capture cannot start; nothing stays running after a throw.
    func start(into buffer: SampleRingBuffer) throws -> Double
    /// Stops the engine and releases the session. Safe to call when not running.
    func stop()
}

/// The system capture: `AVAudioSession` with `MicrophoneAudioSource`'s category, mode and options, an `AVAudioEngine`
/// whose input node is tapped by a `MicrophoneTapSink`, torn down with `.notifyOthersOnDeactivation`.
@MainActor
final class SystemMicrophoneCapture: MicrophoneCapture {
    private var engine: AVAudioEngine?
    private var sink: MicrophoneTapSink?

    /// Creates an idle capture; nothing touches the audio session until `start(into:)`.
    init() {}

    isolated deinit { tearDown() }

    /// Starts a new engine into `buffer` (stopping any previous one first).
    func start(into buffer: SampleRingBuffer) throws -> Double {
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
            let sink = MicrophoneTapSink(buffer: buffer)
            input.installTap(onBus: 0, bufferSize: MicrophoneAudioSource.tapFrames, format: format,
                             block: Self.makeTapBlock(sink))
            engine.prepare()
            self.engine = engine
            self.sink = sink
            try engine.start()
            return format.sampleRate
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
    private nonisolated static func makeTapBlock(_ sink: MicrophoneTapSink) -> AVAudioNodeTapBlock {
        { pcm, _ in sink.consume(pcm) }
    }
}
