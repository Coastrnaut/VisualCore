// SeededRandomChoiceTests — feature 203 R02-F03 T-R02F03-005 (FR-R02F03-020..023, SC-R02F03-003).
// Golden values were computed independently in Python by re-implementing xoshiro256** seeded through SplitMix64
// (validated against the seed-42 golden first output 0x15780B2E0C2EC716) together with the documented rules:
// index(below: n) = high 64 bits of n × next() (one draw); Fisher–Yates from the end (i = n−1 … 1, j = index(below: i+1));
// weighted choice u = double() × total, first positive-weight index whose running sum exceeds u.
import Foundation
import Testing
@testable import VisualCoreSimulation

/// Golden and draw-count tests for shuffle, pick and weighted choice.
@Suite struct SeededRandomChoiceTests {
    @Test func indexBelowUsesExactlyOneDraw() {
        var r = SeededRandom(seed: 5)
        var copy = r
        let i = r.index(below: 1000)
        _ = copy.next()
        #expect(r == copy)
        #expect(i == 288)
        let next3: [Int] = (0..<3).map { _ in r.index(below: 1000) }
        #expect(next3 == [602, 649, 821])
        var one = SeededRandom(seed: 9)
        for _ in 0..<100 { #expect(one.index(below: 1) == 0) }
        for _ in 0..<1000 { #expect((0..<7).contains(one.index(below: 7))) }
    }

    @Test func goldenShuffleOfZeroToNineWithSeed7() {
        var r = SeededRandom(seed: 7)
        var items = Array(0...9)
        r.shuffle(&items)
        #expect(items == [1, 8, 3, 0, 4, 5, 9, 6, 2, 7])
        #expect(items.sorted() == Array(0...9))
        var s = SeededRandom(seed: 7)
        let copy = s.shuffled(Array(0...9))
        #expect(copy == items)
    }

    @Test func shuffleUsesNMinusOneDraws() {
        var r = SeededRandom(seed: 7)
        var expected = r
        var items = Array(0..<25)
        r.shuffle(&items)
        for _ in 0..<24 { _ = expected.next() }
        #expect(r == expected)
        var e = SeededRandom(seed: 3), eCopy = e
        var empty: [Int] = [], single = [42]
        e.shuffle(&empty); e.shuffle(&single)
        #expect(e == eCopy)
        #expect(empty.isEmpty && single == [42])
    }

    @Test func pickGoldenAndOneDraw() throws {
        var r = SeededRandom(seed: 11)
        let items = Array(0..<10)
        let picks = try (0..<8).map { _ in try r.pick(items) }
        #expect(picks == [2, 0, 2, 4, 0, 3, 5, 9])
        var a = SeededRandom(seed: 4), b = a
        _ = try a.pick(["x", "y", "z"])
        _ = b.next()
        #expect(a == b)
    }

    @Test func pickReportsEmpty() {
        var r = SeededRandom(seed: 1), before = r
        #expect(throws: RandomChoiceError.empty) { try r.pick([Int]()) }
        #expect(r == before)
    }

    @Test func weightedIndexGoldenCountsNeverZeroWeight() throws {
        var r = SeededRandom(seed: 2026)
        var counts = [0, 0, 0]
        for _ in 0..<1000 { counts[try r.weightedIndex([1, 0, 3])] += 1 }
        #expect(counts == [248, 0, 752])
        var a = SeededRandom(seed: 8), b = a
        _ = try a.weightedIndex([0.5, 0.5])
        _ = b.next()
        #expect(a == b)
        var z = SeededRandom(seed: 12)
        for _ in 0..<1000 { #expect(try z.weightedIndex([0, 0, 2, 0]) == 2) }
    }

    @Test func weightedIndexReportsInvalidInput() {
        var r = SeededRandom(seed: 1), before = r
        #expect(throws: RandomChoiceError.empty) { try r.weightedIndex([]) }
        #expect(throws: RandomChoiceError.negativeWeight(1)) { try r.weightedIndex([1, -0.5, 2]) }
        #expect(throws: RandomChoiceError.nonFiniteWeight(2)) { try r.weightedIndex([1, 2, .nan]) }
        #expect(throws: RandomChoiceError.nonFiniteWeight(0)) { try r.weightedIndex([-.infinity, 1]) }
        #expect(throws: RandomChoiceError.zeroTotal) { try r.weightedIndex([0, 0, 0]) }
        #expect(throws: RandomChoiceError.zeroTotal) { try r.weightedIndex([.greatestFiniteMagnitude, .greatestFiniteMagnitude]) }
        #expect(r == before)
    }
}
