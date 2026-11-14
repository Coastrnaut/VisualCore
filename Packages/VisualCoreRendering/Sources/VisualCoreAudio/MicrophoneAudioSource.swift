// MicrophoneAudioSource — feature 047 T-A06-103 (FR-A06-104, FR-A06-105, FR-A06-107; gap G-MICPERMISSION): live
// input from AVAudioEngine's input node, started only with granted permission, mixed with other apps' audio. Gaps
// G-AUDIOSOURCE and G-FILESOURCE are closed by the sibling files.
// Feature 050 (A06-P04) T-A06-402 (FR-A06-401–403; SC-A06-402; gap G-INTERRUPTION; research D3, D4, D6b): the session
// and engine code moved to `SystemMicrophoneCapture` behind the internal `MicrophoneCapture` seam; the source pauses
// on interruptions, resumes when allowed or asked, rebuilds on route loss and media-services reset, and never runs two
// captures.
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
///
/// Recovery (FR-A06-402, FR-A06-403): while running or interrupted the source observes the default notification
/// center through an `AudioSessionEventMonitor` and reacts in `handle(_:)`: interruption began → capture stopped,
/// `.interrupted`; ended with permission to resume → restarted; ended without it → stays `.interrupted` until
/// `resume()`; route lost or media services reset while running → capture rebuilt. A restart re-checks the permission;
/// if it fails the state becomes `.failed` with the reason. At most one capture runs at any time.
@MainActor
public final class MicrophoneAudioSource: ResumableAudioSource {
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
    /// True only while `.interrupted` after an interruption ended without permission to resume (`resume()` is the
    /// way back); false otherwise.
    public private(set) var awaitsResume = false

    private let permission: any MicrophonePermission
    private let makeCapture: @MainActor () -> any MicrophoneCapture
    private let center: NotificationCenter?
    private var capture: (any MicrophoneCapture)?
    private var buffer: SampleRingBuffer?
    private var monitor: AudioSessionEventMonitor?
    /// Number of successful capture starts, restarts included (test hook for "no engine without permission").
    internal private(set) var engineStartCount = 0
    /// Number of captures currently running (test hook for FR-A06-403; never above 1).
    internal private(set) var runningCaptures = 0

    /// Creates a microphone source gated by `permission`, capturing with the system engine and observing the
    /// default notification center for audio-session events while running or interrupted.
    public convenience init(permission: any MicrophonePermission) {
        self.init(permission: permission, makeCapture: { SystemMicrophoneCapture() }, center: .default)
    }

    /// Test seam: `makeCapture` builds the capture for every start and restart; a `nil` center installs no monitor
    /// (tests call `handle(_:)` directly or post on a private center).
    init(permission: any MicrophonePermission, makeCapture: @escaping @MainActor () -> any MicrophoneCapture,
         center: NotificationCenter?) {
        self.permission = permission
        self.makeCapture = makeCapture
        self.center = center
    }

    isolated deinit {
        monitor?.stop()
        capture?.stop()
    }

    /// Starts capturing into `buffer`.
    /// - Throws: `AudioSourceError.notDetermined` when permission was never asked, `.permissionDenied` when denied or
    ///   restricted, `.engineFailed` when the session or engine cannot start (for example no input route).
    public func start(into buffer: SampleRingBuffer) throws {
        stop()
        if let error = permissionError() {
            state = .failed(Self.reason(for: error))
            throw error
        }
        self.buffer = buffer
        do {
            try startCapture(into: buffer)
        } catch {
            let (message, thrown) = Self.describe(error)
            state = .failed(message)
            throw thrown
        }
        state = .running
        if let center {
            monitor = AudioSessionEventMonitor(center: center) { [weak self] event in self?.handle(event) }
        }
    }

    /// Stops capturing: removes the tap, stops the engine and deactivates the session. Safe to call when idle.
    /// A running or interrupted source becomes `.idle`; a failed source keeps its failure.
    public func stop() {
        dropMonitor()
        stopCapture()
        awaitsResume = false
        switch state {
        case .running, .interrupted: state = .idle
        case .idle, .failed: break
        }
    }

    /// Reacts to a system audio-session event (research D4). Events while idle or failed are ignored.
    ///
    /// Running: began → capture stopped, `.interrupted`; route lost or media services reset → capture stopped and
    /// restarted; ended → ignored. Interrupted: ended with permission to resume → restarted; ended without it → stays
    /// `.interrupted` with `awaitsResume`; began, route lost and media services reset keep it `.interrupted` (the next
    /// restart builds a fresh engine anyway). A failed restart ends in `.failed(reason)`.
    public func handle(_ event: AudioSessionEvent) {
        switch state {
        case .running:
            switch event {
            case .interruptionBegan:
                stopCapture()
                awaitsResume = false
                state = .interrupted
            case .routeLost, .mediaServicesReset:
                stopCapture()
                restart()
            case .interruptionEnded:
                break
            }
        case .interrupted:
            switch event {
            case .interruptionEnded(let shouldResume):
                if shouldResume { restart() } else { awaitsResume = true }
            case .interruptionBegan:
                awaitsResume = false
            case .routeLost, .mediaServicesReset:
                break
            }
        case .idle, .failed:
            break
        }
    }

    /// Restarts capture after an interruption (for example after it ended without permission to resume). Does
    /// nothing unless the state is `.interrupted`.
    public func resume() {
        guard state == .interrupted else { return }
        restart()
    }

    /// Restarts into the kept buffer, re-checking the permission; ends `.running` or `.failed(reason)`.
    private func restart() {
        stopCapture()
        awaitsResume = false
        if let error = permissionError() {
            fail(Self.reason(for: error))
            return
        }
        guard let buffer else {
            fail("no buffer to resume into")
            return
        }
        do {
            try startCapture(into: buffer)
            state = .running
        } catch {
            fail(Self.describe(error).message)
        }
    }

    private func fail(_ reason: String) {
        dropMonitor()
        stopCapture()
        awaitsResume = false
        state = .failed(reason)
    }

    private func startCapture(into buffer: SampleRingBuffer) throws {
        stopCapture()
        let capture = makeCapture()
        let rate = try capture.start(into: buffer)
        self.capture = capture
        runningCaptures += 1
        engineStartCount += 1
        sampleRate = rate
    }

    private func stopCapture() {
        guard let capture else { return }
        capture.stop()
        self.capture = nil
        runningCaptures -= 1
    }

    private func dropMonitor() {
        monitor?.stop()
        monitor = nil
    }

    private func permissionError() -> AudioSourceError? {
        switch permission.state {
        case .granted: return nil
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .permissionDenied
        }
    }

    private static func reason(for error: AudioSourceError) -> String {
        switch error {
        case .notDetermined: return "microphone permission not determined"
        case .permissionDenied: return "microphone permission denied"
        default: return "\(error)"
        }
    }

    private static func describe(_ error: any Error) -> (message: String, thrown: AudioSourceError) {
        if let known = error as? AudioSourceError { return ("\(known)", known) }
        let message = error.localizedDescription
        return (message, .engineFailed(message))
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
        // vc:hot-path begin
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
        // vc:hot-path end
    }
}
