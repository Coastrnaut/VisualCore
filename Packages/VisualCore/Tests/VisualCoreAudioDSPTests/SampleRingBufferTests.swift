// SampleRingBufferTests — feature 047 (A06-P01) T-A06-102 (FR-A06-110; SC-A06-102): 200 seeded write/read sequences
// against a reference model of "latest" semantics, overflow drops the oldest, capacity rounding.
//
// Allocation check (research D6): not automated here. Darwin's malloc zone statistics count live blocks only, so a
// temporary allocate/free in `write` would not show, and Swift Testing runs other suites in parallel in the same
// process, which makes any process-wide counter flaky. The write path is pointer arithmetic plus `update(from:count:)`
// on storage allocated in `init`; allocation-freedom is verified by inspection and in the device campaign.
import Testing
@testable import VisualCoreAudioDSP

/// Local seeded generator for the tests (SplitMix64).
private struct TestRNG {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }
}

@Test func capacityIsRoundedUpToAPowerOfTwoAndClamped() {
    #expect(SampleRingBuffer(capacity: 0).capacity == 1_024)
    #expect(SampleRingBuffer(capacity: 1_000).capacity == 1_024)
    #expect(SampleRingBuffer(capacity: 1_024).capacity == 1_024)
    #expect(SampleRingBuffer(capacity: 1_025).capacity == 2_048)
    #expect(SampleRingBuffer(capacity: 100_000).capacity == 131_072)
    #expect(SampleRingBuffer(capacity: 262_144).capacity == 262_144)
    #expect(SampleRingBuffer(capacity: 1_000_000).capacity == 262_144)
}

@Test func emptyBufferReadsNothing() {
    let buffer = SampleRingBuffer(capacity: 1_024)
    var out: [Float] = []
    #expect(buffer.latest(100, into: &out) == 0)
    #expect(out.isEmpty)
    #expect(buffer.totalWritten == 0)
}

@Test func overflowDropsTheOldest() {
    let buffer = SampleRingBuffer(capacity: 1_024)
    let samples = (0..<3_000).map(Float.init)
    samples.withUnsafeBufferPointer { buffer.write($0) }
    #expect(buffer.totalWritten == 3_000)
    var out: [Float] = []
    #expect(buffer.latest(5_000, into: &out) == 1_024)
    #expect(Array(out.prefix(1_024)) == Array(samples.suffix(1_024)))
    #expect(buffer.latest(3, into: &out) == 3)
    #expect(Array(out.prefix(3)) == [2_997, 2_998, 2_999])
}

@Test func preallocatedOutputIsNotShrunk() {
    let buffer = SampleRingBuffer(capacity: 1_024)
    [Float](repeating: 1, count: 10).withUnsafeBufferPointer { buffer.write($0) }
    var out = [Float](repeating: -1, count: 64)
    #expect(buffer.latest(64, into: &out) == 10)
    #expect(out.count == 64)
    #expect(Array(out.prefix(10)) == [Float](repeating: 1, count: 10))
    #expect(out[10] == -1)
}

@Test func seededSequencesMatchAReferenceModel() {
    var rng = TestRNG(state: 0x0047_A06_102)
    let requested = [1_000, 1_024, 2_048, 4_096]
    var next: Float = 0
    for _ in 0..<200 {
        let buffer = SampleRingBuffer(capacity: requested[rng.int(0...3)])
        var model: [Float] = []
        var total = 0
        var out: [Float] = []
        for _ in 0..<8 {
            let length = rng.int(1...3_000)
            let chunk = (0..<length).map { _ -> Float in next += 1; return next }
            chunk.withUnsafeBufferPointer { buffer.write($0) }
            total += length
            model += chunk
            if model.count > buffer.capacity { model.removeFirst(model.count - buffer.capacity) }

            let want = rng.int(0...5_000)
            let copied = buffer.latest(want, into: &out)
            let expected = min(want, buffer.capacity, total)
            #expect(copied == expected)
            #expect(Array(out.prefix(copied)) == Array(model.suffix(expected)))
            #expect(buffer.totalWritten == total)
        }
    }
}
