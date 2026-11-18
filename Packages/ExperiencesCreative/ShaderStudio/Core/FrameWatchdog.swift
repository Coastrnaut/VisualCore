// FrameWatchdog — feature 162 (A22-P04) T-A22-402 (FR-A22-403; clarification Q2; research R2, R3; data-model.md
// "FrameWatchdog"). Stops the preview when a shader makes frames too slow: it is fed `FrameInfo.delta` of each drawn
// frame and stops after ``window`` consecutive intervals each above ``limit``.
//
// Choices recorded here: a non-finite or non-positive interval is ignored (it neither counts nor resets the count);
// exactly one valid interval after ``rearm()`` (a setup, a resize, a Run or a Reset) is skipped, because it spans the
// rebuild and not a frame; an interval at or under the limit resets the count; once stopped it stays stopped until
// ``reset()``. A single long interval (a pause) counts once. Pure: no clock, UI or GPU.
import Foundation

/// Watches drawn-frame intervals and says when the preview should stop drawing the shader.
public struct FrameWatchdog: Sendable, Equatable {
    /// The interval above which a frame is slow, in seconds.
    public static let limit = 0.25
    /// The number of consecutive slow intervals that stops the preview.
    public static let window = 8

    /// Whether the preview is drawing the shader.
    public enum State: Sendable, Equatable {
        /// Drawing the shader and counting slow intervals.
        case watching
        /// Stopped: the preview draws a flat frame until ``FrameWatchdog/reset()``.
        case stopped
    }

    /// The current state.
    public private(set) var state: State = .watching
    /// The number of consecutive slow intervals recorded.
    public private(set) var slowCount = 0
    /// Whether the next valid interval is skipped.
    public private(set) var skipsNext = false

    /// A watchdog that is watching, with no slow interval and no skip armed (the presenter's setup calls
    /// ``rearm()``).
    public init() {}

    /// Records the interval since the frame before, in seconds, and returns the state after it.
    @discardableResult
    public mutating func record(_ interval: Double) -> State {
        guard state == .watching, interval.isFinite, interval > 0 else { return state }
        if skipsNext {
            skipsNext = false
            return state
        }
        if interval > Self.limit {
            slowCount += 1
            if slowCount >= Self.window { state = .stopped }
        } else {
            slowCount = 0
        }
        return state
    }

    /// Skips the next valid interval (after a setup, a resize, a Run or a Reset); the count and state are kept.
    public mutating func rearm() {
        skipsNext = true
    }

    /// Returns to watching with no slow interval, and skips the next valid interval.
    public mutating func reset() {
        state = .watching
        slowCount = 0
        skipsNext = true
    }
}
