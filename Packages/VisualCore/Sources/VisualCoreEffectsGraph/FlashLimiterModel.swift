// FlashLimiterModel.swift — Reduce Flashing: the displayed mean luminance changes by at most
// `limitPerSecond` per second (feature 005 T-F405; FR-F409, SC-F403). Same idea as the reference
// FlashLimiter (adapted luminance, bounded step; docs/architecture/current-rendering-pipeline.md §8),
// re-implemented as a pure, host-tested model. The GPU pass measures the frame's mean Rec. 709 luma
// and applies `color * gain + bias` so the displayed mean equals `displayed`.

/// Reduce Flashing model: limits how fast the displayed mean luminance (0…1) may change.
public struct FlashLimiterModel: Sendable, Equatable {
    /// Maximum change of displayed mean luminance per second (default 0.3).
    public let limitPerSecond: Double
    /// Frames longer than this (pauses, debugger) are treated as this long.
    public static let maxDelta = 0.1
    /// Current displayed mean luminance; nil before the first frame or after `reset()`.
    public private(set) var adapted: Double?

    /// Creates a limiter allowing `limitPerSecond` luminance change per second (default 0.3).
    public init(limitPerSecond: Double = 0.3) { self.limitPerSecond = limitPerSecond }

    /// Advances one frame with the measured mean luminance (0…1).
    /// Returns the displayed mean and the per-channel `gain` and `bias` that produce it.
    public mutating func step(measured: Double, dt: Double) -> (displayed: Double, gain: Double, bias: Double) {
        let m = min(max(measured, 0), 1)
        guard let previous = adapted else {
            adapted = m
            return (m, 1, 0)
        }
        let allowed = limitPerSecond * min(max(dt, 0), Self.maxDelta)
        let next = previous + min(max(m - previous, -allowed), allowed)
        adapted = next
        if m > next {                       // too bright: darken
            return (next, m > 0 ? next / m : 1, 0)
        } else {                            // too dark (or equal): lift
            return (next, 1, next - m)
        }
    }

    /// Forgets the adapted luminance so the next frame is shown unmodified.
    public mutating func reset() { adapted = nil }
}
