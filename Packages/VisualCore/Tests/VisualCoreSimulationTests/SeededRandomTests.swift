// SeededRandomTests — feature 006 T-F508 (FR-F504). Golden values from an independent Python
// implementation of the published xoshiro256**/SplitMix64 algorithms (seed 42); SplitMix64's first
// output for seed 0 is the widely published 0xE220A8397B1DCDAF.
import Foundation
import Testing
@testable import VisualCoreSimulation

@Test func splitMixMatchesPublishedValue() {
    var s = SplitMix64(seed: 0)
    #expect(s.next() == 0xE220_A839_7B1D_CDAF)
}

@Test func goldenSequenceForSeed42() {
    var r = SeededRandom(seed: 42)
    let golden: [UInt64] = [0x15780B2E0C2EC716, 0x6104D9866D113A7E, 0xAE17533239E499A1, 0xECB8AD4703B360A1,
                            0xFDE6DC7FE2EC5E64, 0xC50DA53101795238, 0xB82154855A65DDB2, 0xD99A2743EBE60087]
    #expect((0..<8).map { _ in r.next() } == golden)
}

@Test func sameSeedSameSequenceDifferentSeedDiffers() {
    var a = SeededRandom(seed: 7), b = SeededRandom(seed: 7), c = SeededRandom(seed: 8)
    let xa = (0..<100).map { _ in a.next() }, xb = (0..<100).map { _ in b.next() }, xc = (0..<100).map { _ in c.next() }
    #expect(xa == xb)
    #expect(xa != xc)
}

@Test func unitIntervalsAndRanges() {
    var r = SeededRandom(seed: 1)
    for _ in 0..<10_000 {
        let d = r.double(); #expect(d >= 0 && d < 1)
        let f = r.float(); #expect(f >= 0 && f < 1)
        let x = r.range(-3...5); #expect(x >= -3 && x <= 5)
        let i = r.int(-2...2); #expect((-2...2).contains(i))
    }
    var counts = [Int](repeating: 0, count: 5)
    for _ in 0..<50_000 { counts[r.int(0...4)] += 1 }
    let uniform = counts.allSatisfy { abs($0 - 10_000) < 500 }
    #expect(uniform, "roughly uniform: \(counts)")
    let single = r.int(5...5)
    #expect(single == 5)
    _ = r.int(Int.min...Int.max)
}

@Test func normalMeanAndVariance() {
    var r = SeededRandom(seed: 99)
    let n = 100_000
    let xs = (0..<n).map { _ in r.normal(mean: 2, deviation: 3) }
    let mean = xs.reduce(0, +) / Double(n)
    let variance = xs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(n)
    #expect(abs(mean - 2) < 0.05 * 3)
    #expect(abs(variance - 9) < 0.05 * 9)
    let finite = xs.allSatisfy(\.isFinite)
    #expect(finite)
}

@Test func worksWithStandardLibrary() {
    var r = SeededRandom(seed: 3)
    var s = SeededRandom(seed: 3)
    #expect([1, 2, 3, 4, 5].shuffled(using: &r) == [1, 2, 3, 4, 5].shuffled(using: &s))
}
