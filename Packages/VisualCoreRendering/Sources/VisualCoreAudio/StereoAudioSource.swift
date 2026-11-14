// StereoAudioSource — feature 061 (A08-P01) T-A08-103 (FR-A08-102; gap G-STEREO): one interface for the two-channel
// sources of the oscilloscope (test signal and file). Every source writes left and right `Float` frames into a
// `StereoSampleBuffer`, the single hand-off point to the render side. It reuses `AudioSourceState` and
// `AudioSourceError` of the mono family (spec Clarifications; contract specs/061-os-p01-acquisition/contracts/api.md).
import Foundation
import VisualCoreAudioDSP

/// A producer of two-channel `Float` audio frames (FR-A08-102).
///
/// Sources are main-actor objects; the frames themselves travel through the lock-free `StereoSampleBuffer`. A mono
/// source (``channelCount`` 1) writes the same samples to both channels. Nothing is written to disk and nothing leaves
/// the device.
@MainActor
public protocol StereoAudioSource: AnyObject {
    /// Sample rate, in hertz, of the frames written to the buffer.
    var sampleRate: Double { get }
    /// Current lifecycle state.
    var state: AudioSourceState { get }
    /// Number of distinct channels the source carries: 1 (written to both buffer channels) or 2.
    var channelCount: Int { get }
    /// Starts writing frames into `buffer`. Starting a running source restarts it on the new buffer.
    /// - Throws: `AudioSourceError` when the source cannot start.
    func start(into buffer: StereoSampleBuffer) throws
    /// Stops writing frames and releases any system resource. Safe to call when idle.
    func stop()
}
