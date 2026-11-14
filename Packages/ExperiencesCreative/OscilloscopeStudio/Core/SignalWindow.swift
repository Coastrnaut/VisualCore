// SignalWindow — feature 061 (A08-P01) T-A08-104 (FR-A08-110; clarifications 3 and 4; data-model "SignalWindow"). One
// acquired scope window: the samples of one or two channels exactly as the source wrote them (never invented, never
// scaled), where they start in the source's frame count, and the flags the display and the spoken description need —
// triggered, waiting (normal mode keeping its last window), partial (fewer frames written than the span), shortened
// (the span capped at 4,096 samples) and clipped (some sample × gain outside −1…1).
import Foundation

/// One acquired scope window of one or two channels.
public struct SignalWindow: Sendable, Equatable {
    /// The sample rate of the samples in hertz.
    public let sampleRate: Double
    /// The number of channels, 1 or 2.
    public let channelCount: Int
    /// The number of samples per channel (the timebase span, or fewer for a partial window).
    public let sampleCount: Int
    /// The absolute frame position of the first sample in the source's frame count.
    public let startFrame: Int
    /// The samples of the first (left) channel, oldest first.
    public let left: [Float]
    /// The samples of the second (right) channel, oldest first; empty when the window is mono.
    public let right: [Float]
    /// Whether the window starts at a trigger crossing.
    public let triggered: Bool
    /// Whether the trigger is in normal mode and waiting: the window is the last triggered one (or, before the first
    /// trigger, the newest span).
    public let waiting: Bool
    /// Whether fewer frames than the span were written, so the window holds only what exists.
    public let partial: Bool
    /// Whether the span was capped at `TimebaseWindow.maxSamples` (4,096) and so covers less time than ten divisions.
    public let shortened: Bool
    /// Whether some sample × the gain the window was acquired with lies outside −1…1.
    public let clipped: Bool

    /// A window; `channelCount` is clamped to 1…2, `right` is emptied for a mono window and `sampleCount` is the
    /// length of `left`.
    public init(sampleRate: Double, channelCount: Int, startFrame: Int, left: [Float], right: [Float],
                triggered: Bool, waiting: Bool, partial: Bool, shortened: Bool, clipped: Bool) {
        let channels = min(max(channelCount, 1), 2)
        self.sampleRate = sampleRate
        self.channelCount = channels
        self.sampleCount = left.count
        self.startFrame = startFrame
        self.left = left
        self.right = channels == 2 ? right : []
        self.triggered = triggered
        self.waiting = waiting
        self.partial = partial
        self.shortened = shortened
        self.clipped = clipped
    }

    /// An empty window (nothing written yet), marked partial.
    public static func empty(sampleRate: Double, channelCount: Int, waiting: Bool, shortened: Bool) -> SignalWindow {
        SignalWindow(sampleRate: sampleRate, channelCount: channelCount, startFrame: 0, left: [], right: [],
                     triggered: false, waiting: waiting, partial: true, shortened: shortened, clipped: false)
    }

    /// The samples of `channel` (0 left, 1 right); empty for an unknown channel or the right channel of a mono window.
    public func samples(channel: Int) -> [Float] {
        switch channel {
        case 0: left
        case 1: right
        default: []
        }
    }

    /// The samples of `channel` multiplied by `gain` and clamped to −1…1, as the trace draws them.
    public func displayValues(channel: Int, gain: Double) -> [Float] {
        let g = Float(gain)
        return samples(channel: channel).map { min(max($0 * g, -1), 1) }
    }

    /// Whether some sample of `left` or `right` multiplied by `gain` lies outside −1…1.
    public static func isClipped(left: [Float], right: [Float], gain: Double) -> Bool {
        let g = Float(gain)
        return left.contains { abs($0 * g) > 1 } || right.contains { abs($0 * g) > 1 }
    }

    /// The same window with the given trigger, waiting and clipping flags (samples and positions unchanged).
    public func with(triggered: Bool, waiting: Bool, clipped: Bool) -> SignalWindow {
        SignalWindow(sampleRate: sampleRate, channelCount: channelCount, startFrame: startFrame, left: left,
                     right: right, triggered: triggered, waiting: waiting, partial: partial, shortened: shortened,
                     clipped: clipped)
    }
}
