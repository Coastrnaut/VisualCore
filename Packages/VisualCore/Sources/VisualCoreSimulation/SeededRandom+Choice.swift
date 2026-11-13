// SeededRandom+Choice.swift — feature 203 R02-F03 (T-R02F03-006; FR-R02F03-020..023).
// Project-owned shuffle (Fisher–Yates from the end, Durstenfeld's in-place form), pick and weighted choice, so a seed
// gives the same result on every platform and toolchain (the standard library does not promise stable algorithms).
// Every random index costs exactly one draw, mapped to [0, n) by the high half of the 128-bit product.
import Foundation

/// Why a pick or weighted choice could not be made from its input.
public enum RandomChoiceError: Error, Equatable, Sendable {
    /// The list of items or weights is empty.
    case empty
    /// The weight at this index is negative.
    case negativeWeight(Int)
    /// The weight at this index is NaN or infinite.
    case nonFiniteWeight(Int)
    /// The weights sum to zero or to a non-finite value.
    case zeroTotal
}

extension SeededRandom {
    /// Uniform integer in `0..<n` from exactly one `next()`: the high 64 bits of `n × next()`
    /// (bias at most n / 2^64, accepted for exact replay).
    ///
    /// - Precondition: `n >= 1`. Callers that cannot guarantee it use ``pick(_:)`` or ``weightedIndex(_:)``.
    public mutating func index(below n: Int) -> Int {
        precondition(n >= 1, "index(below:) requires n >= 1")
        return Int(UInt64(n).multipliedFullWidth(by: next()).high)
    }

    /// Shuffles `items` in place with Fisher–Yates from the end; uses `items.count − 1` draws (none for 0 or 1 items).
    public mutating func shuffle<T>(_ items: inout [T]) {
        guard items.count > 1 else { return }
        for i in stride(from: items.count - 1, to: 0, by: -1) {
            let j = index(below: i + 1)
            items.swapAt(i, j)
        }
    }

    /// A shuffled copy of `items`, identical to ``shuffle(_:)`` applied to a copy.
    public mutating func shuffled<T>(_ items: [T]) -> [T] {
        var copy = items
        shuffle(&copy)
        return copy
    }

    /// A uniformly chosen element of `items`, using one draw.
    ///
    /// - Throws: ``RandomChoiceError/empty`` when `items` is empty (no draw is used).
    public mutating func pick<T>(_ items: [T]) throws(RandomChoiceError) -> T {
        guard !items.isEmpty else { throw .empty }
        return items[index(below: items.count)]
    }

    /// An index chosen with probability proportional to its weight, using one draw; a zero weight is never chosen.
    ///
    /// Draws `u = double() × total` and returns the first positive-weight index whose running sum exceeds `u`.
    /// - Throws: ``RandomChoiceError/empty``, ``RandomChoiceError/nonFiniteWeight(_:)`` or
    ///   ``RandomChoiceError/negativeWeight(_:)`` for the first offending index (non-finite checked first),
    ///   ``RandomChoiceError/zeroTotal`` when the sum is zero or not finite. No draw is used when it throws.
    public mutating func weightedIndex(_ weights: [Double]) throws(RandomChoiceError) -> Int {
        guard !weights.isEmpty else { throw .empty }
        var total = 0.0
        var lastPositive = -1
        for (i, w) in weights.enumerated() {
            guard w.isFinite else { throw .nonFiniteWeight(i) }
            guard w >= 0 else { throw .negativeWeight(i) }
            total += w
            if w > 0 { lastPositive = i }
        }
        guard total > 0, total.isFinite, lastPositive >= 0 else { throw .zeroTotal }
        let u = double() * total
        var running = 0.0
        for (i, w) in weights.enumerated() where w > 0 {
            running += w
            if running > u { return i }
        }
        return lastPositive   // floating-point edge: u rounded up to the full sum
    }
}
