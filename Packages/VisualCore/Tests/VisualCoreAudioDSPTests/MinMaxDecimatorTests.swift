// MinMaxDecimatorTests — feature 062 (A08-P02) T-A08-202 (FR-A08-201; gap G-DECIMATION): squares and impulses keep
// their extremes, seeded noise of 2,400 samples reduced to 100, 400 and 1,000 columns keeps every column's true min and
// max (brute-force reference) and never exceeds the column count, the global extremes survive, short windows pass
// through unchanged, NaN samples are skipped and column counts below 1 are treated as 1.
import Foundation
import Testing
@testable import VisualCoreAudioDSP

/// Tiny deterministic linear congruential generator (Numerical Recipes constants) for the noise.
private struct LCG {
    var state: UInt32
    mutating func nextUnit() -> Float {
        state = state &* 1_664_525 &+ 1_013_904_223
        return Float(state >> 8) / Float(1 << 24) * 2 - 1   // −1 ..< 1
    }
}

/// Brute-force reference: per column (⌊i × N / count⌋) min and max over finite samples, empty columns omitted.
private func reference(_ samples: [Float], columns n: Int) -> [ColumnRange] {
    var buckets = [[Float]](repeating: [], count: n)
    for (i, s) in samples.enumerated() where s.isFinite { buckets[i * n / samples.count].append(s) }
    return buckets.compactMap { b in b.isEmpty ? nil : ColumnRange(min: b.min()!, max: b.max()!) }
}

@Test func minMaxDecimatorSquareWaveKeepsBothRails() {
    let samples: [Float] = (0..<2_000).map { ($0 / 50) % 2 == 0 ? 0.8 : -0.8 }
    let out = MinMaxDecimator.reduce(samples, columns: 100)
    #expect(out.count == 100)
    #expect(out == reference(samples, columns: 100))
    #expect(out.map(\.max).max() == 0.8 && out.map(\.min).min() == -0.8)
}

@Test func minMaxDecimatorImpulseAtEveryPositionSurvives() {
    let count = 64, columns = 7
    for pos in 0..<count {
        var samples = [Float](repeating: 0, count: count)
        samples[pos] = 1
        let out = MinMaxDecimator.reduce(samples, columns: columns)
        #expect(out.count == columns, "position \(pos)")
        #expect(out[pos * columns / count].max == 1, "impulse at \(pos) in its column")
        #expect(out.filter { $0.max == 1 }.count == 1)
        samples[pos] = -1
        #expect(MinMaxDecimator.reduce(samples, columns: columns)[pos * columns / count].min == -1)
    }
}

@Test func minMaxDecimatorImpulsesInLongWindow() {
    for pos in [0, 1, 777, 1_200, 2_398, 2_399] {
        var samples = [Float](repeating: 0.1, count: 2_400)
        samples[pos] = 0.95
        let out = MinMaxDecimator.reduce(samples, columns: 400)
        #expect(out[pos * 400 / 2_400].max == 0.95, "position \(pos)")
        #expect(out == reference(samples, columns: 400))
    }
}

@Test func minMaxDecimatorSeededNoiseMatchesBruteForce() {
    var rng = LCG(state: 0x0A08_0202)
    let samples = (0..<2_400).map { _ in rng.nextUnit() }
    for columns in [100, 400, 1_000] {
        let out = MinMaxDecimator.reduce(samples, columns: columns)
        #expect(out.count <= columns)
        #expect(out == reference(samples, columns: columns), "columns \(columns)")
        #expect(out.map(\.max).max() == samples.max(), "global max at \(columns)")
        #expect(out.map(\.min).min() == samples.min(), "global min at \(columns)")
        #expect(out.allSatisfy { $0.min <= $0.max })
    }
}

@Test func minMaxDecimatorShortWindowIsIdentity() {
    var rng = LCG(state: 0x0A08_0203)
    let samples = (0..<300).map { _ in rng.nextUnit() }
    let out = MinMaxDecimator.reduce(samples, columns: 400)
    #expect(out == samples.map { ColumnRange(min: $0, max: $0) })
    #expect(MinMaxDecimator.reduce([], columns: 10).isEmpty)
}

@Test func minMaxDecimatorSkipsNonFiniteSamples() {
    let short: [Float] = [0.1, .nan, 0.3, .infinity, -0.2]
    #expect(MinMaxDecimator.reduce(short, columns: 10) == [0.1, 0.3, -0.2].map { ColumnRange(min: $0, max: $0) })
    var samples = [Float](repeating: 0.5, count: 100)
    for i in 0..<10 { samples[i] = .nan }          // column 0 of 10 is all NaN → omitted
    samples[50] = -.infinity
    let out = MinMaxDecimator.reduce(samples, columns: 10)
    #expect(out.count == 9)
    #expect(out.allSatisfy { $0.min.isFinite && $0.max.isFinite })
    #expect(out == reference(samples, columns: 10))
}

@Test func minMaxDecimatorClampsColumnCount() {
    let samples: [Float] = [0.2, -0.7, 0.9, 0.1]
    for columns in [0, -5] {
        #expect(MinMaxDecimator.reduce(samples, columns: columns) == [ColumnRange(min: -0.7, max: 0.9)])
    }
    let many = [Float](repeating: 0, count: 10_000)
    #expect(MinMaxDecimator.reduce(many, columns: 100_000).count == MinMaxDecimator.maxColumns)
}
