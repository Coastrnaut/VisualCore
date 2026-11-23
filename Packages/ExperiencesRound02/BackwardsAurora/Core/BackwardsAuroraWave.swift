// BackwardsAuroraWave — feature 391 (R02-G10-01) T-R02G1001-002 (FR-R02G1001-002, 003, 014; clarifications Q1, Q2,
// Q4). The aurora as a wave of N signed integer samples (N 12 … 32, each −64 … 64; one unit is 1/64 of the aurora's
// half-height) at positions 0 … N − 1. The bend at an interior position k (1 … N − 2) is the exact second difference
// b(k) = s(k − 1) − 2·s(k) + s(k + 1). Reversing the section [i, j] reverses the order of its samples; the bends
// strictly inside the section are carried along in reverse order, so only the bends at its seam positions i − 1, i, j
// and j + 1 (where they are interior) can change. The distance to a target is the exact fraction Σ|s − t| / Σ|t|
// (0/1 when the target is all zero). Every value is a plain `Int`: at most 32 samples of magnitude at most 64, so a
// bend is at most 256 and a sum at most 4 096 in magnitude. No floating point.

/// A wave of signed integer samples.
public struct BackwardsAuroraWave: Sendable, Hashable {
    /// The allowed sample heights.
    public static let sampleRange: ClosedRange<Int> = -64...64
    /// The allowed wave lengths.
    public static let lengthRange: ClosedRange<Int> = 12...32

    /// The samples, position 0 first.
    public let samples: [Int]

    /// A wave of `samples`.
    ///
    /// - Throws: `.level("length")` when the count is outside 12 … 32; `.level("samples")` when a height is outside
    ///   −64 … 64.
    public init(_ samples: [Int]) throws(BackwardsAuroraError) {
        guard Self.lengthRange.contains(samples.count) else { throw .level("length") }
        guard samples.allSatisfy({ Self.sampleRange.contains($0) }) else { throw .level("samples") }
        self.samples = samples
    }

    /// A wave of samples already checked (a reordering of a checked wave).
    init(unchecked samples: [Int]) {
        self.samples = samples
    }

    /// The number of samples, N.
    public var count: Int { samples.count }

    /// The interior positions 1 … N − 2, where a bend exists.
    public var interior: ClosedRange<Int> { 1...(count - 2) }

    /// The bend at interior position `k`: s(k − 1) − 2·s(k) + s(k + 1).
    public func bend(at k: Int) -> Int {
        precondition(interior.contains(k), "bend position \(k) outside 1 … \(count - 2)")
        return samples[k - 1] - 2 * samples[k] + samples[k + 1]
    }

    /// Every bend in position order; index 0 is the bend at position 1.
    public var bends: [Int] { interior.map { bend(at: $0) } }

    /// The largest bend magnitude, max |b(k)|.
    public var worstBend: Int { bends.reduce(0) { max($0, abs($1)) } }

    /// Whether every bend is within `limit`: |b(k)| ≤ limit for every interior k.
    public func isSmooth(limit: Int) -> Bool {
        interior.allSatisfy { abs(bend(at: $0)) <= limit }
    }

    /// The wave with the section [start, end] (inclusive) reversed in time; nothing else changes.
    public func reversed(start: Int, end: Int) -> BackwardsAuroraWave {
        precondition(start >= 0 && start < end && end < count, "section \(start) … \(end) outside the wave")
        var result: [Int] = samples
        result.replaceSubrange(start...end, with: samples[start...end].reversed())
        return BackwardsAuroraWave(unchecked: result)
    }

    /// The seam positions of the section [start, end] in a wave of `count` samples: the interior positions among
    /// start − 1, start, end and end + 1, sorted and without repeats. Only the bends at these positions can take new
    /// values when the section is reversed; the bends strictly inside are the old ones in reverse order.
    public static func seams(start: Int, end: Int, count: Int) -> [Int] {
        var result: [Int] = []
        for k in [start - 1, start, end, end + 1] where k >= 1 && k <= count - 2 && !result.contains(k) {
            result.append(k)
        }
        return result.sorted()
    }

    /// Whether the section [start, end] reads the same both ways (reversing it would change nothing).
    public func isPalindrome(start: Int, end: Int) -> Bool {
        var a: Int = start
        var b: Int = end
        while a < b {
            if samples[a] != samples[b] { return false }
            a += 1
            b -= 1
        }
        return true
    }

    /// The distance to `target` as an exact fraction: (Σ|s(k) − t(k)|, Σ|t(k)|), or (0, 1) when the target is all
    /// zero. The waves must have the same length.
    public func distance(to target: BackwardsAuroraWave) -> (numerator: Int, denominator: Int) {
        precondition(target.count == count, "distance between waves of different lengths")
        var numerator: Int = 0
        var denominator: Int = 0
        for k in 0..<count {
            numerator += abs(samples[k] - target.samples[k])
            denominator += abs(target.samples[k])
        }
        if denominator == 0 { return (numerator: numerator, denominator: 1) }
        return (numerator: numerator, denominator: denominator)
    }
}

extension BackwardsAuroraWave: Codable {
    /// Decodes the samples as a JSON array, re-checking their ranges.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.singleValueContainer().decode([Int].self)
        do {
            try self.init(values)
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
    }

    /// Encodes the samples as a JSON array.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(samples)
    }
}
