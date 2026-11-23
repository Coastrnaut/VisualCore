// BackwardsAuroraWaveTests — feature 391 (R02-G10-01) T-R02G1001-003 (FR-R02G1001-002, 003, 014; SC-R02G1001-003).
// The exact wave against independent references written here: on 500 seeded waves (lengths 12 … 32, heights −64 …
// 64, with extreme, alternating and constant waves among them) and seeded sections, the reversal equals the index
// formula result[k] = s[start + end − k] inside and s[k] outside; every bend equals a separate recomputation; no bend
// outside the section and its seams changes and the inside bends are the old ones reversed; the worst bend, smoothness at
// the worst and one below, checkpoint matches and the distance equal brute force; palindromes equal a comparison with
// the reversed slice; reversing twice restores the wave; and the seams equal a brute-force set. Explicit types, plain
// loops, short runs.
import Foundation
import Testing
import VisualCoreSimulation
@testable import BackwardsAuroraCore

struct BackwardsAuroraWaveTests {
    /// The test seed.
    static let seed: UInt64 = 2_391
    /// The number of seeded waves.
    static let waveCount: Int = 500

    /// The seeded samples of wave `index`: every eighth wave is constant, every eighth (offset 1) alternates the
    /// extremes −64 and 64, every eighth (offset 2) is pinned to an extreme with a few steps; the rest are uniform.
    static func samples(_ index: Int, _ random: inout SeededRandom) -> [Int] {
        let count: Int = random.int(12...32)
        var result: [Int] = []
        switch index % 8 {
        case 0:
            let height: Int = random.int(-64...64)
            for _ in 0..<count { result.append(height) }
        case 1:
            let first: Int = random.int(0...1) == 0 ? -64 : 64
            for k in 0..<count { result.append(k % 2 == 0 ? first : -first) }
        case 2:
            for _ in 0..<count {
                let draw: Int = random.int(0...3)
                result.append(draw == 0 ? -64 : (draw == 1 ? 64 : random.int(-64...64)))
            }
        default:
            for _ in 0..<count { result.append(random.int(-64...64)) }
        }
        return result
    }

    /// The 500 seeded waves.
    static func waves() throws -> [BackwardsAuroraWave] {
        var random: SeededRandom = SeededRandom(seed: seed)
        var result: [BackwardsAuroraWave] = []
        for index in 0..<waveCount {
            result.append(try BackwardsAuroraWave(samples(index, &random)))
        }
        return result
    }

    /// A seeded section (start < end) of a wave of `count` samples.
    static func section(_ count: Int, _ random: inout SeededRandom) -> (start: Int, end: Int) {
        let start: Int = random.int(0...(count - 2))
        let end: Int = random.int((start + 1)...(count - 1))
        return (start: start, end: end)
    }

    /// The independent bend: (s[k+1] − s[k]) − (s[k] − s[k−1]).
    static func referenceBend(_ s: [Int], _ k: Int) -> Int {
        (s[k + 1] - s[k]) - (s[k] - s[k - 1])
    }

    /// The independent bends at positions 1 … N − 2, keyed by position.
    static func referenceBends(_ s: [Int]) -> [Int: Int] {
        var result: [Int: Int] = [:]
        var k: Int = 1
        while k <= s.count - 2 {
            result[k] = referenceBend(s, k)
            k += 1
        }
        return result
    }

    /// The independent reversal: result[k] = s[start + end − k] inside, s[k] outside.
    static func referenceReversal(_ s: [Int], start: Int, end: Int) -> [Int] {
        var result: [Int] = []
        for k in 0..<s.count {
            result.append(k >= start && k <= end ? s[start + end - k] : s[k])
        }
        return result
    }

