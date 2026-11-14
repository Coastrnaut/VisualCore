// StereoSampleBufferTests — feature 061 (A08-P01) T-A08-102 (FR-A08-102, FR-A08-104; gap G-STEREO): capacity
// rounding and clamping, interleaved frames kept apart per channel, wrap-around, `frames(from:count:)` returns 0 for
// overwritten and unwritten ranges and the exact frames otherwise, `latestFrames` returns the newest frames.
import Testing
@testable import VisualCoreAudioDSP

private func ramp(_ start: Int, _ count: Int, scale: Float) -> [Float] {
    (start..<(start + count)).map { Float($0) * scale }
}

@Test func stereoBufferCapacityRounding() {
    #expect(StereoSampleBuffer(capacityFrames: 1).capacityFrames == 1_024)
    #expect(StereoSampleBuffer(capacityFrames: 1_025).capacityFrames == 2_048)
    #expect(StereoSampleBuffer(capacityFrames: 4_096).capacityFrames == 4_096)
    #expect(StereoSampleBuffer(capacityFrames: 1_000_000).capacityFrames == 131_072)
    #expect(StereoSampleBuffer(capacityFrames: 2_048).totalFrames == 0)
}

@Test func stereoBufferReadsWrittenFramesPerChannel() {
    let buffer = StereoSampleBuffer(capacityFrames: 1_024)
    buffer.write(left: ramp(0, 600, scale: 1), right: ramp(0, 600, scale: -1))
    #expect(buffer.totalFrames == 600)
    var l: [Float] = []
    var r: [Float] = []
    #expect(buffer.frames(from: 100, count: 200, left: &l, right: &r) == 200)
    #expect(Array(l[0..<200]) == ramp(100, 200, scale: 1))
    #expect(Array(r[0..<200]) == ramp(100, 200, scale: -1))
    // Not yet written (end past total) and negative start give 0.
    #expect(buffer.frames(from: 500, count: 101, left: &l, right: &r) == 0)
    #expect(buffer.frames(from: -1, count: 10, left: &l, right: &r) == 0)
    #expect(buffer.frames(from: 500, count: 100, left: &l, right: &r) == 100)
}

@Test func stereoBufferWrapAndOverwriteDetection() {
    let buffer = StereoSampleBuffer(capacityFrames: 1_024)
    var written = 0
    for block in [300, 700, 500, 1_000, 77] {
        buffer.write(left: ramp(written, block, scale: 1), right: ramp(written, block, scale: 0.5))
        written += block
    }
    #expect(buffer.totalFrames == written)   // 2,577
    var l: [Float] = []
    var r: [Float] = []
    let oldest = written - 1_024
    // Overwritten: starts one frame before the oldest retained frame.
    #expect(buffer.frames(from: oldest - 1, count: 10, left: &l, right: &r) == 0)
    #expect(buffer.frames(from: 0, count: 10, left: &l, right: &r) == 0)
    // The whole retained span, crossing the wrap point.
    #expect(buffer.frames(from: oldest, count: 1_024, left: &l, right: &r) == 1_024)
    #expect(Array(l[0..<1_024]) == ramp(oldest, 1_024, scale: 1))
    #expect(Array(r[0..<1_024]) == ramp(oldest, 1_024, scale: 0.5))
    // Latest frames.
    #expect(buffer.latestFrames(100, left: &l, right: &r) == 100)
    #expect(Array(l[0..<100]) == ramp(written - 100, 100, scale: 1))
    #expect(Array(r[0..<100]) == ramp(written - 100, 100, scale: 0.5))
    #expect(buffer.latestFrames(5_000, left: &l, right: &r) == 1_024)
}

@Test func stereoBufferOversizedBlockKeepsNewest() {
    let buffer = StereoSampleBuffer(capacityFrames: 1_024)
    buffer.write(left: ramp(0, 3_000, scale: 1), right: ramp(0, 3_000, scale: 2))
    #expect(buffer.totalFrames == 3_000)
    var l: [Float] = []
    var r: [Float] = []
    #expect(buffer.frames(from: 3_000 - 1_024, count: 1_024, left: &l, right: &r) == 1_024)
    #expect(Array(l[0..<1_024]) == ramp(3_000 - 1_024, 1_024, scale: 1))
    #expect(Array(r[0..<1_024]) == ramp(3_000 - 1_024, 1_024, scale: 2))
}

@Test func stereoBufferMonoWriterSamePointerTwice() {
    let buffer = StereoSampleBuffer(capacityFrames: 1_024)
    let mono = ramp(0, 64, scale: 0.25)
    mono.withUnsafeBufferPointer { p in buffer.write(left: p, right: p) }
    var l: [Float] = []
    var r: [Float] = []
    #expect(buffer.latestFrames(64, left: &l, right: &r) == 64)
    #expect(Array(l[0..<64]) == mono)
    #expect(Array(r[0..<64]) == mono)
}

@Test func stereoBufferUnequalLengthsWriteNothing() {
    let buffer = StereoSampleBuffer(capacityFrames: 1_024)
    buffer.write(left: [1, 2, 3], right: [1, 2])
    #expect(buffer.totalFrames == 0)
    var l: [Float] = []
    var r: [Float] = []
    #expect(buffer.latestFrames(10, left: &l, right: &r) == 0)
    #expect(buffer.frames(from: 0, count: 0, left: &l, right: &r) == 0)
}
