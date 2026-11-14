// DemoAudioSourceTests — feature 047 T-A06-103 (FR-A06-101, FR-A06-102; gap G-AUDIOSOURCE): the demo source fills
// the ring buffer at its rate and is deterministic for a seed. Each test runs well under 3 s.
import Foundation
import XCTest
import VisualCoreAudioDSP
@testable import VisualCoreAudio

@MainActor
final class DemoAudioSourceTests: XCTestCase {
    private func pump(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func testStartFillsBufferAtRealTimePace() throws {
        let source = DemoAudioSource(signal: DemoSignal(seed: 7, mode: .sequence))
        let buffer = SampleRingBuffer(capacity: 65_536)
        try source.start(into: buffer)
        XCTAssertEqual(source.state, .running)
        XCTAssertEqual(buffer.totalWritten, DemoAudioSource.blockFrames, "first block is written synchronously")
        pump(0.25)
        source.stop()
        XCTAssertEqual(source.state, .idle)
        // 0.25 s at 48 kHz is 12,000 frames; accept generous timer jitter but require the timer to have run.
        XCTAssertGreaterThan(buffer.totalWritten, 2 * DemoAudioSource.blockFrames)
        XCTAssertLessThanOrEqual(buffer.totalWritten, 48_000)
    }

    func testStopHaltsWriting() throws {
        let source = DemoAudioSource(signal: DemoSignal(seed: 1, mode: .tone440))
        let buffer = SampleRingBuffer(capacity: 65_536)
        try source.start(into: buffer)
        pump(0.05)
        source.stop()
        let written = buffer.totalWritten
        pump(0.1)
        XCTAssertEqual(buffer.totalWritten, written)
    }

    func testSameSeedGivesIdenticalFirstBlock() throws {
        let a = DemoAudioSource(signal: DemoSignal(seed: 42, mode: .sequence))
        let b = DemoAudioSource(signal: DemoSignal(seed: 42, mode: .sequence))
        let bufferA = SampleRingBuffer(capacity: 4_096)
        let bufferB = SampleRingBuffer(capacity: 4_096)
        try a.start(into: bufferA)
        try b.start(into: bufferB)
        a.stop()
        b.stop()
        var blockA = [Float](repeating: 0, count: DemoAudioSource.blockFrames)
        var blockB = [Float](repeating: 0, count: DemoAudioSource.blockFrames)
        XCTAssertEqual(bufferA.latest(DemoAudioSource.blockFrames, into: &blockA), DemoAudioSource.blockFrames)
        XCTAssertEqual(bufferB.latest(DemoAudioSource.blockFrames, into: &blockB), DemoAudioSource.blockFrames)
        XCTAssertEqual(blockA, blockB)
        XCTAssertTrue(blockA.contains { $0 != 0 }, "the sequence mode is not silent")

        // The source writes exactly what the signal renders.
        var signal = DemoSignal(seed: 42, mode: .sequence)
        var direct = [Float](repeating: 0, count: DemoAudioSource.blockFrames)
        direct.withUnsafeMutableBufferPointer { signal.render(into: $0) }
        XCTAssertEqual(blockA, direct)
    }

    func testRestartReplaysFromTheStart() throws {
        let source = DemoAudioSource(signal: DemoSignal(seed: 3, mode: .sequence))
        let first = SampleRingBuffer(capacity: 4_096)
        let second = SampleRingBuffer(capacity: 4_096)
        try source.start(into: first)
        try source.start(into: second)
        source.stop()
        var a = [Float](repeating: 0, count: DemoAudioSource.blockFrames)
        var b = [Float](repeating: 0, count: DemoAudioSource.blockFrames)
        _ = first.latest(DemoAudioSource.blockFrames, into: &a)
        _ = second.latest(DemoAudioSource.blockFrames, into: &b)
        XCTAssertEqual(a, b)
    }
}