    /// The reversal equals the independent index formula on 500 seeded waves, three sections each.
    @Test func reversalEqualsIndexFormula() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 1)
        for wave in try Self.waves() {
            for _ in 0..<3 {
                let section: (start: Int, end: Int) = Self.section(wave.count, &random)
                let reversed: BackwardsAuroraWave = wave.reversed(start: section.start, end: section.end)
                #expect(reversed.samples == Self.referenceReversal(wave.samples, start: section.start,
                                                                   end: section.end))
                #expect(reversed.count == wave.count)
            }
        }
    }

    /// Every bend, the bend list and the interior equal the separate recomputation.
    @Test func everyBendEqualsRecomputation() throws {
        for wave in try Self.waves() {
            let reference: [Int: Int] = Self.referenceBends(wave.samples)
            #expect(wave.interior == 1...(wave.count - 2))
            #expect(wave.bends.count == wave.count - 2)
            for k in 1...(wave.count - 2) {
                #expect(wave.bend(at: k) == reference[k])
                #expect(wave.bends[k - 1] == reference[k])
            }
        }
    }

    /// Before and after a reversal: no bend outside the section and its seams changes, the bends strictly inside are
    /// the old ones reversed (b'(k) = b(start + end − k)), so away from the seams the bend values are only moved.
    @Test func onlySeamBendsChange() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 2)
        var changedSomewhere: Int = 0
        for wave in try Self.waves() {
            for _ in 0..<3 {
                let section: (start: Int, end: Int) = Self.section(wave.count, &random)
                let after: [Int] = Self.referenceReversal(wave.samples, start: section.start, end: section.end)
                let before: [Int: Int] = Self.referenceBends(wave.samples)
                let reversed: BackwardsAuroraWave = wave.reversed(start: section.start, end: section.end)
                let seams: [Int] = BackwardsAuroraWave.seams(start: section.start, end: section.end, count: wave.count)
                for k in 1...(wave.count - 2) {
                    #expect(reversed.bend(at: k) == Self.referenceBend(after, k))
                    let inside: Bool = k > section.start && k < section.end
                    if !seams.contains(k) && !inside {
                        #expect(reversed.bend(at: k) == before[k])
                    }
                    if inside {
                        #expect(reversed.bend(at: k) == before[section.start + section.end - k])
                    }
                    if reversed.bend(at: k) != before[k] { changedSomewhere += 1 }
                }
                // Away from the seams the bend values are only moved: the multisets agree.
                var oldValues: [Int] = []
                var newValues: [Int] = []
                for k in 1...(wave.count - 2) where !seams.contains(k) {
                    oldValues.append(before[k] ?? 0)
                    newValues.append(reversed.bend(at: k))
                }
                #expect(oldValues.sorted() == newValues.sorted())
            }
        }
        // The random sections do change bends somewhere, so the comparison is not vacuous.
        #expect(changedSomewhere > 0)
    }

    /// The worst bend and smoothness at the worst and one below equal brute force.
    @Test func worstBendAndSmoothnessEqualBruteForce() throws {
        for wave in try Self.waves() {
            var worst: Int = 0
            for k in 1...(wave.count - 2) {
                let magnitude: Int = abs(Self.referenceBend(wave.samples, k))
                if magnitude > worst { worst = magnitude }
            }
            #expect(wave.worstBend == worst)
            #expect(wave.isSmooth(limit: worst))
            #expect(wave.isSmooth(limit: worst - 1) == false)
        }
    }

    /// Checkpoint matches through fixture levels equal a brute-force comparison with the target.
    @Test func checkpointMatchesEqualBruteForce() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 3)
        let waves: [BackwardsAuroraWave] = try Self.waves()
        for fixture in BackwardsAuroraFixtures.fixtures(20) {
            let level: BackwardsAuroraLevel = fixture.level
            var candidates: [BackwardsAuroraWave] = [level.opening, level.target] + fixture.waves
            for wave in waves where wave.count == level.count { candidates.append(wave) }
            for _ in 0..<5 {
                let section: (start: Int, end: Int) = Self.section(level.count, &random)
                candidates.append(level.opening.reversed(start: section.start, end: section.end))
            }
            for wave in candidates {
                var expected: [Bool] = []
                for position in level.checkpoints.sorted() {
                    expected.append(wave.samples[position] == level.target.samples[position])
                }
                #expect(level.matched(wave) == expected)
            }
            #expect(level.matched(level.target).allSatisfy { $0 })
        }
    }

    /// The distance is the unreduced pair (Σ|s − t|, Σ|t|), or (Σ|s − t|, 1) when the target is all zero.
    @Test func distanceEqualsBruteForce() throws {
        let waves: [BackwardsAuroraWave] = try Self.waves()
        var zeroTargets: Int = 0
        var unreduced: Int = 0
        for i in 0..<waves.count {
            for j in i..<min(waves.count, i + 40) where waves[j].count == waves[i].count {
                let wave: BackwardsAuroraWave = waves[i]
                let target: BackwardsAuroraWave = waves[j]
                var numerator: Int = 0
                var denominator: Int = 0
                for k in 0..<wave.count {
                    numerator += abs(wave.samples[k] - target.samples[k])
                    denominator += abs(target.samples[k])
                }
                if denominator == 0 { denominator = 1 }
                let distance: (numerator: Int, denominator: Int) = wave.distance(to: target)
                #expect(distance.numerator == numerator)
                #expect(distance.denominator == denominator)
                #expect(wave.distance(to: wave).numerator == 0)
                if numerator > 0 && denominator > 1 && numerator % 2 == 0 && denominator % 2 == 0 { unreduced += 1 }
            }
        }
        // An all-zero target: the pair is (Σ|s|, 1).
        for wave in waves.prefix(20) {
            let zero: BackwardsAuroraWave = try BackwardsAuroraWave(Array(repeating: 0, count: wave.count))
            var magnitude: Int = 0
            for value in wave.samples { magnitude += abs(value) }
            let distance: (numerator: Int, denominator: Int) = wave.distance(to: zero)
            #expect(distance.numerator == magnitude)
            #expect(distance.denominator == 1)
            #expect(zero.distance(to: zero) == (numerator: 0, denominator: 1))
            zeroTargets += 1
        }
        #expect(zeroTargets == 20)
        // Pairs with a common factor were met, so the check covers the unreduced form.
        #expect(unreduced > 0)
    }

    /// Palindromes equal a comparison with the reversed slice; reversing twice restores the wave.
    @Test func palindromesAndDoubleReversal() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 4)
        var palindromes: Int = 0
        var others: Int = 0
        for wave in try Self.waves() {
            for _ in 0..<3 {
                let section: (start: Int, end: Int) = Self.section(wave.count, &random)
                var slice: [Int] = []
                for k in section.start...section.end { slice.append(wave.samples[k]) }
                var backwards: [Int] = []
                var k: Int = section.end
                while k >= section.start {
                    backwards.append(wave.samples[k])
                    k -= 1
                }
                let expected: Bool = slice == backwards
                #expect(wave.isPalindrome(start: section.start, end: section.end) == expected)
                let once: BackwardsAuroraWave = wave.reversed(start: section.start, end: section.end)
                #expect((once == wave) == expected)
                #expect(once.reversed(start: section.start, end: section.end) == wave)
                if expected { palindromes += 1 } else { others += 1 }
            }
        }
        // Constant and alternating waves give palindromes; uniform waves give the rest.
        #expect(palindromes > 0)
        #expect(others > 0)
    }

    /// The seams over every (start, end) pair equal a brute-force set for a few counts.
    @Test func seamsEqualBruteForceSet() {
        for count in [12, 13, 20, 32] {
            for start in 0..<(count - 1) {
                for end in (start + 1)..<count {
                    var expected: Set<Int> = []
                    for candidate in 0..<count {
                        let interior: Bool = candidate >= 1 && candidate <= count - 2
                        let atSeam: Bool = candidate == start - 1 || candidate == start || candidate == end
                            || candidate == end + 1
                        if interior && atSeam { expected.insert(candidate) }
                    }
                    let seams: [Int] = BackwardsAuroraWave.seams(start: start, end: end, count: count)
                    #expect(Set(seams) == expected)
                    #expect(seams.count == expected.count)
                    #expect(seams == seams.sorted())
                }
            }
        }
    }
}
