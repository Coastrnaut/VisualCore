// ScopeAcquisition — feature 061 (A08-P01) T-A08-104 (FR-A08-110; clarifications 3 and 4; research D4, D5). Builds a
// `SignalWindow` from a two-channel `StereoSampleBuffer` or a mono `SampleRingBuffer` with the trigger of the scope
// state.
//
// Rule (clarification 3): span = `TimebaseWindow.sampleCount(sampleRate:)` (ten divisions, capped at 4,096 samples).
// The newest 2 × span frames are read (one span of lookback plus one span). The trigger crossing is searched on the
// first channel in the start positions whose whole span lies inside that read (the first span, plus the position
// where the window ends exactly at the newest frame), and `ScopeTrigger.find` returns the most recent one:
//   - crossing found  → the window starts at the crossing, `triggered`; it becomes the last triggered window;
//   - none, auto      → the newest span, not triggered;
//   - none, normal    → the last triggered window (same span, sample rate and channel count) marked `waiting`; before
//                       the first trigger, the newest span marked `waiting`;
//   - fewer frames written than the span → a `partial` window of what exists (not triggered; `waiting` in normal mode).
// `clipped` is evaluated with the state's gain. Windows never invent samples: every sample is one the source wrote.
import Foundation
import VisualCoreAudioDSP

/// Acquires scope windows and remembers the last triggered one for normal mode.
public final class ScopeAcquisition {
    /// The trigger channel (the first channel; the experience triggers on the left or mono channel in this phase).
    public static let triggerChannel = 0

    /// The last triggered window, which normal mode keeps showing while it waits.
    public private(set) var lastTriggered: SignalWindow?

    /// An acquisition with no window yet.
    public init() {}

    /// Forgets the last triggered window (a new source or a fresh buffer).
    public func reset() { lastTriggered = nil }

    /// The window of `buffer` for `state`: `channelCount` (clamped to 1…2) channels at `sampleRate`.
    public func window(from buffer: StereoSampleBuffer, channelCount: Int, sampleRate: Double,
                       state: ScopeState) -> SignalWindow {
        let channels = min(max(channelCount, 1), 2)
        return acquire(channelCount: channels, sampleRate: sampleRate, state: state) { want in
            let total = buffer.totalFrames
            let count = min(want, total)
            guard count > 0 else { return (0, [], [], 0) }
            let start = total - count
            var left = [Float](repeating: 0, count: count)
            var right = [Float](repeating: 0, count: count)
            let read = buffer.frames(from: start, count: count, left: &left, right: &right)
            let n = min(max(read, 0), count)
            return (start, Array(left.prefix(n)), channels == 2 ? Array(right.prefix(n)) : [], n)
        }
    }

    /// The mono window of `ring` for `state` at `sampleRate` (the microphone path; one channel, `right` empty).
    ///
    /// The ring is read from the consumer side: `startFrame` is derived from `totalWritten` read just before the copy.
    public func window(from ring: SampleRingBuffer, sampleRate: Double, state: ScopeState) -> SignalWindow {
        acquire(channelCount: 1, sampleRate: sampleRate, state: state) { want in
            let total = ring.totalWritten
            let count = min(want, total, ring.capacity)
            guard count > 0 else { return (0, [], [], 0) }
            var left = [Float](repeating: 0, count: count)
            let n = min(ring.latest(count, into: &left), count)
            return (total - n, Array(left.prefix(n)), [], n)
        }
    }

    /// The shared rule. `read(want)` returns the newest up-to-`want` frames: their absolute start frame, the left and
    /// right samples (right empty for mono) and their count.
    private func acquire(channelCount: Int, sampleRate: Double, state: ScopeState,
                         read: (Int) -> (start: Int, left: [Float], right: [Float], count: Int)) -> SignalWindow {
        let normal = ScopeSettings.index(of: state.triggerMode) == 1
        let timebase = TimebaseWindow(secondsPerDivision: state.secondsPerDivision)
        guard sampleRate.isFinite, sampleRate > 0 else {
            return .empty(sampleRate: sampleRate, channelCount: channelCount, waiting: normal, shortened: false)
        }
        let span = max(timebase.sampleCount(sampleRate: sampleRate), 1)
        let shortened = timebase.isShortened(sampleRate: sampleRate)
        let gain = state.gain
        let data = read(2 * span)
        let n = data.count

        func make(_ offset: Int, _ length: Int, triggered: Bool, waiting: Bool, partial: Bool) -> SignalWindow {
            let left = Array(data.left[offset..<(offset + length)])
            let right = channelCount == 2 ? Array(data.right[offset..<(offset + length)]) : []
            return SignalWindow(sampleRate: sampleRate, channelCount: channelCount, startFrame: data.start + offset,
                                left: left, right: right, triggered: triggered, waiting: waiting, partial: partial,
                                shortened: shortened,
                                clipped: SignalWindow.isClipped(left: left, right: right, gain: gain))
        }

        guard n >= span else {
            guard n > 0 else {
                return .empty(sampleRate: sampleRate, channelCount: channelCount, waiting: normal, shortened: shortened)
            }
            return make(0, n, triggered: false, waiting: normal, partial: true)
        }

        let settings = TriggerSettings(channel: Self.triggerChannel, level: state.triggerLevel,
                                       slope: state.triggerSlope, hysteresis: ScopeSettings.triggerHysteresis,
                                       mode: state.triggerMode)
        if let settings,
           let crossing = ScopeTrigger.find(in: data.left, settings: settings, searchRange: 0..<(n - span + 1)),
           crossing >= 0, crossing + span <= n {
            let window = make(crossing, span, triggered: true, waiting: false, partial: false)
            lastTriggered = window
            return window
        }
        if normal, let last = lastTriggered, last.sampleCount == span, last.sampleRate == sampleRate,
           last.channelCount == channelCount {
            return last.with(triggered: true, waiting: true,
                             clipped: SignalWindow.isClipped(left: last.left, right: last.right, gain: gain))
        }
        return make(n - span, span, triggered: false, waiting: normal, partial: false)
    }
}
