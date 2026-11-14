// ScopeTrace — feature 062 (A08-P02) T-A08-205 (FR-A08-210, FR-A08-211; SC-A08-203; clarifications 2 and 4;
// data-model "ScopeTrace"). The points of the scope's line shapes, host-free and in the caller's units (the presenter
// passes pixels): the waveform zig-zag through the per-column (min, max) ranges of `MinMaxDecimator`, and the XY trace
// through the window's (left × gain, right × gain) pairs. Values are clamped to −1…1 and mapped linearly so that −1 is
// the low edge and +1 the high edge of the rectangle (y grows with the value; the caller flips if its y axis points
// down). Nothing is invented: a column or a frame gives exactly its own points, and non-finite XY pairs are skipped.
import Foundation
import VisualCoreAudioDSP

/// One point of a scope trace in the caller's units.
public struct TracePoint: Sendable, Equatable {
    /// The horizontal position.
    public let x: Double
    /// The vertical position.
    public let y: Double

    /// A point at (`x`, `y`).
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// The point lists of the waveform and XY traces.
public enum ScopeTrace {
    /// The most points of one XY trace (the window cap, `TimebaseWindow.maxSamples`).
    public static let maxXYPoints = 4_096

    /// The zig-zag through `columns` inside `rect`: for column c of N, at x = rect.x + (c + 0.5) / N × width, the point
    /// of the column's minimum and then the point of its maximum, where a value v (clamped to −1…1; a non-finite bound
    /// counts as 0) maps to y = rect.y + (v + 1) / 2 × height. Exactly two points per column; empty for no columns.
    public static func waveformPoints(_ columns: [ColumnRange],
                                      in rect: (x: Double, y: Double, width: Double, height: Double)) -> [TracePoint] {
        guard !columns.isEmpty else { return [] }
        let n = Double(columns.count)
        var points: [TracePoint] = []
        points.reserveCapacity(columns.count * 2)
        for (c, range) in columns.enumerated() {
            let x = rect.x + (Double(c) + 0.5) / n * rect.width
            points.append(TracePoint(x: x, y: map(Double(range.min), origin: rect.y, length: rect.height)))
            points.append(TracePoint(x: x, y: map(Double(range.max), origin: rect.y, length: rect.height)))
        }
        return points
    }

    /// The XY trace of the frames of `left` and `right` inside `square`: for each frame i < min(counts), in order, the
    /// point x = square.x + (clamp(left[i] × gain) + 1) / 2 × side, y = square.y + (clamp(right[i] × gain) + 1) / 2 ×
    /// side, with clamp to −1…1. A pair whose scaled left or right is not finite is skipped; at most ``maxXYPoints``
    /// points (the first frames) are returned.
    public static func xyPoints(left: [Float], right: [Float], gain: Double,
                                in square: (x: Double, y: Double, side: Double)) -> [TracePoint] {
        let count = min(left.count, right.count)
        guard count > 0 else { return [] }
        var points: [TracePoint] = []
        points.reserveCapacity(min(count, maxXYPoints))
        for i in 0..<count {
            let l = Double(left[i]) * gain
            let r = Double(right[i]) * gain
            guard l.isFinite, r.isFinite else { continue }
            points.append(TracePoint(x: map(l, origin: square.x, length: square.side),
                                     y: map(r, origin: square.y, length: square.side)))
            if points.count == maxXYPoints { break }
        }
        return points
    }

    /// `value` clamped to −1…1 (a non-finite value counts as 0).
    public static func clamped(_ value: Double) -> Double {
        value.isFinite ? min(max(value, -1), 1) : 0
    }

    /// The position of `value` (clamped) on an axis that starts at `origin` (−1) and spans `length` (to +1).
    private static func map(_ value: Double, origin: Double, length: Double) -> Double {
        origin + (clamped(value) + 1) / 2 * length
    }
}
