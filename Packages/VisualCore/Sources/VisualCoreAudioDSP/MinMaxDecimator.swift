// MinMaxDecimator — feature 062 (A08-P02) T-A08-202 (FR-A08-201); gap G-DECIMATION.
// Spec Clarifications (reduction semantics); data-model.md; contract specs/062-os-p02-trace-xy/contracts/api.md.
import Foundation

/// The smallest and largest finite sample of one display column.
public struct ColumnRange: Sendable, Equatable {
    /// The smallest finite sample in the column.
    public let min: Float
    /// The largest finite sample in the column.
    public let max: Float

    /// Creates a column range from its extremes.
    public init(min: Float, max: Float) {
        self.min = min
        self.max = max
    }
}

/// Min/max decimation of a sample window into display columns, so every peak stays visible at any zoom.
public enum MinMaxDecimator {
    /// The largest column count `reduce` produces; larger requests are clamped.
    public static let maxColumns = 8_192

    /// Reduces `samples` to at most `columns` per-column extremes, in column order.
    ///
    /// `columns` is clamped to `1…maxColumns`; non-finite samples are skipped. When the finite sample count is at most
    /// the column count, the result has one range per finite sample (`min == max == sample`) in order. Otherwise sample
    /// `i` belongs to column `⌊i × N / samples.count⌋` and each column gives the min and max of its finite samples;
    /// columns without a finite sample are omitted. O(count) time, one allocation.
    public static func reduce(_ samples: [Float], columns: Int) -> [ColumnRange] {
        let n = Swift.min(Swift.max(columns, 1), maxColumns)
        var finite = 0
        for s in samples where s.isFinite { finite += 1 }
        var out: [ColumnRange] = []
        if finite <= n {
            out.reserveCapacity(finite)
            for s in samples where s.isFinite { out.append(ColumnRange(min: s, max: s)) }
            return out
        }
        out.reserveCapacity(n)
        let count = samples.count
        var column = -1
        var lo = Float.infinity, hi = -Float.infinity
        for i in 0..<count {
            let s = samples[i]
            guard s.isFinite else { continue }
            let c = i * n / count
            if c != column {
                if column >= 0 { out.append(ColumnRange(min: lo, max: hi)) }
                column = c
                lo = s; hi = s
            } else {
                if s < lo { lo = s }
                if s > hi { hi = s }
            }
        }
        if column >= 0 { out.append(ColumnRange(min: lo, max: hi)) }
        return out
    }
}
