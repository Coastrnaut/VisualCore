// AudioSource — feature 047 T-A06-103 (FR-A06-101, FR-A06-105; gaps G-AUDIOSOURCE, G-MICPERMISSION, G-FILESOURCE):
// one interface for the demo, file and microphone sources. Every source writes mono Float samples into a
// `SampleRingBuffer`, the single hand-off point to the render side.
// Feature 050 (A06-P04) T-A06-402 (FR-A06-402; gap G-INTERRUPTION; analyze U1): adds the `interrupted` state and the
// `ResumableAudioSource` protocol.
import Foundation
import VisualCoreAudioDSP

/// The lifecycle state of an `AudioSource`.
public enum AudioSourceState: Equatable, Sendable {
    /// Not producing samples (never started, or stopped).
    case idle
    /// Producing samples into the ring buffer.
    case running
    /// Paused by the system (an audio interruption such as a call or an alarm). Capture is stopped; the source resumes
    /// by itself when the interruption ends with permission to resume, or when `ResumableAudioSource.resume()` is
    /// called after an interruption ended without that permission.
    case interrupted
    /// Start failed; the associated text says why.
    case failed(String)
}

/// Errors thrown by `AudioSource` implementations.
public enum AudioSourceError: Error, Equatable, Sendable {
    /// The microphone permission is denied or restricted.
    case permissionDenied
    /// The microphone permission has not been asked yet; call `MicrophonePermission.request()` first.
    case notDetermined
    /// The audio session or engine could not be configured or started.
    case engineFailed(String)
    /// The file could not be opened or decoded.
    case undecodable(String)
}

/// A producer of mono `Float` audio samples (FR-A06-101).
///
/// Sources are main-actor objects; the samples themselves travel through the lock-free `SampleRingBuffer`.
/// Nothing is written to disk and nothing leaves the device (FR-A06-105).
@MainActor
public protocol AudioSource: AnyObject {
    /// Sample rate, in hertz, of the samples written to the buffer.
    var sampleRate: Double { get }
    /// Current lifecycle state.
    var state: AudioSourceState { get }
    /// Starts writing samples into `buffer`. Starting a running source restarts it on the new buffer.
    /// - Throws: `AudioSourceError` when the source cannot start.
    func start(into buffer: SampleRingBuffer) throws
    /// Stops writing samples and releases any system resource. Safe to call when idle.
    func stop()
}

/// An `AudioSource` that can be paused by the system and resumed on request (FR-A06-402; analyze U1).
///
/// Presenters resume any resumable source through this protocol (for example from a "Resume" button), so tests can
/// use doubles.
@MainActor
public protocol ResumableAudioSource: AudioSource {
    /// True only while the source is `.interrupted` after an interruption ended without permission to resume, that
    /// is when `resume()` is the way back; false in every other situation.
    var awaitsResume: Bool { get }
    /// Restarts capture after an interruption. Does nothing unless the state is `.interrupted`; a restart that fails
    /// leaves the source `.failed` with a reason.
    func resume()
}
